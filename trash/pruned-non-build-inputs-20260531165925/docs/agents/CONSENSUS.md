# CONSENSUS — Settled `@ble` Repo Points

This file records settled `@ble` repository points that are easy to regress in review or maintenance.

-----

## 1. Source of Truth and Activation

- The filesystem reflects the current `@ble` repository state. There is no additional central metadata store.
- The loadlist (`.loadlist`) controls future-session activation.

-----

## 2. Loader, Modules, and Packages: Layer and Variable Boundaries

- `$RING_ROOT` names the root of any ring. `$PROFILE_D` is the login-ring alias only, where `$PROFILE_D == $RING_ROOT`.
- The loader reads `.loadlist`, recurses, and may read directory-local loader metadata such as `.env`. It does not supply
module or package semantics.

## 3. Layer 4: Collections and Profiles

- Layer 4 succeeds layer 3.
- Collections are named membership objects over package ids, nominal in identity; extensional in membership.
- Declared collection membership is authoritative in `.package`.
- `.collections` is a derived cache rebuilt from those declarations.
- Profiles are registry-first identity-bearing contexts referencing collections.
- Packages declare collection membership, not profile membership.
- Profile switching is persistent.
- Manual drift under an active profile is allowed.
- Host/context overlays are superseded by collection + profile semantics.
- Secrets are referenced via `@secrets.d`, not stored directly in profiles.
- `@collections.d` and `@profiles.d` are ordinary correspondent submodules under the `@packages.d` chain.

-----

## 4. Metadata Role Boundaries

- `.package` is package identity and manifest.
- `.module` is module-level metadata, including `default_ownership`.
- `.env` is directory-local rings metadata read on directory entry before `.loadlist`. It is not the place for durable exported environment state.
- `env.d` contains durable exported environment artifacts.

-----

## 5. Ownership

- Ownership is per artifact, not per package.
- Registry-owned and module-owned are co-equal first-class states.
- Ownership precedence is: per-artifact override, then `.package`, then `.module`.
- A package may be module-owned in one file group and registry-owned in another.
- Choose ownership by where the real files are intended to live and be edited.
- If the intended editing location is a module directory such as `functions.d/@pkg/` or `aliases.d/@pkg/`, that file group should be module-owned.
- If the intended editing location is `packages.d/@pkg/`, that file group should be registry-owned.
- A `.loadlist` file is an artifact.
- Ownership of `.loadlist` files is decided per file, like any other artifact.
- For each `.loadlist`, only one path holds the real bytes.
- Any corresponding path is a projection or reverse-projection of that same `.loadlist`.
- The reason is to keep loading behavior the same regardless of which corresponding path is used.
- Flat convenience forms are non-canonical paths, but they are expected to be common in `.loadlist` use, especially when toggling individual artifacts.

-----

## 6. Namespace Derivation

- Function namespace follows package scope, not filesystem seat. A callable rings function takes its `::` namespace from the package scope that exports it. When that scope is inside reserved `@core`, the `core::` portion may be elided in the public surface.
- `packages::reconcile` from `@core/@packages.d` uses the namespace `packages::`.
- `modules::reconcile` from `@core/@modules` uses the namespace `modules::`.
- Do not derive callable names from filesystem seat alone, and do not invent a separate domain namespace when the package scope already determines it.
- The literal `_` segment is transparent to package scope. `@a/_/@b` and `@a/@b` derive the same callable namespace.
- Singleton files may represent same-named subpackage leaves. `@pkg/tool.sh` and `@pkg/@tool/tool.sh` are equivalent forms of the same concern when `tool` is singleton-eligible.
- Registry seats and module seats are co-equal materializations. Callable namespace follows the reconciled package scope, not whichever seat currently holds the real bytes.

### 6.1 Private Helpers

[`docs/rings/PACKAGES.md`](../rings/PACKAGES.md) §10 is the active authority for package privacy and public calls. `docs/rings` is the shared rings specification symlink, not local BLE-only documentation.

