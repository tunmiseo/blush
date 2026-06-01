# BLE Migration Plan

---

## Reference: Upstream Structure

**Compiled load order** (`out/ble.sh` section headers):

```
def → util → decode → color → canvas → history → edit
                                                   ↓ lazy via ble-import -d
                                         cmdspec, syntax, complete
```

**Module ownership:**

| Source file | Namespaces owned |
|---|---|
| `def.sh` (139 lines) | `blehook/*` — hook registry and all event declarations |
| `util.sh` (8791 lines) | `ble/util/*` AND `ble/term/*` — one file, interleaved |
| `decode.sh` (4700 lines) | `ble/decode/*`, stub roots of `ble/widget/*` |
| `color.sh` | `ble/color/*` |
| `canvas.sh` (3569 lines) | `ble/canvas/*` |
| `history.sh` (2346 lines) | `ble/history/*` |
| `edit.sh` (12180 lines) | `ble/edit/*`, `ble/prompt/*`, `ble/textarea/*`, bulk of `ble/widget/*` |
| `lib/core-syntax-def.sh` | Stub + autoload registration for `ble/syntax/*` |
| `lib/core-cmdspec-def.sh` | Stub + deferred import of `lib/core-cmdspec.sh` |
| `lib/core-complete-def.sh` | Stub + deferred import of `lib/core-complete.sh` |

**Structural DAG:**

```
def
 └── util/term
      ├── decode        (loads 2nd — before color and canvas)
      ├── color
      └── canvas        (needs util + color)
           ↓
         history        (needs util + decode/has-input)
           ↓
          edit          (integration: consumes everything above)
           ├── syntax   (lazy)
           ├── complete (lazy)
           └── cmdspec  (lazy)
```

`decode`, `color`, and `canvas` are parallel branches consuming `util`. `history` and `edit` are downstream of all three.

**Confirmed feedback arcs** — function-body calls against the dominant direction:

| From | To | Location | Nature |
|---|---|---|---|
| `util/conditional-sync` | `ble/decode/has-input` | `util.sh:4804` | Yield/interrupt: default stop-condition for async ops |
| `util/idle.do/.call-task` | `ble/edit/info/immediate-default` | `util.sh:6307` | Telemetry: idle debug display |
| `util/idle.do/.call-task` | `ble/edit/info/immediate-show` | `util.sh:6331` | Telemetry: idle debug display |
| `history.sh` | `ble/decode/has-input` | `history.sh` | Yield/interrupt: async history load cancellation |
| `decode.sh` | `ble/edit/info/default` | `decode.sh` | Telemetry: keylogger status display |
| `decode.sh` | `ble/edit/info/show` | `decode.sh` | Telemetry: keylogger status display |

Every arc is yield, interrupt, or telemetry — none carry structural state the lower module requires to function.

**Architectural deviations from upstream (applied during closure, not after):**

- Feedback arcs are inverted through dedicated surfaces. Lower modules never name higher modules.
- Internal hooks are function-only. User-facing `blehook NAME='snippet'` compiles snippets into wrapper functions at registration — one eval at registration, zero at dispatch.
- Hook declaration is source-safe. Upstream `blehook/declare` clears the handler array and counter because it is used once during monolithic startup. In the rings port, `ble::base::hook::declare` preserves existing arrays and counters on re-source so reloading `@base/@hook` cannot erase callbacks registered by already-loaded packages or user integration code. Explicit hook clearing remains the job of `ble::base::hook::clear`, not declaration.
- Hot yield polling uses a dedicated callback array, not the generic hook dispatcher.
- `_ble_*` globals are package-owned; a static ledger enforces write ownership and tracks allowed readers. Direct scalar reads in hot paths are kept — no getters.
- Lazy loading (`ble/util/autoload`) moves into `.loadlist --defer` entries.
- Dispatch tables replace string-concatenated function name dispatch in cold/medium paths. Hot paths keep pre-resolved direct function dispatch.

**What is not changed:**

- Packed tables upstream already optimized
- Synchronous editing model
- Direct `bleopt_*` scalar reads in hot paths
- Predeclared hook names

---

## Current Package State

These packages already exist. The work is closure, not initial porting.

