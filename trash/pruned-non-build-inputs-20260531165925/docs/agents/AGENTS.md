# AGENTS — Working Method for `@ble`

> **Status:** Active guidance.
> **Scope:** Reading authority, reasoning about changes, implementing carefully, and communicating clearly.

-----

## 1. Repository Posture

`@ble` is a rings package repository: filesystem-first, shell-native, and document-driven. It uses the shared rings package model through [`docs/rings`](../rings), which is a symlink to the rings repository's `docs/spec` tree.

That has four practical consequences:

1. Read the tree before theorizing about it.
2. Treat the live filesystem as primary evidence.
3. Prefer extending the existing loader, module, and package model over introducing parallel systems.
4. Keep local rules local. Do not turn a repo-specific behavior into a global law unless the architecture requires it.

-----

## 2. Authority and Read Order

When a task touches semantics or behavior, read the authority documents before proposing changes.

In this repository, [`docs/rings`](../rings) is the active shared rings specification. It is a symlink to the rings repository's `docs/spec` tree. Do not treat `docs/spec/bootstrap/rings-reference-spec/` as active authority unless an active document routes to it explicitly.

Use this order:

1. [`docs/rings/ARCHITECTURE.md`](../rings/ARCHITECTURE.md) for the layer model and document boundaries.
2. [`docs/rings/LOADER.md`](../rings/LOADER.md) for loader behavior, `.loadlist`, boot flow, and caching.
3. [`docs/rings/MODULES.md`](../rings/MODULES.md) for module identity, submodules, and `@core`.
4. [`docs/rings/PACKAGES.md`](../rings/PACKAGES.md) for package grammar, routing, registry behavior, lifecycle, facets, and package call rules.
5. [`DOCUMENTATION-STYLE-GUIDE.md`](../style/DOCUMENTATION-STYLE-GUIDE.md) for prose and specification writing.
6. [`SHELL_STYLE_GUIDE.md`](../style/SHELL_STYLE_GUIDE.md) for shell code.
7. [`CONSENSUS.md`](./CONSENSUS.md) for settled repo points worth repeating in review.
8. [`CLAUDE.md`](./CLAUDE.md) for repository-specific coding and writing discipline.

If two documents differ, the more specific authority wins.

Examples:

- If `ARCHITECTURE.md` and `MODULES.md` differ on module identity, follow `MODULES.md`.
- If `PACKAGES.md` and a draft note differ on package routing, follow `PACKAGES.md`, but _always_ flag for discussion.

Drafts, handoffs, and historical notes are not authority unless an authority document points to them.

Repository-status documents — `STATUS.md`, files matching `*ASSESSMENT*.md` or `*PARITY*.md`, contents of `notes/migration-snapshot/`, and any prose that describes repository state — are point-in-time narration. They do not prove their own claims. The active authority for completion claims is the structured ledger ([`@test/@oracle/classification/upstream.tsv`](../../src/@ble/@test/@oracle/classification/upstream.tsv)) plus the lane registry ([`@test/@oracle/pty/lanes.tsv`](../../src/@ble/@test/@oracle/pty/lanes.tsv)). When narration disagrees with the ledger, the ledger wins.

Before changing any `@ble` package boundary, private helper, public API, facet, function namespace, or cross-package call, read [`docs/rings/PACKAGES.md`](../rings/PACKAGES.md) §10.

-----

## 3. Design and Specification Work

### 3.1 Basic Discipline

1. Distinguish structure from behavior.
2. Distinguish mechanism from meaning.
3. State what the system does before explaining why it is useful.
4. State affirmative rules directly and only when fully evident. Add boundary rules only when the boundary matters.
5. Prefer the contextualized, concrete, and fully true sentence over the broad impressive one.

### 3.2 Terms

Terms, or operative definitions, are essential for semantic compression and do real work. They become harmful when they only decorate the prose, obfuscate the point, or abstract away the distinctions that matter.

Judge a term by the work it does:

1. Does it name a real repeated distinction?
2. Is it defined plainly the first time?
3. Does it save space and thought later?
4. Is it reused consistently?
5. Does it preserve flexibility instead of narrowing the design accidentally?
6. If it is an abstraction, does the generalization invite real concrete novel directions?

Do not judge a term by its logical consistency or technical denotative accuracy alone. Those matter, but they are not enough.

If a term's scope or context matters, make that scope or context clear. Do it early, and do it concisely.

If two terms overlap, state the relation plainly instead of forcing one to replace the other. Use chosen terms consistently. Never equivocate.

### 3.3 Style

Follow [`DOCUMENTATION-STYLE-GUIDE.md`](../style/DOCUMENTATION-STYLE-GUIDE.md).

In practice:

