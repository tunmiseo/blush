# `io::*` Derivation Plan

> **Status:** Planning specification (pre-implementation).
> **Scope:** Methodology and work plan for deriving the `io::*` package surface.
> **Not this document:** This is not the public `io::*` package specification. [`IO.md`](./IO.md) remains the package-surface spec-to-be-documentation.
> **See also:** [`IO.md`](./IO.md)

-----

## 1. Purpose

This document specifies how the `io::*` surface will be *derived*, not how it will be presented to end users once settled.

The immediate problem is not "what commands exist in `io::*`?" but "how do we systematically construct those commands from a heterogeneous backend set without drifting into ad hoc side-channel passthrough flags and backend leaks while still preserving backend familiarity where that is the point?"

The derivation plan has four goals:

1. Enumerate the backend command surface before writing shims.
2. Partition that surface into canonical `io::*` union commands.
3. Partition each union command's option surface into canonical union options, then classify them into public, private, and rejected subsets.
4. Freeze that partition as the contract that later code must compile against.

-----

## 2. Split From `IO.md`

`IO.md` is the package spec. It should eventually read like the documentation of a settled public surface.

This document is upstream of that:

* it records the quotient/partition methodology
* it records the command inventory that must be analyzed
* it records the first-pass classification work
* it guides implementation order

So:

* [`IO.md`](./IO.md) answers: "What is `io::*`?"
* this document answers: "How do we derive and stabilize `io::*`?"

-----

## 3. Definitions

### 3.1 Backend Binary

A **backend binary** is a concrete tool or implementation family such as `gum`, `fzf`, `bat`, `glow`, `pv`, or `native`.

### 3.2 Backend Command

A **backend command** is one concrete subcommand or callable surface offered by a backend binary, such as `gum filter`, `gum choose`, `fzf`, `bat`, or the native shell implementation of `select + grep`.

### 3.3 Union Command

A **union command** is one canonical `io::*` command formed by partitioning backend commands into equivalence classes of "same operation".

Examples:

* `io::in::filter` is the union command over `gum filter`, `fzf`, and native filter/select.
* `io::out::view` is the union command over `bat`, `glow -p`, `gum pager`, and native pager/viewers.

### 3.4 Union Option

A **union option** is a canonical option class for one union command, formed by:

1. taking the disjoint union of all backend options for that union command's backend members
2. partitioning that set into equivalence classes of "same semantic option"
3. naming each resulting class canonically

The full set of named union options is the option surface for that union command.

This full partition, not merely the public subset, is the specification object for the command.

The canonical union-option name is primarily a specification and documentation handle. The parser may accept multiple spellings for the same union option, including backend-native spellings.

In practice, union names should usually stay short and familiar.

Common-sense defaults:

* if one backend spelling already names the concern well, usually reuse it
* avoid explanatory paraphrases when a familiar backend name already does the job
* when backend names diverge substantially, let the more familiar spelling win or use a light compromise
* short aliases such as `-w` or `-N` do not by themselves force one-letter canonical names

### 3.5 Public Option

A **public option** is a union option classified as part of the stable documented contract.

Publicity is a contract decision, not a cardinality or portability fact.

A public option:

* is named in the documented command surface
* is promised as part of the stable `io::*` API
* has a clear command-level semantic
* admits a mapping on every participating backend
* admits a concrete native implementation, even if degraded
* has its native realization specified tightly enough to implement and test
* may be singleton or non-singleton
* may be lowered by translation or verbatim forwarding

The canonical public spelling exists for documentation and backend-agnostic scripts. Users are not required to abandon familiar backend-native spellings when those can be recognized honestly.

Here, "participating backend" means every backend still eligible after the option set's own constraints are applied. A public option may legitimately narrow the backend set, provided the remaining backend set still has a coherent mapping and a concrete native realization.

Placeholder labels such as "multi selection mode" or "header line" are not enough to settle publicity. If the native realization is still hand-wavy, the option remains only a candidate public option.

### 3.6 Private Option

A **private option** is a union option that `io::*` accepts but that is not part of the stable documented contract.

Private options:

* are still part of the designed union-option surface
* are recognized rather than treated as unknown leftovers
* may be singleton or non-singleton
* are often preserved in backend-familiar syntax
* should not require the user to memorize a separate union spelling merely because `rings` exists

### 3.7 Singleton Union Option

A **singleton union option** is a union option whose equivalence class has cardinality 1.

Singleton is a fact about the partition, not about publicity.

A singleton union option may be:

* public or private
* verbatim-forwarded or translated

The default policy is verbatim preservation. Renaming or syntax-changing a singleton requires compelling justification.

### 3.8 Verbatim Forwarding

**Verbatim forwarding** is a lowering policy in which a recognized union option is forwarded to the target backend unchanged.

This is the default for singleton union options, because the point is often to preserve backend familiarity cheaply.

### 3.9 Translation

**Translation** is a lowering policy in which a recognized union option is rewritten into backend-native syntax.

Translation is common for non-singleton union options and exceptional for singleton union options.

### 3.10 Backend-Pinned Verbatim Forwarding

**Backend-pinned verbatim forwarding** is the escape-hatch mode used only when `--backend <id>` has already pinned dispatch.

In backend-pinned verbatim forwarding:

* remaining backend-native arguments may be forwarded unchanged
* `io::*` does not need to prove they are valid backend options
* the pinned backend is the validator and error source

This is distinct from recognized union-option forwarding. It is backend-pinned verbatim forwarding, not a side-channel passthrough facility.

### 3.11 Rejected Option

A **rejected option** is a backend option or candidate union option explicitly excluded from the unpinned `io::*` contract because it is unsafe, non-composable, shell-integration-oriented, transport-oriented, or otherwise out of scope for the capability.

-----

## 4. Methodology

### 4.1 Inventory the backend set

For each namespace and leaf command:

1. list the participating backend binaries
2. list the concrete backend commands
3. record the current or intended preference order

No shim design starts before the backend set is explicit.

### 4.2 Partition commands first

Given the disjoint union of backend commands, partition them into equivalence classes of "same command".

Each resulting class becomes one canonical `io::*` union command.

This step defines the command surface.

### 4.3 Partition options second

For each union command:

1. list every positional argument across all backend members
2. list every option across all backend members
3. identify semantic equivalences
4. name each canonical class

This named partition is the option-surface specification for that command.

### 4.4 Classify after partitioning

After the option partition is explicit, classify each union option as one of:

* **public**
* **private**
* **rejected**

The classification rule is:

* **public** if the option is worth documenting and promising as part of the stable command surface
* **private** if the option is legitimate to accept but not part of the stable documented command surface
* **rejected** if the option would make the capability non-composable, unsafe, or shell/tooling specific

Public/private classification is independent of singleton/non-singleton cardinality.

For a candidate public option to become truly public, its native behavior must be specified concretely enough that the native backend can actually implement it in a meaningful, testable way.

Every candidate-public table must therefore carry a **Native contract** column. Each row in that column must either state one testable native behavior sentence or name the blocker plainly enough that the row remains only candidate status rather than silently reading as public.

### 4.5 Independent Axes

The derivation plan tracks several independent properties:

* `public` / `private` / `rejected`
* `singleton` / `non-singleton`
* `verbatim-forwarded` / `translated`
* `unpinned` / `backend-pinned`
* whether a recognized `(option, value)` pair reduces backend eligibility during unpinned dispatch

These axes must not be collapsed into one another.

`constrains_backend(option, value) -> bool` is a pure dispatch predicate. It is true exactly when recognizing that option/value pair eliminates at least one participating backend from the current eligible set for the command. It says nothing about whether the option is public or private.

In particular:

* a public option may be singleton
* a private option may be non-singleton
* a singleton option is usually verbatim-forwarded
* a non-singleton option is often translated
* a public option may constrain backend eligibility
* a private option may constrain backend eligibility

### 4.6 Minimum Transformation Principle

The parser should not force users to unlearn backend flags they already know.

In practice:

* the shim is a polyglot parser, not a dialect enforcer
* canonical union names exist for the spec and for backend-agnostic scripting
* those canonical spellings should be concise rather than explanatory paraphrases
* backend-native spellings should be accepted whenever they can be recognized honestly
* private options should usually be accepted in their backend-native spellings without fuss
* a separate mandatory union spelling should not be introduced unless there is compelling justification

### 4.7 Default Lowering Policy

Lowering policy follows these defaults:

* singleton union options are preserved verbatim by default
* renaming or syntax-changing a singleton requires compelling justification
* non-singleton union options may be translated where necessary to express one canonical class across backends

### 4.8 `--backend` Pins Dispatch

Backend selection may be pinned with `--backend <id>`.

That flag belongs:

* on namespace dispatchers, such as `io::in --backend gum --filter ...`
* and on leaf commands, such as `io::in::filter --backend gum ...`

Once dispatch is pinned, the backend choice no longer depends on the option surface.

Backend-pinned verbatim forwarding does not replace the partition process. It exists alongside it as an explicit escape hatch after routing has already been settled.

### 4.9 No Side-Channel Passthrough

The following pattern is prohibited as the long-term design:

* `--gum-arg ...`
* `--gum ... --`
* environment-carried raw argv blobs such as `IO_GUM_PASSTHROUGH`

Those bypass the contract derivation step and leak backend syntax through the public layer.

Backend-pinned verbatim forwarding, when allowed, must happen through ordinary argv after backend pinning, not through synthetic side channels.

### 4.10 Runtime Rule

Runtime behavior splits into unpinned and pinned cases.

In unpinned mode:

1. parse argv left to right into command-specific union options, recognizing either canonical spellings or honest backend-native spellings
2. reject unknown options with a hard parse failure
3. begin with the full eligible backend set for the command
4. when a recognized `(option, value)` pair satisfies `constrains_backend(option, value)`, reduce the eligible backend set to the backends that honestly realize it
5. the first recognized `(option, value)` pair that reduces eligibility fixes dispatch to the highest-preference backend inside that reduced eligible set
6. if no recognized `(option, value)` pair reduces eligibility, choose by the command's backend preference order
7. once the backend is fixed, resolve subsequent recognized options against that fixed backend only
8. if a subsequent recognized option cannot resolve against the fixed backend, terminate the current dispatch and compose the remainder as a separate invocation, typically by pipe chaining or equivalent staged composition
9. lower recognized options by verbatim forwarding or translation as appropriate

Silent dropping of unknown flags is not permitted in unpinned mode.

This algorithm is greedy and directional:

* it commits on the first eligibility-reducing option/value pair
* it does not backtrack
* it does not search globally for a backend that satisfies every option at once
* it does not perform an optimal partition search over the full option set

Redundant backend spellings that collapse to the same union option are tolerated. Non-composable recognized options force composition rather than global re-resolution.

In backend-pinned mode:

1. peel off `--backend <id>`
2. pin dispatch to that backend
3. optionally consume recognized union options
4. allow remaining backend-native args to flow through unchanged
5. let the pinned backend validate and fail on bad backend-specific argv

This rule belongs here once. It should not be repeated per command.

### 4.11 Singletons do not require quotient work

Native-only leaf commands do not require the full quotient process.

For those commands, the command surface is already settled by the function itself.

The heavy derivation work belongs to the multi-backend leaves.

### 4.12 Composed Lowering

**Composed lowering** is a first-class dispatch path in which one `io::*` command lowers into a staged pipeline of other `io::*` commands before any raw native degradation is attempted.

This is distinct from backend substitution:

* backend substitution picks a different backend member for the same union command
* composed lowering rewrites the current command into an explicit `io::*` pipeline whose stages each remain honest about their own command identity

Composed lowering should be preferred over raw native degradation when all three of the following hold:

1. the command semantics remain honest after staging
2. the pipeline preserves the underlying data without lossy reversal or display-string guessing
3. the composed pipeline is simpler than the native equivalent, or at least less complex and less fragile than the native path it replaces

The third condition is comparative, not absolute. A composed lowering may still be nontrivial. It is justified when the alternative native realization would be worse: more brittle, more stateful, or more ad hoc.

Examples:

* `io::in::confirm` may lower to `io::in::choose "Yes" "No"` before falling to raw `read`
* `io::in::choose` may lower to `io::in::filter --exact` before falling to a plain numbered prompt
* `io::out::table` may lower through indexed, data-preserving selection stages rather than trying to reverse visual rows back into raw records by string match

When the pipeline cannot preserve data honestly, or when staging would be more fragile than a direct native implementation, raw native lowering remains the correct fallback.

### 4.13 Style-family doctrine

Style families are a first-class kind of union-option family.

A **style family** names one semantic UI element within a command and the style properties attached to that element. The canonical class name is **`<ELEMENT>_STYLES`**.

A **style property** is one member of that family. In the first pass, the style-property vocabulary is:

* `foreground`
* `background`

Style families are partitioned per element. They must not be:

* collapsed into omnibus wrappers such as `COLORS` or generic `STYLES`
* split back apart into unrelated per-flag singleton rows
* left under raw backend-residue names such as `GUM_MATCH_STYLE`

The canonical family name belongs to the quotient. It need not be a literal backend element name. For example, `gum pager` exposes a bare `--foreground` / `--background` pair with no named element; `rings` therefore coins the canonical family `TEXT_STYLES` rather than pretending the backend supplied a recoverable literal element name.

Non-style presentation controls are outside this doctrine even when a backend places them near style flags or environment variables. In particular:

* `padding`
* `width`
* `height`
* `cursor.mode`
* `spinner`
* `theme`
* `show-help`
* `timeout`

remain ordinary option classes. They may still admit ambient defaults, but they are not style families.

Argv spellings and ambient defaults target the same canonical family/property values:

* argv uses the ordinary parser and option partition
* ambient defaults are folded into canonical values before backend lowering

Backend-native spellings may remain accepted where the worked-command surface chooses to preserve backend familiarity.

### 4.14 Publicity and native realization for style families

A style family is **eligible** for publicity only if the styled element exists honestly in the command's native interaction model.

A style family becomes **public** only if `rings` wants that element to be part of the stable documented command contract. The methodology supplies the criterion; the worked-command tables carry only recommendations where that decision remains open.

Raw native color capability does not by itself make a family public.

Every public style family must name one deterministic native realization that is concrete enough to implement and test. The derivation plan does not permit phrases such as "ANSI approximation or honest no-op" as a substitute for that contract.

If a styled element has no honest native analog, the family remains private rather than being granted a fake public fallback.

### 4.15 Ambient defaults and shim declarations

Ambient defaults are rings-native environment values that feed the same canonical option space as argv. Their precedence is:

1. explicit argv
2. rings-native ambient defaults
3. backend-native environment variables for the selected backend only
4. backend compiled defaults

Within the rings-native ambient-default layer:

* canonical full-path names win over alias names
* alias names are convenience synonyms only where a matching qualified `io::...` functional alias already exists

Canonical ambient-default names use the full command path, for example:

* `RINGS_IO_IN_CHOOSE_CURSOR_FOREGROUND`
* `RINGS_IO_IN_FILTER_MATCH_FOREGROUND`
* `RINGS_IO_OUT_LOG_LEVEL_FOREGROUND`

When a qualified functional alias exists for the command, the corresponding ambient-default alias drops the `RINGS_` prefix and mirrors the alias path mechanically, for example:

* `io::confirm` -> `IO_CONFIRM_*`
* `io::input` -> `IO_INPUT_*`
* `io::choose` -> `IO_CHOOSE_*`
* `io::filter` -> `IO_FILTER_*`
* `io::log` -> `IO_LOG_*`
* `fmt::bold` -> `FMT_BOLD_*`
* `layout::border` -> `LAYOUT_BORDER_*`