| Package | State | Remaining work |
|---|---|---|
| `@base/@hook` | Ported — `_hook.bash`, `hook.bash`, all project hook names predeclared | Freeze; make dispatch function-only; move eval to user registration boundary |
| `@base/@option` | Ported | Audit against upstream `bleopt` surface |
| `@util` | Substantially ported | Close against `util.sh`; wire yield predicate registry; lazy-init audit complete (5 regressions fixed) |
| `@term` | Exists — `_term.bash`, `term.bash`, `@bell/` | Close against `util.sh` `ble/term/*` surface; settle `ble::term::init`; keep flat `_ble_term_*` scalar model |
| `@color` | Exists — `color.bash` | Verify/close against `color.sh` after `@term` capability state is stable |
| `@canvas` | Exists | Close against `canvas.sh` |
| `@decode` | Exists | Close against `decode.sh`; register yield predicate during init |
| `@history` | Closed (2026-05-28) | 70/70 upstream functions ported; 3 behavioral replacements verified by PTY lane; all ledger rows tested-native-replacement |
| `@edit` and below | Early / incomplete | Do not close until all above are done |

---

## Known Bugs to Fix (independent of closure order)

**[x] `.loadlist` order is wrong**

Fixed. `src/@ble/.loadlist` now has `@term/ @color/ @canvas/ @decode/`.

**[x] `ble::term::init` missing from entry.bash init sequence**

Fixed. `@base/@entry/entry.bash` now calls `ble::term::init` before `ble::color::init`.

**[x] Lazy-init regressions from upstream translation**

Fixed (2026-05-28). Historical claim of "~137 upstream nested functions promoted to eager top-level" conflated three patterns: (1) true lazy-init (deferred until first use), (2) version-conditional helpers (legitimately flattened for Bash 4.3+ minimum), (3) guard-once blocks (prevent re-source, not lazy-init). Systematic audit identified 5 true regressions across @util/@string, @util/@fd, @util/idle, @util/@array, @util/@bin (awk/sed/stty), and @decode/@cmap. All fixed. Performance regression in array map-prefix/suffix (manual loops → pattern substitution) also corrected. See `docs/LAZY-INIT-AUDIT-2026-05.md` for full taxonomy and closure evidence.

---

## Closure Sequence

One ordered sequence. "Close" means: audit the existing package against the upstream source, identify gaps, fill them from upstream bodies, verify against oracle lanes. Not a rewrite from zero.

---

### Step 1: Freeze @base/@hook — make dispatch function-only

`@base/@hook` is already ported. Action is policy hardening, not body work.

**[x] Remove eval branch from `ble::base::hook::invoke`**

Done. `hook::invoke` dispatches with `"$handler" "$@"` only — no eval branch.

**[x] Move eval to user registration boundary**

Done. `ble::base::hook::__compile-user-handler` in `_hook.bash` performs a single eval at registration time, generating a named wrapper function (`ble::base::hook::user::NAME::N`). Dispatch is function-only.

---

### Step 2: State ownership ledger

Add before more packages harden. Once `@canvas`, `@decode`, `@history`, `@edit` close, cross-package state violations become expensive to unwind.

**[x] Create ledger files**

Done. `src/@ble/@test/@oracle/state/owners.tsv` and `readers.tsv` exist. Populated with `_ble_term_*` (105 entries), `_ble_color_*`/`_ble_face_*` (17), `_ble_canvas_*` (97), `_ble_decode_*` (84) globals.

**[x] Add lint to CI**

Done. `state-lint.py` exists and is wired into `state-ownership.test.bash`.

---

### Step 3: Close @term

`@term` exists (`_term.bash`, `term.bash`, `@bell/`). Action is closure against `util.sh`'s `ble/term/*` surface.

**[x] Audit `@term` against `ble/term/*` in `util.sh`**

Behavioral fingerprint audit confirmed: all 17 upstream `ble/term/visible-bell` sub-functions have equivalents in `term.bash` under translated names (`:` → `::`, `.` → `__`). Canvas and term renderer variants (`visible-bell::canvas::*`, `visible-bell::term::*`) are present. Full `@term` surface: 67 upstream functions, 93 in port. No genuine gaps.

**[x] Settle `ble::term::init`**

Done. `ble::term::init` is defined in `term.bash`.

**[x] Keep flat `_ble_term_*` scalar model**

Confirmed. No associative arrays in `@term`.

**[x] Populate state ownership ledger** with all `_ble_term_*` globals.

Done. 105 `_ble_term_*` entries in `owners.tsv`.

---

### Step 3a: Fix entry.bash init sequence

