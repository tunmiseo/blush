# `io::*` Capability Surface

> **Status:** Partial specification; core capability model and public surface are settled, with backend and implementation parity still in progress.
> **Scope:** Public `io::*` capability surfaces, their tier split, root-level operational counterparts, alias discipline, backend-shim boundaries, and filesystem placement.
> **See also:** [`ARCHITECTURE.md`](../ARCHITECTURE.md) · [`LOADER.md`](../LOADER.md) · [`PACKAGES.md`](../PACKAGES.md)

Current branch-local implementation tracking for `@core` lives in [`functions.d/@core/_/@io/MIGRATION-STATUS.md`](/Users/monad/src/repos/rings/functions.d/@core/_/@io/MIGRATION-STATUS.md) and [`functions.d/@core/_/@io/CONFORMANCE-MATRIX.md`](/Users/monad/src/repos/rings/functions.d/@core/_/@io/CONFORMANCE-MATRIX.md). Those files do not define canonical truth, but they do gate branch-level completion claims against the current tree.

## 1. Purpose

This document defines the canonical `io::*` surface for interactive terminal I/O in `rings`.

Within `rings`, `io::*` spans two related but distinct concerns. Layer 1 loader operations such as `io::load` and `io::load::*` move sourceable artifacts between the filesystem and the live shell. The capability tiers in this document (`io::in`, `io::out`, `io::fmt`, `io::layout`, `io::ui`) cover interactive terminal behavior. The root-level operational counterparts `io::load` and `io::save` remain public `io::*` surfaces without belonging to the interactive tier taxonomy.

The `io::*` surface satisfies four requirements:

1. It is derived from the real capability surfaces of the interactive terminal libraries that `rings` supports.
2. It preserves a strict internal split between pure transforms and effectful interaction.
3. It degrades cleanly when richer backends are unavailable.
4. It admits richer backends and compound interfaces without distorting the first layer.

The governing rule is simple:

**The public API is derived from real libraries. The internal semantics remain disciplined.**

## 2. Definitions

### 2.1 Capability

A **capability** is one named operation in the `io::*` surface, such as `io::in::confirm` or `io::layout::border`.

Each capability defines:

* a core contract
* a stable option vocabulary
* zero or more enriched features
* a degradation rule

### 2.2 Stable Option Vocabulary

A capability's **stable option vocabulary** is the small, public set of options that callers may rely on across backends.

The stable option vocabulary belongs to the public contract.

Explicit argv and rings-native ambient defaults feed the same canonical option
space. Ambient defaults do not create a second public vocabulary; they are a
second input path to the same stable option surface.

### 2.3 Enriched Feature

An **enriched feature** is a backend-specific or backend-dependent capability extension such as preview panes, grouped forms, or tree navigation.

Enriched features may exist without becoming part of the initial stable public option vocabulary.

### 2.4 Backend Adapter

A **backend adapter** is the internal layer that resolves which backend will satisfy a capability request.

The adapter resolves by:

* capability
* requested stable options
* required enriched features
* backend availability

Concrete selection uses a fixed try-order per capability tier and shim presence (see **§8.3**). **Stable options** and **enriched features** are not separate, first-class inputs to that walk yet; they shape capability choice only indirectly. Extending the adapter to take them explicitly is future work.

### 2.5 Backend Shim

A **backend shim** is a small backend-specific wrapper that translates the generic capability call into backend-specific command syntax.

**Rings `@core` implementation:** public leaves call **`io::_backends::dispatch io::<tier>::<leaf> …`**. Dispatch runs **`io::__parse-options`** against the per-command schema (`functions.d/@core/_/@io/@<tier>/<leaf>.schema.sh`, with optional fragments under `@_schema/`), merges argv and schema-defined env defaults, then intersects **schema-owned eligibility** metadata with the configured backend try-order. **`io::_backends::translate-options`** projects the parsed map into **`key=value` … `--` …** argv for the chosen shim. Pinned **`--backend <id>`** still parses canonical flags, then forwards unrecognized tokens verbatim to **`io::_backends::<id>::shim::<tier>::<leaf>::pinned`** when that function exists.