1. Define syntax once and reuse the defined noun.
2. Use plain declarative language.
3. Prefer ordinary verbs over abstract summary nouns when both are equally accurate.
4. Do not add conceptual weight where a direct sentence will do.
5. Do not narrate the drafting process inside the document.

-----

## 4. Implementation Work

### 4.0 Copy-First Porting

For upstream BLE behavior, implementation work starts from upstream code, not from a local design.

If an upstream subsystem exists, never rely on simplified original code instead of porting that subsystem. This is the invariant for parity work. Original code is allowed only where there is no upstream subsystem to port: rings glue, compiler and loader machinery, lints, ledgers, harnesses, package adapters, and other native integration surfaces.

Source parity is established by copying the upstream body or data table, translating names and ownership in place, and preserving the upstream call chain. PTY lanes are final smoke checks for completed user paths. They are not a design tool, not a prerequisite for starting a port, and not a substitute for source translation.

**Before splitting.** If an upstream body cannot fit in a single rings target, map every operation in the body to its rings destination before writing any code. The map must account for every upstream operation exactly once. Do not begin writing until the map is complete and every operation has a clear owner. Discovering the split mid-implementation produces invented bridging code.

1. Locate the upstream function body or data table before editing.
2. Copy that upstream body or data table into the rings target.
3. Translate names, calls, package-owned globals, file placement, and package-boundary wrappers.
4. Apply Bash 5 idioms only after the copied upstream body is present, and only when the edit is a direct semantics-preserving translation.
5. If a dependency or package boundary blocks the copied body, port the dependency, reshape the boundary, or stop and report the blocker.

Do not create a plausible local implementation for upstream behavior. Do not write stubs, facades, simplified algorithms, or test-shaped bodies as an intermediate step. Tests verify copied-and-translated upstream behavior; they do not define it.

### 4.1 Code Discipline

1. Keep implementation claims aligned with the authority docs.
2. Do not harden an unsettled interface name into code or docs unless the task is to settle it.
3. Keep active subsystem names current. Treat `PACKAGES.md` §8 as the authority for the current `packages::verb` lifecycle surface and its `pkgs::verb` alias. Treat stale `bindings::...` references as legacy unless the task is explicitly historical. Do not harden alternate top-level `rings ...` spellings unless the binary surface is explicitly settled in the authority docs.
4. Never hardcode user-specific paths or secrets or other metadata. Seek a repository-relative or environment-derived safe and flexible solution.
5. Use `$RING_ROOT` generically and `$PROFILE_D` only when the login ring specifically matters.
6. Keep `.package`, `.module`, `.env`, and `env.d` role boundaries explicit.
7. Respect ownership precedence: per-artifact override first, then `.package`, then `.module`.
8. Do not privilege `packages.d/` as the only meaningful authoring surface. Module-owned artifacts are co-equal.
9. Callable namespace follows package scope. When the package scope is inside reserved `@core`, the `core::` portion may be elided in the public surface. Do not infer callable names mechanically from raw implementation paths.
10. When the callable surface is in doubt, ask for or inspect the actual code surface before hardening names into docs. See `CONSENSUS.md` for the settled rule and examples.
11. Broad mutation requires a recovery point. Before running a scripted rewrite, formatter, recursive rename, generated replacement, or any command that can change multiple files, create an atomic backup of the exact target set. Git protects tracked files only; copy or archive untracked files before mutating them. Recovery archives must cover active source targets only: exclude `.git/`, `trash/`, previous backup archives, and other recovery artifacts. A backup that contains older backups grows without adding recovery value and is not an acceptable recovery point.
12. Place artifacts in their correct modular component. If a file belongs in the `env.d` module, place it in the `env.d/` modular component inside the package (e.g., `packages.d/@pkg/env.d/file.sh`). Do not bypass the registry to write directly to module directories without applying ownership rules.
13. When a plan or claim asserts a precondition — "X passes," "Y is closed," "Z is implemented" — cite the artifact that proves it, run the verification before proceeding, or label the precondition as unverified. A repository-status document does not count as proof of its own claims. Plans built on unverified preconditions inherit those preconditions as risks.
14. Check `src/@ble/@test/@oracle/classification/upstream.tsv` at the start of every port task. Verify that every upstream symbol being translated has a row in `upstream.tsv`. Add missing rows before writing implementation code. Do not create or expand PTY lanes before the source port is complete. If a completed user path lacks final smoke coverage, document that gap explicitly; do not block the source translation on a new lane and do not claim ledger closure without the registered proof.
15. Use `/usr/local/bin/trash` instead of `rm` when removing files or directories. Deletions in this repository should be recoverable from the user's Trash, including generated artifacts, stale notes, temporary probe files, and directories. If `/usr/local/bin/trash` is unavailable, stop and report the blocker instead of falling back to permanent deletion.

### 4.2 Sourced and Executed Shell

Keep the sourced/executed split explicit.