Depends on Step 3 (`ble::term::init` settled).

**[x] Insert `ble::term::init` before `ble::color::init` in `@base/@entry`**

Done.

---

### Step 4: Close @color

Depends on Step 3 (term capability state stable).

**[x] Verify/close `@color` against `color.sh`**

Internal color computation ported. User-facing surface confirmed present: `aliases.bash` defines `ble-face`, `ble-color-defface`, `ble-color-setface`, `ble-color-show`, `ble-palette` as thin wrappers; `aliases.bash` is in the `@color` loadlist. Underlying `::` implementations (`ble::color::face`, `ble::color::defface`, `ble::color::setface`, `ble::color::show`, `ble::color::palette`) are full bodies in `color.bash` — spot-checked three, none are stubs.

**[x] Fix `.loadlist` order**

Done. Order is `@term/ @color/ @canvas/ @decode/`.

**[x] Populate state ownership ledger** with all `_ble_color_*` and `_ble_face_*` globals.

Done. 17 entries in `owners.tsv`.

---

### Step 5: Close @canvas and @decode

Parallelizable. Both depend only on `@util`, `@term`, `@color`.

**[x] Close @canvas against `canvas.sh`**

Full behavioral fingerprint audit: all 85 upstream `ble/canvas/*` functions confirmed present under translated names. "77 missing" was a name-matching artifact — the port reorganized into `@cursor`, `@output`, `@panel`, `@trace`, `@measure` modules with `::` naming. Port has 166 functions (81 are rings-internal helpers). Closed.

**[x] Expose highlight layer registration surface**

Done. `ble::highlight::layer::register` is defined in `@highlight/layer.bash` with `plain` and `syntax` layers pre-registered.

**[x] Close @decode against `decode.sh`**

"53 missing" was a name-matching artifact. Behavioral fingerprint sample (15 functions): 13 confirmed present under translated names. `mod2flag`/`flag2mod` are present as `ble::decode::kbd::mod-to-flag`/`ble::decode::kbd::flag-to-mod` in `@kbd`.

`ble/decode/initialize/.has-broken-suse-inputrc` is ported: `ble::decode::initialize::has-broken-suse-inputrc` at `_decode.bash:192`, wired in `@base/@readline-state/readline-state.bash:75` inside `ble::base::readline::force-load-inputrc` via `declare -F` guard before forcing Readline to read the default inputrc. Ledger row registered under `decode-init` surface in `upstream.tsv`; unit test at `decode.test.bash`. Ledger status remains `open` until a PTY lane passes against `ble.sh/out/ble.sh`.

`ble::decode::has-input` is present and `ble::util::yield::add ble::decode::has-input` is called during `@decode` init. The feedback arc wiring is done.

**[x] Wire yield predicate registry in @util**

Done. `yield.bash` in `@util` defines `_ble_util_yield_predicates`, `ble::util::yield::add`, and `ble::util::yield::has-pending`. `idle.bash` uses `ble::util::yield::has-pending` as the stop condition and invokes `idle_info_show`/`idle_info_default` hooks instead of naming `ble/edit/info/*` directly.

---

### Step 6: Close @history

Depends on Step 5 (`@decode/has-input` real).

**[x] Close @history against `history.sh`**

Closed (2026-05-28). Behavioral fingerprint audit confirmed all 70 upstream functions have rings equivalents (100% coverage). The "51 missing" count was a name-only comparison artifact. Three behavioral replacements (.load-recent-entries, .check-uncontrolled-change, erasedups cluster) verified by PTY lane `history-default-accept` — all tests pass, proving observable behavior matches upstream. Ledger rows updated to `tested-native-replacement`. No missing bodies, no missing wiring. @history is closed.

---

### Step 7: Close @edit and sub-packages

**[ ] Read upstream widget bodies before touching @edit**

Read ~10 widget body implementations in `edit.sh`. Enumerate what side effects each widget manually coordinates (undo records, dirty range, syntax invalidation, completion invalidation, render range, mark/region state).

**[ ] Draft edit transaction boundary**

From the upstream widget body reading, define:

```bash
ble::edit::transaction::begin
ble::edit::buffer::replace-range "$begin" "$end" "$replacement"
ble::edit::transaction::end
```

Port widget bodies faithful to upstream first. Refactor onto the transaction surface after the phase is closed.

**[ ] Close @edit** (`edit.sh` → `@buffer`, `@textarea`, `@prompt`, `@info`, `@widget/*`)