- Private helpers are private to the package and its descendants.
- A descendant may use ancestor private helpers. Prefer a local wrapper at the nearest package that owns the narrower rule.
- A parent package must not use child private helpers.
- Sibling packages must not use each other's private helpers.
- Shared private behavior belongs at the lowest ancestor that owns the rule.

### 6.2 Package-Scoped Composition

Package architecture is ownership first, call permission second. A package map names the package that owns behavior. It does not grant arbitrary access to every function in that package subtree.

A package owns its directly contained files. A nested `@child/` directory is a separate package with its own privacy boundary. A `__` helper is private to the package that owns it.

The active topology rule is:

```text
private = package and descendants
public  = immediate parent and direct siblings
all other reach routes through the tree
```

Public functions may be called by the immediate package parent and direct package siblings. Direct sibling means the same immediate `@` package parent, not the same registry or filesystem parent.

A parent may compose from the public functions of its immediate children. A package should not call skipped descendants directly. Each package is responsible for summarizing its own subtree.

Sibling private calls are forbidden. Direct sibling public calls are allowed only when the sibling public function is the intended boundary behavior. Descendants of a sibling are not direct siblings.

A descendant should not build on an ancestor public API. Public APIs summarize upward and may already depend on the descendant branch. If a descendant needs behavior currently hidden inside an ancestor public function, split the underlying primitive into an ancestor-private helper and call that helper downward.

Localizing a legal sibling dependency at the caller package boundary counts as semantic content. A wrapper is valid when it localizes the dependency, establishes package-level meaning, or adds package-owned policy. A wrapper that only forwards for access is invalid.

Private cross-branch reuse that is not a legal direct-sibling call belongs at the lowest ancestor that owns the shared rule. That ancestor may provide a real private adapter. Descendants may reuse that ancestor-private helper downward; they wrap it only when the wrapper adds package-owned meaning or localizes a legal sibling dependency at the caller package boundary.

Direct sibling cycles fail. Sibling chains, hubs, repeated dependency-localization helpers, and unclear one-line delegates are review shapes, not automatic call-boundary permission changes.

Public is relative to the package boundary. A child package's public function may be public to its parent for composition without being a project-facing external API.

`RINGS-ADAPTER`, `BASH-COMPAT`, and `NATIVE-OWNERSHIP-REFINEMENT` apply only to upstream-family and projection-shape lint. They never widen rings-native call-boundary permission.

### 6.3 Package Identity, Modular Components, and Facets

- **Packages and Modules:** A module is a `.d` suffixed directory in the ring root (e.g., `env.d/`). A package is an `@` prefixed directory (e.g., `@pkg/`). The `packages.d/` module is the registry.
- **Modular Components:** A `.d` suffixed directory inside a package is a modular component. It is a routing signal. It directs the system to project the component's contents into the corresponding module. For example, `packages.d/@pkg/env.d/` routes to `env.d/@pkg/`.
- **Facets:** A package nested inside another package is a subpackage with its own package boundary for ownership and calls. The same occurrence may also be a facet when viewed under the nested package's identity; the outer package provides the prefixed scope for facet discovery.

-----

## 7. Terminology

- `rings` is the binary and application. `@rings` is the framework package. A ring is an instantiated fork rooted at `$RING_ROOT`.

-----

## 8. Active Surfaces and Paths

[to complete]

-----

## 9. Document Boundaries

[to complete]

-----

## 10. Bash Package Migration Principles

These rules apply to every ported or migrated Bash package. They cohere with and do not supersede [`SHELL_STYLE_GUIDE.md`](../style/SHELL_STYLE_GUIDE.md), [`DOCUMENTATION-STYLE-GUIDE.md`](../style/DOCUMENTATION-STYLE-GUIDE.md), or the active rings package rules in [`docs/rings/PACKAGES.md`](../rings/PACKAGES.md) §10.