Shim functions are named **`io::_backends::<backend_id>::shim::<tier>::<leaf>`** (for example **`io::_backends::gum::shim::in::filter`**). Older prose may refer to **`io::shim::<backend>::<path>::__<leaf>`**; that pattern is not the current `@core` layout.

A backend shim may know:

* the command or library name
* backend-specific flags
* backend-native environment variables
* output quirks
* capability gaps

No other layer may depend on those details.

For shell implementation conventions in `functions.d/@io/...` and related shim/helper files, follow the [SHELL_STYLE_GUIDE](../../style/SHELL_STYLE_GUIDE.md).

### 2.6 Pure Transform

A **pure transform** consumes text and emits transformed text without prompting, claiming terminal interaction state, or performing interactive terminal behavior.

`io::fmt::*` and `io::layout::*` are pure transforms.

### 2.7 Effectful Capability

An **effectful capability** prompts a human, owns terminal behavior, or orchestrates a stateful interaction.

`io::in::*`, `io::out::*`, and `io::ui::*` are effectful capabilities.

This interactive-tier definition does not subsume the root operational counterparts in §3.6. `io::load` and `io::save` are effectful in an operational shell/filesystem sense without belonging to the five-tier interactive taxonomy.

### 2.8 Shell `print` substrate (not an `io::*` capability)

Zsh provides **`print`** as a builtin. Bash does not. Rings installs a **bash polyfill** at `functions.d/@builtin-wrappers/@bash/print.bash`.

For `@io` on bash, `functions.d/@io/load.bash` sources that polyfill first (`earlySourcePrint`) before other `@io` files. `_helpers.sh` also defines **`io::__ensure-print`** so a minimal source order still loads the polyfill when possible.

**`io::__emit`** is the internal dispatch point: on zsh it uses `builtin print`; on bash it uses the polyfill `print` function. Prefer **`io::__emit`** in new `@io` helpers so future behavior (TTY checks, tracing, or polyfill fixes) can live in one place. Bare **`print`** remains acceptable once **`io::__ensure-print`** has run.

Shared helpers that collect stdin or positional text into a single body for transforms use **`io::__capture-input`** (not a public capability).

Do not add **`io::out::print`** as a public name: `print` is shell substrate, not a tier on the `io::out::*` capability surface (which covers logging, paging, tables, progress, and similar).

Non-interactive bash without stdin closed can interact badly with the polyfill’s stdin path; when testing `bash -c '…'`, tie off stdin (for example `</dev/null`) if a hang appears.

## 3. Architectural Tiers

The `io::*` surface is partitioned into five tiers:

* `io::in` — one-shot interactive input
* `io::out` — effectful output behavior
* `io::fmt` — pure inline text transforms
* `io::layout` — pure block transforms
* `io::ui` — compound or stateful interactive surfaces

### 3.1 `io::in`

`io::in::*` acquires a value from a human through one-shot interaction. These capabilities emit the chosen or entered value on standard output when a value is produced, and use exit status to report success, cancellation, or failure.

### 3.2 `io::out`

`io::out::*` owns output behavior such as logging, paging, tabular rendering, or progress display.

### 3.3 `io::fmt`

`io::fmt::*` performs inline text transformation. These capabilities operate on text fragments and do not own terminal interaction state.

### 3.4 `io::layout`

`io::layout::*` performs block transformation. These capabilities operate on borders, padding, margins, alignment, width, height, and block composition, and do not own terminal interaction state.

### 3.5 `io::ui`

`io::ui::*` owns compound or stateful interaction. This tier exists so that forms and future multi-step interfaces are not flattened into `io::in::*`.

### 3.6 Root Operational Counterparts

The five tiers above describe the interactive terminal capability taxonomy. They do not exhaust the public `io::*` surface.

`io::load` and `io::save` remain first-class root-level operational counterparts. The `io::load::*` family likewise operates on shell/session artifacts rather than on the interactive terminal capability tiers. These operational surfaces sit outside `io::in`, `io::out`, `io::fmt`, `io::layout`, and `io::ui`.