Thus `RINGS_IO_IN_CONFIRM_PROMPT_FOREGROUND` and `IO_CONFIRM_PROMPT_FOREGROUND` are the same rings-native ambient-default layer, with the canonical full-path name winning on conflict.

Backend-native environment variables remain shim-owned compatibility input. They do not define the canonical option space.

The derivation plan does not introduce a heavyweight backend-registration subsystem. It requires only that a shim declare, in implementation terms, which canonical families or properties it supports and how they lower.

### 4.16 Parser, schema, dispatch, and shim contract

The implementation contract is:

1. one canonical parser engine
2. per-command schemas
3. optional reusable schema fragments
4. central dispatch that evaluates schema-owned eligibility metadata
5. schema-driven shim projection

The structures below are conceptual contract shapes. They do not require JSON at runtime. Shell implementation may realize them with ordinary shell-native tables, arrays, and variables so long as the same invariants hold.

#### 4.16.1 Canonical option map

The parser produces one normalized option map per invocation.

```text
{
  command: "io::in::filter",
  backend_pin: null | "gum" | "fzf" | "native",
  verbatim_tail: [string, ...],
  options: {
    PROMPT: { value: "> ", source: "argv" },
    HEADER: { value: "Pick one", source: "env:canonical" },
    LIMIT: { value: 1, source: "default" },
    FILTER: { value: "foo", source: "argv" },
    SELECTED_STYLES: {
      value: { foreground: "212", background: "" },
      source: "argv"
    }
  },
  positionals: [string, ...],
  recognized_private: {
    "selected.foreground": { value: "212", source: "argv" }
  }
}
```

Rules:

* `options` is keyed by canonical option id only
* style families are represented as nested property maps under one canonical family id
* `recognized_private` is only for accepted backend-familiar private spellings that do not have a public canonical leaf spelling
* every present entry records one source:
  * `argv`
  * `env:canonical`
  * `env:alias`
  * `env:backend`
  * `default`
* absent means unset; the parser does not materialize null-filled maps

#### 4.16.2 Schema format

Each command exports one schema.

```text
{
  command: "io::in::filter",
  fragments: ["selector", "timeout", "help"],
  options: {
    PROMPT: {
      type: "string",
      classification: "public",
      aliases: ["--prompt"],
      env: {
        canonical: "RINGS_IO_IN_FILTER_PROMPT",
        alias: "IO_FILTER_PROMPT"
      },
      repeat: "last",
      payload_key: "prompt"
    },
    LIMIT: {
      type: "integer",
      classification: "public",
      aliases: ["--limit"],
      env: {
        canonical: "RINGS_IO_IN_FILTER_LIMIT",
        alias: "IO_FILTER_LIMIT"
      },
      repeat: "last",
      payload_key: "limit"
    },
    SELECTED_STYLES: {
      type: "style-family",
      classification: "private",
      aliases: [],
      properties: {
        foreground: {
          private_spellings: ["--selected.foreground"],
          env: {
            canonical: "RINGS_IO_IN_FILTER_SELECTED_FOREGROUND",
            alias: "IO_FILTER_SELECTED_FOREGROUND"
          }
        },
        background: {
          private_spellings: ["--selected.background"],
          env: {
            canonical: "RINGS_IO_IN_FILTER_SELECTED_BACKGROUND",
            alias: "IO_FILTER_SELECTED_BACKGROUND"
          }
        }
      },
      payload_key: "selected_styles"
    }
  }
}
```

Rules:

* classification is per canonical option: `public`, `private`, or `candidate`
* accepted backend-familiar spellings live in schema, not in leaf parser code
* env keys live in schema, not hand-written in leaves
* `payload_key` is projection metadata only; the parser does not emit backend argv

#### 4.16.3 Parser result

`io::__parse-options <schema-id> -- "$@"` returns the canonical option map and also exposes the ordered recognized-option stream used by dispatch.

```text
{
  map: <canonical option map>,
  seen: [
    { id: "PROMPT", value: "> ", source: "argv" },
    { id: "FILTER", value: "foo", source: "argv" },
    { id: "selected.foreground", value: "212", source: "argv", private: true }
  ]
}
```

Rules:

* `seen` preserves left-to-right recognition order
* dispatch consumes `seen` for eligibility reduction
* shims do not consume `seen`; they consume projected payload only
* parse failure additionally exposes errors and the first unrecognized token when unpinned parsing fails

#### 4.16.4 Eligibility hook

`constrains_backend(option, value)` lives in schema-owned metadata and is evaluated centrally by dispatch.

Possible schema forms:

```text
FILTER: {
  ...
  eligibility: {
    when: "always",
    allow: ["fzf", "native"]
  }
}
```

```text
MODE: {
  ...
  eligibility: [
    { when_value: "interactive", allow: ["gum", "fzf", "native"] },
    { when_value: "batch", allow: ["fzf", "native"] }
  ]
}
```

Rules:

* leaves do not encode eligibility
* shims do not encode eligibility
* dispatch evaluates schema eligibility against `seen`
* if multiple recognized options constrain eligibility, dispatch intersects the allowed backend sets in recognition order

This keeps constraints authoritative without a hand-written capability monolith in the backend adapter.

#### 4.16.5 Shim projection

Shim projection is structured, not positional.

Dispatch performs a schema-driven projection step:

```text
{
  prompt: "> ",
  header: "Pick one",
  limit: 1,
  filter: "foo",
  selected_styles: {
    foreground: "212",
    background: ""
  },
  positionals: [...]
}
```

In shell terms, this projects to `key=value` argv pairs followed by `--` and then any positionals.

```text
prompt=>\  header=Pick\ one limit=1 filter=foo selected_styles.foreground=212 -- item1 item2
```

Rules:

* no rigid `$1` / `$2` / `$3` shim contracts
* no backend-native flags passed into shims from leaves
* projection is schema-owned and uniform across backends
* shims parse projected `key=value` pairs and then lower to backend-native flags

The frozen implementation decisions are:

1. one parser engine
2. per-command schemas
3. parser output is the canonical option map plus ordered `seen`
4. eligibility lives in schemas and is evaluated centrally by dispatch
5. shim projection uses structured `key=value` pairs, not positional payloads

-----

## 5. Current Scope And Work Order

This first derivation pass focuses on the four core namespaces discussed in the backend refactor:

* `io::in`
* `io::out`
* `io::fmt`
* `io::layout`

Dispatchers, aliases, and native-only singletons need little or no quotient work. Multi-backend leaves are the priority.

### 5.1 Command Inventory

#### `io::in`

| Command | File | Backends | Priority |
|---|---|---|---|
| `in` | `functions.d/@core/@io/@in/in.sh` | dispatcher | n/a |
| `choose` | `functions.d/@core/@io/@in/choose.sh` | `gum choose`, native select | 3 |
| `confirm` | `functions.d/@core/@io/@in/confirm.sh` | `gum confirm`, native read | 7 |
| `file` | `functions.d/@core/@io/@in/file.sh` | `gum file`, `fzf`, native find+select | 4 |
| `filter` | `functions.d/@core/@io/@in/filter.sh` | `gum filter`, `fzf`, native filter/select | 1 |
| `input` | `functions.d/@core/@io/@in/input.sh` | `gum input`, native read | 6 |
| `write` | `functions.d/@core/@io/@in/write.sh` | `gum write`, native read/cat | 8 |

#### `io::out`

| Command | File | Backends | Priority |
|---|---|---|---|
| `out` | `functions.d/@core/@io/@out/out.sh` | dispatcher | n/a |
| `view` | planned surface; no current leaf file | `bat`, `glow -p`, `gum pager`, native pager/viewer | 2 |
| `pager` | `functions.d/@core/@io/@out/pager.sh` | alias of planned `view --paging` | n/a |
| `spin` | `functions.d/@core/@io/@out/spin.sh` | `gum spin`, native loop/printf | 9 |
| `progress` | `functions.d/@core/@io/@out/progress.sh` | `pv`, native progress | 5 |
| `table` | `functions.d/@core/@io/@out/table.sh` | `gum table`, native `column -t` | 10 |
| `log` | `functions.d/@core/@io/@out/log.sh` | `gum log`, native `printf >&2` | 11 |
| `center` | `functions.d/@core/@io/@out/center.sh` | native | singleton |
| `left` | `functions.d/@core/@io/@out/left.sh` | native | singleton |
| `newline` | `functions.d/@core/@io/@out/newline.sh` | native | singleton |
| `println` | `functions.d/@core/@io/@out/println.sh` | native | singleton |
| `rule` | `functions.d/@core/@io/@out/rule.sh` | native | singleton |
| `tab` | `functions.d/@core/@io/@out/tab.sh` | native | singleton |
| `status` family | `functions.d/@core/@io/@out/@status/*` | native, optional gum styling | singleton-first |
| `preset` family | `functions.d/@core/@io/@out/@preset/*` | native, optional gum styling | singleton-first |

#### `io::fmt`

| Command | File | Backends | Priority |
|---|---|---|---|
| `fmt` | `functions.d/@core/@io/@fmt/fmt.sh` | dispatcher | n/a |
| `bold` | `functions.d/@core/@io/@fmt/bold.sh` | `gum style --bold`, native ANSI | 13 |
| `faint` | `functions.d/@core/@io/@fmt/faint.sh` | `gum style --faint`, native ANSI | 13 |
| `italic` | `functions.d/@core/@io/@fmt/italic.sh` | `gum style --italic`, native ANSI | 13 |
| `underline` | `functions.d/@core/@io/@fmt/underline.sh` | `gum style --underline`, native ANSI | 13 |
| `strikethrough` | `functions.d/@core/@io/@fmt/strikethrough.sh` | `gum style --strikethrough`, native ANSI | 13 |
| `fg` | `functions.d/@core/@io/@fmt/fg.sh` | `gum style --foreground`, native ANSI | 13 |
| `bg` | `functions.d/@core/@io/@fmt/bg.sh` | `gum style --background`, native ANSI | 13 |
| `render` | `functions.d/@core/@io/@fmt/render.sh` | `gum format`, native renderer | 13 |
| `wrap` | `functions.d/@core/@io/@fmt/wrap.sh` | native | singleton |
| `shorten` | `functions.d/@core/@io/@fmt/shorten.sh` | native | singleton |
| `capitalize` | `functions.d/@core/@io/@fmt/capitalize.sh` | native | singleton |
| `uppercase` | `functions.d/@core/@io/@fmt/uppercase.sh` | native | singleton |
| `lowercase` | `functions.d/@core/@io/@fmt/lowercase.sh` | native | singleton |
| `trim-whitespace` | `functions.d/@core/@io/@fmt/trim-whitespace.sh` | native | singleton |

#### `io::layout`

| Command | File | Backends | Priority |
|---|---|---|---|
| `layout` | `functions.d/@core/@io/@layout/layout.sh` | dispatcher | n/a |
| `align` | `functions.d/@core/@io/@layout/align.sh` | `gum style --align`, native | 12 |
| `border` | `functions.d/@core/@io/@layout/border.sh` | `gum style --border`, native | 12 |
| `height` | `functions.d/@core/@io/@layout/height.sh` | `gum style --height`, native | 12 |
| `join` | `functions.d/@core/@io/@layout/join.sh` | `gum join`, native | 12 |
| `margin` | `functions.d/@core/@io/@layout/margin.sh` | `gum style --margin`, native | 12 |
| `pad` | `functions.d/@core/@io/@layout/pad.sh` | `gum style --padding`, native | 12 |
| `width` | `functions.d/@core/@io/@layout/width.sh` | `gum style --width`, native | 12 |

### 5.2 Priority Order

Richness-first work order:

1. `io::in::filter`
2. `io::out::view`
3. `io::in::choose`
4. `io::in::file`
5. `io::out::progress`
6. `io::in::input`
7. `io::in::confirm`
8. `io::in::write`
9. `io::out::spin`
10. `io::out::table`
11. `io::out::log`
12. `io::layout::*`
13. `io::fmt::*` decoration commands
14. native-only `io::out::*` singletons

### 5.3 Reference style-family inventory

The style-family inventory is derived mechanically from the full Gum surface
recorded in [`functions.d/@std/gum-style-variables`](/Users/monad/src/repos/rings/functions.d/@std/gum-style-variables).
Inventory is discovery only. Public/private classification remains a separate
worked-command pass under §4.14.

| Backend command | Canonical style families | Notes |
|---|---|---|
| `gum choose` | `CURSOR_STYLES`, `HEADER_STYLES`, `ITEM_STYLES`, `SELECTED_STYLES` | Element names are mechanically recovered from `--cursor.*`, `--header.*`, `--item.*`, and `--selected.*`. |
| `gum confirm` | `PROMPT_STYLES`, `SELECTED_STYLES`, `UNSELECTED_STYLES` | Mechanically recovered from `--prompt.*`, `--selected.*`, and `--unselected.*`. |
| `gum file` | `CURSOR_STYLES`, `SYMLINK_STYLES`, `DIRECTORY_STYLES`, `FILE_STYLES`, `PERMISSIONS_STYLES`, `SELECTED_STYLES`, `FILE_SIZE_STYLES`, `HEADER_STYLES` | `FILE_SIZE_STYLES` normalizes Gum's `--file-size.*` pair. |
| `gum filter` | `INDICATOR_STYLES`, `SELECTED_INDICATOR_STYLES`, `UNSELECTED_PREFIX_STYLES`, `HEADER_STYLES`, `TEXT_STYLES`, `CURSOR_TEXT_STYLES`, `MATCH_STYLES`, `PROMPT_STYLES`, `PLACEHOLDER_STYLES` | `SELECTED_INDICATOR_STYLES` normalizes the flag pair `--selected-indicator.*`; the paired env vars use the legacy `GUM_FILTER_SELECTED_PREFIX_*` name. |
| `gum input` | `PROMPT_STYLES`, `PLACEHOLDER_STYLES`, `CURSOR_STYLES`, `HEADER_STYLES` | Mechanically recovered from the dotted Gum surface. |
| `gum pager` | `TEXT_STYLES`, `LINE_NUMBER_STYLES`, `MATCH_STYLES`, `MATCH_HIGHLIGHT_STYLES`, `HELP_STYLES` | `TEXT_STYLES` is a quotient name introduced by `rings` for Gum pager's elementless `--foreground` / `--background` pair. |
| `gum spin` | `SPINNER_STYLES`, `TITLE_STYLES` | Mechanically recovered from `--spinner.*` and `--title.*`. |
| `gum table` | `BORDER_STYLES`, `CELL_STYLES`, `HEADER_STYLES`, `SELECTED_STYLES` | Mechanically recovered from the dotted Gum surface. |
| `gum write` | `BASE_STYLES`, `CURSOR_LINE_NUMBER_STYLES`, `CURSOR_LINE_STYLES`, `CURSOR_STYLES`, `END_OF_BUFFER_STYLES`, `LINE_NUMBER_STYLES`, `HEADER_STYLES`, `PLACEHOLDER_STYLES`, `PROMPT_STYLES` | `CURSOR_LINE_NUMBER_STYLES`, `CURSOR_LINE_STYLES`, and `END_OF_BUFFER_STYLES` normalize Gum's longer element names. |
| `gum log` | `LEVEL_STYLES`, `TIME_STYLES`, `PREFIX_STYLES`, `MESSAGE_STYLES`, `KEY_STYLES`, `VALUE_STYLES`, `SEPARATOR_STYLES` | Mechanically recovered from the dotted Gum surface. |

-----

## 6. First Worked Command: `io::in::filter`

### 6.1 Command

| Field | Value |
|---|---|
| canonical command | `io::in::filter` |
| file | `functions.d/@core/@io/@in/filter.sh` |
| backend preference | `gum`, `fzf`, `native` |
| backend members | `gum filter`; `fzf`; native filter/select |

