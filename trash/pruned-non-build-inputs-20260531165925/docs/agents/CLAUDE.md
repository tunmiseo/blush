# CLAUDE — `@ble`

Follow [`CLAUDE-GLOBAL.md`](./CLAUDE-GLOBAL.md). This file adds the local rules for `@ble`.

-----

## 1. Repository Stance

`@ble` is a rings package repository: filesystem-first, shell-native, and dependency-minimal. It uses the shared rings package model through [`docs/rings`](../rings), which is a symlink to the rings repository's `docs/spec` tree.

Prefer extending the existing loader, module, and package model over introducing parallel systems.

Treat the live filesystem as primary evidence. Treat projections, caches, and generated views as derived.

Do not generalize a local rule beyond the layer, object, or scope that gives it meaning.

In this repository especially, keep loader, module, and package concerns separate unless the architecture explicitly couples them.

- **Package Geometry:** Do not treat a package as a flat directory. A package's internal `.d` modular components define where its files project.
- **Facets:** Nested `@` directories are subpackages with their own package boundaries; they may also be facets when viewed under the nested package's identity.
- **Rings Authority:** [`docs/rings/ARCHITECTURE.md`](../rings/ARCHITECTURE.md) and [`docs/rings/PACKAGES.md`](../rings/PACKAGES.md) are the active shared rings spec. `docs/rings` is a symlink to the rings repository's `docs/spec` tree. Do not use `docs/spec/bootstrap/rings-reference-spec/` as active authority unless an active document routes there.

### 1.1 Silent Rigor

All internal verification, consistency checking, auditing, and
disambiguation must happen before the response reaches the page. State
conclusions directly. Do not narrate the process that produced them.

This rule has five concrete prohibitions:

**No process narration.** Do not announce what you are about to do. Do
not describe the steps you are taking. Do not preview your verification
strategy. The reader wants the result.

```text
# Bad
Let me first check the spec, then verify against the code, then
compare with CONSENSUS.

# Good
The spec and code agree: `default_ownership` is the correct field name.
```

**No self-justifying scaffolding.** Do not frame a statement with
language whose only purpose is to signal that you were careful. If the
statement is correct, it does not need an escort.

```text
# Bad
To be precise here, and for the sake of rigor, the ownership
precedence is per-artifact first, then .package, then .module.

# Good
Ownership precedence: per-artifact first, then .package, then .module.
```

**No performative uncertainty.** If you are genuinely uncertain, say so
plainly and say what you are uncertain about. Do not spray hedges across
confident claims to sound appropriately cautious.

```text
# Bad
I believe this might potentially be the case, though it's worth noting
that there could be exceptions.

# Good
This holds for leaf projection. I have not verified whether it holds
under tree projection with folded subtrees.
```

**No visible mid-response self-correction.** If you catch an error
while composing, fix it and present the corrected version. Do not leave
the wrong version on the page with a correction appended. The reader
should not have to determine which version survived.

```text
# Bad
The namespace is core::reconcile — actually wait, no, it should be
modules::reconcile because the namespace follows the package scope.

# Good
The namespace is modules::reconcile. The package scope is
@core/@modules; the core:: portion is elided in the public surface.
```

**No epistemic throat-clearing.** Do not introduce a distinction,
definition, or correction with language that frames the act of
distinguishing rather than the distinction itself.

```text
# Bad
It's important to distinguish between .env and env.d here, because
they serve fundamentally different purposes in the system.

# Good
.env is directory-local metadata read before .loadlist. env.d contains
durable exported environment artifacts. They are not interchangeable.
```

### Why this matters for `@ble` work specifically

Spec review, code review, and design sessions in this repository
routinely involve long, dense exchanges where every sentence carries
semantic weight. Process narration and scaffolding language dilute
signal density. They also create a second problem: when an agent
visibly performs its checking, the arbiter must decide whether the
performance is genuine or decorative — an unnecessary cognitive tax
that compounds over a session.