## 4. Stable Public Surface

The initial canonical public surface is:

### 4.1 Input

* `io::in::confirm`
* `io::in::input`
* `io::in::choose`
* `io::in::filter`
* `io::in::file`
* `io::in::write`

### 4.2 Output

* `io::out::rule`
* `io::out::center`
* `io::out::left`
* `io::out::newline`
* `io::out::log`
* `io::out::pager`
* `io::out::table`
* `io::out::progress`
* `io::out::spin`
* `io::out::status::info`
* `io::out::status::warning`
* `io::out::status::success`
* `io::out::status::okay`
* `io::out::status::announce`
* `io::out::preset::box::black-on-yellow`
* `io::out::preset::box::blue-in-yellow`
* `io::out::preset::heading::h1`
* `io::out::preset::heading::red`
* `io::out::preset::heading::yellow`
* `io::out::preset::highlight::blue`
* `io::out::preset::highlight::green`
* `io::out::preset::highlight::subtle`
* `io::out::preset::highlight::yellow`

### 4.3 Inline Formatting

* `io::fmt::bold`
* `io::fmt::faint`
* `io::fmt::italic`
* `io::fmt::underline`
* `io::fmt::strikethrough`
* `io::fmt::fg`
* `io::fmt::bg`
* `io::fmt::render`

### 4.4 Block Layout

* `io::layout::border`
* `io::layout::pad`
* `io::layout::margin`
* `io::layout::align`
* `io::layout::width`
* `io::layout::height`
* `io::layout::join`

### 4.5 Compound UI

* `io::ui::form`

### 4.6 Root Operational Surface

* `io::load`
* `io::save`

No additional `io::ui::*` noun is canonical until it becomes a real first-class contract.

## 5. Alias Rules

### 5.1 Ergonomic Effectful Aliases

The canonical ergonomic aliases are:

* `io::confirm` → `io::in::confirm`
* `io::input` → `io::in::input`
* `io::choose` → `io::in::choose`
* `io::filter` → `io::in::filter`
* `io::file` → `io::in::file`
* `io::write` → `io::in::write`
* `io::save` → `save`
* `io::log` → `io::out::log`
* `io::pager` → `io::out::pager`
* `io::table` → `io::out::table`
* `io::progress` → `io::out::progress`
* `io::spin` → `io::out::spin`
* `out::rule` → `io::out::rule`
* `out::center` → `io::out::center`
* `out::left` → `io::out::left`
* `out::newline` → `io::out::newline`
* `status::info` → `io::out::status::info`
* `status::warning` → `io::out::status::warning`
* `status::success` → `io::out::status::success`
* `status::okay` → `io::out::status::okay`
* `status::announce` → `io::out::status::announce`

For the root operational surface, `save` is the current ergonomic shell entrypoint corresponding to the public `io::save` capability.

Where a capability admits ambient defaults, the canonical environment form mirrors the full capability path, for example `RINGS_IO_IN_FILTER_MATCH_FOREGROUND`.

If a matching qualified `io::...` functional alias exists for that command, the alias ambient-default form drops the `RINGS_` prefix and mirrors the alias path mechanically, for example `io::filter` -> `IO_FILTER_MATCH_FOREGROUND` and `io::confirm` -> `IO_CONFIRM_PROMPT_FOREGROUND`. Canonical full-path names win on conflict.

### 5.2 Pure Transform Aliases

The canonical pure-transform aliases are:

* `fmt::bold` → `io::fmt::bold`
* `fmt::faint` → `io::fmt::faint`
* `fmt::italic` → `io::fmt::italic`
* `fmt::underline` → `io::fmt::underline`
* `fmt::strikethrough` → `io::fmt::strikethrough`
* `fmt::fg` → `io::fmt::fg`
* `fmt::bg` → `io::fmt::bg`
* `fmt::render` → `io::fmt::render`
* `layout::border` → `io::layout::border`
* `layout::pad` → `io::layout::pad`
* `layout::margin` → `io::layout::margin`
* `layout::align` → `io::layout::align`
* `layout::width` → `io::layout::width`
* `layout::height` → `io::layout::height`
* `layout::join` → `io::layout::join`