### 6.2 Arguments

`io::in::filter` takes a candidate list, applies a matching pattern, and returns results.

Candidate input is one logical argument surface with two equivalent feeds:

* positional candidates: `io::in::filter [opts] item1 item2 ...`
* stdin candidates: newline-delimited input on stdin

Result semantics:

* by default, the command is interactive and returns selected result or results
* single-select emits one selected candidate
* multi-select emits one selected candidate per line
* in non-interactive mode, the command emits matching results without opening a TUI

### 6.3 Candidate Public Options

These are the current candidate public options for `io::in::filter`.

| Class | Canonical option | Meaning | `gum filter` | `fzf` | `native` | Native contract |
|---|---|---|---|---|---|---|
| `PROMPT` | `--prompt <text>` | prompt text | `--prompt` | `--prompt` | prompt text before native interactive filtering | Native prints the prompt text before the interactive query line and preserves it for the full filtering session. |
| `HEADER` | `--header <text>` | header text | `--header` | `--header` | header text above native filtering output | Native prints the header text once above the interactive candidate view or above batch output when a header is requested. |
| `MULTI` | `--multi` | enable multi-select | `--no-limit` or `--limit > 1` | `--multi` | repeated native selection | Native accepts repeated selections until termination or limit and emits one selected candidate per line. |
| `LIMIT` | `--limit <n>` | cap number of selections | `--limit` | `--multi=<n>` | cap accepted selections | Native emits at most `n` selected candidates and stops accepting further selections after that cap. |
| `EXACT` | `--exact` | exact matching mode | `--no-fuzzy` | `--exact` | exact/fixed native matching | Native matches candidates by exact or fixed comparison rather than fuzzy scoring. |
| `QUERY` | `--query <text>` | seed the initial query | `--value` | `--query` | initial native filter seed | Native seeds the initial query buffer before the first interactive render. |
| `SELECT_IF_ONE` | `--select-if-one` | auto-select if one candidate remains | `--select-if-one` | `--select-1` | auto-return sole remaining match | Native emits the sole remaining candidate immediately without prompting. |
| `NON_INTERACTIVE` | `--filter <pattern>` | batch filter, no TUI | — excludes gum | `--filter <text>` | native pattern-match path | When `--filter <pattern>` is present, native skips interactive UI and emits matching candidates line by line. |

Notes:

* Public options are the documented contract, not the whole accepted surface.
* Publicity does not imply non-singleton cardinality.
* For `io::in::filter`, the first-pass candidate public options happen to be overlapping across backends.
* The Native contract column states the concrete sentence each row would have to satisfy before promotion from candidate to settled public status.
* `NON_INTERACTIVE` is a value-dependent eligibility constraint: `--filter <pattern>` narrows the eligible backend set to `fzf` and `native`, while interactive calls leave `gum`, `fzf`, and `native` in play.
* The canonical spelling is `--filter <pattern>` rather than a longer paraphrase such as `--non-interactive <pattern>`, because union spellings should not be more verbose than the backend spellings they unify.

### 6.4 Private Options

Private options are accepted union options that are not part of the documented public contract. They are still recognized by the command surface in unpinned mode.

Private options may still reduce backend eligibility under `constrains_backend(option, value)`. That is a dispatch fact, not a publicity promise.

Private options obey the same partition discipline as public options. A real union option must not be split apart merely because it is private.

The union-option labels in this section are specification labels. They do not imply that users must type a separate canonical private flag. In most cases the preferred user spellings remain the backend-native flags that the parser recognizes jointly.

For `io::in::filter`, the private partition is still first-pass work. The backend-grouped inventories below are supporting material for the remaining quotient work, not a claim that every listed backend flag is already a backend-unique union option.

Even so, in unpinned mode recognized private options still constrain backend choice because they are recognized union options rather than raw leftover argv.

The style-family rows below are recommendation-level placements under §4.14
and remain subject to final arbitration.

#### Already identified cross-backend private union options

For the style-family rows below, the current cross-backend correspondence to `fzf` is one shared open problem rather than nine separate ones: each family participates in `fzf`'s `--color <COLSPEC>` surface, but the exact token-level mapping still needs tightening.

| Class | Meaning | `gum filter` | `fzf` | Notes |
|---|---|---|---|---|
| `CURSOR` | glyph marking the current item / cursor line | `--indicator <text>` | `--pointer <text>` | direct correspondence |
| `HEIGHT` | finder height | `--height <n>` | `--height <spec>` | same concern; value domains still need refinement |
| `REVERSE` | reverse / bottom-origin layout | `--reverse` | `--layout=reverse` | additional `fzf --layout` values remain outside this row |
| `INPUT_DELIMITER` | input record separation | `--input-delimiter <text>` | `--read0` | same concern; gum accepts arbitrary delimiter, fzf only NUL |
| `OUTPUT_DELIMITER` | output record separation | `--output-delimiter <text>` | `--print0` | same concern; gum accepts arbitrary delimiter, fzf only NUL |
| `ANSI` | ANSI handling on input | `--strip-ansi`, `--no-strip-ansi` | `--ansi` and default non-`--ansi` mode | same concern; polarity/defaults still need refinement |
| `INDICATOR_STYLES` | style family for the current indicator glyph | `--indicator.*` | `--color <COLSPEC>` | shared `fzf` color-mapping refinement |
| `SELECTED_INDICATOR_STYLES` | style family for the selected-item indicator glyph | `--selected-indicator.*` | `--color <COLSPEC>` | shared `fzf` color-mapping refinement; Gum uses `--selected-indicator.*`, while the paired env vars use the legacy `GUM_FILTER_SELECTED_PREFIX_*` name |
| `UNSELECTED_PREFIX_STYLES` | style family for the unselected-item prefix glyph | `--unselected-prefix.*` | `--color <COLSPEC>` | shared `fzf` color-mapping refinement |
| `HEADER_STYLES` | style family for the header text | `--header.*` | `--color <COLSPEC>` | shared `fzf` color-mapping refinement |
| `TEXT_STYLES` | style family for ordinary result text | `--text.*` | `--color <COLSPEC>` | shared `fzf` color-mapping refinement |
| `CURSOR_TEXT_STYLES` | style family for the text under the current cursor row | `--cursor-text.*` | `--color <COLSPEC>` | shared `fzf` color-mapping refinement |
| `MATCH_STYLES` | style family for matched query fragments | `--match.*` | `--color <COLSPEC>` | shared `fzf` color-mapping refinement |
| `PROMPT_STYLES` | style family for the prompt text | `--prompt.*` | `--color <COLSPEC>` | shared `fzf` color-mapping refinement |
| `PLACEHOLDER_STYLES` | style family for placeholder text | `--placeholder.*` | `--color <COLSPEC>` | shared `fzf` color-mapping refinement |

For rows such as `REVERSE`, `INPUT_DELIMITER`, and `OUTPUT_DELIMITER`, the important requirement is joint recognition and honest routing. The spec does not require a third user-facing private spelling if the backend-native spellings already carry the right familiarity.

#### Remaining gum-side private inventory still requiring final partitioning

| Class | Native flag(s) | Meaning |
|---|---|---|
| `GUM_SELECTED` | `--selected <csv|*>` | preselected items |
| `GUM_SHOW_HELP` | `--show-help`, `--no-show-help` | help keybind visibility |
| `GUM_SELECTED_PREFIX` | `--selected-prefix <text>` | selected-item prefix |
| `GUM_UNSELECTED_PREFIX` | `--unselected-prefix <text>` | unselected-item prefix |
| `GUM_PLACEHOLDER` | `--placeholder <text>` | input placeholder |
| `GUM_WIDTH` | `--width <n>` | input width |
| `GUM_FUZZY_SORT` | `--fuzzy-sort`, `--no-fuzzy-sort` | score-sort fuzzy results |
| `GUM_TIMEOUT` | `--timeout <duration>` | abort after timeout |
| `GUM_STRICT` | `--strict`, `--no-strict` | require a match before returning |
| `GUM_PADDING` | `--padding <box>` | inner padding |

#### Remaining fzf-side private inventory still requiring final partitioning

| Class | Native flag(s) | Meaning |
|---|---|---|
| `FZF_EXTENDED` | `--extended`, `--no-extended` | extended query syntax |
| `FZF_IGNORE_CASE` | `--ignore-case`, `--no-ignore-case` | case matching mode |
| `FZF_SCHEME` | `--scheme <default|path|history>` | scoring scheme |
| `FZF_LITERAL` | `--literal` | disable latin normalization |
| `FZF_NTH` | `--nth <expr>` | restrict searchable fields |
| `FZF_WITH_NTH` | `--with-nth <expr>` | transform displayed fields |
| `FZF_DELIMITER` | `--delimiter <regex>` | field delimiter |
| `FZF_NO_SORT` | `--no-sort` | disable result sorting |
| `FZF_TAIL` | `--tail <n>` | input memory cap |
| `FZF_TRACK` | `--track` | track current selection on updates |
| `FZF_TAC` | `--tac` | reverse input order |
| `FZF_DISABLED` | `--disabled` | start with search disabled |
| `FZF_TIEBREAK` | `--tiebreak <csv>` | tie-break criteria |
| `FZF_NO_MOUSE` | `--no-mouse` | disable mouse |
| `FZF_BIND` | `--bind <spec>` | key bindings |
| `FZF_CYCLE` | `--cycle` | cyclic scroll |
| `FZF_WRAP` | `--wrap` | wrap lines |
| `FZF_WRAP_SIGN` | `--wrap-sign <text>` | wrapped-line marker |
| `FZF_NO_MULTI_LINE` | `--no-multi-line` | disable multi-line items with `--read0` |
| `FZF_KEEP_RIGHT` | `--keep-right` | keep line end visible |
| `FZF_SCROLL_OFF` | `--scroll-off <n>` | vertical scroll margin |
| `FZF_NO_HSCROLL` | `--no-hscroll` | disable horizontal scroll |
| `FZF_HSCROLL_OFF` | `--hscroll-off <n>` | right scroll margin |
| `FZF_FILEPATH_WORD` | `--filepath-word` | path-aware word motions |
| `FZF_JUMP_LABELS` | `--jump-labels <chars>` | jump-label alphabet |
| `FZF_MIN_HEIGHT` | `--min-height <n>` | minimum percent-height |
| `FZF_TMUX` | `--tmux[=<spec>]` | tmux popup mode |
| `FZF_LAYOUT_OTHER` | `--layout <layout>` | layout modes not covered by `REVERSE` |
| `FZF_BORDER` | `--border[=<style>]` | border style |
| `FZF_BORDER_LABEL` | `--border-label <text>` | border label |
| `FZF_BORDER_LABEL_POS` | `--border-label-pos <spec>` | border label position |
| `FZF_MARGIN` | `--margin <box>` | outer margin |
| `FZF_PADDING` | `--padding <box>` | inner padding |
| `FZF_INFO` | `--info <style>` | info line style |
| `FZF_INFO_COMMAND` | `--info-command <cmd>` | generated info line |
| `FZF_SEPARATOR` | `--separator <text>` | info separator |
| `FZF_NO_SEPARATOR` | `--no-separator` | hide separator |
| `FZF_SCROLLBAR` | `--scrollbar[=<chars>]` | scrollbar characters |
| `FZF_NO_SCROLLBAR` | `--no-scrollbar` | hide scrollbar |
| `FZF_MARKER` | `--marker <text>` | multi-select marker |
| `FZF_MARKER_MULTI_LINE` | `--marker-multi-line <text>` | multiline marker glyphs |
| `FZF_HEADER_LINES` | `--header-lines <n>` | fixed header lines from input |
| `FZF_HEADER_FIRST` | `--header-first` | print header before prompt |
| `FZF_ELLIPSIS` | `--ellipsis <text>` | truncation marker |
| `FZF_TABSTOP` | `--tabstop <n>` | tab width |
| `FZF_HIGHLIGHT_LINE` | `--highlight-line` | highlight whole current line |
| `FZF_NO_BOLD` | `--no-bold` | disable bold |
| `FZF_HISTORY` | `--history <file>` | history file |
| `FZF_HISTORY_SIZE` | `--history-size <n>` | history capacity |
| `FZF_PREVIEW` | `--preview <cmd>` | preview command |
| `FZF_PREVIEW_WINDOW` | `--preview-window <spec>` | preview layout |
| `FZF_PREVIEW_LABEL` | `--preview-label <text>` | preview label |
| `FZF_PREVIEW_LABEL_POS` | `--preview-label-pos <spec>` | preview label position |
| `FZF_EXIT_0` | `--exit-0` | exit immediately if no match |
| `FZF_PRINT_QUERY` | `--print-query` | emit query as first line |
| `FZF_EXPECT` | `--expect <csv>` | accept on specific keys |
| `FZF_SYNC` | `--sync` | synchronous staged filtering |
| `FZF_WITH_SHELL` | `--with-shell <cmd>` | child-process shell command |
| `FZF_WALKER` | `--walker <spec>` | directory walker options |
| `FZF_WALKER_ROOT` | `--walker-root <dir>` | walker root |
| `FZF_WALKER_SKIP` | `--walker-skip <csv>` | skipped directories |

### 6.5 Rejected In Unpinned Mode

