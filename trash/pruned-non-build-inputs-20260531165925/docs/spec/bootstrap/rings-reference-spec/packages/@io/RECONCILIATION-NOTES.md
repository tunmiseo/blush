# `@io` Reconciliation Notes — `codex/clever-girl`

This file records the current high-value contradictions Lex is actively tracking.

Each item is intentionally narrow:

- family
- contradiction
- smallest corrective set
- certification impact

## Active contradictions

### 1. `io::out::table`

- **Contradiction:** the family is far enough along to no longer be called legacy, but the leaf still duplicates dispatch behavior in `__dispatch-print` instead of routing entirely through the canonical dispatch path.
- **Smallest corrective set:** finish the table leaf/shim integration so the print/direct path does not need a table-specific dispatch reimplementation in the leaf.
- **Certification impact:** blocks `derived and certified`; current status remains `partially derived`.

### 2. `io::in::confirm`

- **Contradiction:** the command dispatches into the schema/runtime path correctly, but the leaf still keeps a narrow local flag loop and its own unknown-option diagnostic instead of becoming a pure schema-driven entry.
- **Smallest corrective set:** either move confirm fully onto parser-driven entry semantics or keep it explicitly marked as partial until that leaf-local loop is retired.
- **Certification impact:** blocks `derived and certified`; current status remains `partially derived`.

### 3. `io::out::view`

- **Contradiction:** surface and paging semantics are now coherent, but final content-aware backend preference is still only partially modeled at the schema/runtime layer.
- **Smallest corrective set:** either land the intended content-type-aware preference behavior or explicitly document the accepted branch divergence.
- **Certification impact:** blocks full-derivation certification for `view`; branch-level partial certification remains acceptable.

### 4. `io::out::progress`

- **Contradiction:** the command family is now on the parser/schema/dispatch path, but current semantics still do not prove final derivation semantics for a transfer-monitor contract.
- **Smallest corrective set:** either keep `progress` explicitly out of the “fully derived” claim, or land the final backend semantics before making that claim.
- **Certification impact:** blocks full `@io` derivation completion.

### 5. Runtime algorithm

- **Contradiction:** current dispatch behavior uses constraint intersection; the derivation plan still describes the stronger greedy-first-with-composition model.
- **Smallest corrective set:** either update the authority docs to accept the current runtime behavior, or change the runtime to match the authority docs.
- **Certification impact:** blocks full derivation completion until resolved one way or the other.

### 6. Completion claims vs actual migrated surface

- **Contradiction:** branch summaries can easily outrun the actual migrated family set because parser/runtime infrastructure is ahead of several command families.
- **Smallest corrective set:** keep all completion language anchored to [CONFORMANCE-MATRIX.md](/Users/monad/src/repos/rings/functions.d/@core/_/@io/CONFORMANCE-MATRIX.md) and [MIGRATION-STATUS.md](/Users/monad/src/repos/rings/functions.d/@core/_/@io/MIGRATION-STATUS.md).
- **Certification impact:** blocks branch-complete and full-complete wording when ignored; does not itself block code behavior.