### 5.3 Non-Canonical Aliases

These aliases are not canonical:

* bare `confirm`, `choose`, `filter`, `input`, `file`, `write`
* `io::bold`, `io::fg`, `io::bg`
* `io::border`, `io::pad`, `io::align`, `io::join`
* `io::form`

Bare aliases are forbidden because they erode namespace discipline and collide semantically.

Pure transforms must not be flattened into `io::*`, because that would collapse distinct semantic strata back into a grab-bag.

The old `@formatting` preset names remain as compatibility wrappers during absorption:

* `box.black-on-yellow` → `io::out::preset::box::black-on-yellow`
* `box.blue-in-yellow` → `io::out::preset::box::blue-in-yellow`
* `h1` → `io::out::preset::heading::h1`
* `h.red` → `io::out::preset::heading::red`
* `h.yellow` → `io::out::preset::heading::yellow`
* `hl.blue` → `io::out::preset::highlight::blue`
* `hl.green` → `io::out::preset::highlight::green`
* `hl.subtle` → `io::out::preset::highlight::subtle`
* `hl.yellow` → `io::out::preset::highlight::yellow`

The interactive shell aliases:

* `info`
* `warning`
* `success`

point directly to the authoritative status functions, not to the shorter `status::*` aliases.

## 6. Capability Contracts

Every capability defines a core contract, a stable option vocabulary, possible enriched features, and a degradation rule.

### 6.1 `io::in::confirm`

`io::in::confirm` asks a human to confirm an action.

Core contract:

* display a prompt
* return success for affirmative confirmation
* return nonzero for negative or cancelled confirmation

Stable options may include:

* prompt or title text
* default yes/no

Typical degradation:

* rich confirm backend → native `read` prompt

### 6.2 `io::in::input`

`io::in::input` prompts for a short scalar input value.

Core contract:

* display a prompt
* collect one scalar input value
* emit the value on standard output

Stable options may include:

* prompt text
* placeholder or default
* password mode
* validation hook

Typical degradation:

* rich input backend → shell `read`

### 6.3 `io::in::choose`

`io::in::choose` selects one or more values from a discrete list.

Core contract:

* display candidate items
* allow interactive selection
* emit selected item or items

Stable options may include:

* single vs multiple selection
* header or prompt text
* limit or height

Enriched features may include:

* preview
* cursor control
* typed values
* label/value display

Typical degradation:

* richer chooser → simpler chooser → numbered native selection

### 6.4 `io::in::filter`

`io::in::filter` interactively narrows a candidate list and returns selected results.

Core contract:

* accept candidate items
* support narrowing or filtering interaction
* emit selected result or results

Stable options may include:

* single vs multiple selection
* prompt or header text
* exact vs fuzzy preference

Enriched features may include:

* preview
* query seed
* result reload
* scoring behavior

Typical degradation:

* richer filter → simpler filter → choose-like fallback

### 6.5 `io::in::file`

`io::in::file` selects a file or path from a root.

Core contract:

* browse or choose a path
* emit the selected path

Stable options may include:

* root directory
* file vs directory mode
* multiple selection

Enriched features may include:

* preview
* extension or type filters
* tree navigation

Typical degradation:

* richer file picker → chooser over paths → plain path prompt

### 6.6 `io::in::write`

`io::in::write` prompts for long-form text.

Core contract:

* open a long-form editing experience
* emit the resulting text on standard output

Stable options may include:

* initial contents
* target path
* editor preference

Typical degradation:

* richer writer backend → `$EDITOR` on a temporary file → minimal fallback

When `io::in::write` accepts a target path, that path is an option on the canonical command. The canonical behavior remains stdout emission.

### 6.7 `io::save`

`io::save` persists an in-memory shell artifact to disk.

Core contract:

* accept a function or alias name from the current shell session
* derive or accept a target namespace and output path
* write a disk artifact suitable for subsequent packaging or loading

Stable options may include:

* target namespace
* output name or path
* overwrite vs append behavior
* extension or shell mode

Typical use:

* capture a manual shell artifact into a durable file before packaging or normalization

`io::save` is the first-class root-level counterpart to `io::load`: `io::load` brings sourceable artifacts into the live shell; `io::save` persists live shell artifacts back to disk.

### 6.7 `io::out::rule`

`io::out::rule` prints an optional label and a horizontal rule.

Stable options may include:

* width
* character
* color

The usual use is a visual divider between larger output blocks.

### 6.8 `io::out::center`

`io::out::center` prints one centered line.

Stable options may include:

* style sequence

It is the low-level output helper used by centered heading presets.

### 6.9 `io::out::left`

`io::out::left` prints one padded left-justified block.

Stable options may include:

* style sequence

It is the low-level output helper used by left-highlight presets.

### 6.10 `io::out::newline`

`io::out::newline` prints one blank line.

This is a small convenience output function used in presentation wrappers.

### 6.11 `io::out::status::*`

The `io::out::status::*` family prints status-specific output blocks and lines.

The initial authoritative functions are:

* `io::out::status::info`
* `io::out::status::warning`
* `io::out::status::success`
* `io::out::status::okay`
* `io::out::status::announce`

`status::info`, `status::warning`, `status::success`, `status::okay`, and `status::announce` are the official functional aliases.

### 6.12 `io::out::preset::box::*`

The `io::out::preset::box::*` family prints named boxed-output presets.

The initial authoritative functions are:

* `io::out::preset::box::black-on-yellow`
* `io::out::preset::box::blue-in-yellow`

These are the direct replacements for the old boxed-output helpers from `@formatting`.

### 6.13 `io::out::preset::heading::*` and `io::out::preset::highlight::*`

The `io::out::preset::heading::*` family prints named centered heading presets.

The initial authoritative functions are:

* `io::out::preset::heading::h1`
* `io::out::preset::heading::red`
* `io::out::preset::heading::yellow`

The `io::out::preset::highlight::*` family prints named left-highlight presets.

The initial authoritative functions are:

* `io::out::preset::highlight::blue`
* `io::out::preset::highlight::green`
* `io::out::preset::highlight::subtle`
* `io::out::preset::highlight::yellow`

These preset families absorb the old `box.*`, `h*`, and `hl.*` output names without keeping `@formatting` as a separate public vocabulary.

### 6.14 `io::out::log`

`io::out::log` emits level-aware terminal messages.

Stable options may include:

* level
* prefix or tag
* output stream

Typical levels include:

* `info`
* `warn`
* `error`
* `success`
* `debug`

### 6.15 `io::out::pager`

`io::out::pager` presents text through a pager-like interface.

Typical degradation:

* richer pager → `${PAGER:-less}` → plain print

### 6.16 `io::out::table`

`io::out::table` renders rows and columns legibly.

Stable options may include:

* headers
* alignment
* separator policy

Enriched features may include:

* borders
* width policy
* styled cells

Typical degradation:

* richer table backend → plain columnar rendering

### 6.17 `io::out::progress`

`io::out::progress` displays progress while work is occurring.

Core contract:

* present running progress state while a command or operation executes

Stable options may include:

* title or label
* style

Enriched styles may include:

* spinner
* bar
* pulse

`progress` is the semantic family. `spin` is one concrete specialization.

### 6.18 `io::out::spin`

`io::out::spin` invokes `io::out::progress` in spinner mode.

`io::out::spin` is a convenience specialization. It is not the architectural center of the progress contract.

### 6.19 `io::fmt::bold`

`io::fmt::bold` returns bold-styled text.

### 6.20 `io::fmt::faint`

`io::fmt::faint` returns faint-styled text.

### 6.21 `io::fmt::italic`

`io::fmt::italic` returns italic-styled text.

### 6.22 `io::fmt::underline`