The following are outside the unpinned `io::in::filter` contract and should be rejected rather than treated as recognized union options:

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `FZF_LISTEN` | `--listen[=<addr>]` | starts an HTTP control surface |
| `FZF_BASH` | `--bash` | shell integration script output, not filtering |
| `FZF_ZSH` | `--zsh` | shell integration script output, not filtering |
| `FZF_FISH` | `--fish` | shell integration script output, not filtering |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` help, not part of command contract |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |
| `FZF_MAN` | `--man` | documentation output, not capability behavior |

### 6.6 Backend-Pinned Verbatim Forwarding

When `io::in::filter --backend <id> ...` is used, dispatch is already settled.

In that mode:

* recognized union options may still be consumed
* remaining backend-native args may be forwarded unchanged
* bad backend-specific argv is the caller's problem
* backend diagnostics are acceptable

This escape hatch does not make unknown options acceptable in unpinned mode.

Example:

```sh
io::in::filter --backend gum --indicator=">" --gum-option-wrong value
```

may validly dispatch to backend argv equivalent to:

```sh
gum filter --indicator=">" --gum-option-wrong value
```

and let `gum` reject `--gum-option-wrong`.

### 6.7 Consequences For Implementation

`io::in::filter` should eventually parse:

* canonical public options
* private options
* `--backend <id>`

In unpinned mode it should not accept unknown leftover argv.

`--unknown-flag` in unpinned mode should fail immediately rather than being ignored or guessed at.

In backend-pinned mode it may forward backend-native leftover argv unchanged.

Unpinned resolution should follow the same greedy rule stated in §4.9:

* the first constraining recognized option fixes backend choice for the current dispatch
* later options are interpreted against that fixed backend
* incompatibility triggers composition, not global backend search

In other words:

* `--prompt ">"` is a public option
* `--indicator ">"` is a typed gum singleton
* `--pointer ">"` is a typed fzf singleton
* `--gum-arg --indicator='>'` is invalid
* `--backend gum --gum-option-wrong` may be forwarded and fail in `gum`

-----

## 7. Second Worked Command: `io::out::view`

### 7.1 Command

| Field | Value |
|---|---|
| canonical command | `io::out::view` |
| file | `functions.d/@core/@io/@out/view.sh` (planned) |
| backend preference | `bat`, `glow`, `gum`, `native` |
| backend members | `bat`; `glow` (stdout/pager mode); `gum pager`; native `less` / `cat` |
| functional alias | `io::out::pager` = `io::out::view --paging always` |

### 7.2 Arguments

`io::out::view` takes content and displays it.

Content is supplied as a file argument or via stdin.

Two modes are controlled by `PAGING`:

* paging mode: interactive scroll / viewport presentation
* non-paging mode: straight to stdout, possibly decorated

### 7.3 Candidate Public Options

These are the current candidate public options for `io::out::view`.

| Class | Canonical option | Meaning | `bat` | `glow` | `gum pager` | `native` | Native contract |
|---|---|---|---|---|---|---|---|
| `PAGING` | `--paging <when>` | control interactive paging: `auto`, `always`, `never` | `--paging <when>` | `-p` for pager-on, default stdout for non-paging | always interactive | `less` vs `cat` | Native uses a pager for `always`, plain stdout rendering for `never`, and terminal-context detection for `auto`. |
| `LINE_NUMBERS` | `--line-numbers` | show line numbers while viewing | `--number` or `--style=numbers` | `-l`, `--line-numbers` | `--show-line-numbers` | `less -N`, `cat -n` | Native emits visible line numbers in both paging and non-paging paths when this option is present. |
| `WRAP` | `--wrap <mode>` | wrap policy: `auto`, `on`, `off` | `--wrap <mode>` | — | `--soft-wrap`, `--no-soft-wrap` | plain wrap vs `less -S` | Native wraps or preserves long lines according to the requested mode in both pager and non-pager paths. |
| `WIDTH` | `--width <n>` | wrapping width / presentation width | `--terminal-width <n>` | `-w`, `--width <n>` | — | native width-controlled rendering | Native wraps or truncates against the requested presentation width before output, using terminal width or `80` when no width is given. |
| `LANGUAGE` | `--language <lang>` | force syntax-highlighting language | `--language <lang>` | — excludes glow | — excludes gum | native currently ineligible | No native rendering contract is accepted yet for `LANGUAGE`; if native is selected, it must reject the option rather than silently ignoring it. |
| `THEME` | `--theme <name>` | syntax-highlighting theme | `--theme <name>` | — | — excludes gum | native currently ineligible | No native rendering contract is accepted yet for `THEME`; if native is selected, it must reject the option rather than silently ignoring it. |

Notes:

* `io::out::pager` is expected to collapse into `io::out::view --paging always`.
* `PAGING` has value-level backend constraints:
  `--paging never` excludes `gum pager`.
  `--paging always` excludes plain `cat`.
  `--paging auto` follows terminal/pipe context.
* `WRAP` and `WIDTH` are distinct concerns. `glow -w` is width, not general wrap policy.
* The canonical width spelling is `--width <n>`, not a longer paraphrase such as `--wrap-width <n>`.
* `THEME` and `LANGUAGE` remain candidate only. They should be demoted or promoted only after a real native rendering sentence is accepted.

### 7.4 Private Options

The style-family rows in this section are recommendation-level placements
under §4.14 and remain subject to final arbitration.

#### Already identified private union options

| Class | Meaning | `bat` | `glow` | `gum pager` | `native` | Notes |
|---|---|---|---|---|---|---|
| `STYLE_COMPONENTS` | what decorations to show | `--style <components>` | — | — | — | bat-only |
| `HIGHLIGHT_LINES` | highlight specific line ranges | `--highlight-line <N:M>` | — | — | — | bat-only |
| `LINE_RANGE` | display only a line range | `--line-range <N:M>` | — | — | — | bat-only |
| `COLOR_MODE` | when to use color output | `--color <when>` | — | — | — | bat-only |
| `FILE_NAME` | override displayed filename | `--file-name <name>` | — | — | — | bat-only |
| `DIFF_MODE` | show only changed lines | `--diff` | — | — | — | bat-only |
| `DIFF_CONTEXT` | diff context lines | `--diff-context <n>` | — | — | — | bat-only |
| `SQUEEZE_BLANK` | collapse consecutive empty lines | `--squeeze-blank` | — | — | — | bat-only |
| `STRIP_ANSI` | strip ANSI from input | `--strip-ansi <when>` | — | — | — | bat-only |
| `MAP_SYNTAX` | map globs to syntax | `--map-syntax <glob:syntax>` | — | — | — | bat-only |
| `IGNORED_SUFFIX` | ignore filename suffix when detecting syntax | `--ignored-suffix <sfx>` | — | — | — | bat-only |
| `PAGER_COMMAND` | which pager binary to invoke | `--pager <cmd>` | — | — | `$PAGER` | same concern, refinement still light |
| `TAB_WIDTH` | tab stop width | `--tabs <T>` | — | — | `less -x<T>` | same concern across two backends |
| `MARKDOWN_STYLE` | markdown rendering style | — | `-s`, `--style <name>` | — | — | glow-only; distinct from `THEME` |
| `MARKDOWN_WIDTH` | markdown word-wrap width | — | `-w`, `--width <n>` | — | — | glow-only; distinct from `WRAP` |
| `PRESERVE_NEWLINES` | preserve original newlines | — | `-n`, `--preserve-new-lines` | — | — | glow-only |
| `TIMEOUT` | timeout until exit | — | — | `--timeout <dur>` | — | gum-only singleton |
| `TEXT_STYLES` | style family for the main pager body text | — | — | `--foreground`, `--background` | — | `TEXT_STYLES` is the quotient name for Gum pager's bare body-color pair; raw Gum spellings `--foreground` and `--background` remain accepted |
| `LINE_NUMBER_STYLES` | style family for line-number rendering | — | — | `--line-number.*` | — | recommended private placement pending final arbitration |
| `MATCH_STYLES` | style family for search matches | — | — | `--match.*` | — | recommended private placement pending final arbitration |
| `MATCH_HIGHLIGHT_STYLES` | style family for the active or emphasized search match | — | — | `--match-highlight.*` | — | recommended private placement pending final arbitration |
| `HELP_STYLES` | style family for pager help text | — | — | `--help.*` | — | recommended private placement pending final arbitration |

#### Cross-backend equivalences still requiring refinement

| Concern | `bat` | `glow` | `gum pager` | `native` | Notes |
|---|---|---|---|---|---|
| `SHOW_ALL` | `--show-all` | — | — | `cat -A` | same concern, two backends |

Notes:

* No synthetic dotted alias such as `--text.foreground` is introduced in this pass. `TEXT_STYLES` is the canonical quotient family, while Gum's raw `--foreground` and `--background` spellings remain accepted backend-familiar input.

### 7.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `BAT_CACHE` | `bat cache` subcommand | syntax/theme management, not viewing |
| `BAT_LIST_LANGUAGES` | `--list-languages` | introspection, not viewing |
| `BAT_LIST_THEMES` | `--list-themes` | introspection, not viewing |
| `BAT_DIAGNOSTIC` | `--diagnostic` | debug output |
| `BAT_ACKNOWLEDGEMENTS` | `--acknowledgements` | metadata |
| `BAT_COMPLETION` | `--completion <shell>` | shell integration |
| `BAT_SET_TERMINAL_TITLE` | `--set-terminal-title` | side effect outside content display |
| `GLOW_CONFIG` | `glow config` subcommand | editor/config integration |
| `GLOW_COMPLETION` | `glow completion` subcommand | shell integration |
| `GLOW_TUI` | `-t`, `--tui` | changes the command from content display to content discovery |
| `GLOW_ALL_FILES` | `-a`, `--all` | content-discovery mode, not content display |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 7.6 Content-Aware Backend Selection

Unlike `io::in::filter`, `io::out::view` benefits from content-aware preference:

* if the input is Markdown, prefer `glow`, then `bat`, then `gum`, then `native`
* if the input is source code or structured text, prefer `bat`, then `gum`, then `native`
* if the content type is unknown but a filename is available, use extension or language hints before falling back
* if stdin has no filename and no `--language` hint, use the static fallback `bat`, then `gum`, then `native`
* `--language` fixes preference to `bat`

This parameterizes backend preference; it does not replace the greedy resolution algorithm.

### 7.7 Current Split To Collapse

The present tree does not yet expose one unified `io::out::view` leaf.

Instead:

* [`pager.sh`](/Users/monad/src/repos/rings/functions.d/@core/@io/@out/pager.sh) is the current pager-oriented entrypoint
* [`render.sh`](/Users/monad/src/repos/rings/functions.d/@core/@io/@fmt/render.sh) is the current render-oriented entrypoint
* [`@glow/shims.sh`](/Users/monad/src/repos/rings/functions.d/@core/@io/@_backends/@glow/shims.sh) currently participates through `io::fmt::render`, not through an `io::out::view` leaf
* glow therefore appears in two commands for two different roles: markdown rendering belongs to `io::fmt::render`, while viewing already-supplied content belongs to `io::out::view`
* [`@gum/shims.sh`](/Users/monad/src/repos/rings/functions.d/@core/@io/@_backends/@gum/shims.sh) and [`@native/shims.sh`](/Users/monad/src/repos/rings/functions.d/@core/@io/@_backends/@native/shims.sh) currently expose pager shims
* `bat` is part of the planned `view` backend set but is not yet represented in the current tree

### 7.8 Consequences For Implementation

The derivation work for `io::out::view` should collapse the current split without forcing users to learn a new dialect:

* existing familiar spellings like `--number`, `--line-numbers`, `--style`, and pager-oriented flags should continue to parse honestly where they belong
* `io::out::pager` should become an alias of `io::out::view --paging always`
* render-oriented and pager-oriented options should be unified only where they really describe the same concern
* anything still lacking a concrete native realization must remain provisional rather than being overstated as public

-----

## 8. Third Worked Command: `io::in::choose`

### 8.1 Command

| Field | Value |
|---|---|
| canonical command | `io::in::choose` |
| file | `functions.d/@core/@io/@in/choose.sh` |
| backend preference | direct `gum choose`, then staged `io::in::filter --exact`, then `native` |
| direct backend members | `gum choose`; native numbered selection |
| staged lowering | discrete candidate set piped into `io::in::filter --exact` before any raw native fallback |

### 8.2 Arguments

`io::in::choose` takes a finite candidate set and returns one or more chosen results.

Candidate input is supplied in two equivalent feeds:

* positional candidates: `io::in::choose [opts] item1 item2 ...`
* stdin candidates: newline-delimited input on stdin

Result semantics:

* single-select emits one chosen candidate
* multi-select emits one chosen candidate per line

Notes:

* direct chooser UI remains preferred when available and honest
* when direct chooser backends are unavailable or otherwise ineligible, `choose` may lower through `io::in::filter --exact` under §4.12 before dropping to a raw numbered prompt
* searchable exact-match staging remains honest because the emitted values are still the original candidates rather than transformed display strings

### 8.3 Candidate Public Options

These are the current candidate public options for `io::in::choose`.

| Class | Canonical option | Meaning | direct `gum choose` | staged `io::in::filter --exact` | `native` | Native contract |
|---|---|---|---|---|---|---|
| `HEADER` | `--header <text>` | header text above choices | `--header <text>` | `--header <text>` | printed header text before choice list | Native prints the header text once before numbering or listing choices. |
| `LIMIT` | `--limit <n>` | maximum number of selections | `--limit <n>` | `--limit <n>` | cap accepted selections | Native returns no more than `n` selected values. |
| `MULTI` | `--multi` | enable choosing more than one item | `--no-limit` or `--limit > 1` | `--multi` | repeated native selection | Native allows repeated selection and emits selected values one per line. |
| `SELECT_IF_ONE` | `--select-if-one` | auto-accept the only candidate | `--select-if-one` | `--select-if-one` | emit the sole candidate without prompting | Native emits the sole candidate immediately without prompting. |

Notes:

* `HEADER`, `LIMIT`, `MULTI`, and `SELECT_IF_ONE` are the cleanest current public candidates because the direct, staged, and native paths all admit straightforward realizations.
* `PROMPT` is intentionally not listed as a candidate public option yet. `gum choose` has no prompt plane distinct from `--header`, so the current shim's `--prompt` behavior is better treated as an implementation alias or fallback than as a settled union option.
* `MULTI` and `LIMIT` remain distinct concerns. `MULTI` enables cardinality greater than one; `LIMIT` caps the maximum number of returned choices.
* The staged `filter` path is not backend substitution. It is composed lowering under §4.12, used to preserve a richer selection UI before falling all the way to raw native prompting.
* As with other worked commands, no row is truly public until its native realization is specified concretely enough to implement and test.

### 8.4 Private Options

The current `choose` tree only exposes a small public shim surface, but the upstream `gum choose` command surface exposes a larger native option inventory that must be partitioned honestly.

#### Cross-backend private union options

| Class | Meaning | `gum choose` | `native` | Notes |
|---|---|---|---|---|
| `LABEL_DELIMITER` | display one label while emitting another value | `--label-delimiter <text>` | candidate native `label:value` split before numbering choices | same concern across two backends; not yet promoted to public |
| `INPUT_DELIMITER` | delimiter for stdin-fed choices | `--input-delimiter <text>` | candidate native delimiter parsing instead of newline-only input | same concern across two backends; native side still needs concrete realization |
| `OUTPUT_DELIMITER` | delimiter for emitted selections | `--output-delimiter <text>` | candidate native join delimiter instead of newline output | same concern across two backends; native side still needs concrete realization |
| `ORDERED` | preserve selection order in emitted results | `--ordered` | native multi-select already emits in selection order | native default already matches the ordered behavior |
| `STRIP_ANSI` | strip ANSI sequences when reading stdin choices | `--[no-]strip-ansi` | candidate native ANSI stripping on stdin-fed choices | same concern across two backends; native behavior still needs specification |
| `TIMEOUT` | timeout until choose aborts or returns | `--timeout <dur>` | candidate timed native selection prompt | same concern, but the native timeout semantics are still unsettled |

#### Gum-only singleton / structured private surface

| Class | Meaning | `gum choose` | Notes |
|---|---|---|---|
| `HEIGHT` | chooser viewport height | `--height <n>` | gum-only singleton |
| `CURSOR` | cursor marker glyph | `--cursor <text>` | gum-only singleton |
| `SHOW_HELP` | show or hide help keybinds | `--[no-]show-help` | gum-only singleton |
| `CURSOR_PREFIX` | prefix on the cursor row | `--cursor-prefix <text>` | gum-only singleton |
| `SELECTED_PREFIX` | prefix on selected rows | `--selected-prefix <text>` | gum-only singleton |
| `UNSELECTED_PREFIX` | prefix on unselected rows | `--unselected-prefix <text>` | gum-only singleton |
| `SELECTED` | choices that should start selected | `--selected <value|*>` | gum-only singleton; official command surface uses `--selected`, not `--select` |
| `PADDING` | inner padding around the chooser viewport | `--padding <box>` | gum-only singleton |
| `CURSOR_STYLES` | style family for the cursor row marker | `--cursor.*` | recommended private placement pending final arbitration |
| `HEADER_STYLES` | style family for chooser header text | `--header.*` | recommended private placement pending final arbitration |
| `ITEM_STYLES` | style family for ordinary chooser items | `--item.*` | recommended private placement pending final arbitration |
| `SELECTED_STYLES` | style family for chosen items | `--selected.*` | recommended private placement pending final arbitration |

Notes:

* This inventory is grounded in the upstream `gum choose` command definition and help surface, not just README examples.
* The workspace does not currently have `gum` installed, so the derivation is based on upstream source and upstream help output rather than a local invocation.
* The minimum-transformation rule applies here too: backend-native spellings like `--label-delimiter` should continue to parse honestly if they remain in the accepted surface.
* Several of these rows are still candidate private union options rather than settled classifications because the native realization has to be specified with the same care as `filter` and `view`.
* When `choose` lowers through `io::in::filter`, the accepted private surface of `filter` may participate at that staged step. That does not enlarge the stable public vocabulary of `choose` itself.

### 8.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 8.6 Consequences For Implementation

`io::in::choose` should stay simpler than `filter`, but the same general rules apply:

* unknown flags fail in unpinned mode
* direct `gum choose` remains preferred when available and honest
* before falling to a raw numbered prompt, `choose` may lower to `io::in::filter --exact` under §4.12
* staged lowering must preserve the underlying candidate values exactly; display-only transformations require a recoverable value mapping
* backend-native spellings should be preserved where they can be recognized honestly
* `--backend gum` may still permit raw backend-native forwarding after dispatch is pinned
* the current `--prompt` shim behavior should not be allowed to silently masquerade as a distinct union option until the `PROMPT` vs `HEADER` question is settled
* `--selected` should be treated as the honest gum-native spelling of preselection if that surface is accepted
* cancellation from either the direct chooser or the staged filter path is terminal and should not trigger a second prompt

-----

## 9. Fourth Worked Command: `io::out::progress`

### 9.1 Command

| Field | Value |
|---|---|
| canonical command | `io::out::progress` |
| file | `functions.d/@core/@io/@out/progress.sh` |
| planned backend preference | `pv`, `native` |
| planned backend members | `pv`; native shell progress loop / byte or line counter |
| related specialization | `io::out::spin` remains the busy-indicator specialization |

### 9.2 Arguments

`io::out::progress` monitors a transfer and emits the original data unchanged.

Portable argument surface:

* optional positional paths: `io::out::progress [opts] [path ...]`
* if no paths are given, read from stdin and write to stdout
* progress information is emitted on stderr

This section treats `progress` as a transfer-monitoring capability derived from `pv`, not as a generic command-wrapper spinner.

### 9.3 Candidate Public Options

These are the current candidate public options for `io::out::progress`.

| Class | Canonical option | Meaning | `pv` | `native` | Native contract |
|---|---|---|---|---|---|
| `NAME` | `--name <text>` | label the progress display | `--name <text>` | native progress label/title | Native prints the name as a fixed prefix or title on each progress update line. |
| `SIZE` | `--size <bytes>` | total expected transfer size | `--size <bytes>` | total-size hint for native percentage / completion reporting | Native computes percentage and completion against the declared total size in bytes. |
| `LINES` | `--lines` | count lines instead of bytes | `--line-mode` | line-counting native progress mode | Native increments progress by line count rather than byte count. |

Notes:

* These rows are still candidate status until the native realization is specified concretely enough to implement and test.
* `NAME` intentionally inherits `pv`'s naming rather than being renamed to `--title`; command-local familiarity wins here.
* The package spec currently describes `progress` as the semantic family above `spin`, but the backend surfaces here are transfer-oriented. That split is real and must be kept explicit.

### 9.4 Private Options

The `pv` surface is much richer than the likely native fallback surface, so most of the real backend vocabulary remains private in this first pass.

#### Candidate cross-backend private union options

| Class | Meaning | `pv` | `native` | Notes |
|---|---|---|---|---|
| `INTERVAL` | refresh interval | `--interval <sec>` | candidate native update cadence | same concern across two backends; native behavior still needs specification |
| `WIDTH` | assumed terminal width | `--width <n>` | candidate native progress width hint | same concern across two backends; native behavior still needs specification |

#### Pv-only private surface

| Class | Meaning | `pv` | Notes |
|---|---|---|---|
| `PROGRESS` | show progress bar | `--progress` | pv-only display toggle |
| `TIMER` | show elapsed time | `--timer` | pv-only display toggle |
| `ETA` | show remaining time | `--eta` | pv-only display toggle |
| `FINETA` | show absolute finish time | `--fineta` | pv-only display toggle |
| `RATE` | show current transfer rate | `--rate` | pv-only display toggle |
| `AVERAGE_RATE` | show average transfer rate | `--average-rate` | pv-only display toggle |
| `BYTES` | show bytes transferred | `--bytes` | pv-only display toggle |
| `BUFFER_PERCENT` | show transfer-buffer fill percentage | `--buffer-percent` | pv-only display toggle |
| `LAST_WRITTEN` | show the last written bytes | `--last-written <n>` | pv-only display toggle |
| `FORMAT` | explicit display format string | `--format <fmt>` | pv-only formatting surface |
| `NUMERIC` | output numeric progress instead of visual display | `--numeric` | pv-only display mode |
| `QUIET` | suppress transfer display | `--quiet` | pv-only display mode |
| `WAIT` | wait for first byte before displaying | `--wait` | pv-only behavior flag |
| `DELAY_START` | delay display startup | `--delay-start <sec>` | pv-only behavior flag |
| `HEIGHT` | assumed terminal height | `--height <n>` | pv-only singleton for now |
| `FORCE` | force output on non-terminal stderr | `--force` | pv-only singleton for now |
| `CURSOR` | use cursor positioning escape sequences | `--cursor` | pv-only singleton for now |
| `RATE_LIMIT` | cap transfer rate | `--rate-limit <rate>` | pv-only transfer control |
| `BUFFER_SIZE` | internal transfer buffer size | `--buffer-size <bytes>` | pv-only transfer control |
| `NO_SPLICE` | disable splice optimization | `--no-splice` | pv-only transfer control |
| `SKIP_ERRORS` | continue past read errors | `--skip-errors` | pv-only error-handling policy |
| `STOP_AT_SIZE` | stop after the declared size | `--stop-at-size` | pv-only transfer control |
| `PIDFILE` | write the pv PID to a file | `--pidfile <file>` | pv-only process-management surface |

### 9.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `REMOTE` | `--remote <pid>` | mutates another pv process; outside the ordinary capability contract |
| `WATCHFD` | `--watchfd <pid[:fd]>` | monitors a foreign process FD rather than the command's own transfer surface |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 9.6 Current Split To Collapse

The current tree does not yet implement this transfer-monitoring derivation.

Instead:

* [`progress.sh`](/Users/monad/src/repos/rings/functions.d/@core/@io/@out/progress.sh) currently exposes a command-wrapper interface with `--style` and `--title`
* [`@gum/shims.sh`](/Users/monad/src/repos/rings/functions.d/@core/@io/@_backends/@gum/shims.sh) currently routes `io::out::progress` through `gum spin`
* [`@native/shims.sh`](/Users/monad/src/repos/rings/functions.d/@core/@io/@_backends/@native/shims.sh) currently implements `progress` as "print title, then run command"
* there is no in-tree `pv` backend yet

So this worked command is a planned derivation, not a description of the present runtime behavior.

### 9.7 Consequences For Implementation

To realize this derivation honestly:

* transfer progress must be separated from spinner semantics instead of treating them as the same backend surface
* `io::out::spin` should absorb the current command-wrapper / busy-indicator behavior
* `io::out::progress` should move toward a stream/file transfer contract derived from `pv`
* candidate public options remain provisional until the native transfer loop is specified concretely enough to implement and test

## 10. Fifth Worked Command: `io::in::confirm`

### 10.1 Command

| Field | Value |
|---|---|
| canonical command | `io::in::confirm` |
| file | `functions.d/@core/@io/@in/confirm.sh` |
| backend preference | direct `gum confirm`, then staged `io::in::choose`, then `native` |
| direct backend members | `gum confirm`; native shell yes/no prompt |
| staged lowering | canonical yes/no labels passed through `io::in::choose` before any raw `read` fallback |

### 10.2 Arguments

`io::in::confirm` asks for one affirmative or negative decision and reports the decision by exit status.

Argument surface:

* optional positional prompt: `io::in::confirm [opts] [prompt]`
* no value is emitted on stdout in the ordinary case
* success exit status means affirmative; nonzero means negative, cancel, or failure

Notes:

* direct `gum confirm` remains the preferred path when available and honest
* before dropping to a raw `[Y/n]` prompt, `confirm` may lower through `io::in::choose "Yes" "No"` under §4.12
* staged lowering remains honest because the composed chooser still expresses the same binary human decision; the wrapper simply maps the chosen label back to exit status and suppresses stdout

### 10.3 Candidate Public Options

These are the current candidate public options for `io::in::confirm`.

| Class | Canonical option | Meaning | direct `gum confirm` | staged `io::in::choose` | `native` | Native contract |
|---|---|---|---|---|---|---|
| `PROMPT` | `--prompt <text>` | prompt text | positional prompt argument | prompt/header text over `Yes` / `No` choices | prompt text before confirmation input | Native prints the prompt text once before reading confirmation input or staged choice. |
| `DEFAULT_YES` | `--default-yes` | empty submission resolves affirmatively | `--default` | affirmative option preselected or ordered first when the staged chooser supports it | `[Y/n]` native default handling | Native treats empty confirmation input as yes and returns success. |

Notes:

* `PROMPT` is a straightforward public candidate even though `gum confirm` takes it positionally rather than as a named flag.
* `DEFAULT_YES` is the only default-direction concern presently realized across the direct, staged, and native paths.
* The staged `choose` path is composed lowering, not a claim that `confirm` has become a generic chooser. The wrapper still maps affirmative to exit `0`, negative or cancel to exit `1`, and emits no ordinary stdout payload.
* `TIMEOUT` is intentionally not public in this first pass. `gum confirm --timeout` and shell `read -t` do not yet have a sufficiently unified timeout contract to promise portably.
* As elsewhere, these rows remain candidate status until the native realization is specified tightly enough to implement and test against the final shim contract.

### 10.4 Private Options

`gum confirm` has a small but real private surface beyond the two public candidates.

#### Gum-only private surface

| Class | Meaning | `gum confirm` | Notes |
|---|---|---|---|
| `AFFIRMATIVE` | custom affirmative label | `--affirmative <text>` | gum-only singleton |
| `NEGATIVE` | custom negative label | `--negative <text>` | gum-only singleton |
| `SHOW_OUTPUT` | print prompt and chosen action to stdout | `--show-output` | gum-only singleton |
| `SHOW_HELP` | show or hide help keybinds | `--[no-]show-help` | gum-only singleton |
| `TIMEOUT` | timeout until confirm returns | `--timeout <dur>` | gum-only singleton for now |
| `PADDING` | inner padding around the confirm UI | `--padding <box>` | gum-only singleton |
| `PROMPT_STYLES` | style family for the prompt text | `--prompt.*` | recommended private placement pending final arbitration |
| `SELECTED_STYLES` | style family for the affirmative choice | `--selected.*` | recommended private placement pending final arbitration |
| `UNSELECTED_STYLES` | style family for the negative choice | `--unselected.*` | recommended private placement pending final arbitration |

Notes:

* When `confirm` lowers through `io::in::choose`, the private surface of that staged chooser may participate there. It does not enlarge the stable public surface of `confirm`.

### 10.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 10.6 Consequences For Implementation

`io::in::confirm` should be one of the simplest derivations in the tree:

* unknown flags fail in unpinned mode
* direct `gum confirm` remains preferred when available and honest
* if direct confirm is unavailable or ineligible, `confirm` should lower to `io::in::choose "Yes" "No"` before falling to raw `read`
* only when no interactive selector path is available should the final raw `[Y/n]` prompt be used
* cancellation from the staged chooser is terminal and returns nonzero rather than triggering a reprompt
* backend-native spellings should be preserved where they can be recognized honestly
* the current positional-prompt behavior should remain acceptable as the backend-native spelling of `PROMPT`
* `--backend gum` may still permit raw backend-native forwarding after dispatch is pinned

-----

## 11. Sixth Worked Command: `io::in::input`

### 11.1 Command

| Field | Value |
|---|---|
| canonical command | `io::in::input` |
| file | `functions.d/@core/@io/@in/input.sh` |
| backend preference | `gum`, `native` |
| backend members | `gum input`; native shell `read` |

### 11.2 Arguments

`io::in::input` acquires one line of text from a human and emits the resulting value on stdout.

Argument surface:

* no positional arguments in the current canonical surface
* result is emitted on stdout
* empty submission may resolve to the initial value when `VALUE` is provided

### 11.3 Candidate Public Options

These are the current candidate public options for `io::in::input`.

| Class | Canonical option | Meaning | `gum input` | `native` | Native contract |
|---|---|---|---|---|---|
| `PROMPT` | `--prompt <text>` | prompt text | `--prompt <text>` | prompt text before input | Native prints the prompt text before reading input. |
| `VALUE` | `--value <text>` | initial value / fallback value | `--value <text>` | seeded-edit path or native rejection | If the active native input path supports seeded editing, native preloads the editable buffer with `VALUE`; otherwise native rejects the option rather than pretending it was honored. |
| `PASSWORD` | `--password` | mask input characters | `--password` | silent native read | Native disables terminal echo while reading the input value. |
| `HEADER` | `--header <text>` | fixed header text above the prompt | `--header <text>` | printed header text before prompt | Native prints the header text once above the prompt. |

Notes:

* `PROMPT`, `VALUE`, `PASSWORD`, and `HEADER` are the strongest current public candidates.
* `VALUE` remains candidate status rather than settled public: `gum --value` is an editable initial buffer, while native realization depends on shell-specific facilities such as readline-backed `read -e -i` or `vared`, not just plain `read`.
* `PLACEHOLDER` is intentionally not public in this first pass. Gum's vanishing inline placeholder is not honestly matched by shell prompt-hint text.
* These rows remain candidate status until the final native behavior is written tightly enough to implement and test.

### 11.4 Private Options

`gum input` exposes a larger private surface than `confirm`, but it is still much smaller than `filter` or `view`.

#### Gum-only private surface

| Class | Meaning | `gum input` | Notes |
|---|---|---|---|
| `PLACEHOLDER` | vanishing inline placeholder text | `--placeholder <text>` | gum-only singleton for now |
| `WIDTH` | input width | `--width <n>` | gum-only singleton for now |
| `CHAR_LIMIT` | maximum value length | `--char-limit <n>` | gum-only singleton; native `read -n` changes UX by auto-submitting at the limit |
| `SHOW_HELP` | show or hide help keybinds | `--[no-]show-help` | gum-only singleton |
| `TIMEOUT` | timeout until input aborts | `--timeout <dur>` | gum-only singleton for now |
| `STRIP_ANSI` | strip ANSI when reading stdin-fed initial value | `--[no-]strip-ansi` | gum-only singleton for now |
| `CURSOR_MODE` | cursor mode | `--cursor.mode <blink|hide|static>` | gum-only singleton |
| `PADDING` | inner padding around the input UI | `--padding <box>` | gum-only singleton |
| `PROMPT_STYLES` | style family for the prompt text | `--prompt.*` | recommended private placement pending final arbitration |
| `PLACEHOLDER_STYLES` | style family for placeholder text | `--placeholder.*` | recommended private placement pending final arbitration |
| `CURSOR_STYLES` | style family for the cursor | `--cursor.*` | recommended private placement pending final arbitration |
| `HEADER_STYLES` | style family for header text | `--header.*` | recommended private placement pending final arbitration |

### 11.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 11.6 Consequences For Implementation

`io::in::input` should remain a narrow one-shot input derivation:

* unknown flags fail in unpinned mode
* backend-native spellings should be preserved where they can be recognized honestly
* `VALUE` should stay explicit as the initializer / empty-submission fallback concern
* `PLACEHOLDER` should remain private unless a genuinely honest native inline-placeholder realization is specified
* `--backend gum` may still permit raw backend-native forwarding after dispatch is pinned
* multiline editing, editor launch, and file-target semantics belong to `io::in::write`, not to `input`

-----

## 12. Seventh Worked Command: `io::in::write`

### 12.1 Command

| Field | Value |
|---|---|
| canonical command | `io::in::write` |
| file | `functions.d/@core/@io/@in/write.sh` |
| backend preference | `gum`, `native` |
| backend members | `gum write`; native `$EDITOR` / fallback `cat` capture |
| native subpaths | editor-backed temporary-file editing; minimal capture fallback |

### 12.2 Arguments

`io::in::write` provides a multiline text editing surface. It is fundamentally a stdout-emitting UI component, but it preserves additive command-level target routing.

Argument surface:

* no positional arguments in the current canonical surface
* multiline text is expected
* stdout emission remains canonical even when a target path is also requested
* when `TARGET` is set, the captured text is additionally written to that path

The multiline trap here is real and must remain explicit:

* `gum write` is an inline multiline textarea backend
* native with `$EDITOR` is full-screen or external-editor temporary-file editing
* native without `$EDITOR` degrades to printed prompt / header plus raw `cat` capture
* public options must be derived honestly across those three interaction shapes rather than pretending they are one uniform UI

Stdin-seeded initial content is intentionally outside the first public contract. Upstream `gum write` can treat stdin as initial value when `--value` is empty; the native fallback does not share that behavior cleanly.

### 12.3 Candidate Public Options

These are the current candidate public options for `io::in::write`.

| Class | Canonical option | Meaning | `gum write` | `native` | Native contract |
|---|---|---|---|---|---|
| `PROMPT` | `--prompt <text>` | prompt text / prompt glyph | `--prompt <text>` | prompt text shown before editor or capture | Native shows the prompt text before entering either the editor-backed path or the minimal capture path. |
| `HEADER` | `--header <text>` | fixed header text above the writer | `--header <text>` | printed header text before editor or capture | Native prints the header text once before entering either native write subpath. |
| `VALUE` | `--value <text>` | initial contents / fallback contents | `--value <text>` | blocked on native subpath selection | Native handling of `VALUE` is blocked on native subpath selection: the implementation must either prefill the editor-backed temporary file or reject `VALUE` until that authoritative subpath rule is settled. |
| `TARGET` | `--target <path>` | also write the captured text to a path while still emitting stdout | canonical command behavior after capture | canonical command behavior after capture | Native writes the captured text to the target path and still emits the same text on stdout. |

Notes:

* `TARGET` is a command-level canonical behavior already named in [`IO.md`](./IO.md), not a backend-native `gum write` flag.
* The native realization does not force a false binary. It acknowledges two distinct subpaths: minimal inline capture and editor-backed temporary-file editing.
* The minimal capture path preserves the inline spatial expectation of `gum write`, but it cannot honestly provide editable seeded contents.
* The editor-backed path honestly provides editable seeded contents, but it introduces the full-screen / external-editor UX chasm.
* `VALUE` remains candidate status rather than settled public because it is blocked on native subpath selection rather than merely being generally provisional.
* The unresolved dependency is whether the authoritative native path is the editor-backed seeded-content path or the minimal capture fallback. That decision is where a future `EDITOR_PREFERENCE` concern could enter if it later becomes public.
* `PLACEHOLDER` is intentionally not public in this first pass. A native prompt hint is not the same semantic as Gum's vanishing inline placeholder.
* `EDITOR_PREFERENCE` is intentionally deferred. [`IO.md`](./IO.md) allows it as a possible stable option, but the derivation plan does not yet treat native subpath selection as a settled public concern.
* As elsewhere, no row is truly public until the native realization is written tightly enough to implement and test.

### 12.4 Private Options

No cross-backend private union options are settled in this first pass. The remaining accepted surface is currently dominated by `gum write`.

#### Gum-only private surface

| Class | Meaning | `gum write` | Notes |
|---|---|---|---|
| `PLACEHOLDER` | vanishing inline placeholder text | `--placeholder <text>` | gum-only singleton for now |
| `WIDTH` | textarea width | `--width <n>` | gum-only singleton |
| `HEIGHT` | textarea height | `--height <n>` | gum-only singleton |
| `SHOW_CURSOR_LINE` | show the current cursor line | `--show-cursor-line` | gum-only singleton |
| `SHOW_LINE_NUMBERS` | show line numbers in the textarea | `--show-line-numbers` | gum-only singleton |
| `CHAR_LIMIT` | maximum value length | `--char-limit <n>` | gum-only singleton; native limits do not share Gum's editing semantics |
| `MAX_LINES` | maximum number of lines | `--max-lines <n>` | gum-only singleton |
| `SHOW_HELP` | show or hide help keybinds | `--[no-]show-help` | gum-only singleton |
| `CURSOR_MODE` | cursor mode | `--cursor.mode <blink|hide|static>` | gum-only singleton |
| `TIMEOUT` | timeout until write aborts | `--timeout <dur>` | gum-only singleton for now |
| `STRIP_ANSI` | strip ANSI when reading stdin-fed initial value | `--[no-]strip-ansi` | gum-only singleton for now |
| `PADDING` | inner padding around the writer UI | `--padding <box>` | gum-only singleton |
| `BASE_STYLES` | style family for the main textarea body | `--base.*` | recommended private placement pending final arbitration |
| `CURSOR_LINE_NUMBER_STYLES` | style family for the current line number | `--cursor-line-number.*` | recommended private placement pending final arbitration |
| `CURSOR_LINE_STYLES` | style family for the current cursor line | `--cursor-line.*` | recommended private placement pending final arbitration |
| `CURSOR_STYLES` | style family for the cursor | `--cursor.*` | recommended private placement pending final arbitration |
| `END_OF_BUFFER_STYLES` | style family for end-of-buffer filler rows | `--end-of-buffer.*` | recommended private placement pending final arbitration |
| `LINE_NUMBER_STYLES` | style family for ordinary line numbers | `--line-number.*` | recommended private placement pending final arbitration |
| `HEADER_STYLES` | style family for header text | `--header.*` | recommended private placement pending final arbitration |
| `PLACEHOLDER_STYLES` | style family for placeholder text | `--placeholder.*` | recommended private placement pending final arbitration |
| `PROMPT_STYLES` | style family for prompt text | `--prompt.*` | recommended private placement pending final arbitration |

Notes:

* `PLACEHOLDER` stays private because neither native editor mode nor minimal native capture has an honest vanishing-inline-placeholder realization.
* `CHAR_LIMIT`, `MAX_LINES`, and `TIMEOUT` stay private because the native backend is split across editor-backed and capture-backed paths that do not share Gum's interactive enforcement semantics.

### 12.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 12.6 Consequences For Implementation

`io::in::write` is where the derivation plan has to acknowledge the multiline trap directly:

* unknown flags fail in unpinned mode
* backend-native spellings should be preserved where they can be recognized honestly
* `TARGET` must remain additive to stdout emission rather than replacing it
* native editor-backed and capture-backed paths must stay explicit in the implementation; they should not be hand-waved into one fake uniform "native write" behavior
* `VALUE` should only become truly public once both native subpaths are specified tightly enough to implement and test
* stdin-seeded initial contents should remain outside the first public contract unless the native behavior is redesigned to match it honestly
* if `EDITOR_PREFERENCE` becomes public later, it must be specified as command behavior rather than left as hidden environment policy
* `--backend gum` may still permit raw backend-native forwarding after dispatch is pinned

-----

## 13. Eighth Worked Command: `io::out::table`

### 13.1 Command

| Field | Value |
|---|---|
| canonical command | `io::out::table` |
| file | `functions.d/@core/@io/@out/table.sh` |
| backend preference | direct `gum table`, then staged indexed selection through `io::in::filter` or `io::in::choose`, then native render |
| direct backend members | `gum table`; native `column -t` / shell formatter |
| staged lowering | indexed raw records rendered for display and selected through `io::in::filter` or `io::in::choose` when direct table selection is unavailable, ineligible, or less honest than composed lowering |
| default mode | interactive row selection; `--print` switches to static render mode |

### 13.2 Arguments

`io::out::table` presents delimited tabular data legibly and, by default, lets the user select rows from it.

Argument surface:

* stdin is the primary input source
* `--file <path>` is the alternate input source
* default interactive mode emits the selected row or rows to stdout
* `--return-column <n>` emits one selected field per selected row instead of the whole row
* `--print` disables selection and renders the full table to stdout
* if `COLUMNS` is provided, those names are used as the header row
* if `COLUMNS` is omitted, the first input record is treated as the header row

Notes:

* This is the main place where the derivation deliberately bends a strict `out = non-interactive` taxonomy. Forcing `table` into render-only mode by default would fight the dominant backend and make `io::out::table` feel worse than `gum table`.
* The stable contract is on the underlying rows and fields, not on any one backend's display widget.

### 13.3 Candidate Public Options

These are the current candidate public options for `io::out::table`.

| Class | Canonical option | Meaning | direct `gum table` | staged indexed selection / render path | `native` | Native contract |
|---|---|---|---|---|---|---|
| `SEPARATOR` | `--separator <char>` | input field delimiter | `--separator <char>` | parse records with the same delimiter before rendering or selection | split input fields on the delimiter before formatting | Native splits each input record on the declared separator before any rendering or selection step. |
| `COLUMNS` | `--columns <csv>` | explicit header names | `--columns <csv>` | use explicit header names when rendering display rows or print output | prepend explicit header names before rendering | Native uses the explicit column names as the header row during rendering and print output. |
| `FILE` | `--file <path>` | read tabular input from a file instead of stdin | `--file <path>` | open and read the file path instead of stdin | open and read the file path instead of stdin | Native reads table input from the specified file path instead of stdin. |
| `PRINT` | `--print` | render the table without row selection | `--print` | render-only path; no selection stage is entered | render only | Native renders the table and exits without invoking any row-selection stage. |
| `RETURN_COLUMN` | `--return-column <n>` | return one selected field instead of the whole row | `--return-column <n>` | extract the field from the recovered raw record after indexed selection | extract the field from the recovered raw record after selection | Native applies `RETURN_COLUMN` only after recovering the selected raw record, never against padded display output. |
| `MULTI` | `--multi` | allow selecting more than one row | no direct peer; direct Gum path becomes ineligible and lowers to staged selection | `io::in::filter --multi` or `io::in::choose --multi` over indexed rows | staged or native selection path over indexed rows | Native allows selecting more than one raw record and emits the selected records one per line. |
| `BORDER` | `--border <style>` | border style for rendered output | `--border <style>` | apply the same border style in the staged display renderer or print renderer | candidate ASCII / UTF-8 border renderer | Native renders the requested border style around the table using Unicode or ASCII fallback as needed. |
| `WIDTHS` | `--widths <csv>` | per-column width hints | `--widths <csv>` | apply width hints to the staged display renderer or print renderer | candidate native width hints for shell formatter; may degrade to advisory | Native treats the supplied widths as per-column rendering hints before truncation or padding. |

Notes:

* Interactive selection is the default command identity. `--print` is the explicit mode switch into static rendering.
* `--print` conflicts with selection-result options such as `RETURN_COLUMN` and `MULTI`. Those combinations should fail hard rather than silently changing meaning.
* `MULTI` is not a claim that direct `gum table` itself supports multi-select. It is a claim that `io::out::table` may lower through an indexed staged selection pipeline when multiple row selection is requested.
* `ALIGN` is intentionally absent in this first pass. The earlier proposed Gum mapping was hallucinated; there is still no honest Gum-side alignment flag to unify.
* No row is truly public until the native realization is written tightly enough to implement and test.

### 13.4 Private Options

`io::out::table` accepts the remaining Gum surface privately rather than forcing direct `gum table` usage. Private options remain recognized in unpinned mode.

The style-family rows in this section are recommendation-level placements
under §4.14 and remain subject to final arbitration.

#### Accepted private options

| Class | Meaning | direct `gum table` / staged path | Notes |
|---|---|---|---|
| `LAZY_QUOTES` | relaxed CSV quote parsing | `--lazy-quotes` | direct Gum parsing concern |
| `FIELDS_PER_RECORD` | expected field count per record | `--fields-per-record <n>` | direct Gum parsing concern |
| `HEIGHT` | interactive viewport height | `--height <n>` or staged selector height hint | selection-mode concern |
| `PADDING` | table padding / internal spacing | `--padding <box>` | render-layout concern |
| `SHOW_HELP` | show or hide help keybinds | `--[no-]show-help` or staged selector help setting | selection-mode concern |
| `HIDE_COUNT` | hide item count chrome | `--[no-]hide-count` | direct Gum singleton for now |
| `TIMEOUT` | timeout until selector returns | `--timeout <dur>` or staged selector timeout when supported | selection-mode concern |
| `BORDER_STYLES` | border style family | `--border.*` | recommended private placement pending final arbitration |
| `CELL_STYLES` | cell style family | `--cell.*` | recommended private placement pending final arbitration |
| `HEADER_STYLES` | header style family | `--header.*` | recommended private placement pending final arbitration |
| `SELECTED_STYLES` | selected-row style family | `--selected.*` | recommended private placement pending final arbitration |

Notes:

* Direct `gum table` remains preferred whenever the requested option set honestly fits it.
* When `table` lowers through `io::in::filter` or `io::in::choose`, the accepted private surfaces of those staged commands may participate there. That does not enlarge the stable public vocabulary of `table`.

### 13.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 13.6 Consequences For Implementation

`io::out::table` now has to preserve backend familiarity without losing data integrity:

* unknown flags fail in unpinned mode
* interactive selection is the default mode; `--print` is the explicit render-only switch
* direct `gum table` remains preferred for compatible interactive single-select cases and for direct print mode
* selection-result options such as `RETURN_COLUMN` and `MULTI` are invalid under `--print`
* when the option set outruns direct `gum table`, or when a staged `io::*` pipeline is less fragile than raw native parsing, `table` must lower under a stable indexed wire format:
  1. enumerate the raw records under the settled separator/header contract and assign each record an opaque stable index
  2. render selector input as `index<TAB>display`, one indexed record per line
  3. require the selector stage to return indexes only
  4. recover the selected raw records by index and only then apply `RETURN_COLUMN`
* no lossy string-match reversal is acceptable in the staged path
* raw native rendering remains the right fallback for `--print` and for any case where direct rendering is more honest than staged selection
* `ALIGN` remains intentionally absent from the first derived surface because there is still no honest Gum mapping to unify

-----

## 14. Ninth Worked Command: `io::out::spin`

### 14.1 Command

| Field | Value |
|---|---|
| canonical command | `io::out::spin` |
| file | `functions.d/@core/@io/@out/spin.sh` |
| backend preference | `gum`, `native` |
| backend members | `gum spin`; native spinner/supervisor wrapper |
| architectural relation | convenience specialization over `io::out::progress` |

### 14.2 Arguments

`io::out::spin` runs a command while displaying spinner-oriented progress state on stderr.

Argument surface:

* invocation shape: `io::out::spin [options] [title] -- <command> [args...]`
* a wrapped command argv is required
* title may be supplied positionally, by `--title <text>`, or both
* if both positional title and `--title` are provided, the last specified title wins
* command exit status propagates through the wrapper, subject to any future timeout semantics

This command remains architecturally subordinate to `io::out::progress`, but that does not justify trimming its derived option surface. The backend set is small enough that the full `gum spin` surface can be partitioned directly.

### 14.3 Candidate Public Options

These are the current candidate public options for `io::out::spin`.

| Class | Canonical option | Meaning | `gum spin` | `native` | Native contract |
|---|---|---|---|---|---|
| `TITLE` | `[title]`, `--title <text>` | text displayed alongside the spinner | `--title <text>` | print/update title beside spinner frames on stderr | Native prints and updates the title text beside spinner frames on stderr while the child runs. |
| `SHOW_OUTPUT` | `--show-output` | show combined stdout and stderr during execution | `--show-output` | stream combined child output while spinner runs | Native streams combined stdout and stderr while the spinner remains active. |
| `SHOW_ERROR` | `--show-error` | show buffered output only when the command fails | `--show-error` | buffer output and emit on failure | Native buffers child output and emits it only if the wrapped command exits non-zero. |
| `SHOW_STDOUT` | `--show-stdout` | show stdout during execution | `--show-stdout` | stream stdout while spinner runs | Native streams stdout while the spinner remains active. |
| `SHOW_STDERR` | `--show-stderr` | show stderr during execution | `--show-stderr` | stream stderr while spinner runs | Native streams stderr while the spinner remains active. |
| `SPINNER` | `--spinner <name>` | spinner glyph set / style name | `--spinner <name>` | candidate ASCII/native spinner-set approximation | Native cycles the named spinner set, or the nearest supported spinner set, on stderr while the child runs. |
| `ALIGN` | `--align <left|right>` | spinner placement relative to title | `--align <left|right>` | candidate native left/right arrangement | Native prints spinner frames to the left or right of the title according to the requested alignment. |
| `TIMEOUT` | `--timeout <dur>` | abort the wrapped command after a duration | `--timeout <dur>` | candidate native watchdog / process-group timeout | Native terminates the wrapped command after the timeout expires and exits non-zero. |
| `PADDING` | `--padding <box>` | padding around the spinner line | `--padding <box>` | candidate native spacing approximation | Native adds surrounding spacing that approximates the requested padding box around the spinner line. |

Notes:

* `io::out::spin` should not feel like a trimmed wrapper that makes users reach for direct `gum spin`.
* Both positional title and `--title` are accepted as coequal spellings of the same concern.
* Because the backend set is only Gum plus native, there is little reason to keep the upstream Gum surface artificially hidden behind private passthrough.
* As elsewhere, no row is truly public until the native realization is written tightly enough to implement and test.

### 14.4 Private Options

The style-family rows in this section are recommendation-level placements
under §4.14 and remain subject to final arbitration.

| Class | Meaning | `gum spin` | Notes |
|---|---|---|---|
| `SPINNER_STYLES` | style family for spinner glyph rendering | `--spinner.*` | recommended private placement pending final arbitration |
| `TITLE_STYLES` | style family for spinner title text | `--title.*` | recommended private placement pending final arbitration |

### 14.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 14.6 Consequences For Implementation

`io::out::spin` should preserve the full Gum surface without giving up on native fallback:

* unknown flags fail in unpinned mode
* title parsing must accept both positional and `--title` spellings, with last-one-wins semantics
* native must supervise the wrapped command rather than just printing a label and running it
* output-routing flags (`SHOW_OUTPUT`, `SHOW_ERROR`, `SHOW_STDOUT`, `SHOW_STDERR`) need concrete native behavior so they are not fake portability promises
* `SPINNER`, `ALIGN`, `PADDING`, and any future public style families need deterministic native behavior that is explicit and testable
* timeout behavior remains candidate status until the native watchdog/process-group semantics are written tightly enough to implement and test

-----

## 15. Tenth Worked Command: `io::out::log`

### 15.1 Command

| Field | Value |
|---|---|
| canonical command | `io::out::log` |
| file | `functions.d/@core/@io/@out/log.sh` |
| backend preference | `gum`, `native` |
| backend members | `gum log`; native shell logger |

### 15.2 Arguments

`io::out::log` emits one log record to `stderr` by default, or to a file when `FILE` is specified.

Argument surface:

* default mode: all remaining positional arguments are joined into one message
* `FORMAT` mode: the first positional argument is a `printf` format string and remaining positional arguments are format arguments
* `STRUCTURED` mode: the first positional argument is the message and remaining positional arguments are parsed as key/value pairs
* `FORMAT` and `STRUCTURED` are mutually exclusive modes

Notes:

* `io::out::log` is a record emitter, not a long-running logger configuration surface.
* Caller-reporting concerns are intentionally absent from the union surface. They exist in the underlying Go logger library, but the current `gum log` CLI does not expose a caller flag.

### 15.3 Candidate Public Options

These are the current candidate public options for `io::out::log`.

| Class | Canonical option | Meaning | `gum log` | `native` | Native contract |
|---|---|---|---|---|---|
| `LEVEL` | `--level <none|debug|info|warn|error|fatal>` | severity level for the emitted record | `--level <name>` | prepend or encode the chosen severity; `fatal` emits and terminates with non-zero status | Native prepends or encodes the chosen severity, and `fatal` emits the record then exits non-zero. |
| `MIN_LEVEL` | `--min-level <none|debug|info|warn|error|fatal>` | suppress records below a threshold | `--min-level <name>` | compare against a native severity ranking and drop lower-severity records | Native suppresses records whose level falls below the declared minimum severity. |
| `PREFIX` | `--prefix <text>` | fixed prefix before the message | `--prefix <text>` | prepend prefix text before the rendered message | Native prepends the prefix text before the rendered message body. |
| `FILE` | `--file <path>` | append the record to a file instead of `stderr` | `--file <path>`, `-o <path>` | append output to the specified path rather than writing to `stderr` | Native appends the rendered record to the specified file instead of writing it to `stderr`. |
| `FORMAT` | `--format` | treat the first positional argument as a `printf` format string | `--format`, `-f` | format the message with shell `printf` before record rendering | Native applies shell `printf` formatting to the first positional argument before record rendering. |
| `STRUCTURED` | `--structured` | treat trailing positional arguments as structured key/value fields | `--structured`, `-s` | parse trailing arguments as key/value pairs and emit them in the chosen formatter | Native parses trailing arguments as key/value pairs and emits them as structured fields in the selected formatter. |
| `FORMATTER` | `--formatter <text|logfmt|json>` | output formatter for the record | `--formatter <name>` | `text` and `logfmt` are direct native candidates; `json` remains candidate status until the native escaping contract is specified tightly enough | Native renders `text` and `logfmt` directly; `json` remains candidate only until the native escaping contract is fully specified. |
| `TIME` | `--time <preset>` | prepend a timestamp using a named preset format | `--time <format>` | map named presets such as `rfc822`, `rfc3339`, `kitchen`, `stamp`, `datetime`, `dateonly`, and `timeonly` to native date formatting | Native prepends a timestamp using the requested named preset format. |

Notes:

* `LEVEL`, `MIN_LEVEL`, `PREFIX`, `FILE`, and `STRUCTURED` are the cleanest current public candidates because both backends admit straightforward realizations.
* `FORMAT` is kept public rather than hidden as a Gum-only convenience. It is a real command-level concern and native shell can realize it honestly with `printf`.
* `TIME` is public only for named preset formats. Arbitrary backend-native time layout strings are not part of the stable cross-backend contract.
* `FORMATTER=json` remains only candidate status in this first pass. It should not be treated as truly public until the native JSON escaping contract is specified tightly enough to implement and test.
* `STRUCTURED` with an odd trailing key/value arity should be a hard error in unpinned mode rather than being silently tolerated.
* As elsewhere, no row is truly public until the native realization is written tightly enough to implement and test.

### 15.4 Private Options

The remaining Gum-side formatting surface is still accepted privately rather than forcing users to drop to direct `gum log`.

The style-family rows in this section are recommendation-level placements
under §4.14 and remain subject to final arbitration.

| Class | Meaning | `gum log` | Notes |
|---|---|---|---|
| `CUSTOM_TIME_LAYOUT` | arbitrary backend-native time layout string | `--time <layout>` | private because native only promises named preset mappings in the public contract |
| `LEVEL_STYLES` | style family for the level label | `--level.*` | recommended private placement pending final arbitration |
| `TIME_STYLES` | style family for the timestamp | `--time.*` | recommended private placement pending final arbitration |
| `PREFIX_STYLES` | style family for the prefix | `--prefix.*` | recommended private placement pending final arbitration |
| `MESSAGE_STYLES` | style family for the message body | `--message.*` | recommended private placement pending final arbitration |
| `KEY_STYLES` | style family for structured keys | `--key.*` | recommended private placement pending final arbitration |
| `VALUE_STYLES` | style family for structured values | `--value.*` | recommended private placement pending final arbitration |
| `SEPARATOR_STYLES` | style family for record separators | `--separator.*` | recommended private placement pending final arbitration |

Notes:

* These rows remain recognized union options even though they are not part of the stable documented contract.
* These families should not be promoted until their native rendering contract is specified element by element and tested as command behavior.

### 15.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 15.6 Consequences For Implementation

`io::out::log` should preserve the useful Gum surface without pretending that native shell can reproduce the entire Go logging engine verbatim:

* unknown flags fail in unpinned mode
* native must preserve the default sink behavior of `stderr`, with `FILE` switching output to append-to-path behavior
* native should implement an explicit severity ranking so `MIN_LEVEL` suppression is deterministic and testable
* `FORMAT` should build the message first with shell `printf`, then render the record through the selected formatter
* `STRUCTURED` should parse the first positional argument as the message and the remaining positional arguments as key/value pairs, with odd arity treated as a hard error
* `TIME` should support only the named preset table publicly; arbitrary layout strings remain private Gum-side behavior
* `FORMATTER=text` and `FORMATTER=logfmt` are straightforward native obligations, while `FORMATTER=json` remains candidate status until the native escaping rules are written tightly enough to implement and test
* `LEVEL=fatal` should emit the record and then terminate the current dispatch with non-zero status

-----

## 16. Eleventh Worked Group: `io::layout::*`

### 16.1 Scope

The layout leaves are block transforms rather than terminal-owning UI commands. They operate on block geometry and emit transformed text to stdout.

Shared contract:

* they are pure, deterministic text-to-text transforms
* they restructure blocks in two dimensions rather than applying inline decoration
* native realizations must preserve structure, not silently flatten or drop it

The intended backend set is:

* `gum style` for `border`, `pad`, `margin`, `align`, `width`, and `height`
* `gum join` for `join`
* native shell implementations for all of the above

Notes:

* The current tree is still wired native-first for several of these leaves, but the derivation follows the intended backend set recorded in the inventory and package spec.
* These commands should not silently become no-ops. If native cannot match rich styling exactly, it must still preserve the underlying geometry or spacing concern.
* Native realizations are expected to be dense shell/awk/paste/fold transforms, not passive no-op degradations.

### 16.2 `io::layout::border`

| Field | Value |
|---|---|
| canonical command | `io::layout::border` |
| file | `functions.d/@core/@io/@layout/border.sh` |
| backend members | `gum style --border`; native border renderer |

Arguments:

* text is supplied positionally or on stdin

Candidate public options:

| Class | Canonical option | Meaning | `gum style` | `native` | Native contract |
|---|---|---|---|---|---|
| `STYLE` | `--style <none|hidden|normal|rounded|thick|double>` | border style | `--border <style>` | draw the requested border style around the block, with Unicode or ASCII fallback as needed | Native draws the requested border style around the block with Unicode or ASCII fallback as needed. |
| `BORDER_FOREGROUND` | `--border-foreground <color>` | border foreground color | `--border-foreground <color>` | candidate ANSI color applied to border glyphs only | Native applies the requested foreground color to border glyphs only and resets before emitting inner text. |

Private options:

| Class | Meaning | `gum style` | Notes |
|---|---|---|---|
| `BORDER_BACKGROUND` | border background color | `--border-background <color>` | richer Gum styling concern; native may later approximate it |

### 16.3 `io::layout::pad`

| Field | Value |
|---|---|
| canonical command | `io::layout::pad` |
| file | `functions.d/@core/@io/@layout/pad.sh` |
| backend members | `gum style --padding`; native padding transform |

Arguments:

* side specification is positional CSS-style shorthand: `1`, `1 2`, or `1 2 3 4`
* text is supplied positionally or on stdin

Candidate public options:

* none in the first pass; the stable surface is argument-driven rather than option-driven

Notes:

* `pad` and `margin` may share the same native spacing engine even though they remain distinct commands in the public contract.
* Their semantic distinction matters in composition, especially when combined with `border`.

### 16.4 `io::layout::margin`

| Field | Value |
|---|---|
| canonical command | `io::layout::margin` |
| file | `functions.d/@core/@io/@layout/margin.sh` |
| backend members | `gum style --margin`; native margin transform |

Arguments:

* side specification is positional CSS-style shorthand: `1`, `1 2`, or `1 2 3 4`
* text is supplied positionally or on stdin

Candidate public options:

* none in the first pass; the stable surface is argument-driven rather than option-driven

Notes:

* `margin` and `pad` may share the same native spacing engine even though they remain distinct commands in the public contract.

### 16.5 `io::layout::align`

| Field | Value |
|---|---|
| canonical command | `io::layout::align` |
| file | `functions.d/@core/@io/@layout/align.sh` |
| backend members | `gum style --align`; native line alignment transform |

Arguments:

* text is supplied positionally or on stdin

Candidate public options:

| Class | Canonical option | Meaning | `gum style` | `native` | Native contract |
|---|---|---|---|---|---|
| `ALIGNMENT` | `--alignment <left|center|right>` | horizontal block alignment | `--align <value>` | pad each line left/right to the requested width | Native pads each line left, center, or right within the active width according to the requested alignment. |
| `WIDTH` | `--width <n>` | target width for alignment | `--width <n>` | align within the given width; if omitted, use terminal width or `80` | Native aligns within the explicit width, or within terminal width or `80` when no width is given. |

Private options:

| Class | Meaning | `gum style` | Notes |
|---|---|---|---|
| `VERTICAL_ALIGNMENT_VALUES` | extended `top|middle|bottom` value domain | `--align <value>` | deferred until a height-aware native contract is specified |
| `HEIGHT` | target height for vertical alignment | `--height <n>` | deferred until vertical alignment is promoted |

Notes:

* `io::layout::align` is intentionally conservative in its first public pass. `IO.md` frames it as alignment within available width, so the stable surface starts with `left`, `center`, and `right`.
* The native default width should follow the existing terminal-width helper: `$COLUMNS`, then `tput cols`, then `80`.

### 16.6 `io::layout::width`

| Field | Value |
|---|---|
| canonical command | `io::layout::width` |
| file | `functions.d/@core/@io/@layout/width.sh` |
| backend members | `gum style --width`; native width normalizer |

Arguments:

* width is the first positional argument
* text is supplied positionally or on stdin

Candidate public options:

* none in the first pass; width is the core positional argument of the command

### 16.7 `io::layout::height`

| Field | Value |
|---|---|
| canonical command | `io::layout::height` |
| file | `functions.d/@core/@io/@layout/height.sh` |
| backend members | `gum style --height`; native height normalizer |

Arguments:

* height is the first positional argument
* text is supplied positionally or on stdin

Candidate public options:

* none in the first pass; height is the core positional argument of the command

### 16.8 `io::layout::join`

| Field | Value |
|---|---|
| canonical command | `io::layout::join` |
| file | `functions.d/@core/@io/@layout/join.sh` |
| backend members | `gum join`; native block joiner |

Arguments:

* one or more block arguments are required

Candidate public options:

| Class | Canonical option | Meaning | `gum join` | `native` | Native contract |
|---|---|---|---|---|---|
| `DIRECTION` | `--direction <vertical|horizontal>` | join direction | `--vertical` / `--horizontal` | vertical concatenation or horizontal block join | Native concatenates blocks vertically or performs horizontal block join according to the requested direction. |
| `ALIGN` | `--align <left|center|right|top|middle|bottom>` | alignment of blocks while joining | `--align <value>` | candidate native block padding/alignment during join | Native pads shorter blocks so the joined output honors the requested alignment before concatenation. |
| `SEPARATOR` | `--separator <text>` | separator inserted between joined blocks | interleave separator blocks before invoking `gum join` | print separator text between joined blocks | Native inserts the separator text exactly once between adjacent joined blocks. |

Notes:

* `SEPARATOR` remains candidate public because both backends can realize it honestly even though Gum does not expose it as a direct flag.
* The canonical `--direction` spelling follows `IO.md`, while backend-native `--vertical` and `--horizontal` spellings should still be accepted honestly by the parser.
* Horizontal native joining requires block buffering and padding. Naive `paste` alone is not sufficient when the blocks have uneven widths or heights.

### 16.9 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 16.10 Consequences For Implementation

* The layout leaves should derive only the flags that actually belong to each leaf's concern rather than accepting the entire `gum style` surface everywhere.
* `border`, `pad`, `margin`, `width`, and `height` are primarily argument-driven commands.
* `align` begins with horizontal alignment only; vertical alignment remains deferred until the height contract is tightened.
* `join` should preserve backend familiarity without forcing the user to abandon `gum join` spellings.
* Native layout fallbacks must preserve geometry or spacing even when style/color degradation is coarse.
* For `join`, vertical concatenation is trivial but horizontal joining requires block-aware padding rather than raw `paste`.

-----

## 17. Twelfth Worked Group: `io::fmt::*`

### 17.1 Scope

The formatting leaves are pure text transforms. They do not prompt, page, own terminal interaction, or manage layout state.

The intended backend set is:

* `gum style` for `bold`, `faint`, `italic`, `underline`, `strikethrough`, `fg`, and `bg`
* `gum format` for `render`
* native ANSI or shell renderers for all of the above

Notes:

* The current `render` implementation already routes to `gum format`; the older inventory entry naming `glow` as the only rich backend was stale and has been corrected above.
* Native-only singleton leaves such as `wrap`, `shorten`, `capitalize`, `uppercase`, `lowercase`, and `trim-whitespace` still do not require quotient work.

### 17.2 `io::fmt::bold`, `faint`, `italic`, `underline`, `strikethrough`

These leaves all share the same derivation shape:

| Family | Backend members | Stable surface |
|---|---|---|
| `bold`, `faint`, `italic`, `underline`, `strikethrough` | `gum style` corresponding boolean flag; native ANSI transform | no options in the first pass; text via args or stdin |

Notes:

* The leaf command name already names the concern, so no additional stable option is required.
* Non-corresponding `gum style` flags are outside the scope of these leaves and should not be silently accepted as if they belonged here.

### 17.3 `io::fmt::fg`

| Field | Value |
|---|---|
| canonical command | `io::fmt::fg` |
| file | `functions.d/@core/@io/@fmt/fg.sh` |
| backend members | `gum style --foreground`; native ANSI foreground transform |

Arguments:

* the first positional argument is the color
* text is supplied by remaining positional arguments or stdin

Candidate public options:

* none in the first pass; the color is the core positional argument of the command

Notes:

* Supported color domains may include named colors, 0-255 palette values, and `#rrggbb` where the backend supports them.
* Native color parsing should aim high rather than degrading immediately to no-op: named colors, 256-color indexes, and hex colors are all legitimate targets.
* If color parsing fails completely, native should fall back to the terminal default color rather than throwing a hard script error.