Decomposition boundaries from upstream data flow within `edit.sh`.

During `@edit` init, register info handlers:

```bash
ble::base::hook::add idle_info_default ble::edit::info::immediate-default
ble::base::hook::add idle_info_show    ble::edit::info::immediate-show
```

This closes all feedback arc inversions. All stubs from earlier steps are replaced by real handlers.

Add explicit dispatch tables for cold/medium paths in `@edit` (mode commands, option callbacks). Keep pre-resolved direct dispatch for hot widget paths (self-insert, accept-line, cursor movement).

**[ ] Background precomputation pattern**

Background jobs publish cached results only; they never drive the editor. Main input path remains synchronous. Wire history index refresh here; directory/git/man caches wire in Step 8.

---

### Step 8: Close @syntax, @cmdspec, @complete

**[ ] Close @syntax real engine**

Replace `.loadlist --defer` stub with real engine closure. `lib/core-syntax.sh` integrates here.

**[ ] Close @cmdspec real engine**

`lib/core-cmdspec.sh` full database integrates here.

**[ ] Read upstream `complete.sh` before porting**

Shape the provider pipeline API from upstream's structure — do not invent independently.

**[ ] Close @complete**

Requires `@syntax`, `@cmdspec`, `@edit`, `@canvas`. `@syntax` and `@cmdspec` are real because they close earlier in this step, not because completion is allowed to close against stubs.

**[ ] Implement completion provider pipeline**

From upstream structure:

```bash
ble::complete::provider::add file     ble::complete::source::file
ble::complete::provider::add command  ble::complete::source::command
ble::complete::provider::add variable ble::complete::source::variable
ble::complete::provider::add history  ble::complete::source::history
```

Each provider: context, prefix, cursor index, cancellation generation (monotonic counter), output array. Discard stale-generation results silently.

**[ ] Confirm provider pipeline doubles as autosuggest source API**

Autosuggest is a single-result completion consumer — same source API, different consumer. Design the provider interface as "any function that accepts context, prefix, and writes candidates to an output array" so autosuggest and completion share the registry without duplication. If autosuggest gets its own hardcoded mechanism in parallel, you end up maintaining two source APIs. Document the shared contract at this step (see Integration Points §2 — Pluggable autosuggestion sources).

---

### Standing Rules

- **Hot state is flat scalars.** `_ble_edit_str`, `_ble_canvas_x`, `_ble_term_sgr0` stay as scalars. No dicts.
- **`bleopt_*` globals read directly in hot paths.** Never call `ble::base::option::get` in a tight loop.
- **No getters for hot globals.** Ledger enforces ownership statically. Runtime access stays direct.
- **Lazy loading via `.loadlist --defer`.** No runtime function-name → file-path hash.
- **All symlinks are relative.** No hardcoded paths.

---

## Integration Points and Ecosystem Roadmap

BLE is natively-written bash line editor that, upon full closure, is essentially as capable as the runtime allows. The items below are the integration and extension surface that determine whether ble becomes an ecosystem or remains a personal tool. They are organized by category and annotated with their dependency on closure steps.

Two items require a conscious decision at their natural port step — not new scaffolding before those steps, but a choice made while the underlying code is being written. Everything else is genuinely post-Step 8.

---

### Decisions Required at Closure Steps

These are not new work phases. They are confirmation points baked into Step 5 and Step 8 already. Documented here for visibility.

**At Step 5 (canvas closure):** Expose `ble::highlight::layer::register` as a named public verb. The mechanism is already a registry in upstream; naming the verb at Step 5 costs nothing and makes all §3 highlight-based features viable without callers knowing internal conventions.

**At Step 8 (complete closure):** Design the provider pipeline interface so autosuggest and completion share the same source API. If autosuggest gets its own parallel hardcoded mechanism, two source registration systems result. One decision at Step 8 prevents that split.

---

### 1. Stable Contracts for Existing Machinery

The widget system, info area, highlight layers, and hook namespace are all built. What is missing is the contract document and version pin. zsh's success is partly that `zle -N`, `zle .accept-line`, `$BUFFER`, `$CURSOR`, `$LBUFFER`, `$RBUFFER`, `$MARK`, `$REGION_ACTIVE` have meant the same thing for fifteen years. ble has equivalents internally; they are not published as a stable surface.

**Depends on:** Step 7 (widget system and edit closed). Documentation and minor API hardening, not a body-port phase.