- **Split by semantic domain, not upstream file shape.** Package boundaries follow conceptual fault lines — raw tables, width policy, cluster traversal, terminal capabilities, output buffer, cursor movement — not the shape of the source file being ported.
- **Public names use short domain nouns.** `width::char`, `cluster::next`, `output::put`, `cursor::move`. See SHELL_STYLE_GUIDE §4.1 for the naming convention (`::` for namespace, `-` for words). Do not carry upstream punctuation or overlong descriptive suffixes into new names.
- **Private abbreviations require a file-local glossary declaration.** An abbreviation such as `fpb` in `__fpb-ZWJ` is acceptable only inside the file where "`fpb = find previous boundary`" is declared once at the top. Abbreviations do not cross file boundaries.
- **One owner for any shared resource read.** Every named resource category (terminal capabilities, locale state, Unicode tables) is read by exactly one package. All other packages call that package's public API. No cross-owner direct reads.
- **State variables belong to their package.** A variable named `_ble_canvas_textmap_*` lives in `@textmap`. A variable declared in the wrong package is a package boundary violation, not a convenience.
- **File headers explain the package.** Standard fields are `Source`, `On Load`, `Provides`, and `Requires` (SHELL_STYLE_GUIDE §3.1). Additional fields must be concrete and file-specific: name the actual data format, lifecycle, ownership rule, dispatch rule, timing model, or edit hazard. Do not use migration-origin fields such as `Translation`, and do not hide content in generic buckets such as `Contract`, `Notes`, or `Implementation`.
- **Tests are guard rails.** A passing test suite must: source each subpackage twice (idempotency); assert that forbidden patterns are absent (legacy call prefixes, direct resource reads from non-owning packages, `TODO: migrate` markers); load real upstream dependencies, not local stubs.
- **Public-facing packages are thin facades.** A package that exposes a stable public API composes over richer internal packages. Its surface does not change when its internals change.
- **Package hierarchy discipline is structural.** Cross-package dependency calls use public APIs unless the package-call rules allow descendant reuse of ancestor private helpers. A package does not call sibling privates or child privates. See CONSENSUS §6.1 and §6.2.

-----

## 11. Translation Posture

BLE is upstream `ble.sh` translated into rings style.

Rings-native means the upstream implementation expressed through rings package ownership, `::` names, loadlists, and local boundary wrappers.

