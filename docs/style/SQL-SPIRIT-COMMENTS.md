# SQL Spirit Comments

> **Status:** Active authority.
> **Scope:** Content quality of in-code comments across all source languages in this repository.
> **Relationship:** [`DOCUMENTATION-STYLE-GUIDE.md`](./DOCUMENTATION-STYLE-GUIDE.md) governs prose in `docs/`. [`SHELL_STYLE_GUIDE.md`](./SHELL_STYLE_GUIDE.md) §3 governs **where** comments sit (header / docblock / statement / inline) and their visual format. This document governs **what those comments say**.

-----

## 1. Thesis

A comment must explain the **codebase**, not the **language**.

The reader is a seasoned developer who knows the language and is new to this code. Comments should serve as a tutorial to the codebase: they should teach the reader how this package's data structures, performance choices, state transitions, and boundaries work. They do not need detached language lessons about what `local` means, what a `for` loop does, or what an array index is. They do need to know why *this code* stores data this way, why one access path is preferred over another, and what would break if someone "fixed" the line that looks redundant.

This is the SQL Spirit — named for the documentation culture in SQLite, where detailed source comments are part of the long-term correctness system. SQLite code comments explain file formats, parser states, b-tree rules, planner choices, locking behavior, compatibility promises, and performance paths near the code that depends on those facts. The point is not a line-count target. The point is that a competent stranger should be able to modify this file years later without asking the original author why anything is the way it is.

### 1.1 What SQLite Spirit Means Here

SQLite Spirit means comments are maintenance infrastructure.

They teach the codebase deeply enough that future maintainers can preserve behavior, performance, and design intent over long time horizons. A good comment says what promise the code is preserving, why the shape exists, which edge case or compatibility rule it protects, and how to change it without breaking that promise.

This repository borrows that discipline for BLE:

- Comments should explain the editor model, history model, prompt model, terminal model, package boundary, or state machine that the code implements.
- Comments should explain performance choices when a faster access path, cached scalar, sparse array, reverse scan, or apparently slower safe path matters.
- Comments should explain compatibility behavior that protects Bash, terminal, history-file, or user-configuration expectations.
- Comments should make testable claims when the comment states behavior that can be checked. If a comment describes a caller rule, a state transition, or a boundary rule, there should be a test, lint, or oracle row when practical.
- Comments should prepare the next maintainer to make a correct edit, not merely identify what the current line syntactically does.

-----

## 2. Codebase, Not Language

This is the rule that produces all the others. Apply it at every comment site.

### 2.1 Comments that explain the codebase (do this)

- **Invariants this code maintains.** "After this point, `_ble_edit_ind` is guaranteed to be within `[0, ${#_ble_edit_str}]` — downstream renderers rely on this."
- **Why this code exists here.** "This early return covers the case where `attach` is called twice during a re-source — the second call must be idempotent because user `.bashrc` files commonly do this."
- **What would break if changed.** "Do not collapse this into a single substitution: the intermediate variable preserves the exit status of the previous command for the caller's `$?` check."
- **External caller expectations.** "This function is called from `blehook PRECMD` — it must not exit non-zero or the user's prompt color changes."
- **Domain meaning of values.** "`-1` here means 'cursor not yet placed', not 'last position'. The placed-vs-unplaced distinction matters because the renderer skips dirty-range computation when unplaced."
- **Unobvious ordering.** "Width must be computed before SGR escapes are inserted, because SGR sequences have zero display width but non-zero string length."
- **Performance choices in this codebase.** "The cached count avoids walking sparse history arrays on every Up/Down keypress; deletion is the only path that pays the cost to rebuild position-indexed dirty flags."

### 2.2 Comments that explain the language (do not do this)

- **Restating syntax.** `# loop over the array`, `# declare a local variable`, `# concatenate strings`, `# return from function`.
- **Naming what is already named.** `# the index variable` next to `local i=0`.
- **Narrating control flow visible in the code.** `# if the value is empty, return early`.
- **Generic shell tutorials.** `# in bash, $? holds the exit status of the previous command`.

If the comment would belong unchanged in a generic Bash tutorial, delete it. The reader has already read the tutorial.