The standard is: arrive having done the work. Present conclusions at
the density the material requires. Reserve process narration for cases
where the process itself is the subject under discussion — for example,
when explaining a loader algorithm or a reconciliation sequence — not
for cases where the agent is merely doing its job.

### Relationship to other constraints

This rule is complementary to the review taxonomy and the
anti-circularity rule. A response that silently checks its claims
against authority docs and presents only the result is better than one
that narrates the checking. A response that silently classifies a
finding as a semantic contradiction versus a stylistic preference and
then presents only the finding is better than one that walks through the
classification aloud.

Silent rigor is not the same as false confidence. Genuine uncertainty,
open questions, and unresolved risks should be stated plainly as what
they are. The prohibition is on decorative process, not on honest
epistemic status.

### 1.2 Work Completion and Next Steps

Every response that does not fully complete the assigned work must end with concrete next steps. The steps must be anchored to the existing plan or task — not invented, not drifted, not replaced by parallel exploration.

Three rules:

1. If work is incomplete, identify what remains and name the immediate next action.
2. Next steps are drawn from the plan already established, not generated at response time.
3. If the plan has no next step for the current gap, that gap is the item to raise — not a substitute plan.

Reporting incompletion without naming next steps is not acceptable. The reader must be able to act on the response without reconstructing the continuation path.

-----

## 2. Code Changes

Make the smallest correct change.

Do not make a broader change than the task requires. Do not refactor opportunistically.

### 2.1 Rings Translation

Take upstream `ble.sh` and translate it to rings style.

Rings-native means translated upstream code in rings form: package ownership, `::` names, loadlists, local wrappers, and comments. It does not mean originating a new implementation.

If an upstream subsystem exists, never rely on simplified original code instead of porting that subsystem. This is not a preference or a temporary workflow rule. Original code is allowed only where there is no upstream subsystem to port: rings glue, compiler and loader machinery, lints, ledgers, harnesses, package adapters, and other native integration surfaces.

Every new or changed function that implements upstream behavior must start by locating and copying the upstream function body or upstream data table that owns that behavior. Translate the body; do not replace it.

The order is mandatory:

1. Open the upstream symbol and body first.
2. Copy that body or data table into the rings target.
3. Translate names, calls, package-owned globals, file placement, and package-boundary wrappers.
4. Apply version-selection collapse and lazy-init preservation as part of translation (see CONSENSUS.md §11).
5. Only after the copied body is present, apply Bash 5 idioms that are direct semantics-preserving mechanical edits.
6. If a dependency or package boundary blocks the copied body, port the dependency, reshape the boundary, or stop and report the blocker.


Never write a plausible local implementation as an intermediate step. Tests and maps verify a copied-and-translated body; they do not authorize one invented from the desired behavior.

If the upstream body does not fit the current package boundary, reshape the boundary or stop and report the blocker. Do not bridge the mismatch with original code.

Do not begin a port by writing a PTY lane, oracle case, or harness extension. Source translation is the work: copy the upstream closure, translate it in place, and preserve the call chain. Use direct source checks and in-process probes while porting. PTY is a final smoke check for a completed user path, not the unit of implementation progress.

**Split bodies.** When a single upstream function body maps to multiple rings components (e.g., a hook that owns one phase and a caller that owns another), the split is a routing decision, not a license to originate. Each component receives only the upstream operations that belong to its phase — translated, not supplemented. No component may add code to bridge, compensate for, or complete another component's phase. If the split leaves an apparent gap, the gap is closed by the other component. The test: for every line of code in a component, identify the line in the upstream body it translates. Any line with no upstream counterpart is unauthorized and must be removed.

**Ledger registration.** Every upstream function or variable translated in a port change must have a row in `src/@ble/@test/@oracle/classification/upstream.tsv` before the change is committed. Registration happens at port time, not after. A missing row means no closure requirement and no oracle gate — the omission is a gap in the harness, not a sign the symbol does not need tracking. If a suitable surface label does not exist for the symbol's domain, create one. Status is `open` until its registered proof passes against `ble.sh/out/ble.sh` — an existing or explicitly approved PTY lane for completed user-path behavior, or a table-fidelity diff for a declarative data table whose consuming engine is already proven (see CONSENSUS.md §12). Do not create a new PTY lane as a precondition for source work.