- If an upstream subsystem exists, never rely on simplified original code instead of porting that subsystem. Original code is allowed only where there is no upstream subsystem to port: rings glue, compiler and loader machinery, lints, ledgers, harnesses, package adapters, and other native integration surfaces.
- Every new or changed function that implements upstream behavior must start by locating and copying the upstream function body or upstream data table that owns that behavior.
- Translate upstream into rings form after the copy: rename functions, translate calls, route packages, adjust package-owned globals, add package-boundary wrappers, and comment the translated behavior.
- Bash 5 idioms are allowed only as semantics-preserving mechanical edits on an already copied upstream body. If equivalence is not obvious, keep the upstream spelling.
- **Version-selection collapse.** Upstream defines function variants inside `if ((_ble_bash>=N)); then function f { A } else function f { B } fi` at source time. This is not lazy initialization — it is version-selection: exactly one variant is defined at source time and the other is dead code for all runtimes that satisfy the condition. Translate by collapsing: if N is at or below the rings minimum Bash version (currently 4.3 = `40300`), the condition is always-true on all supported runtimes; define only the `if`-branch variant unconditionally and omit the else-branch entirely. If N is above the rings minimum, preserve the condition as a runtime `if ((_ble_bash>=N))` check. Never define both variants unconditionally in rings source — that would double the function definition count and parse cost for no runtime benefit.
- **Lazy-init closure.** A small number of upstream functions are created inside an `__initialize` function that redefines itself to a no-op on first call (`function f/init { function f/init { return 0; }; function f { ... } }`). These functions are deferred to first use, not defined at source time. The rings translation must preserve this: define the `__initialize` function at source time, have it redefine itself to `return 0` on first call, and create the real function body inside it. Do not promote the deferred functions to top-level eager definitions.
- Never originate an implementation for upstream behavior. Do not invent algorithms, queues, stores, registries, facades, or replacement bodies.
- **Split-body corollary.** An upstream function translated into multiple rings components is still one translation. The sum of all components must equal the upstream body — no more, no less. A component that adds operations not present in the upstream body is originating, regardless of how locally sensible the addition appears. This applies even when the addition is small and appears to fix a real problem: the fix is the other component's responsibility, not invented bridging code.
- If upstream code does not fit the current rings boundary, reshape the boundary or stop and report the blocker. Do not bridge the mismatch with original code.
- Never write a plausible local implementation first and then steer it toward upstream. The workflow is copy upstream, translate rings names and bodies, then verify.
- Source parity is established by copying the upstream body or data table, translating names and ownership in place, and preserving the upstream call chain. A PTY lane is not source parity; it is final composed smoke coverage for a completed user path.
- Do not start a port by writing a lane, oracle case, or harness extension. Use direct source comparison, table diffs for declarative data, syntax checks, and in-process probes while translating. Add or run PTY only after the upstream source closure exists.
- The user-visible terminal surface — bytes, ordering, options, observable behavior — follows upstream. Lanes in [`@test/@oracle/pty/lanes.tsv`](../../src/@ble/@test/@oracle/pty/lanes.tsv) record final composed coverage for completed user paths; they do not authorize invented implementation and they are not required for every mini-slice.
- Corrections that bring observed behavior closer to upstream's own intent must be grounded in upstream code or explicit project approval. Encode the corrected expectation in the lane and note the divergence-from-observed where the lane is registered. The row in `upstream.tsv` remains `closed`.
- Deliberate user-visible departure from upstream requires explicit approval before implementation. When required, document it in the owning package's `@PACKAGES.md` with rationale.

The goal is a semantics-preserving rings projection of upstream `ble.sh`.

-----

## 12. Closure Ledger

A row in [`@test/@oracle/classification/upstream.tsv`](../../src/@ble/@test/@oracle/classification/upstream.tsv) is `closed` only when a registered proof shows it against `ble.sh/out/ble.sh` and currently passes. Closure cannot be claimed in prose, in commit messages, or in narrative status documents.

Two proof instruments are valid. Both run against `ble.sh/out/ble.sh`; both are registered artifacts, not prose.

1. **PTY lane** — a named lane in [`@test/@oracle/pty/lanes.tsv`](../../src/@ble/@test/@oracle/pty/lanes.tsv) drives a completed user path through the composed stack and matches upstream output. This is final composed proof for *behavior*: widget effects, render output, decode dispatch, completion results. One lane proves many rows. It is not the first step of a port and must not be created for every helper or internal mini-slice.

2. **Table-fidelity diff** — for a *declarative data table* copied from upstream under the translation rule (an option table, a key-binding table), a registered differential tool extracts the upstream table from `ble.sh/out/ble.sh` and the rings table from source, and asserts the two match. The first such tool is [`@test/@oracle/translation/check-options.bash`](../../src/@ble/@test/@oracle/translation/check-options.bash) for the `bleopt` surface. This is the proof for *data*: you prove a copied table was copied faithfully by diffing it, not by exercising every entry through a PTY.

The table-fidelity instrument is bounded by two hard preconditions:

- **Declarative data only.** It is valid for surfaces that are upstream data tables — `bleopt`, `default-key-binding`, `vi-command`, and similar name→value or key→target tables. It is never valid for behavioral logic; behavioral logic is implemented by copied upstream source and finally covered by composed behavior checks.
- **The consuming engine must already be proven.** A table-fidelity diff proves the entries match upstream; it does not prove they do anything. A binding table closes by table-fidelity only once the decode→keymap→widget dispatch engine that reads it has a completed user-path proof that a table entry fires its target. Prove the engine once with a few representative checks; then the rest of the table closes as data. A matched entry whose engine is unproven is a *candidate*, not `closed`.