`io::fmt::underline` returns underlined text.

### 6.23 `io::fmt::strikethrough`

`io::fmt::strikethrough` returns strikethrough-styled text.

### 6.24 `io::fmt::fg`

`io::fmt::fg` applies foreground color to text.

### 6.25 `io::fmt::bg`

`io::fmt::bg` applies background color to text.

### 6.26 `io::fmt::render`

`io::fmt::render` renders plain, structured, or markup-like text into styled terminal text.

This contract is explicit and bounded. `io::fmt::render` does not own prompting, paging, layout, progress, or any other terminal interaction behavior.

Stable options may include:

* input mode or format hint
* theme or style hint

Typical behavior may include:

* markdown-like rendering
* template-like interpolation when supported
* code or style highlighting when supported

### 6.27 `io::layout::border`

`io::layout::border` surrounds a block with a border.

Stable options may include:

* border style
* border color

### 6.28 `io::layout::pad`

`io::layout::pad` applies inner spacing to a block.

### 6.29 `io::layout::margin`

`io::layout::margin` applies outer spacing to a block.

### 6.30 `io::layout::align`

`io::layout::align` aligns a block within available width.

Typical alignments are:

* `left`
* `center`
* `right`

### 6.31 `io::layout::width`

`io::layout::width` constrains or normalizes block width.

### 6.32 `io::layout::height`

`io::layout::height` constrains or normalizes block height.

### 6.33 `io::layout::join`

`io::layout::join` joins blocks vertically or horizontally.

Stable options may include:

* direction (`vertical` / `horizontal`)
* separator

### 6.34 `io::ui::form`

`io::ui::form` presents a compound or multi-step form surface.

Core contract:

* orchestrate multiple related fields as one stateful interface
* emit a resulting structured submission

Stable options may include:

* title
* description or help
* validation
* grouping or pages

Typical degradation:

* richer form backend → sequential `io::in::*` prompts

`io::ui::form` is the only initial canonical `io::ui::*` noun.

`io::ui::form` is declarative. It is not a giant serialized argument blob.

Form construction occurs through independent builder operations that define the form structure step by step. The concrete builder surface may evolve, but the contract must preserve this shape:

1. initialize form state
2. create or identify a form
3. add groups, dialogs, or pages
4. add fields to those groups
5. run the form

The `io::ui::form` family therefore behaves more like a declarative builder than a one-shot prompt.

This distinction is mandatory:

* one-shot prompts belong in `io::in::*`
* stateful form construction belongs in `io::ui::form::*`

The `io::ui::form` family may expose sub-operations such as form creation, group creation, field declaration, validation, and execution. Those operations must remain declarative and compositional.

## 7. Relationship Between `progress` and `spin`

`progress` is the semantic contract. `spin` is a specialized convenience entrypoint into that contract.

The rule is:

* `io::out::progress` is canonical
* `io::out::spin` is a thin specialization or preset over `progress`
* `io::spin` is a convenience alias for `io::out::spin`

Example shape:

* `io::out::progress --style=spin --title "Loading" -- command ...`
* `io::out::spin "Loading" -- command ...`

Both may exist. They are not peers in the architecture.

## 8. Backend Model

The wrapper resolves backends by capability, not by hardcoded public backend choice.

### 8.1 Public Functions Stay Generic

A public capability function does not know backend-specific command syntax.

For a migrated capability such as `io::in::filter`, the public function forwards argv (and may merge stdin candidates) into **`io::_backends::dispatch`**. Dispatch performs schema-driven parse, backend resolution, projection, and shim invocation. Legacy leaves that have not been migrated may still perform local argument canonicalization before dispatch; the target state is a **thin leaf** plus schema plus shims only.

### 8.2 Backend Shims Own Backend Syntax

The backend shim is the only layer that may know:

* the command or library name
* backend-specific flags
* backend-native environment-variable names
* output quirks
* capability gaps

No public capability may branch across backends with repeated inline ladders such as:

* `if gum ...`
* `elif fzf ...`
* `else ...`