**Derived artifacts.** `src/@ble/ble.bash` and `src/@ble/out/ble.full.bash` are build outputs. Do not commit them as part of a porting change. Commit source files only. Regenerate derived artifacts separately when explicitly asked.

A function is not complete because it looks equivalent or passes local unit tests. It is complete only when its upstream source is identified, its rings translation is faithful, and the relevant ledger/oracle evidence exists.

Respect existing contracts such as:

- `.loadlist` format
- loader behavior

Use environment-derived paths such as `$BIN` and `$LIB`. Do not hardcode one user's absolute filesystem layout.

When a change would alter semantics, interfaces, or authority docs, discuss it first and get sign-off before acting.

When implementing or reorganizing a package, decide where the real files live for each file group before writing files.

If the docs or task do not already answer this question, stop and ask before writing files.

Never run broad batch mutation without an atomic recovery point. This includes `perl -pi`, `sed -i`, scripted rename loops, formatter rewrites, generated replacement, and any command that can change more than one file. A git checkpoint protects tracked files only. If the target set includes untracked files, copy or archive those files first. Recovery archives must exclude `.git/`, `trash/`, previous backup archives, and other recovery artifacts; backing up old backups adds size without improving restoration. Do not rely on reconstruction from terminal output or conversation history.

Use `/usr/local/bin/trash` instead of `rm` when removing files or directories. Deletions in this repository should be recoverable from the user's Trash. If `/usr/local/bin/trash` is unavailable, stop and report the blocker instead of falling back to permanent deletion.

For ingest, read, review, audit, or assimilation-only tasks, follow the non-mutating default in `AGENTS.md` unless the user explicitly asks for edits.

Use `$RING_ROOT` generically and `$PROFILE_D` only when the login ring specifically matters.

Callable namespace follows package scope. When the package scope is inside reserved `@core`, the `core::` portion may be elided in the public surface. Do not infer public names mechanically from raw implementation paths.

Do not justify a specification by citing the specification itself. That is circular.

When asked why a rule should exist, answer from the underlying reason for the rule.

The specification may record the rule, but citing it alone is not an argument for its merit.

-----

## 3. Shell Discipline

In `ble`, default to sourced, functionally encapsulated, `::`-qualified shell files.

Sourced files must be safe in an existing shell session.

- use `return`, not `exit`
- do not set global shell options
- keep sourced code dual-shell unless it is explicitly shell-specific

Executed scripts run as their own process.

- use an explicit shebang
- use stricter shell options when they help

Use fully qualified `namespace::name` forms for public sourced functions.

Do not write an executed script unless the task clearly calls for a subprocess entrypoint.

Do not write naked top-level shell code unless the file is intentionally an executed script or an explicitly chosen define-then-dispatch form.

Functional encapsulation and autoinvoking are separate choices. Do not assume `&& fn` unless the task or file role calls for it.

Follow [`SHELL_STYLE_GUIDE.md`](../style/SHELL_STYLE_GUIDE.md) for the concrete shell rules.

-----

## 4. Package Boundary Checklist

Before adding or changing a package boundary, private helper, public API, facet, function namespace, or cross-package call, read [`docs/rings/PACKAGES.md`](../rings/PACKAGES.md) §10. Then check the caller's package path.

The active topology rule is:

```text
private = package and descendants
public  = immediate parent and direct siblings
all other reach routes through the tree
```

Allowed direct calls:

- local package public and private functions;
- ancestor private helpers, preferably localized through the nearest package wrapper that owns the narrower rule;
- immediate child public functions, when composing the child into the parent surface;
- immediate sibling public functions, only when the sibling public API is the intended boundary behavior.

Do not call:

- sibling `__` helpers;
- cousin, uncle, nephew, or unrelated package public or private functions;
- skipped descendants;
- a parent public function as implementation substrate;
- sibling descendant public functions;
- public functions from a sibling's descendant.

Direct sibling means the same immediate `@` package parent, not the same registry or filesystem parent.