### 17.4 `io::fmt::bg`

| Field | Value |
|---|---|
| canonical command | `io::fmt::bg` |
| file | `functions.d/@core/@io/@fmt/bg.sh` |
| backend members | `gum style --background`; native ANSI background transform |

Arguments:

* the first positional argument is the color
* text is supplied by remaining positional arguments or stdin

Candidate public options:

* none in the first pass; the color is the core positional argument of the command

Notes:

* Native background color parsing should follow the same ambition as `fg`: named colors, 256-color indexes, and hex colors where the backend supports them.
* If parsing fails completely, native should fall back to the terminal default background rather than throwing a hard script error.

### 17.5 `io::fmt::render`

| Field | Value |
|---|---|
| canonical command | `io::fmt::render` |
| file | `functions.d/@core/@io/@fmt/render.sh` |
| backend members | `gum format`; native bounded renderer |

Arguments:

* text is supplied positionally or on stdin

Candidate public options:

| Class | Canonical option | Meaning | `gum format` | `native` | Native contract |
|---|---|---|---|---|---|
| `TYPE` | `--type <markdown|template|code|emoji>` | rendering mode / format hint | `--type <value>` | `markdown` has a native bounded renderer; other values remain candidate status and may constrain backend choice | Native renders `markdown` with the bounded renderer; for `template`, `code`, and `emoji`, native remains ineligible until those rendering semantics are specified. |
| `THEME` | `--theme <name>` | theme or style hint for markdown-like rendering | `--theme <name>` | native currently ineligible | No native theme contract is accepted yet for `THEME`; if native is selected, it must reject the option rather than silently ignoring it. |

