# Phase 3: Architectural Reconciliation & Visual Parity

> [!WARNING]
> **Correction & Apology:** You are entirely right. I fundamentally misunderstood the repository state by failing to inspect `src/@ble` correctly, incorrectly assuming that packages like `@edit`, `@syntax`, and `@color` had not been ported at all. I see now that they *are* present and fully scaffolded. My previous plan was based on a flawed assumption that we were starting from scratch. I apologize for this oversight. 

This updated plan is based on the **actual** state of `src/@ble` and the requirement to strictly enforce the newly formalized `PACKAGES.md` architecture (no cyclical private calls, proper ancestor-descendant delegation, strict boundary encapsulation) across the *already ported* codebase, while prioritizing **human-observable visual syntax highlighting** over purely passing headless PTY tests.

## User Review Required

> [!IMPORTANT]
> **Pivoting the Success Metric:** We previously had 99% test coverage on headless prompts, but `ble.bash` couldn't even be sourced interactively to provide syntax highlighting. The plan below proposes shifting our execution strategy: we will pause the `oracle-prompt-pty.test.bash` deep-dives and prioritize a top-down execution that gets `source src/@ble/ble.bash` to successfully attach and render live syntax highlighting in an interactive terminal. Do you agree with this pivot for Phase 3?

## Open Questions

1. **Call-Graph Violations:** The recent `PACKAGES.md` formalization outlaws diagonal private calls and sibling-cyclic dependencies. Given the massive upstream coupling between `@edit` (buffer state), `@syntax` (parsing), and `@complete` (context), what is our preferred pattern for resolving existing violations in `src/@ble`? Should we introduce parent-private adapters in `@ble` itself, or define strict, pure-public interfaces that `@edit` exposes for `@syntax` to consume?
2. **The `ble.bash` Cache:** I notice `src/@ble/ble.bash` is currently a 1.6MB cached bundle of the modular files. During this refactoring phase, should we rely on an on-the-fly loader, or do we need to rebuild this cache using a `make` command after every architectural fix?

---

## Proposed Changes: Enforcing `PACKAGES.md` & Re-Wiring the Edit Loop

Instead of porting new files, we will refactor and re-wire the existing packages in `src/@ble` to eliminate architectural violations and achieve a functional edit-to-highlight pipeline.

### 1. Breaking Cyclic Dependencies (`@edit` ↔ `@syntax` ↔ `@color`)
Upstream `edit.sh` and `core-syntax.sh` are tightly coupled. In our Rings architecture, `@syntax` parses strings, but `@edit` owns the readline buffer and dirty-ranges.
*   **Action:** Audit `@edit` and `@syntax` for diagonal call violations.
*   **Resolution:** If `@edit` needs to trigger syntax updates, it must do so via a clean public boundary (e.g., `ble::syntax::parse`). If `@syntax` needs buffer state, it must query `@edit`'s public API. We will implement strict parent-private wrappers (`ble::__edit_syntax_bridge`) if immediate sibling calls violate semantic ownership.
*   **Goal:** Ensure `ble-edit/content/update-syntax` correctly flows without cross-package internal calls.

### 2. Wiring `@canvas` and `@color` for Visual Output
Upstream `color.sh` relies on heavy global state. We need to ensure that the existing `@canvas` and `@color` (or `@color`) packages are properly exposing SGR rendering functions.
*   **Action:** Ensure `ble::canvas::write` and `ble::color::...` (which resolve colors) are correctly utilized by `@syntax` to attach terminal SGR strings to the parsed AST.
*   **Goal:** Verify that terminal bytes emitted contain the correct SGR sequences, independent of the headless PTY harness.

### 3. Restoring Interactive Attachment (`@attach`)
The user noted that sourcing `ble.bash` previously resulted in broken behavior. `@attach` is the sole host adapter (tty, stty, fd plumbing, `bind -x`).
*   **Action:** Audit the `invoke-precmd` and bash-hook lifecycle in `@attach`. 
*   **Goal:** Ensure that sourcing the file successfully hooks `READLINE_LINE` and delegates to `@edit` without crashing the shell or locking the TTY.

---

## Verification & Execution Plan

We will execute this phase in three functional milestones, verifying *live* behavior at each step.

### Milestone 1: Load and Attach without Crashing
*   **Task:** Resolve any load-order cyclic dependencies or illegal diagonal calls that prevent `source src/@ble/ble.bash` from executing cleanly.
*   **Validation (Manual):** `bash --norc`, then `source src/@ble/ble.bash`. The prompt should appear, and typing should echo to the screen, even if monochrome.

### Milestone 2: Syntax Highlighting Pipeline
*   **Task:** Fix the dirty-range and syntax update loop between `@edit` and `@syntax`. Ensure `@color` resolves the default palette.
*   **Validation (Manual):** Type `echo "hello $USER"`. 
    *   *Expectation:* Command (`echo`), string (`"..."`), and variable (`$USER`) are instantly highlighted using the upstream palette. Backspacing dynamically updates the highlight.

### Milestone 3: Regression Sweeps (Post-Visual Parity)
*   **Task:** Only *after* the human-observable edit loop is functional, we will run the `oracle-prompt-pty.test.bash` and `test-syntax.sh` harnesses to verify that our architectural uncoupling didn't drift from upstream byte-for-byte correctness.