For private cross-branch reuse, localize a legal sibling dependency at the caller package boundary. Descendants should reuse that package-local helper downward instead of reaching sideways. Localizing a legal sibling dependency counts as semantic content; forwarding only for access is forbidden.

Prefer shadowing inherited helper names in child wrappers. For example, `ble::prompt::render::__width` may wrap `ble::prompt::__width`. Do not add longer names only to avoid shadowing unless the local behavior is actually different.

`RINGS-ADAPTER`, `BASH-COMPAT`, and `NATIVE-OWNERSHIP-REFINEMENT` explain upstream-family or projection shape only. They never grant call-boundary permission.

When updating an `@PACKAGES.md` map, describe ownership and boundary intent. Do not write package-map prose that can be read as permission to call arbitrary sibling internals or skipped descendants.

-----

## 5. Documentation Boundaries

[To complete]

-----

## 6. Reviews

When reviewing or discussing a problem, include:

1. the exact sentence, path, or command being discussed, with citations, references, or line numbers when they help
2. the current rule, contract, or behavior it conflicts with
3. the direct consequence of leaving it unchanged
4. what should change

Do not assume shared context. Provide enough context in the review itself for another person to follow the point without re-reading the whole conversation.

If something is unsettled, say so plainly.

Speak your mind plainly. Defend recommendations with reasons, evidence, or direct reference to the current docs or code.

When reviewing robustness or integration, do not justify a draft sentence by citing the same draft unless the task is explicitly internal-consistency checking. Compare against live code when known, the current authority docs, settled addenda, and the user's stated target.

Treat absorbed authority docs as canonical over transitional addenda or pasted review notes.

When a draft and its addendum conflict, identify whether the addendum is intended as amendment, migration bridge, or deprecated historical context.

### 6.1 Review Taxonomy

When reviewing, distinguish these registers and do not present one as another:

- semantic contradiction
- contract-surface omission
- implementation-spec gap
- stylistic preference

### 6.2 Default Audit Scope

When asked to audit a spec document without a narrower brief, default to:

- integration gaps such as cross-document vocabulary drift, missing authority pointers, and unresolved behavioral contracts
- correctness of named artifacts such as verbs, variables, and paths
- production-robustness gaps where a rule is too underspecified to implement safely

Do not default to style-register enforcement, duplication cleanup that does not change meaning, or category-policing that adds no operational clarity.

Default scope also excludes duplication that is already consistent and classification of residual categories unless the reader is visibly left without a term to use.

If the requester wants style-register enforcement included, they will say so explicitly.

-----

## 7. Test Discipline

One ownership concern per `.test.bash`. Soft cap of ~25 asserts or ~300 lines before splitting. State-dependent failures across cases inside one file are the symptom of having waited too long; split by ownership boundary at that point.

`harness.bash` and `image.bash` are sourced once at the top of a test file, never mid-file. Sourcing `harness.bash` mid-file emits a duplicate `TAP version 13` header and breaks parsers.

PTY logic belongs under `@test/pty/`, not embedded inline in test files. One PTY runner, one timeout policy, one capture policy.

Tests that source the stitched `ble.bash` runtime image must call `ble::test::require-image` after sourcing `image.bash` (or `harness.bash`, which sources `image.bash` for them). The guard fails loud unless `BLE_TEST_REBUILD=1` is set; `run-all.bash` sets it for local development, CI does not.

Tests are guard rails. A passing suite must source each subpackage twice (idempotency); assert that forbidden patterns are absent (legacy call prefixes, direct resource reads from non-owning packages, `TODO: migrate` markers); and load real upstream dependencies, not local stubs. See `CONSENSUS.md` §10.

Test files (`*.test.bash`) and oracle lane implementation directories may not be created or modified without explicit user approval for each file. This applies regardless of the test's correctness or the port's completeness. State what test coverage is missing and why; do not fill the gap without approval.

PTY lanes cover completed user paths. They must not be used as mini-slice tasks for every helper, branch, option, or internal closure. A port task that needs upstream behavior starts by copying and translating upstream source; if final composed coverage is missing, report the missing lane after the source closure is in place.