Private options:

| Class | Meaning | `gum format` | Notes |
|---|---|---|---|
| `LANGUAGE` | language hint for code rendering | `--language <name>`, `-l <name>` | code-mode detail; remains private until native code-render behavior is specified tightly enough |
| `STRIP_ANSI` | strip ANSI sequences from stdin before rendering | `--[no-]strip-ansi` | Gum-only input preprocessing concern for now |

Notes:

* `io::fmt::render` remains explicitly bounded. It does not own paging, prompting, progress, or layout.
* `TYPE=markdown` is the cleanest cross-backend value today. `template`, `code`, and `emoji` remain candidate status because they may legitimately constrain backend choice until native semantics are specified more tightly.
* Native markdown rendering is intentionally bounded rather than AST-complete. It should handle wrapping and a small, explicit set of inline/block cues, while unsupported structures pass through as readable raw text rather than failing.

### 17.6 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 17.7 Consequences For Implementation

* The decorator leaves should stay narrow and pure; they should not quietly become generic `gum style` wrappers.
* `fg` and `bg` keep color as a positional command argument rather than reintroducing redundant `--foreground` / `--background` options inside the leaf.
* `render` should continue to be derived as `gum format` plus a bounded native renderer, not as a paging or discovery command.
* Native `render` should be a robust bounded formatter, not a full Markdown parser and not a total `cat`-only surrender. Unsupported structures may pass through raw, but the fallback should still honor width and simple emphasis cues.
* Additional native-only formatting helpers remain singleton work outside the quotient-heavy surface.