If the comment is a tutorial for this codebase's model, keep it. It is useful to explain why a sparse array is used here, why a cached scalar exists beside an array, why a reverse scan preserves the newest history entry, or why a slower-looking path is chosen to preserve prompt or history semantics. The line is whether the explanation teaches BLE's design, not whether it has a tutorial shape.

### 2.3 Why the distinction is strict

A language-level comment is worse than no comment. It costs vertical space, dilutes signal density when scanning, and trains readers to skim past comments because most of them carry no information. A reader who learns to skip comments will also skip the codebase-level comment that explains the actual invariant — and break the invariant on their next edit.

-----

## 3. Density

High comment density is correct **when comments carry maintenance or ancillary information the code alone does not**.

- **Substantive density** is good. A function with 30 lines of code and 25 lines of comments is well-documented if those 25 lines teach the data model, performance reason, state transition, compatibility rule, package boundary, or failure mode that the code depends on.
- **Verbose density** is bad. The same function with 25 lines of comments restating what the 30 lines obviously do is noise.

Extensive ≠ verbose. Extensive means *justified*; verbose means *repetitive*. SQL Spirit favors extensive and rejects verbose with equal force.

When in doubt: would deleting this comment make the next edit *less safe* or *less informed*? If yes, keep it. If no, delete it.

Do not delete a detailed explanation merely because it is long or tutorial-shaped. Delete or rewrite it only when it teaches the wrong subject: generic shell mechanics, generic programming advice, stale provenance, or claims that are not true of this code.

-----

## 4. Where to spend comment effort

Concentrate substantive commentary at the points where readers most often go wrong:

- **File headers** — package role, what loads at source time, what assumptions the file makes about its environment.
- **Function docblocks** — preconditions, postconditions, invariants, return behavior (per `SHELL_STYLE_GUIDE.md §3.2`). All functions must have a docblock--either the templated "blade", or for simpler functions, a normal (but comprehensive) comment.
- **Boundaries** — where data crosses a trust boundary, an encoding boundary, a process boundary, or an asynchronous boundary.
- **Error paths** — why the error is recoverable or why it is not, what state is left behind.
- **Code that looks redundant** — when the obvious simplification is wrong, say why before someone tries it.
- **Code that looks wrong** — when an apparent bug is intentional, say so and cite the constraint.
- **Integration points** — calls into parsers, dispatchers, subshells, fd manipulation.

Sparse commentary is correct in code that is genuinely uninteresting. Most code in a maintenance-grade codebase is *not* uninteresting.

-----

## 5. Production Comments Describe This Codebase

Production source comments describe the code as it exists in this repository. They do not make the porting process, upstream provenance, or compliance with a migration rule the subject of the comment.

Bad:

```bash
# ┠─ Translation ─────────────────────────────────────────
# ┃  Upstream message helpers encoded payloads. The rings form preserves this.
```

This explains the migration, not the package. It tells the reader where the code came from, but not what the code owns, stores, guarantees, or can break.

Good:

```bash
# ┠─ Queue Records ───────────────────────────────────────
# ┃  Each queue item starts with a message type followed by payload fields.
# ┃  Payload fields are `%q` encoded before storage and decoded only when the
# ┃  handler runs, so spaces, tabs, and shell metacharacters survive queueing.
```

This explains the package's data format and why the encoding exists.

### 5.1 Field Names Come From The Code

Header fields after `Source`, `On Load`, and `Provides` are chosen from the concrete concern in the file. Do not use a fixed catch-all field when a specific name would explain the code better.

Avoid generic buckets, unless absolutely optimal for the field:

```text
Translation
Contract
Notes
Details
Implementation
```

Always avoid useless generics like "Contract" and "Translation".
Prefer concise field names that name the actual design pressure in that file, such as a queue record format, descriptor lifetime, unset-state handling, path-list format, dispatch rule, timing model, or locale cache. Choose the field dynamically each time. Do not use a field at all if it does not add information that makes future edits safer.

### 5.2 Provenance Is Not Explanation

It is acceptable for symbol maps, ledgers, or a short source note to record upstream provenance when audit requires it. This has nothing to do with commenting or documenting the codebase whatsoever. Provenance does not replace codebase explanation.

A comment that says only "this follows upstream" is incomplete. It must say what the current package does and what invariant the upstream-shaped code preserves.

### 5.3 Explain Bash Only Where BLE Needs It