Those branches belong to the adapter and shim layers.

### 8.3 Default resolution order

Resolution walks a **try-order** of backends, intersects candidates with **schema-derived eligibility** when the command schema attaches `option-eligibility` metadata to options, and picks the first backend that remains eligible, is supported, and exposes a shim for that capability.

If **`IO_BACKEND_ORDER`** is set to a non-empty value, that list is the try-order (whitespace-separated).

If it is unset or empty, the try-order depends on the capability’s top segment after **`io::`**:

* **`fmt`** and **`layout`**: **`native`**, then **`gum`**, then **`fzf`**. Pure transforms default to the in-process native implementation before optional external tools.
* **`in`**, **`out`**, and **`ui`**: **`gum`**, **`fzf`**, **`native`**. Effectful capabilities prefer richer front ends when installed.

Any other leading segment uses the same order as **`in`**, **`out`**, and **`ui`**.

Finer distinctions (stable options, enriched features) are not inputs to this walk yet; they remain part of the capability contract for documentation and future selection rules.

### 8.4 Backend shim naming

Public capabilities keep stable names such as **`io::layout::border`**. Dispatch resolves a backend and invokes the corresponding shim:

* pattern: **`io::_backends::<backend_id>::shim::<tier>::<leaf>`**
* example: **`io::_backends::native::shim::layout::border`** satisfies **`io::layout::border`** when the native backend is selected

Internal helpers shared across `@io` (parser, schema registry, transforms, print dispatch) live under **`io::__…`** (for example **`io::__parse-options`**, **`io::__strip-ansi`**, **`io::__capture-input`**). These are not public `io::*` capabilities.

### 8.5 Implementation Rule

The implementation rule is:

* generic public capability functions
* minimal backend adapter layer
* tiny backend-specific shims
* no public backend-shaped API
* no repeated backend ladders scattered across the public surface

### 8.6 Degradation Rule

Degradation proceeds by semantic preservation.

The rule is not "abstract by intersection only." The rule is:

1. derive the floor from the present intersection
2. define the public capability from the present semantic union
3. degrade from richer implementations toward the floor

## 9. Original Command Mapping

The original motivating command set maps into the canonical surface as follows.

### 9.1 Input

* `choose` → `io::in::choose`
* `confirm` → `io::in::confirm`
* `file` → `io::in::file`
* `filter` → `io::in::filter`
* `input` → `io::in::input`
* `write` → `io::in::write`

### 9.2 Output

* `pager` → `io::out::pager`
* `spin` → `io::out::spin` and semantically `io::out::progress`
* `table` → `io::out::table`
* `log` → `io::out::log`

### 9.3 Pure Formatting and Layout

* `format` → `io::fmt::render`
* `style` → split across `io::fmt::*` and `io::layout::*`
* `join` → `io::layout::join`

### 9.4 `style` Decomposition

`style` is not one thing. It is a conflation of two distinct strata.

Inline styling maps as follows:

* `bold` → `io::fmt::bold`
* `faint` → `io::fmt::faint`
* `italic` → `io::fmt::italic`
* `underline` → `io::fmt::underline`
* `strikethrough` → `io::fmt::strikethrough`
* foreground color → `io::fmt::fg`
* background color → `io::fmt::bg`

When a command later exposes element-scoped presentation styling publicly,
that styling belongs to the command's own per-element style families rather
than to one omnibus `style` bucket.

Block and spatial styling maps as follows:

* borders → `io::layout::border`
* padding → `io::layout::pad`
* margins → `io::layout::margin`
* alignment → `io::layout::align`
* width → `io::layout::width`
* height → `io::layout::height`

The wrapper does not preserve `style` as the architectural center. At most, `io::style` may exist as compatibility sugar that delegates into `fmt` and `layout`.

## 10. Composition Law

### 10.1 Pure Composition

`io::fmt::*` and `io::layout::*` must compose cleanly. They may accept text by argument, standard input, or both, but they remain pure transforms.

Examples:

* `fmt::bold "$(fmt::fg red "$text")"`
* `printf '%s\n' "$text" | layout::border --style=rounded | io::pager`

### 10.2 Effectful Boundary

Prompting, paging, progress display, terminal ownership, and form execution belong only to:

* `io::in`
* `io::out`
* `io::ui`

The pure layers must not perform those behaviors.

## 11. Filesystem Placement

**@io as a package.** `@io` is a **core** sub-package. Its registry seat is **`./packages.d/@core/@io/`**. Canonical module paths for authoring and loading are **`functions.d/@io/`** (functions, nested loadlists) and **`aliases.d/@io/`** (aliases). The registry tree mirrors those locations with **back-symlinks** into the modules — the live module trees hold the real bytes (module-owned file groups). See [`PACKAGES.md`](../PACKAGES.md) §9 (`@core` package behavior).

The public `@io` subpackages are:

```text
@io/@in
@io/@out
@io/@fmt
@io/@layout
@io/@ui
```

Internal support subpackages include schema, backend, wrapper, and test support. The literal `_` segment does not affect these scopes. A concrete path such as:

```text
functions.d/@core/_/@io/@in/filter.sh
```

is a module-side materialization of the `@io/@in` concern after `_` is erased from package scope.

Singleton form applies inside `@io`. For example:

```text
@io/load.sh
@io/@load/load.sh
```

are equivalent forms of the same `@io/@load` concern when `load` is represented as a singleton. Existing names such as `io::load::zsh` and `io::load::bash` therefore belong to the same package concern as a future `io::load`.

The callable surface follows the reconciled package scope with reserved `@core` elided:

```text
@core/@io/@in         -> io::in
@core/@io/@in/@filter -> io::in::filter
```

**Activation.** The root **`functions.d/.loadlist`** and **`aliases.d/.loadlist`** include **`@io`** so the loader pulls the package in normal sessions.

The canonical module home for implementation files is:

* `functions.d/@io/`

Root-level public surfaces such as `io::load` and `io::save`, and loader-adjacent operational surfaces such as `io::load::*`, are implemented from those module-owned seats even though they sit outside the five-tier interactive capability taxonomy.

`@formatting` is legacy implementation material to be subsumed into `@io`. It is not a parallel public vocabulary.

If value survives from `@formatting`, that value converges into the `io::*`, `fmt::*`, and `layout::*` public surface. Any residual `@formatting` names are compatibility or internal details only.

## 12. Extension Rule

The presence of richer interactive systems such as `huh`, `bubbletea`/`bubbles`, and `textual` does not authorize flattening every future interface into `io::in::*`.

The extension rule is:

* keep `io::ui::*` as the compound or stateful tier
* begin that tier with `io::ui::form`
* add additional `io::ui::*` nouns only when they become first-class contracts in their own right

`io::ui::list`, `io::ui::tree`, `io::ui::browser`, `io::ui::screen`, and `io::ui::app` are not canonical until they are separately specified.

## 13. Settled Summary

### 13.1 Stable Tiers

* `io::in`
* `io::out`
* `io::fmt`
* `io::layout`
* `io::ui`

### 13.2 Stable Initial Public Surface

* `load`
* `save`
* `confirm`
* `input`
* `choose`
* `filter`
* `file`
* `write`
* `log`
* `pager`
* `table`
* `progress`
* `spin`
* `bold`
* `faint`
* `italic`
* `underline`
* `strikethrough`
* `fg`
* `bg`
* `render`
* `border`
* `pad`
* `margin`
* `align`
* `width`
* `height`
* `join`
* `form`

### 13.3 Internal Semantic Law

* `fmt` and `layout` are pure
* `in`, `out`, and `ui` are effectful
* `load` and `save` are operational surfaces outside the five-tier pure/effectful split

### 13.4 Alias Rule

* effectful convenience under `io::...`
* pure convenience under `fmt::...` and `layout::...`
* no bare aliases
* no flattening pure transforms into undifferentiated `io::*`

### 13.5 Architectural Rule

**The public API is derived from real libraries. The internal semantics remain disciplined.**