-----

## 18. Thirteenth Worked Command: `io::in::file`

### 18.1 Command

| Field | Value |
|---|---|
| canonical command | `io::in::file` |
| file | `functions.d/@core/@io/@in/file.sh` |
| backend preference | direct `gum file`, then staged `io::in::filter`, then `fzf`, then `native` |
| direct backend members | `gum file`; `fzf` walker mode; native `find` + chooser |
| staged lowering | rooted candidate enumeration piped into `io::in::filter` when the option set outruns direct file-picking |

### 18.2 Arguments

`io::in::file` is a rooted path selector. Rich backends may present a tree browser. Weak backends may present a flat chooser. The stable contract is the emitted path list, not the widget.

Argument surface:

* positional `[path]` selects the starting directory and defaults to `.`
* the root path is resolved to an absolute path before dispatch
* the command emits normalized absolute paths, one path per line
* in single-select mode it emits one selected path
* in multi-select mode it emits one selected path per line

Normalized defaults:

* mode: `any` (files and directories are both selectable unless narrowed)
* hidden entries: off
* follow symlinks: off
* skip list: active on staged, `fzf`, and native traversal paths; best-effort only on direct `gum file`
* cancellation: exit `1`

Notes:

* The current wrapper still exposes `--root <path>`, but the settled derivation treats the root as the command's positional argument.
* In `directory` and `any` modes, some backends may include the root directory itself as a selectable candidate. Direct `gum file` does not expose the root itself as a tree row, so this is not a cross-backend guarantee.