This is a Bash codebase, so some Bash behavior is part of the design. Explain the Bash fact needed to understand BLE's reason for the code, and stop there.

Bad:

```bash
# File descriptors are numbers used by Unix processes for open files.
```

This is a tutorial.

Good:

```bash
# ┃  BLE is sourced into the user's interactive Bash process. A descriptor that
# ┃  BLE opens or duplicates stays open in that shell after the helper returns,
# ┃  can leak into commands the user runs, and can become stale after re-source
# ┃  or cache reuse if only the variable naming it survived.
```

This explains why BLE tracks fd lifetime.

### 5.4 Header Comments Answer Codebase Questions

For a non-trivial package header, answer the questions that make future edits safer:

- What does this package own?
- What state or data format does it maintain?
- Why does BLE need this package?
- What can break if a maintainer "simplifies" it?
- Which nearby package owns the adjacent concern?

Do not answer with abstract labels. Name the actual variables, formats, states, and boundaries when they matter.

### 5.5 Use Plain Language, Not Jargon

Source comments must use plain language. Do not use undefined abstractions, decorative metaphors, or compressed labels when ordinary words can name the thing directly.

Bad:

```bash
# This package owns generic descriptors through an fd registry.
```

This hides the real behavior behind two abstractions. It does not say which descriptors, why BLE records them, or what can go wrong.

Good:

```bash
# This package tracks fds opened by utility helpers: temporary files, helper
# pipes, saved copies of standard streams, and command-output probes. It records
# which fds must be closed when BLE finalizes and which fds must be closed
# before running child commands so they do not leak into user processes.
```

This names the actual resources, the stored lists, and the failure it prevents.

Use project terms only when they are already defined for this codebase or when the comment defines them immediately. If a word such as `registry`, `surface`, `contract`, `adapter`, `primitive`, `lifecycle`, `projection`, or `ownership` does not make the next edit more concrete, replace it with the variable, file, command, state, or caller rule it was trying to summarize.

Do not use metaphor in source comments. A metaphor may be memorable, but it forces the next maintainer to translate the image back into code. Say the code fact directly.

Bad:

```bash
# This is the safety layer between child commands and the fd registry.
```

Good:

```bash
# Before BLE runs a child command, this closes helper fds listed in
# `_ble_util_fdlist_cloexec` so the child cannot inherit temporary files or
# saved standard streams.
```

Plain language is not shallow language. A comment can be detailed and still be plain. The standard is concrete wording: name the variables, files, fds, arrays, queues, states, callbacks, and commands that the code actually uses.

### 5.6 Explain Why BLE Needs The File

A header must say more than the package name. It should explain the codebase reason the file exists.

For descriptor helpers, the reason is not "fd management." The reason is that BLE is sourced into the user's interactive Bash process. Descriptors opened or duplicated by BLE can remain open after a helper returns, leak into commands the user runs, or become stale after re-source or cache reuse. A useful header says that, then says which part of the problem this file handles.

For queue helpers, say what is queued, how records are stored, when handlers run, and what survives across the delay. For parser helpers, say what state is being advanced and which downstream reader assumes that state shape. The header should explain the BLE problem, not the general programming topic.

### 5.7 Explain Loaded State

If a file creates package variables when it is sourced, the nearby comment must say what each lasting variable is for and how long it is expected to remain valid.

Do not write only:

```text
Declares package state.
```

Name the variables when they matter:

```text
`_ble_fd_open` records descriptors opened by utility helpers.
`_ble_util_fdlist_cloexit` records descriptors BLE must close when it finalizes.
`_ble_util_fdlist_cloexec` records descriptors that should not leak into child commands.
`_ble_util_fdvars_export` records exported variable names whose fd numbers must be checked after re-source or cache reuse.
```

The same applies outside fd code. If a variable records parser nesting, pending messages, dirty ranges, prompt cache entries, or option bindings, say what the stored values mean and when they are cleared or revalidated.

### 5.8 Name The Nearby Owner

When a file sits next to another package's responsibility, say where the nearby responsibility belongs.

For example, utility fd code may choose unused fd numbers, duplicate descriptors, restore descriptors, close descriptors, and track helper-side cleanup. Interactive session policy belongs elsewhere: `@attach` decides how the user's stdin/stdout/stderr and terminal-facing streams are arranged for an editing session.

