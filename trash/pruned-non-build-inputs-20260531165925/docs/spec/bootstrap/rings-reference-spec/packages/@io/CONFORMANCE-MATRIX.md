# `@io` Conformance Matrix — `codex/clever-girl`

This matrix is the branch-local source of truth for completion claims.

Status values:

- `derived and certified`
- `partially derived`
- `deferred`
- `intentionally divergent`
- `broken`

Certification criteria:

- leaf uses the parser/schema contract or a narrow preflight that does not redefine parsing semantics
- no leaf-local ambient-default logic
- no leaf-local unknown-option policy for migrated options
- canonical dispatch path is used
- migrated shims consume structured `key=value ... -- ...` ingress
- accepted private spellings lower correctly without being presented as public API
- help/docs align with schema classification
- command-level and backend-facing tests exist for the migrated behavior

## Matrix

| Family | Status | Public Surface | Schema | Dispatch / Projection | Shim Ingress | Staged Lowering | Docs / Help | Tests | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `io::in::filter` | derived and certified | Settled and aligned | Yes | Yes | Structured | N/A | Aligned | Present | Primary proof command for parser/schema/dispatch |
| `io::out::view` | partially derived | Public/private surface aligned in help and schema | Yes | Yes | Structured for gum/native/glow | N/A | Mostly aligned | Present | `PAGING` is explicit and `pager` semantics are preserved, but final content-aware backend preference remains only partially modeled |
| `io::out::pager` | partially derived | Compatibility surface over `view` | N/A | Forwards to `view --paging always` | N/A | N/A | Aligned | Present | Correctly preserves pager guarantee; final certification depends on `view` |
| `io::in::choose` | derived and certified | `PROMPT` remains private | Yes | Yes | Structured on migrated backends | Native-first composed lowering through `filter --exact`, declared in schema metadata and executed centrally | Aligned | Present | Leaf is now pure dispatch; schema declares input fill, single-choice fast path, and native composition in one obvious pattern |
| `io::in::confirm` | partially derived | Stable and small | Yes | Yes | Structured on migrated backends | No composed lowering; direct dispatch | Aligned | Partial | Dispatch target is correct, but the leaf still keeps a narrow local flag loop and local unknown-option diagnostic |
| `io::out::table` | partially derived | Surface exists and is mostly settled | Yes | Mixed: parser/schema plus leaf-local `__dispatch-print` | Structured for print path backends | `choose` for simple selection, indexed `filter` path for multi / return-column | Mostly aligned | Partial | Further along than prior branch summaries, but the print path still duplicates dispatch logic in the leaf and is not yet certification-clean |
| `io::in::file` | partially derived | Public surface exists; `ROOT` / mode flags remain private | Yes | Yes | Structured on migrated backends | Stages through `filter` for multi / hidden / no-skip, dispatches directly otherwise | Mostly aligned | Present | Schema-backed now, but still keeps legacy-style trailing-path handling and staged-helper behavior rather than being certification-clean |
| `io::in::input` | partially derived | Public surface exists and is settled | Yes | Yes | Structured on migrated backends | N/A | Aligned | Present | Schema-backed now and straightforward, though not yet marked certification-clean pending broader family closure |
| `io::in::write` | partially derived | Public surface exists; `VALUE` remains private/candidate | Yes | Yes | Structured on migrated backends | N/A | Mostly aligned | Partial | Schema-backed now, but `VALUE` and native subpath selection remain intentionally unresolved, so the family is not certification-clean |
| `io::out::log` | partially derived | Public level/prefix surface exists | Yes | Yes | Structured on migrated backends | N/A | Mostly aligned | Partial | Level/prefix logging now follows the schema-driven path, but richer candidate logging modes and formatter surface remain deferred |
| `io::out::progress` | partially derived | Public surface exists; transfer-monitor contract (`--name`, `--size`, `--lines`) | Yes | Yes | Structured on migrated backends | N/A | Aligned | Present | Transfer-monitor contract implemented; pv backend added; native clean-room shim with Unicode block bar; legacy `bar_animation` kept for compat shims |
| `io::out::spin` | partially derived | Public surface exists | Yes | Yes | Structured on migrated backends | N/A | Mostly aligned | Partial | Leaf now preserves the positional-title convenience through narrow preflight, but final derivation still depends on the broader `progress` / `spin` contract closure |
| `io::fmt::*` | deferred | Family exists | No | Legacy | Positional / legacy | N/A | Legacy | Representative only | No schema-driven family migration yet |
| `io::layout::*` | deferred | Family exists | No | Legacy | Positional / legacy | N/A | Legacy | Representative only | No schema-driven family migration yet |

## Gate State

### Branch Completion

Not yet satisfied.

Reasons:

- multiple in-scope public command families remain deferred
- `table` is only partially derived
- branch-level test claims must stay qualified by the enforced shell floor
### Full `@io` Derivation Completion

Not yet satisfied.

Reasons:

- deferred command families remain outside the schema-driven contract
- `view` still needs final reconciliation on content-aware backend preference
- runtime algorithm divergence still needs explicit closure as code or authority-doc update