The vocabulary is fixed: `open`, `closed`, `tested-native-replacement`, `status`. New labels are hiding places; do not add them. `closed-mostly`, `closed-pending-pty`, `closed-corrected`, `closed-divergent`, `out-of-scope`, and similar are not valid states. Broadening the proof instrument does not broaden the state set: a row is still exactly `open` until its registered proof — lane or table-fidelity — passes, then `closed`.

A status document that asserts closure for a row the ledger marks `open` is wrong by definition; the ledger is authoritative.

-----

## 13. BLE Runtime Architecture

These are settled decisions about the internal implementation of the `@ble` runtime. They do not alter user-visible behavior and do not require per-closure ledger entries, but they are easy to regress during porting.

**Option value access.** Internal code reads `bleopt_*` globals directly — one scalar variable read, zero overhead. `ble::base::option::get` is for the user-facing `bleopt` command and package initialization callbacks only. Never call `ble::base::option::get` in a hot path or tight loop. This matches upstream `ble.sh` behavior throughout.

**Hot state is flat scalars.** Terminal capability state (`_ble_term_*`), canvas geometry (`_ble_canvas_*`), and edit buffer state (`_ble_edit_*`) are flat scalar variables. Do not wrap them in associative arrays for ergonomics. Consumers read them directly. This is the established pattern in both upstream and the rings port; changing it degrades every hot render and decode path.

**Feedback arc inversion.** Lower packages never name higher packages by direct function call. The upstream `ble.sh` arcs — `util → decode/has-input`, `util → edit/info/*`, `history → decode/has-input`, `decode → edit/info/*` — are inverted in the rings port:

- Yield/interrupt arcs use a dedicated predicate array owned by `@util`. `@decode` registers `ble::decode::has-input` into `_ble_util_yield_predicates` during its init. `@util/conditional-sync` calls `ble::util::yield::has-pending` instead of naming `@decode`. Do not route this through the generic hook dispatcher — the tight poll loop requires direct array iteration.
- Telemetry arcs (idle/info display) use regular hooks (`idle_info_default`, `idle_info_show`) declared in `@util`. `@edit` registers its info handlers during init. `@util` and `@decode` never name `@edit`.

**Internal hooks are function-only.** `ble::base::hook::invoke` dispatches via direct function call only — no function-exists check, no eval fallback. All internal `ble::base::hook::add` calls register function names. The user-facing `blehook NAME='snippet'` command compiles command fragments into generated wrapper functions at registration time (one eval at registration, zero at dispatch). This keeps the dispatcher tight and makes hook call graphs statically discoverable.

**Hook declarations are source-safe.** Upstream `blehook/declare` resets its
array and invocation counter because upstream declares hooks once during the
single flat startup pass. The rings port deliberately makes
`ble::base::hook::declare` idempotent: re-sourcing `@base/@hook` must not erase
handlers registered by packages, bash-preexec arrays, or user integration code.
Use `ble::base::hook::clear` for an explicit clear. A hook declaration that
clears on re-source is incompatible with the rings source-safety requirement.

-----

## 14. Composition, Audit, and Harness Discipline

These points were settled during the 2026-05-29 ground-truth audit. They are recorded so the conclusions are not re-discovered, re-litigated, or contradicted. They are durable rules, not status. The current point-in-time position lives in [`@test/@oracle/translation/AUDIT-7-8.md`](../../src/@ble/@test/@oracle/translation/AUDIT-7-8.md) (dated narration); per-row truth lives in `upstream.tsv` + `lanes.tsv`. Do not copy counts into this file — they drift.

### 14.1 Composition is the bar, not unit greenness

A pile of independently-green units is not a working layered subsystem. Layered correctness needs composed coverage against real `ble.sh/out/ble.sh`, not per-package unit tests alone. That composed coverage is the final check after source translation, not the starting point for each implementation slice.