This kind of comment prevents future edits from moving session behavior into utility code, utility allocation into attach code, syntax attribute generation into highlighting layers, or rendered output policy into low-level string helpers.

### 5.9 Every Function Gets A Comment

Every function must have a comment immediately above it.

That does not mean every function gets a full blade. Small functions can use a compact docblock that states the purpose, usage, and any non-obvious behavior. Larger functions need a full blade when they:

- mutate lasting package or global state;
- open, duplicate, restore, or close fds;
- construct shell code with `eval`;
- handle stale state after re-source, cache reuse, or inherited variables;
- cross process, child-command, terminal, Readline, parser, async, or encoding boundaries;
- implement platform or Bash-version fallback behavior;
- have return status callers depend on.

This list names common cases, not the limits of the rule. If a function is hard to edit safely without context, give it the fuller comment even when it does not match one of these bullets.

Choose the amount of comment for the function in front of you. Do not squeeze every function into the same fields, and do not use a blade as decoration when a compact docblock explains the whole function.

### 5.10 Choose Headings From The Code

Headers and blades should use headings that name the actual concern.

Good headings are specific to the file or function:

```text
Stored Fds
Descriptor Reuse
Child Commands
Queue Records
Unset vs Empty
Fallback Path
Caller Assumption
```

These examples are not a menu. Use the heading that names the actual concern in the code being commented.

Avoid generic headings when a specific heading would say more:

```text
Notes
Details
Implementation
```

Do not use `Translation` in production source comments. It makes the migration process the subject instead of the code. Avoid `Contract` unless it is truly the clearest word; usually the actual constraint is clearer: `Return Status`, `Stored State`, `Caller Assumption`, `Child Commands`, `Queue Records`, or another heading from the code itself.

### 5.11 Explain Risky Shell Mechanics Where BLE Needs Them

Do not teach Bash generally. Explain the BLE-specific reason the shell feature matters.

Bad:

```bash
# Bash file descriptors are numbers.
```

Good:

```bash
# This uses `eval` because Bash redirections are parsed as shell syntax. The fd
# number is checked first so a stale or malformed value cannot be placed into
# `exec $fd<&-`.
```

The second comment does not teach what a descriptor is. It explains why this BLE code validates data before placing it in a dynamic redirection.

### 5.12 Say What Breaks If Simplified

If code looks longer than necessary, say why the shorter version is wrong.

Examples:

- A descriptor is closed only after checking it still names the same resource, because fd numbers can be reused.
- A fallback path exists because `/proc/<pid>/fd` is not available on every platform BLE supports.
- A variable is unset instead of assigned empty because callers distinguish unset from empty.
- A helper uses a parent package function instead of a sibling private helper because package boundaries forbid direct private sibling calls.
- A cache entry is revalidated even when it was just loaded because users can re-source BLE inside an already-mutated shell.

These are examples, not a checklist. The obligation is to explain the simplification that a maintainer is likely to try in this file.

### 5.13 Comment The Dangerous Lines

A file header does not replace local comments. Put statement comments near lines whose local risk is not obvious from the function docblock.

Statement comments are expected around risks like:

- dynamic redirections;
- `eval`;
- fd reuse checks;
- fallback platform probes;
- exported variable cleanup;
- lasting global list mutation;
- child-process leak prevention;
- async or deferred work;
- parser state mutation;
- encoded record formats.

This list is deliberately incomplete. Any line that can corrupt package state, leak process state, change user-visible behavior, hide an error, or break an invariant deserves nearby explanation even if it is not named above.

Keep these comments close to the line they explain. If the same reason applies to a tight cluster, state it once before the cluster instead of repeating it line by line.

-----

## 6. Comment Length

Match the structure of the comment to the structure of the code.

- **Block comment** before a tricky region: state purpose, preconditions, postconditions in plain terms. Aligned with what the following lines actually do, not a paraphrase.
- **Statement-level comment** above a single statement: one non-obvious reason or caveat.
- **Inline trailing comment**: tight — one word or short phrase. If a paragraph is needed, promote it to statement level (per `SHELL_STYLE_GUIDE.md §3.3–3.4`).
- **No decorative paragraphs.** A comment that reads like an essay belongs in `docs/`, not in source.

-----

## 7. Audience