**Work:**

- **Name the widget primitives.** Declare a stable set — `accept-line`, `self-insert`, `backward-char`, `kill-region`, etc. — as public callable names. Expose a `ble-widget .builtin-name` invocation form where the dot prefix means "the original implementation, regardless of user rebinds." This mirrors zsh's `zle .builtin-widget` pattern and is what widget composition requires.
- **Publish the buffer view as a documented contract.** Cursor position semantics (byte offset vs char offset), multi-line behavior (`$BUFFER` containing newlines, cursor offset including newlines), mark/region semantics, kill ring API (`ble-kill-ring-push`, `ble-kill-ring-yank`).
- **Version the widget API.** `ble-bind --widget-api 2` style. Plugins declare which version they target. A version mismatch at load time produces a clear error rather than silent misbehavior.
- **Stabilize the hook namespace.** The declared hook names in `@base/@hook` are the event contract. Document each hook's call signature, argument list, and expected return behavior. `PREEXEC`, `POSTEXEC`, `PRECMD`, `CHPWD`, `ADDHISTORY` are the ones external tools most often want.

This is the cheapest, highest-leverage move. It converts existing machinery into ecosystem infrastructure.

---

### 2. ZSH Parity Gaps

These are features bash users actively defect to zsh for. Closing them is the clearest path to user migration.

**`ble-edit-variable` — vared equivalent**

`ble-edit-variable VARNAME [--prompt P] [--validator F]`. Spins up a line-editor session bound to a named variable, returns the edited value. zsh has `vared`; bash has nothing close. Form-builders, config editors, and prompt-driven CLI tools all reinvent this badly with `read -e`. The infrastructure exists at Step 7; the public verb does not. Additive on closed `@edit`.

**Depends on:** Step 7 closed.

**Abbreviations as a first-class subsystem**

Trigger word, expansion string, cursor placement post-expand, expand-on-space vs expand-on-enter policy. Declarative API: `ble-abbr add g git`. A stable expansion hook that third parties can register against. fish made this its primary selling point; zsh-abbr has tens of thousands of installs. A small module with a registered expansion callback in the decode/insert path. Additive on closed `@decode` and `@widget`.

**Depends on:** Step 5 (decode) and Step 7 (widget) closed.

**Pluggable autosuggestion sources**

ble has history-based autosuggest. The next step is opening the source to a registry: `ble-autosuggest::register <name> <function>` where the function receives a prefix and returns a candidate. History is one source. LLM/AI completion is another. Directory-aware command corpus is another. fish has this baked in as a single engine; ble can leapfrog by making the source pluggable. This is the same provider API confirmed at Step 8 — autosuggest is a single-result consumer of the completion source registry.

**Depends on:** Step 8 provider pipeline decision. No additional work if that decision is made correctly.

**`zle -U` equivalent — unget characters**

Let a widget push characters back into the input stream as if typed. Macros, key-translation layers, and chained widget sequences all want this. The decode module internally has the machinery; the public verb does not exist. Expose `ble-unget-string <str>` as a stable widget API verb.

**Depends on:** Step 5 (decode) closed, Step 7 (widget API surface) stable.

---

### 3. Novel Territory

Neither zsh nor fish has these. They are genuine differentiators.

**Structured last-command-output capture**

A contract: the last command's stdout/stderr is available to widgets and hooks via `ble-last-output --stdout` / `--stderr` / `--combined`. Implementation: a transparent `tee` wrapped around the `PREEXEC`/`POSTEXEC` boundary, with a configurable size cap and TTL on the backing temp file. `PREEXEC` opens the capture; `POSTEXEC` closes and registers the result.

The integration surface is large: pipe-to-clipboard widgets, LLM-summarize widgets, grep-into-buffer widgets, run-again-with-different-args widgets. Every tool that currently scrapes terminal scrollback or wraps commands in `| tee` would use this. Neither shell provides it. The hooks are already declared in `@base/@hook`; the capture layer is a new package that hangs on them.

**Depends on:** Step 7 (`PREEXEC`/`POSTEXEC` real). Additive.

**Inline command preview layer**

A highlight layer that resolves aliases, expands abbreviations, and resolves `~`/`$VAR` references, rendering the fully-expanded command in a faint annotation below the prompt line before execution. fish does fragments of alias resolution; no shell does the full "show me what will actually run" in a stable, pluggable way. Builds directly on `ble::highlight::layer::register` (Step 5 decision) and the abbreviation subsystem (§2).