- `oracle-pty` is the whole-stack composition gate: it exercises term → canvas → decode → keymap → history → edit → render end-to-end. When it passes, the layering composes and edits end-to-end for the behavior its lanes cover.
- "Is layer N working?" is answered first by whether its upstream source closure is copied and translated through the actual call chain. A passing composed lane proves user-path coverage for that layer; it does not replace source translation and it should not be expanded into one lane per helper.
- Ledger closure percentage measures *proof coverage*, not whether the base works. A low closed-row count with `oracle-pty` green means "working but largely unproven by named lanes," not "broken."

### 14.2 Interpreter discipline — the suite must run under Bash ≥ 4.3

Native `@ble` requires Bash 4.3+. macOS `/bin/bash` is 3.2.

- `run-all.bash` resolves a qualifying interpreter and **re-execs the whole runner** under it; launched from 3.2 it self-heals to the discovered Bash 5. It fails loud (exit 2) if `BLE_TEST_BASH` names an older Bash or none is found.
- TAP `rc=77` is **skip**, not pass. A run dominated by `rc=77` was executed under the wrong interpreter and proves nothing. A "green" run under 3.2 is meaningless.
- Before trusting any suite result, confirm it ran under Bash ≥ 4.3.

### 14.3 Audit faithfulness — body-diff is the only verdict

Whether a rings function is a faithful port or invented code is decided by reading its body against the upstream body (CLAUDE.md §9), nothing weaker.

- A failed name search, a leaf-name mismatch, or a file-header claim is **not** evidence. Rings deliberately renames leaves (§10), so a leaf-miss is as likely a faithful rename or a split as an invention.
- Settled finding: there are **no invented subsystems**. The big engines are faithful translations or reshapings — `@syntax/@parse` is the ported incremental dirty-range engine (the "clean-room scanner" note is historical); `@textarea` redraw is a reshaping that collapses upstream `ble/textarea#render`+`#redraw`; `@prompt/@render::trace` routes SOH/STX through `ble::canvas::trace::run`. Invention, where it exists, is rare and confined to small utility/validation helpers, and is fixed by porting from upstream, not by inventing further.
- Stale "this is clean-room / invented" notes from earlier sessions are not authority. Re-confirm against the current body before repeating such a claim.

### 14.4 File headers explain the code, never its provenance

A file header documents what the package **owns and guarantees** and what breaks if it is simplified — codebase-first. It does not narrate migration.

- No upstream-provenance framing in headers. A `Source:` field naming an upstream file (e.g. `core-complete.sh`) is wrong; the `Source` header field is the file's own rings filesystem home only (SHELL_STYLE_GUIDE §3.1). Provenance — which upstream symbol a function translates — belongs in the ledger and `symbols.tsv`, not the header.
- False or upstream-pointing provenance in a header is an **audit smell**: it signals a header that explains migration instead of code. The fix is to rewrite the header codebase-first, not to correct the citation.

### 14.5 State ownership — writes versus reads versus drains

The `state-ownership` lint enforces package ownership of `_ble_*` globals. The distinction is settled:

- A cross-package **write** is a boundary violation and must be routed through the owner package's API (or, for a consuming-loop drain, recorded — see below). Cross-package writes are driven to zero.
- A cross-package **read** of a flat hot-state scalar is sanctioned (§13) and recorded in `readers.tsv`. It is not a violation.
- A **drain** (read-and-clear) of a handoff variable by a consuming loop that lives in another package is recorded in `writers.tsv` (sparse, owner-validated; absence means owner-only). This generalizes the §13 consumer-loop pattern; it is not a new write violation.
- The lint's remaining diagnostics after writes reach zero are **ledger-registration bookkeeping** (unregistered own-state symbols; sanctioned reads not yet listed), not boundary bugs. Do not treat the bookkeeping backlog as evidence of a boundary defect.