**Sourced code** must be safe in an existing shell session.

- Do not call `exit`; use `return`.
- Do not set global shell options such as `set -e` or `set -u`.
- Do not add a shebang.
- Keep code dual-shell unless it lives in an explicitly shell-specific namespace such as `@zsh/` or `@bash/`.

**Executed code** may use stricter process-local behavior.

- Use an explicit shebang.
- Use stricter shell options when appropriate.

See [`SHELL_STYLE_GUIDE.md`](../style/SHELL_STYLE_GUIDE.md) for the full rules.

### 4.3 Existing Contracts

Do not change these casually. First organize and defend a coherent proposal:

- `.loadlist` format
- loader regex behavior
- `.zshrc.cache` format
- projection and reverse-projection rules

If a task requires changing one of these, update the relevant authority doc in the same change.

### 4.4 Read-Only and Assimilation Tasks

When the user asks to read, ingest, internalize, review, summarize, or audit documentation or code without asking for edits, implementation, or repository updates, do not modify repository files.

Do not add index entries, cross-links, README navigation, formatting-only passes, or other "helpful" discoverability edits unless the user explicitly asks for those changes.

Treat assimilation as context load for the session, not as a trigger to maintain docs.

Read-only, audit, and assimilation tasks are non-mutating by default, even when stale or broken documentation is discovered.

If it is unclear whether writes are in scope, ask once before editing.

-----

## 5. Documentation Work

1. Keep each section understandable on its own.
2. Put the real rule in the document, not a note about the revision.
3. Do not preserve stale names because older examples used them.
4. Avoid superfluous invariants. Do not propose invariants simply for closure or elegance.
5. Do not make lossy edits. Do not drop distinctions or weaken correct claims in the name of cleanup.
6. Update the authority doc first when a semantic rule changes.
7. Update [`CONSENSUS.md`](./CONSENSUS.md) only when a point is settled enough to repeat as standing guidance.
8. In spec integration work, compare the target document against the prior authority doc, the settled amendment or addendum if one exists, and the actual intended end state.
9. A successful integration pass removes stale conflicting text; it does not merely append corrected text.
10. Transitional addenda are not permanent authority. Once absorbed, the authority doc wins.
11. When updating an existing document, preserve its structure, explicit distinctions, and strong operative sentences. Add new facts into the existing shape without rewriting prose. Do not replace full lists with examples or summaries.

-----

## 6. Review and Discussion

1. Quote the exact sentence, path, or command under discussion, with citations, references, or line numbers when they help.
2. State the current rule or behavior it conflicts with.
3. State the consequence of leaving it unchanged.
4. State what should change in direct language.

Do not make the reader reconstruct the context from memory.

If something is unsettled, say so plainly. Do not write as if a possible future interface were already authority.

Speak your mind plainly. Defend recommendations with reasons, evidence, or direct reference to the current docs or code.

When a change would alter semantics, interfaces, or authority docs, prefer discussion and sign-off to unilateral action.

This section governs what to do with findings. The review taxonomy in `CLAUDE.md` governs how to think about them.

When auditing, classify each point before pushing it forward:

- real contradiction
- unresolved contract gap
- missing authority pointer
- implementation note
- style maximalism

Separate "keep and act on" from "optional cleanup" and "ignore." Do not require every residual category to gain a formal noun unless the term materially improves reuse and reasoning.

### 6.1 Reviewing Terms

Do not use a binary test such as "operational or ornamental."

Use a graded judgment:

- clearly earned
- earned but needing a sharper first definition
- earned but inconsistently reused
- useful only in a local subsection
- not yet earning its cost

### 6.2 Handoff and Verification

For inter-agent handoff, carry at least:

- claim
- evidence
- proposed change
- unresolved risk

Before finalizing a semantic or documentation change:

1. identify which document or layer owns the rule
2. update the authority surface first
3. verify cross-document consistency and local links
4. surface any unresolved conflict explicitly instead of silently choosing

### 6.3 Concrete Next Steps — Mandatory When Work Is Incomplete

Every response that does not fully complete the assigned work must end with concrete next steps.

Concrete means: specific file, specific line, specific command, specific question to ask. Not categories. Not directions. Not "investigate X."

Bad: "Add ledger rows for the unverified clusters."
Good: "Insert three rows into upstream.tsv after line 1110: `history-core | ble/builtin/history/.load-recent-entries | open | <rings-fn> | ...`"

Next steps must stay anchored to the existing plan. No drift, no new directions not already established. If the plan has no next step for the current gap, the TODO is "raise gap X with user" — not a substitute plan invented on the spot.

Reporting incompletion without concrete next steps is not acceptable.

-----

## 7. Boundaries

Module identity, package grammar, loader behavior, and lifecycle mechanics belong in the authority documents listed above.