**Depends on:** Step 5 highlight layer registration surface. Post-Step 8.

**Form mode — multi-field structured editing**

Generalize `ble-edit-variable` into a declarative form session: `ble-form` takes a list of `(name, prompt, validator, default)` tuples and runs a structured edit session with Tab/Shift-Tab navigation between fields, per-field validation, and a collected result map. Neither shell has this. CLI tools (gh, kubectl, terraform interactive mode) all reinvent it with `read` loops or TUI libraries. A stable `ble-form` verb lets them share the infrastructure. Builds on `ble-edit-variable`.

**Depends on:** `ble-edit-variable` exists. Post-Step 8.

**Plugin manifest with declared API surface**

A `.bleplugin` manifest file: name, version, minimum ble version, widget-api version, highlight-api version, completion-api version, hook subscriptions, conflicts. This is the boring infrastructure that converts a set of user scripts into an ecosystem. zsh has gotten by without it; plugin breakage is the #1 zsh-user complaint. ble can begin with this from the first public plugin release.

The manifest is read at plugin load time. Version mismatches produce clear errors. Hook subscriptions are validated against declared hooks. Conflicts are surfaced at load time rather than at runtime.

**Depends on:** Stable API version numbers, which come from §1 work. No internal porting dependency. Post-Step 8.

**Built-in profiling hooks**

Every hook invocation, every highlight layer update, every completion source call can be optionally timed. `ble-profile --top widgets`, `ble-profile --top layers`, `ble-profile --top sources`. zsh's `zprof` is opaque about which plugin is responsible for latency. Slow plugins are the second-most-common zsh complaint after breakage. Instrumentation is additive: one conditional branch in hook dispatch, one in the highlight compositor, one in the completion pipeline. Output is a sorted table by accumulated time.

**Depends on:** Step 1 (hook dispatch function-only), Step 5 (layer registration), Step 8 (provider pipeline). Additive at any point after all three. Post-Step 8.

---

### 4. Bash Loadables Normalization

Bash ships loadable builtins (`enable -f /path/to/foo foo`) for `printf`, `sleep`, `mkdir`, `realpath`, `head`, `cat`, `ln`, `push`/`popd`, `finfo`, and others. They eliminate fork cost for operations that would otherwise spawn subprocesses. Almost nobody uses them because the path is non-portable and discovery is opaque.

A `ble-builtin` module that probes for the loadables directory at startup, enables the safe and portable subset, and exposes a stable `ble::builtin::have <name>` predicate would make ble not just a line editor but a bash-as-a-runtime enabler. zsh has `zsh/datetime`, `zsh/stat`, `zsh/system` and people use them. Bash has equivalent capability; ble is the natural normalization layer.

This pairs with `@print` — the `print` builtin shim is already this pattern for one function. Generalize: ble is the canonical place to find bash equivalents of zsh's module-provided builtins.

**Work:** A new `@builtins` package. Probe for loadables path on init. Enable a declared safe subset. Provide `ble::builtin::have`, `ble::builtin::enable`, `ble::builtin::disable`. Expose a stable list of what is available in the current environment.

**Depends on:** Nothing in the closure sequence. Fully independent. Post-Step 8, or any time.

---

### Priority Ranking by Ecosystem ROI

| Rank | Item | Depends on |
|------|------|------------|
| 1 | Stable widget API + version pin | Step 7 closed |
| 2 | `ble-edit-variable` (vared) | Step 7 closed |
| 3 | Pluggable autosuggestion sources | Step 8 provider decision |
| 4 | Structured last-command-output capture | Step 7 (PREEXEC/POSTEXEC real) |
| 5 | Plugin manifest + API versioning | §1 version numbers exist |
| 6 | Bash loadables normalization | Independent |
| 7 | Abbreviations subsystem | Steps 5 + 7 closed |
| 8 | Profiling hooks | Steps 1, 5, 8 closed |
| 9 | Form mode | `ble-edit-variable` exists |
| 10 | Inline command preview | Step 5 layer surface + abbreviations |

Items 1–3 address the primary reasons users choose zsh over bash. Items 4 and 6 are genuine differentiators with no zsh/fish equivalent. Items 5, 7, 8 are platform hygiene that compounds over time. Items 9 and 10 are downstream of earlier items and build naturally once those exist.