Write for a **seasoned developer who is new to this codebase**.

- Assume language fluency. Do not explain `local`, `set -e`, parameter expansion, or arithmetic context.
- Do not assume project fluency. Explain naming conventions on first use, dispatch patterns, what "empty" vs "unset" means in this codebase's helpers, and which functions or variables other packages are expected to call.
- Mentor through precision, not paternalism. The goal is that the reader does not have to ask in chat why something is the way it is.

A useful test: would a competent new hire still need to ask the original author "why is this like this?" If yes, the comment is thin. If the comment only answers a question a beginner would ask after reading a `bash(1)` page, it is the wrong kind of thin.

-----

## 8. Anti–Bit-Rot

A wrong comment is worse than no comment.

- When code behavior changes, the comment changes in the same diff. This is non-negotiable.
- Comment maintenance is a code review concern, not an afterthought. A reviewer who notices stale commentary blocks the merge.
- Prefer one short comment that will be maintained over one long comment that will not.

If a comment cannot be kept truthful through the project's normal rate of change, the comment is too detailed. Move the detail into `docs/` where it can be updated as a coherent unit, and leave a pointer.

-----

## 9. Pre-Merge Check

Before merging, walk the diff and confirm:

1. **Each non-obvious line has a non-obvious reason next to it**, or a pointer to a single block that states it once.
2. **No comment restates syntax** the language already documents. Such comments are deleted, not improved.
3. **Behavior changes carry comment changes.** If `_ble_edit_ind` semantics changed in this diff, every comment that mentions `_ble_edit_ind` was reread and either updated or confirmed still correct.
4. **If a comment were deleted, would safety, performance, or correctness become easier to break?** If no, the comment can go.
5. **Public behavior rules are stated once at their owning site** (file header or docblock) and pointed to from elsewhere — not duplicated and drifted.

-----

## 10. Worked Examples

### 10.1 Buffer mutation

**Without SQL Spirit:**

```bash
function ble::edit::buffer::insert {
  local pos=$1     # the position
  local text=$2    # the text to insert
  # check if position is valid
  if (( pos < 0 || pos > ${#_ble_edit_str} )); then
    return 1
  fi
  # do the insertion
  _ble_edit_str="${_ble_edit_str::pos}$text${_ble_edit_str:pos}"
  # update the cursor
  (( _ble_edit_ind >= pos )) && (( _ble_edit_ind += ${#text} ))
}
```

Every comment restates what the line obviously does. Delete all of them — the function becomes more readable.

**With SQL Spirit:**

```bash
function ble::edit::buffer::insert {
  local pos=$1 text=$2

  # Out-of-range positions are caller errors, not silent no-ops: the dirty-range
  # tracker downstream assumes every successful return has mutated the buffer.
  (( pos < 0 || pos > ${#_ble_edit_str} )) && return 1

  _ble_edit_str="${_ble_edit_str::pos}$text${_ble_edit_str:pos}"

  # Cursor adjustment is a separate decision from buffer mutation: a cursor at
  # exactly `pos` stays put (text inserted *after* the cursor), a cursor past
  # `pos` shifts. This asymmetry matters for yank-pop, which calls insert at
  # the cursor and expects the cursor not to move.
  (( _ble_edit_ind > pos )) && (( _ble_edit_ind += ${#text} ))
}
```

Each comment carries information not present in the code: the dirty-range tracker expectation, and the reason for the `>` instead of `>=`.

### 10.2 Terminal capability

**Without SQL Spirit:**

```bash
# Set up the variable
local cap=${_ble_term_il//'%d'/$n}
```

**With SQL Spirit:**

```bash
# Insert-Line escape: `_ble_term_il` is a printf-style template with `%d` as
# the count placeholder. We do not use printf because some terminals encode
# count as a literal repeat (`\eM\eM\eM`) rather than a parameterized escape,
# and the cached template already accounts for this.
local cap=${_ble_term_il//'%d'/$n}
```

-----

## 11. See Also

- [`DOCUMENTATION-STYLE-GUIDE.md`](./DOCUMENTATION-STYLE-GUIDE.md) — `docs/` prose rules.
- [`SHELL_STYLE_GUIDE.md`](./SHELL_STYLE_GUIDE.md) §3 — comment placement, header boxes, docblock format.