-----

## 8. Debugging

When a test fails inside a suite but the failing function looks correct in isolation, the cause is almost always prior-case pollution.

Order:

1. Extract the failing case into a standalone `.test.bash` with only its required setup.
2. If it fails standalone, the bug is in the function. Read the function.
3. If it passes standalone, the bug is pollution. Bisect prior cases by halving (log₂(N) iterations).

Do not read into the failing function's branches before step 2 produces a result. Reading code from inside the failing function while pollution is the actual cause produces plausible-looking false leads.

State-snapshot diffing is the cheap diagnostic for pollution. Before and after each prior case, snapshot:

- `declare -p $(compgen -v _ble_)` for `_ble_*` global state
- `trap -p` for installed traps
- `declare -F | grep ble::` for function definitions and overrides

The first prior case whose diff includes state that survives into the failing case is the polluter.

Reach for the snapshot diff before reading code.

-----

## 9. Upstream Porting Audit Protocol

Before asserting that any upstream symbol — function, variable, state field, hook registration, or behavioral path — is absent from the rings port, verify its absence against the rings source. A failed name search is not a verdict. It is the start of a deeper search.

**Step 1 — Read the upstream symbol.**
Understand what it does: what state it reads and writes, what it calls, what strings, patterns, or file paths appear in its body. Do not reason from the name alone.

**Step 2 — Find the owning rings package.**
Identify which rings subpackage is responsible for this behavioral domain. Use `@PACKAGES.md` and the package directory structure. The translated function lives in the package that owns the concern, not necessarily the package that had the closest name.

**Step 3 — Search by behavioral fingerprint.**
Search the owning package's source for state variable names, distinctive string literals, called functions, file paths, regex patterns, or any body-level signal that would survive a rename. Name-derived grep is a fast first pass only. If it finds nothing, proceed to step 4. Do not conclude absence.

**Step 4 — Read the candidate file.**
If a behavioral match looks plausible, read the full function and compare its behavior to upstream. A different name, different decomposition, or rings-native structural choice does not mean the behavior is absent.

**Step 5 — Conclude absence only after the package read comes up empty.**
"Not translated" requires having read the owning package's relevant file and found no behavioral equivalent. A failed string match on the upstream symbol name is not sufficient evidence.

This protocol applies to: function bodies, state variables, hook registrations, option handlers, behavioral guards, file I/O paths, and async state machines. The rings source is the ground truth. Reading it is not optional before making an audit claim.

-----

## 10. Audit Memoization

Aggregate audit results — function counts, translation coverage, performance metrics, LOC breakdown — are memoized in [`src/@ble/@test/@oracle/translation/metrics.tsv`](../../src/@ble/@test/@oracle/translation/metrics.tsv). Do not re-derive these values by running grep, wc, or sed across the source tree. Read metrics.tsv instead.

The canonical values and the method used to derive each are recorded there with an `as_of` date. The header of [`src/@ble/@test/@oracle/translation/check-symbols.bash`](../../src/@ble/@test/@oracle/translation/check-symbols.bash) embeds the key metrics inline for quick reference without opening metrics.tsv.

**When to update.** If an audit, porting pass, or build step produces a new count that differs from a value in metrics.tsv, update both:

1. `src/@ble/@test/@oracle/translation/metrics.tsv` — update the row's `value` and `as_of` fields.
2. The `Cached Metrics` block in `src/@ble/@test/@oracle/translation/check-symbols.bash` — update the inline key-value table and the date in the section header.

Both files must stay in sync. A metrics.tsv row with a newer `as_of` than the check-symbols.bash header means the header is stale and must be updated in the same change.

**What belongs in metrics.tsv.** Only stable aggregate counts with a reproducible derivation method: function totals, coverage percentages, LOC breakdowns, anti-pattern instance counts. Do not add per-symbol rows — those belong in `symbols.tsv`. Do not add pass/fail status — that belongs in `upstream.tsv` and `lanes.tsv`.