### 18.3 Candidate Public Options

These are the current candidate public options for `io::in::file`.

| Class | Canonical option | Meaning | direct `gum file` | staged / `fzf` | `native` | Native contract |
|---|---|---|---|---|---|---|
| `MODE_FILE` | `--file` | select files only | `--file` | walker `file`; staged enumeration restricted to files | `find -type f` | Native enumerates and returns only files. |
| `MODE_DIRECTORY` | `--directory` | select directories only | `--directory` | walker `dir`; staged enumeration restricted to directories | `find -type d` | Native enumerates and returns only directories. |
| `SHOW_HIDDEN` | `--hidden` | include hidden entries | `--all` | add `hidden` to walker or omit hidden-prune in staged enumeration | omit hidden-prune from `find` | Native includes hidden entries by omitting the default hidden-entry pruning rules. |
| `HEADER` | `--header <text>` | static prompt/header text | `--header <text>` | `--header <text>` | printed before chooser | Native prints the header text once before interactive selection. |
| `MULTI` | `--multi` | allow multiple selection | no direct peer; direct `gum file` path becomes ineligible and lowers to staged selection | `io::in::filter --multi` or `fzf --multi` | `io::in::choose --multi` | Native allows selecting more than one normalized path and emits the chosen paths one per line. |
| `NO_SKIP` | `--no-skip` | disable the default skip-list traversal exclusions | no direct peer; direct `gum file` path becomes ineligible and lowers to staged selection | clear walker skip policy or omit skip pruning in staged enumeration | omit skip-list `-prune` clauses | Native disables the default skip-list prune clauses during traversal. |

Notes:

* No mode flag means `any`: both files and directories are selectable.
* Passing both `--file` and `--directory` is an error.
* `MULTI` is not a claim that `gum file` itself has multi-select. It is a claim that `io::in::file` may lower into a staged selector pipeline when multiple selection is requested.
* `NO_SKIP` is also not a direct `gum file` concern. It disables traversal pruning on the backends that expose traversal control, and may force staged lowering away from the direct Gum tree browser.
* Direct `gum file` remains eligible only when the requested option set is honestly compatible with it.

### 18.4 Private Options

The remaining backend-specific surface is still accepted privately rather than forcing users to bypass `io::in::file`.

The style-family rows in this section are recommendation-level placements
under §4.14 and remain subject to final arbitration.

#### Direct `gum file` singletons

| Class | Meaning | `gum file` | Notes |
|---|---|---|---|
| `PERMISSIONS` | show permissions column | `--[no-]permissions` | Gum-only display concern |
| `SIZE` | show size column | `--[no-]size` | Gum-only display concern |
| `TIMEOUT` | timeout until picker aborts | `--timeout <dur>` | Gum-only singleton |
| `HEIGHT` | maximum picker height | `--height <n>` | Gum-only viewport concern |
| `PADDING` | picker padding | `--padding <box>` | Gum-only layout concern |
| `SHOW_HELP` | show or hide help keybinds | `--[no-]show-help` | Gum-only chrome concern |
| `CURSOR_STYLES` | cursor style family | `--cursor.*` | recommended private placement pending final arbitration |
| `HEADER_STYLES` | header style family | `--header.*` | recommended private placement pending final arbitration |
| `SYMLINK_STYLES` | symlink-entry style family | `--symlink.*` | recommended private placement pending final arbitration |
| `FILE_STYLES` | file-entry style family | `--file.*` | recommended private placement pending final arbitration |
| `DIRECTORY_STYLES` | directory-entry style family | `--directory.*` | recommended private placement pending final arbitration |
| `SELECTED_STYLES` | selected-entry style family | `--selected.*` | recommended private placement pending final arbitration |
| `PERMISSIONS_STYLES` | permissions style family | `--permissions.*` | recommended private placement pending final arbitration |
| `FILE_SIZE_STYLES` | file-size style family | `--file-size.*` | recommended private placement pending final arbitration |

#### `fzf` / traversal singletons

| Class | Meaning | `fzf` / traversal | Notes |
|---|---|---|---|
| `PREVIEW` | preview command for highlighted entry | `--preview <cmd>` | `fzf`-side singleton |
| `HEIGHT` | picker height | `--height <spec>` | `fzf`-side singleton |
| `WALKER_SKIP` | explicit skip list override | `--walker-skip <csv>` | richer traversal concern than public `NO_SKIP` |
| `FOLLOW` | follow symlinks during traversal | walker `follow` token or `find -L` | remains private until the full follow contract is tightened |
| `MAXDEPTH` | limit traversal depth | `find -maxdepth <n>` | native/traversal singleton |

Notes:

* The richer `fzf` private surface from the `io::in::filter` derivation remains available when the staged selection phase resolves to `fzf`.

### 18.5 Rejected In Unpinned Mode

| Class | Native flag(s) | Reason |
|---|---|---|
| `RAW_GUM_PASSTHROUGH` | `--gum-arg`, `--gum ... --` | side-channel backend leakage |
| `RAW_FZF_PASSTHROUGH` | `--fzf-arg`, `--fzf ... --` | side-channel backend leakage |
| `BACKEND_HELP` | backend `--help` | handled by `io::*` |
| `BACKEND_VERSION` | backend `--version` | handled outside capability surface |

### 18.6 Output Contract

* every emitted path is normalized to an absolute path
* one path per line
* newline-terminated line-oriented output is acceptable
* exit `0` on at least one valid selection
* exit `1` on cancellation or empty selection
* the normalization helper must resolve every emitted path to an absolute path, collapse `.` and `..`, preserve symlink structure unless a follow-mode concern is explicitly active, and provide `realpath -m` semantics for non-existent targets

Notes:

* Selection order should be preserved where the active selection backend supports it. Otherwise lexicographic or traversal order is acceptable.
* The direct `gum file` backend already emits absolute paths because it resolves and joins against the absolute current directory internally. Staged, `fzf`, and native paths still need final normalization through the helper specified above.

### 18.7 Consequences For Implementation

`io::in::file` is the last hard `in::*` leaf because it combines traversal, selection UI, and path normalization. The derivation therefore has to separate direct picker backends from staged lowering honestly:

* unknown flags fail in unpinned mode
* wrapper defaults diverge from every backend's native defaults and must be normalized explicitly
* direct `gum file` is only the single-select direct-picker path
* when the option set outruns direct `gum file` (at least `MULTI`, and any other explicit traversal-control concern without a direct Gum peer), `io::in::file` may lower to staged composition:
  * enumerate candidate paths under the `file` contract
  * pipe them into `io::in::filter`
  * let the filter stage resolve to `gum`, `fzf`, or `native` according to its own backend rules
* native skip policy must use `find ... -prune`, not output-only `! -path` filters, so skipped trees are excluded from traversal rather than merely hidden from output
* cancellation is terminal: if the user aborts an interactive backend, exit `1` rather than falling through to a plain prompt
* the plain prompt fallback exists only for backend unavailability or non-functional interactive selection, not as a post-cancel recovery path
* staged, `fzf`, and native outputs must pass through a portable path-normalization helper with `realpath -m` semantics rather than assuming a specific system `realpath` flag set

-----

## 19. Next Steps

With the current recovered worked-command set back in place, the first-pass derivation of the primary multi-backend `io::*` surface is effectively complete. The remaining work is now refinement and implementation alignment:

1. finalize the per-command public/private arbitration for the recommendation-level style families introduced in the worked-command tables
2. specify and land the deterministic native color contract required for any style family promoted to public status
3. implement the canonical rings-native ambient-default layer, including `RINGS_IO_*` names, alias-derived short forms such as `IO_CONFIRM_*`, and the stated precedence rules
4. tighten any still-provisional native realizations in the recovered worked commands, especially where candidate public options remain underspecified
5. decide whether `EDITOR_PREFERENCE` belongs in the public `write` surface or remains a deferred native-subpath concern
6. land the portable path-normalization helper with `realpath -m` semantics that the `file` derivation now relies on
7. resolve remaining inventory-to-implementation drift exposed by the recovered derivations, especially:
   * wrappers that still rely on raw passthrough instead of recognized union options
   * the still-native-first layout/fmt implementation tree
   * the unimplemented staged lowering paths for `io::in::choose`, `io::in::confirm`, `io::out::table`, and `io::in::file`

Only after the command partitions and option classifications are written should the adapter and shim code be rewritten.
