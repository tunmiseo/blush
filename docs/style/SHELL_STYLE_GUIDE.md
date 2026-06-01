# Unified Shell Style Guide — Bash & Zsh

> **Scope:** Code written under this guide targets **both bash and zsh** as first-class runtimes. We do not fall back to POSIX sh — both shells provide rich built-in facilities and we use them. Where those facilities diverge, we use shell-detection guards, shell-specific helper functions, or compatible idioms that work in both without regressing to sh. The goal is to minimize code bloat while staying idiomatic in each shell.

---

## 0. Orientation: Choosing Your Script Type

Decide before line 1 which kind of script you are writing.

| Kind | Shebang | Implication |
|---|---|---|
| Bash-native script/function | `#!/usr/bin/env bash` | Full bash feature set; no zsh portability tax |
| Zsh-native script/function | `#!/usr/bin/env zsh` | Full zsh feature set; no bash portability tax |
| Dual-compatible script | `#!/usr/bin/env bash` or `#!/usr/bin/env zsh` | Write in the common subset described in this guide; use guards for divergences |
| Zsh autoloaded function | No shebang | `emulate -L zsh` at top; loaded into running shell |

**Never put `#!/bin/bash` or `#!/bin/zsh` as a hardcoded path on a portable script — use `env`.**

**Never use `#!/bin/sh` unless you genuinely intend POSIX sh semantics,** which is outside the scope of this guide.

### Shell Detection

When you need to branch on the running shell:

```sh
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # zsh-specific path
elif [[ -n "${BASH_VERSION:-}" ]]; then
    # bash-specific path
fi
```

Use this sparingly. When facing a bash/zsh divergence, prefer these strategies in order:

1. **A compatible idiom that works in both** — no branching, no bloat. Always the first choice.
2. **A helper function** with shell-specific implementations inside — isolates the divergence, keeps call sites clean.
3. **Inline guards** (`if [[ -n "${ZSH_VERSION:-}" ]]`) — last resort, for one-off cases where a helper would be overkill.

### Runtime Infrastructure

This codebase defines a small set of cross-shell primitives that bridge behavioral gaps between bash and zsh. The most important is the **`print` shim for bash** (§8.1), which duplicates zsh's `print` builtin including `-P`, `-u`, `-l`, and `--`. Code throughout this guide assumes these primitives are loaded. Treat them as runtime infrastructure: they must be available before any library or script code runs, and they should be documented and tested like any other foundational dependency.

---

## 1. Safety Options

### 1.1 Executable Scripts vs Sourced Files

**This guide strictly distinguishes between executable scripts and sourced code.**

**Executable scripts** (run directly, have a shebang) set safety options at the top and may contain top-level executable code.

**Sourced files** (libraries, `.bashrc`/`.zshrc` fragments, plugin files) must never contain unencapsulated code. All code must live inside functions, with one exception: a documented define-then-dispatch entrypoint (`function namespace::entry() { … } && namespace::entry`) is treated as a single atomic construct, not as bare top-level execution (see §20.12). Sourced files must not set global options like `errexit` or `pipefail` — these leak into the sourcing shell and break callers. Option-setting belongs inside functions via `setopt local_options` (zsh) or by saving and restoring state (bash).

Within sourced files, distinguish two further categories:

- **Library modules** must contain only function definitions and constants. No top-level execution, no side effects on load. A library should be safe to source multiple times.
- **Shell startup files** (`.zshrc`, `.bashrc`, plugin loaders) may contain initialization logic, but should still minimize bare code and prefer calling an init function.

```sh
# BAD — sourced library with bare code and global options
set -o errexit
MYVAR="initialized"
do-setup

# GOOD — everything encapsulated in functions
function mylib::init() {
    local val="initialized"
    mylib::__setup
}
```

### 1.2 Dual-Compatible Executable Scripts

```sh
# At the top of every dual-compatible executable script:
set -o errexit          # exit on unhandled nonzero exit status
set -o errtrace         # ERR traps inherited by functions, substitutions, subshells
set -o pipefail         # pipeline exit status = rightmost failing command
set -o nounset          # error on expansion of unset variable
```

`set -o` syntax works identically in both shells.

### 1.3 Bash-Only Executable Scripts

```bash
#!/usr/bin/env bash
set -o errexit
set -o errtrace
set -o pipefail
set -o nounset
```

### 1.4 Zsh-Only Executable Scripts

```zsh
#!/usr/bin/env zsh
emulate zsh
setopt err_exit          # equivalent to set -o errexit
setopt err_return        # propagate error return from functions (zsh's errtrace analog)
setopt pipe_fail         # equivalent to set -o pipefail
setopt no_unset          # equivalent to set -o nounset
setopt warn_create_global
```

`err_return` is zsh's counterpart to bash's `errtrace` — it propagates non-zero return status from functions back to the caller, making error handling in function-heavy code reliable.

### 1.5 Zsh Function-Local Options

Inside zsh functions, use `setopt local_options` so option changes do not leak into global state:

```zsh
function process-files() {
    emulate -L zsh
    setopt local_options extended_glob null_glob
    local f
    for f in **/*.log(N); do
        …
    done
}
```

`emulate -L zsh` restores clean option state local to the function. This is the single most important defensive idiom in zsh. Use it at the top of every zsh-specific function in sourced library code.

### 1.6 Zsh Option Naming Convention

Zsh accepts `EXTENDED_GLOB`, `extended_glob`, and `extendedglob` interchangeably. Convention: **lowercase with underscores** in code (`setopt extended_glob`), **UPPER_CASE** in prose and comments ("requires EXTENDED_GLOB"). Be consistent within a file.

> Note: zsh option names are an exception to the general naming conventions in this guide — they are part of the shell's own API and cannot be changed.

---

## 2. Formatting

### 2.1 Indentation

Indent **4 spaces**. No tabs.

**Exception:** The body of `<<-` tab-indented here-documents uses tabs (required by shell syntax).

Use blank lines between logical blocks to improve readability. Precede every control block (`if`, `for`, `while`, `case`) with one blank line, except when a single helper declaration immediately precedes the control header.

No trailing whitespace on any line. End every file with exactly one newline.

### 2.2 Line Length

Maximum line length is **80 characters**, with allowance up to **110** for single long strings to mitigate truncation.

Literal strings longer than 80 characters should use a here-document or embedded newline when possible.

### 2.3 Pipelines and Continuation Lines

If a pipeline fits on one line, keep it on one line:

```sh
command1 | command2
```

If it does not fit, split at one pipe segment per line. The pipe goes on the new line with a **4-space indent**. Use `\` consistently for line continuation:

```sh
command1 \
    | command2 \
    | command3 \
    | command4
```

This applies equally to logical compounds using `||` and `&&`.

If a pipeline is large and complex, consider moving low-level details into a helper function.

### 2.4 Source Filenames

Lowercase. Use hyphens to separate words if desired.

### 2.5 Multi-Item Lists and Wrapping

In `for` lists, array initializations, and similar multi-item constructs, put each item on its own line with a trailing backslash when the list has **3 or more items** or would exceed the line length limit. Continuation lines indent 4 spaces from the control header. The last item has no trailing backslash:

```sh
for csrc in \
    "${COMPLETIONS}/@bash/${pkg}.completion.sh" \
    "${COMPLETIONS}/@bash/${pkg}.completion.bash" \
    "${COMPLETIONS}/${pkg}.completion.sh" \
    "${COMPLETIONS}/${pkg}.completion.bash"
do
    [[ -f "$csrc" ]] || continue
    found=1
    break
done
```

Short lists (1–2 items) that fit on one line may stay on one line.

### 2.6 Preserve Structural Intent, Not Just Surface Shape

Do not reproduce an existing pattern mechanically. First determine what role the pattern is serving, then propose for discussion what you believe that role is in the new code.

When a structure separates phases, scopes, or responsibilities, keep that separation legible. Do not imitate punctuation while discarding the underlying purpose.

### 2.7 Keep Structural Forms Pure

Do not hybridize braced / logical forms (`{ }`, `&&`, `||`) and keyword forms (`if ... fi`, `while`, `for`, and similar constructs) inside the same structure.

Different block forms may be sequenced, but they should not be collapsed into a single mixed form unless the outer form is genuinely governing the inner one.

The goal is not stylistic purity for its own sake. The goal is to keep the reader's model of the code stable: each form should be used for one idiom and used for that idiom cleanly and consistently.

Discourage unnecessary `{ ... }` blocks when a clearer, lighter form is available. But do not ban them categorically: a braced block is still the right tool when you need to treat a whole block as one unit, such as piping it, gating it with `&&` / `||`, or otherwise operating on it as a block.

The rule is disciplined use, not maximal use. Prefer sequential, idiomatic forms when they are clearer. Use braced blocks when they are the strongest and cleanest expression of the whole operation.

Ugly:

```sh
{
    if [[ -n "$flag" ]]; then
        ...
    fi
} && {
    ...
}
```

Better:

```sh
if [[ -n "$flag" ]]; then
    ...
fi

...
```

Good, when the block itself is the unit:

```sh
{
    ...
    ...
} | some-command
```

Disciplined always. Ugly never.

### 2.8 Prefer the Lightest Clear Structure

Choose the lightest structure that still expresses the code's real semantic boundaries clearly.

Do not use a multi-statement structural idiom for a one-statement job. If a grouped phase contains only trivial work, prefer straight-line code.

But do not compact code merely to reduce line count. Artificial compactification that collapses visual rhythm, statement boundaries, comments, or scanability is not simplification.

The rule is:

- remove unnecessary ceremony
- preserve meaningful vertical structure
- preserve comment density
- prefer the simplest form that remains easy to scan and reason about

"Shorter" only counts when it is also clearer.

Do not fake-minify:

- do not cram unrelated statements onto one line
- do not collapse vertical structure just to reduce line count
- do not shorten names merely to make code look tighter
- do not replace clear forms with clever forms that are only superficially shorter

Prefer actual simplification:

- shorter code that is also clearer
- stronger idioms that remove ceremony without hiding structure
- self-documenting forms that still preserve explicit comments where needed

If applying this rule appears to conflict with `SHELL_STYLE_GUIDE.md`, `PACKAGES.md`, or an established high-value local idiom, do not resolve that tension silently. Flag it explicitly and discuss it before changing the code.

### 2.9 Batch Mutation Safety

Never run a command that can rewrite multiple files unless the exact target set has a recovery point.

This rule applies to:

- `perl -pi`, `sed -i`, and similar in-place text rewrites
- formatter runs over more than one file
- scripted rename loops
- generated replacement of directories or package trees
- recursive cleanup commands

The recovery point must cover the files that can be changed. A git commit, stash, or staged index protects tracked files only. Untracked files require an explicit filesystem backup such as a copied tree, archive, or timestamped snapshot. Repository-root archives must exclude `.git/`, `trash/`, previous backup archives, and other recovery artifacts. Those files are not active mutation targets, and including them makes each backup larger without improving rollback. A dry run is useful but does not replace the backup.

Prefer narrow edits with `apply_patch` for hand changes. Use batch mutation only when the change is mechanical, reviewed, and recoverable.

---

## 3. Comments and Documentation

Documentation and comments should appear where the reader needs them, not only at the top of a file. Use the appropriate layer for the appropriate job:

- **Header comments** for the file-level role, state, and edit hazards
- **Function docblocks** for callable interfaces
- **Statement-level comments** for non-obvious local decisions
- **Inline trailing comments** for brief, tightly-scoped clarifications

When code makes a non-obvious decision, explain that decision near the point where it occurs. Do not force the reader to reconstruct intent from syntax alone, and do not push all explanation into one oversized header.

Prefer observable behavior over architectural narration in file-local comments. Comments in code should describe what the file does, what state it computes or mutates, and what interface it provides. Do not use file-local comments to restate higher-level architectural roles that are already defined elsewhere unless that architecture is needed to understand the behavior immediately.

**Do not inject metacommentary** that merely signals the author's design understanding or replays a private discussion. Comments should help the next reader use and modify the code, not transmit conversation residue. If a comment would make no sense without access to a chat transcript, design meeting, or review thread, it does not belong in the code.

There is no real tradeoff between explicit documentation and self-documenting code. The standard is both:

- write code that is structurally clear on its own
- add comments that make important choices explicit where they occur

### 3.0 Visual Design System

All structured documentation templates share a single visual spine built from box-drawing characters:

- `┃` — heavy vertical spine (left edge, structural gravity)
- `╭━` / `╰━` — rounded corners with heavy horizontal (top/bottom closure)
- `┠─` — spine-to-ribbon junction (section headers)
- `─` — thin horizontal rule (ribbon fill)

The spine is the DNA. Every template uses `┃` as its left edge. This gives the reader a single visual signal: structured documentation starts here, code resumes when the spine ends.

No right-side borders. No dashes. No closing boxes on docblock forms.

**Visual formats.** Two box-drawing formats serve the four documentation layers:

| Format                | Internal Name    | Closure      | Padding | Ribbon Width |
|-----------------------|------------------|--------------|---------|--------------|
| Padded box            | Gallery          | `╭━` / `╰━` | Padded  | Full-width   |
| Spine-only            | Blade            | None         | Minimal | Medium       |
| Spine-only compressed | Ultra-compressed | None         | None    | Short        |

The padded box format is used for file-level header comments. The spine-only format is used for function docblocks at two compression levels: full (Blade) for complex functions, compressed (ultra-compressed) for utility helpers and structured statement-level comments.

**Compression principle.** The three formats form a degenerate series sharing the same spine and field vocabulary. Only padding, ribbon width, and closure change. A function that needs more than ~6 spine lines is a Blade, not an ultra-compressed form. A file header always uses the padded box.

### 3.1 Layer 1 — Header Comment

The header comment is the file-level documentation block. It appears once, near the top of the file, immediately after any shebang (executed scripts) or before any code (sourced files). It uses the padded box format.

**Template:**

```sh
# ╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ┃
# ┃  <Title>
# ┃
# ┠─ Source ─────────────────────────────────────────────────────────────────
# ┃  <filesystem home>
# ┃
# ┠─ On Load ────────────────────────────────────────────────────────────────
# ┃  <variable>  ←  <derivation>        [<tag>]
# ┃  <variable>  ←  <derivation>        [<tag>]
# ┃
# ┠─ Provides ───────────────────────────────────────────────────────────────
# ┃  <function>  —  <one-line description>
# ┃  <function>  —  <one-line description>
# ┃
# ┠─ Requires ───────────────────────────────────────────────────────────────
# ┃  <prerequisite>  —  <why>
# ┃
# ┠─ <File-Specific Field> ─────────────────────────────────────────────────
# ┃  <specific invariant, data format, ownership rule, or edit hazard>
# ┃
# ╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Fields:**

- **Title** (required) — The file's human-readable name. Framed by empty `┃` lines above and below.
- **Source** (required) — Filesystem home of this file relative to `$RING_ROOT`. Where the file lives in the rings module tree, not a runtime path.
- **On Load** (required) — What state changes when this file is sourced. Every exported variable, local variable, or side effect that occurs on load. If the file defines functions but performs no state changes on load (pure library), write: `Defines functions only. No side effects on source.`
- **Provides** (required) — Callable interface: function names and functional aliases with one-line descriptions. Use `—` (em-dash) to separate name from description.
- **Requires** (optional — omit when empty) — Semantic prerequisites that must be satisfied before this file is sourced. Real upstream assumptions: prior modules loaded, variables expected to exist, functions expected to be callable, directory structures expected to be in place. Do not list trivialities. "Requires shell" is not a prerequisite. "Requires `$RING_ROOT` exported by `profile.sh`" is.
- **File-specific field** (optional — omit when empty) — A concrete field chosen for this file's real concern: data format, ownership rule, lifecycle, dispatch rule, timing model, edit hazard, or adjacent-package boundary. The field name is not fixed; choose the name that says what the following lines are about. Do not use generic buckets such as `Translation`, `Contract`, `Notes`, `Details`, or `Implementation`.
- **Description** (optional — expected when the role is not obvious) — A short explanation of the code contained in the file and how it fits the codebase. Omit it when Title, Source, On Load, Provides, and file-specific fields already make the file's role clear.

**Rules:**

- Requires and file-specific fields appear only when they carry information. A simple file may have only Title, Source, On Load, and Provides.
- Fields never appear with empty content. If a field has nothing to say, omit the ribbon entirely.
- The top rule (`╭━`) and bottom rule (`╰━`) span to consistent width within a project. 76 characters is a good default for 80-column files.
- Ribbon rules (`┠─ Name ─────...`) fill to the same width as the top/bottom rules.

**Concrete example:**

```sh
# ╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ┃
# ┃  Package Registry Environment
# ┃
# ┠─ Source ─────────────────────────────────────────────────────────────────
# ┃  env.d/@core/@packages
# ┃
# ┠─ On Load ────────────────────────────────────────────────────────────────
# ┃  PACKAGES_D  ←  ${RING_ROOT}/packages.d        [exported]
# ┃
# ┠─ Provides ───────────────────────────────────────────────────────────────
# ┃  packages::env  —  Re-export PACKAGES_D from current RING_ROOT
# ┃  pkgs::env      —  Functional alias
# ┃
# ┠─ Requires ───────────────────────────────────────────────────────────────
# ┃  $RING_ROOT  —  Exported by profile.sh
# ┃
# ╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3.2 Layer 2 — Function Docblock

The function docblock appears immediately above a function definition. It documents how callers use the function, what state it touches, and what it returns. It uses the spine-only format at either full or compressed weight depending on the function's complexity.

**Template (full — Blade):**

```sh
# ┃
# ┃  <function-name> — <one-line description>
# ┃
# ┠─ Usage ──────────────────────────────────────────
# ┃  <calling signature>
# ┃
# ┠─ Options ────────────────────────────────────────
# ┃  <flag>      <description>
# ┃
# ┠─ Arguments ──────────────────────────────────────
# ┃  <name>      <description>
# ┃
# ┠─ Effects ────────────────────────────────────────
# ┃  <what changed>                      [<tag>]
# ┃
# ┠─ Returns ────────────────────────────────────────
# ┃  <code>  →  <meaning>
```

**Template (ultra-compressed):**

```sh
# ┃  <function-name> — <one-line description>
# ┠──── <Field> ───────────────────────────
# ┃  <content>
# ┠──── <Field> ───────────────────────────
# ┃  <content>
```

**Fields:**

- **Name + description** (required) — Function name and a one-line description separated by `—` (em-dash). In the full form, framed by empty `┃` lines above and below. In the ultra-compressed form, snapped directly to the spine with no padding.
- **Usage** (required in full form, optional in ultra-compressed) — The calling signature. Show the function name with its options and positional arguments in the order they are parsed. Use `[brackets]` for optional elements, `<angles>` for required placeholders.
- **Options** (optional — omit when the function takes no flags) — Flag descriptions. Align descriptions to a consistent column. Short and long forms together when both exist: `-q, --quiet`.
- **Arguments** (optional — omit when there are none) — Positional parameter descriptions. Name and description, aligned.
- **Effects** (optional — omit when the function is pure) — What the function mutates: environment variables, filesystem, terminal state, global shell state. Covers variables exported or mutated, files written or deleted, symlinks created, `.loadlist` edits, runtime state changes.
- **Returns** (optional — omit when 0-on-success is the only behavior) — Exit status codes and their meanings. Stdout/stderr shape when the output behavior is non-obvious or machine-parseable.
- **Additional field** (optional) — At most one author-chosen field for a concern not covered by the standard fields. The field name should be specific to the concern. Add it only when omitting it would leave the function materially underdocumented; do not use it as a generic notes bucket.

Split: **Effects** = what changed in the environment after the function ran. **Returns** = what the caller receives (exit codes, stdout shape).

If the function returns 0 on success and 1 on failure with no special stdout behavior, omit the Returns field entirely — that is the default.

**Rules:**

- No top/bottom box closure. The spine starts and ends; code follows.
- Optional fields are omitted, not present with empty content.
- Full form ribbon width: consistent within a file. 52 characters from `┠` to the end of the rule is a good default.
- Ultra-compressed ribbon width: shorter. 40 characters from `┠` to the end.
- The docblock appears immediately above the `function` keyword. No blank lines between the last `# ┃` line and the function declaration.
- If the function needs more than ~6 spine lines to document, use the full form, not the ultra-compressed form.

**Concrete example (full — Blade):**

```sh
# ┃
# ┃  io::load::file — Source a file with trial validation and feedback
# ┃
# ┠─ Usage ──────────────────────────────────────────
# ┃  io::load::file [-q|--quiet] [-s|--silent]
# ┃      [-v|--verbose] [-f|--force]
# ┃      [-b|--batch]=<dir> [-l|--log]=<path>
# ┃      [-c|--cache]=<path> <file>
# ┃
# ┠─ Options ────────────────────────────────────────
# ┃  -b, --batch    Batch mode; alters display path
# ┃                 formatting relative to <dir>.
# ┃  -c, --cache    Append sourcing command to cache
# ┃                 file for replay.
# ┃  -l, --log      Redirect verbose output to file
# ┃                 instead of terminal.
# ┃  -f, --force    Source even if trial fails.
# ┃  -q, --quiet    Suppress filenames in output.
# ┃  -s, --silent   Suppress all non-error output.
# ┃  -v, --verbose  Show captured stdout/stderr from
# ┃                 the trial source.
# ┃
# ┠─ Arguments ──────────────────────────────────────
# ┃  file   Path to the file to source.
# ┃
# ┠─ Effects ────────────────────────────────────────
# ┃  Sources <file> into the running shell on
# ┃  success (or when --force is set). Appends a
# ┃  replay line to <cache> if --cache is given.
# ┃  Writes verbose output to <log> in batch mode.
# ┃
# ┠─ Returns ────────────────────────────────────────
# ┃  0  →  File sourced successfully.
# ┃  1  →  File missing or no argument given.
# ┃  2  →  Trial failed but --force sourced it.
function io::load::file() {
```

**Concrete example (ultra-compressed, simple function):**

```sh
# ┃  packages::env — Export PACKAGES_D from current RING_ROOT
# ┠──── Effects ───────────────────────────
# ┃  PACKAGES_D  ←  ${RING_ROOT}/packages.d   [exported]
function packages::env() {
    local PACKAGES_D
    PACKAGES_D="${RING_ROOT}/packages.d"
    export PACKAGES_D
} && packages::env

# Functional alias.
function pkgs::env() { packages::env "$@"; }
```

**Concrete example (ultra-compressed, utility helper):**

```sh
# ┃  pkg::__resolve-backend — Map @source prefix to install command
# ┠──── Arguments ─────────────────────────
# ┃  source   @brew, @cask, @asdf, etc.
# ┠──── Returns ───────────────────────────
# ┃  0  →  Backend resolved; name in $REPLY.
# ┃  1  →  Unknown source prefix.
function pkg::__resolve-backend() {
```

### 3.3 Layer 3 — Statement-Level Comment

A statement-level comment is a standalone comment placed immediately before a statement or block, explaining why it exists or what decision it is making.

Most statement-level comments are plain `#` lines. The ultra-compressed spine format is available for multi-line blocks doing something complex enough that the reader needs structured fields (Effects, Returns, Arguments) to understand what is happening and why.

**Plain form.** A single `#` line. No template. Written as clear prose.

```sh
    # Skip rings-internal namespaces — not integration packages.
    [[ "$name" == @(io|core|formatting|inspect) ]] && continue
```

**Structured form (ultra-compressed).** Same spine and field vocabulary as the ultra-compressed function docblock. The title line is an explanatory statement rather than a function name. The spine block appears immediately above the statement(s) it documents with no blank line between.

Use this only for multi-line blocks where plain prose would require the reader to reverse-engineer non-obvious mechanics from syntax alone.

```sh
    # ┃  Trial-source in a nested subshell to capture stdout,
    # ┃  stderr, and exit code separately without applying
    # ┃  the source to the running shell. declare -p passes
    # ┃  variable state across subshell boundaries via eval.
    # ┠──── Effects ───────────────────────────
    # ┃  $stdout      captured output          [local]
    # ┃  $stderr      captured errors           [local]
    # ┃  $exit_code   trial result              [local]
    local stdout="" stderr="" exit_code=0
    eval "$({
        stderr=$({
                stdout=${(z)$(builtin source "$file")};
                exit_code=$?;
            } 2>&1;
            declare -p stdout exit_code >&2
        );
        declare -p stderr;
    } 2>&1)" && {
        stdout="$(tr -s '\n' <<< "$stdout")"
        stderr="${stderr//${file:h}\//}"
        stderr="$(tr -s '\n' <<< "$stderr")"
    }
```

### 3.4 Layer 4 — Inline Trailing Comment

Trailing comments are plain `#` comments at the end of a code line. They do not use the spine system.

**Formatting rules:**

- Always capitalized.
- Syntactic sentences (containing verbs, prepositions, or clauses) use full punctuation: `# Set by --dry-run.`
- Bare labels and single words do not require a period: `# Registry root`
- Be consistent within a file. Do not mix punctuation styles for the same category.
- Two spaces between the end of the code and the `#`.
- Align trailing comments to a consistent column within a local block when multiple lines carry them, but do not force global alignment across a file.

**When to use:**

- Tight, line-local clarification that would be awkward as a standalone statement-level comment.
- Bare scope or purpose labels on variable declarations within a compact declaration block.
- Brief disambiguation when two similar-looking lines do different things.

**When not to use:**

- Narrating what the code does when the code is self-evident.
- Restating the left side of an assignment.
- Any explanation that needs more than ~30 characters — promote to a statement-level comment.

```sh
local -a roots              # Module directories to scan.
local found=0               # Match counter.
local dry=0                 # Set by --dry-run.

PACKAGES_D="${RING_ROOT}/packages.d"  # Registry root

# Functional alias.
function pkgs::env() { packages::env "$@"; }
```

### 3.5 Field Reference

| Field       | Header | Docblock (full) | Docblock (compressed) | Content                                |
|-------------|--------|------------------|-----------------------|----------------------------------------|
| Title       | req    | req              | req                   | Name / description (em-dash separated) |
| Source      | req    | —                | —                     | Filesystem home relative to $RING_ROOT |
| On Load     | req    | —                | —                     | State changes on source                |
| Provides    | req    | —                | —                     | Callable interface                     |
| Requires    | opt    | —                | —                     | Semantic upstream prerequisites        |
| File-specific | opt  | —                | —                     | Concrete package concern               |
| Usage       | —      | req              | opt                   | Calling signature                      |
| Options     | —      | opt              | opt                   | Flag descriptions                      |
| Arguments   | —      | opt              | opt                   | Positional parameter descriptions      |
| Effects     | —      | opt              | opt                   | Environment / filesystem / state       |
| Returns     | —      | opt              | opt                   | Exit codes and stdout shape            |

`req` = required. `opt` = present only when carrying information. `—` = not applicable.

### 3.6 Notation Reference

| Symbol             | Meaning                                   |
|--------------------|-------------------------------------------|
| `←`                | Assignment / derivation                   |
| `→`                | Maps to / results in                      |
| `—`                | Separates name from description (em-dash) |
| `[exported]`       | Variable exported to child processes      |
| `[local]`          | Variable set in current shell only        |
| `[filesystem]`     | File or symlink created or modified       |

Tags are always lowercase. They are subordinate annotations, not headings.

### 3.7 TODO Comments

```sh
# TODO(mrmonkey): Handle the unlikely edge cases (bug ####)
```

TODO followed by the name or identifier of the person with best context. A TODO is not a commitment that the referenced person will fix the problem.

### 3.8 Implementation Comments

Comment tricky, non-obvious, interesting, or important parts of your code. Do not comment everything, but assume nothing. Comment semantic boundaries, invariants, redirection tricks, or shell-specific edge cases. Do not narrate straightforward code line by line.

Extensive documentation and verbose documentation are different things. High comment density is good when comments add information the code does not already carry. Comments that merely restate the code are noise.

For comment **content quality** — the distinction between explaining the codebase (invariants, constraints, reasons) and explaining the language (syntax, control flow, naming) — see [`SQL-SPIRIT-COMMENTS.md`](./SQL-SPIRIT-COMMENTS.md). When the project says "write comments in the SQL spirit," that document is the authority.

When comments or docblocks refer to rings-tree semantics, use the notation that matches the intent:

| Form | Intent |
|---|---|
| `./packages.d/` | A concrete path in the tree |
| `packages.d/` | The directory concretely |
| `packages.d` | The module as a concept |

Do not mix forms within the same comment unless the shift in intent is deliberate.

---

## 4. Functions

### 4.1 Naming

Lower-case. Use `::` to separate library namespaces or `-` to separate words in multi-word names. **Do not use `_` as a word separator in function names.** Hyphens in function names are safe — subtraction in arithmetic contexts is always delimited by spaces, so there is no ambiguity.

Private or utility functions **must** be namespaced. Namespace-level private helpers and inner helpers use `__` on the leaf segment of the qualified name. The stem name after the private marker follows the same naming rules as all other functions — `::` for namespacing, `-` for multi-word:

```sh
make::template              # public, namespaced
make-template               # public, multi-word
io::load::file              # public, deeper namespace
io::err::no-file            # public, multi-word within namespace
io::load::__resolve-path    # private helper, namespaced, multi-word
io::__validate              # private helper, namespaced
```

Do not use bare unprefixed names like `_helper` without a namespace — private functions belong to a package and their names should reflect that.

In package-owned code, `__` privacy follows package scope rather than file scope. See [`PACKAGES.md`](../spec/PACKAGES.md#97-package-internal-helper-files) §9.7 for private-helper scope and [`PACKAGES.md`](../spec/PACKAGES.md#98-package-scoped-composition) §9.8 for package-scoped composition.

### 4.2 Declaration

The `function` keyword is mandatory even when `()` is present, for clarity and to prevent conflicts with alias declarations. The opening brace appears on the same line as the function name:

```sh
function cleanup() {
    …
}
```

### 4.3 Local Variables

Declare function-specific variables with `local`. This avoids polluting the global namespace.

Group `local` declarations in a compact block at the top of the function body. Place a blank line between the declaration block and the first line of logic. Do not intersperse declarations with control flow or other executable statements:

```sh
function process-module() {
    local dir="$1"
    local name config found

    name="${dir##*/}"
    config="${dir}/config"
    …
}
```

**Critical in both shells:** Declaration and assignment must be separate statements when the assignment value comes from a command substitution, because `local` does not propagate the exit code:

```sh
# WRONG — masks exit status
local result="$(cmd)"

# CORRECT
local result
result="$(cmd)"
```

In zsh, `setopt warn_create_global` will warn you when you accidentally create a global inside a function.

### 4.3.1 Prefer Semantic Shadowing Over Unnecessary Renaming

When a local variable is just a local working value of an existing concept, prefer shadowing the canonical name rather than inventing a near-duplicate name.

Introduce a distinct name only when the local value represents a genuinely different role, transformation, or semantic concept.

```sh
local PROFILE_D
PROFILE_D="${PROFILE_D:-"${HOME}/.profile.d"}"
```

Prefer that over:

```sh
local PROFILED
PROFILED="${PROFILE_D:-"${HOME}/.profile.d"}"
```

unless `PROFILED` is intentionally a different concept from `PROFILE_D`.

Why: it reduces naming noise, avoids fake conceptual splits, and makes scope — not spelling — carry the distinction.

### 4.4 Function Location

Organize functions together logically in the file, below corresponding constants. Do not hide executable code between functions.

In executable (non-sourced) scripts, `set` statements and constant definitions may precede function declarations.

### 4.5 Zsh: Autoloading

Zsh supports autoloading: placing each function in its own file (named identically to the function, no extension) in a directory on `$fpath`, then declaring it with `autoload`. The function body is loaded on first call rather than at shell startup.

```zsh
fpath=(~/.zsh/functions $fpath)
autoload -Uz greet
```

The function file contains only the body:

```zsh
# file: ~/.zsh/functions/greet
emulate -L zsh
local name="${1:?greet: name required}"
print -- "Hello, ${name}"
```

`-U` disables alias expansion inside the function. `-z` marks it as zsh-style.

Autoloading is available when appropriate but is not the default style for this codebase. Standard `function name() { … }` declarations are preferred unless there is a specific reason to autoload (large function count, startup performance, or integration with zsh's completion system).

### 4.6 Zsh: Return Values via `$REPLY` / `$reply`

In zsh-only code, avoid command substitution (`$(function)`) for pure shell function returns. Set `$REPLY` for scalar returns, `$reply` (lowercase) for array returns:

```zsh
function get-hostname() {
    emulate -L zsh
    # ... compute result
    REPLY="$computed"
}

get-hostname
print -- "$REPLY"
```

This avoids forking a subshell and is the convention used by zsh's own completion system.

### 4.7 Multi-Value Return Conventions

Two return channels are permitted for returning multiple values from a function:

- caller-local variables: the caller declares `local` variables and the function assigns to them
- structured stdout: the function prints a structured value and the caller captures it with `$( )` or `read`

Use caller-local variables for hot-path helpers where avoiding subshell cost matters. Use structured stdout when composition with pipelines or command substitution is clearer.

Persistent non-local variables are not a return channel.

---

## 5. Control Flow

### 5.1 `if` / `for` / `while`

`; then` and `; do` go on the same line as the keyword. `else` and closing keywords (`fi`, `done`) go on their own lines, vertically aligned with the opening keyword:

```sh
local dir
for dir in "${dirs[@]}"; do
    if [[ -d "${dir}/${SESSION}" ]]; then
        log-date "Cleaning up old files in ${dir}/${SESSION}"
        rm -- "${dir}/${SESSION}/"* || handle-error
    else
        mkdir -p -- "${dir}/${SESSION}" || handle-error
    fi
done
```

Although it is possible to omit `in "$@"` in `for` loops, always include it for clarity:

```sh
for arg in "$@"; do
    print -- "argument: ${arg}"
done
```

### 5.2 `case` Statements

Indent alternatives by 4 spaces. Pattern expressions should not be preceded by an open parenthesis. **Do not use `;&` or `;;&` fall-through operators** — they obscure control flow and are not needed in well-structured case statements.

Multi-command alternatives: pattern, actions, and `;;` on separate lines:

```sh
case "$expression" in
    a)
        val="…"
        some-command "$val" "$other"
        ;;
    absolute)
        action="relative"
        another-command "$action" "$other"
        ;;
    *)
        error "Unexpected expression '${expression}'"
        ;;
esac
```

Single-letter option processing may put pattern and `;;` on one line:

```sh
while getopts 'abf:v' flag; do
    case "$flag" in
        a) aflag='true' ;;
        b) bflag='true' ;;
        f) files="$OPTARG" ;;
        v) verbose='true' ;;
        *) error "Unexpected option ${flag}" ;;
    esac
done
```

### 5.3 Guard Expressions

A single-command guard on one line is acceptable:

```sh
[[ -f "$file" ]] || return 1
[[ -n "$val" ]] && process "$val"
```

Do not compress multiple non-control statements into a single guard line. When the guarded block has more than one command, use the multi-line `if` form:

```sh
# BAD — multiple commands in compressed guard
[[ -f "$file" ]] && { load "$file"; count+=1; }

# GOOD
if [[ -f "$file" ]]; then
    load "$file"
    (( count += 1 ))
fi
```

Choose between a guard and an `if` block by one-pass readability, not by line-count minimization. A one-line guard that requires dense parsing is worse than a short `if` block that cleanly separates condition from action.

---

## 6. Variables

### 6.1 Quoting and Brace-Delimiting

These are mandatory rules. They apply in all new code, in all shells, at all nesting depths, without exception.

#### Quoting

**Quote every variable expansion.** Always `"$var"`, never bare `$var`. This applies universally — including inside `[[ ]]`, in zsh-only code where it is technically unnecessary, and in assignment right-hand sides. One rule, no context-dependent exceptions, no class of mistakes from moving code between contexts.

- **"Double quotes"** indicate that substitution is required or possible.
- **'Single quotes'** indicate that no substitution is desired; use for constant or readonly string literals.

#### Bracing

**Bare `"$var"` — the variable is the entire value.** Nothing else appears between the quotes. Braces on a bare reference add visual noise with no disambiguation value. _Never_ brace bare variables.

**Braced `"...${var}..."` — the variable is interpolated with other text.** The quotes contain the variable plus literal text, path components, other expansions, or punctuation. Braces mark where the variable name ends and the surrounding text begins. Again, bracing a variable that is (1) neither interpolated with other text (bare) nor (2) undergoing parameter expansion/substitution (`${var/old/new}`), is _never_ allowed.

```sh
# Bare — the variable is the whole value between the quotes:
rm -- "$file"
[[ -f "$file" ]] || return 1
local x="$bar"
process "$val"
print -- "$name"
case "$flag" in
done < "$file"
return "$rc"

# Braced — other text appears between the same quotes:
print -- "PATH=${PATH}, PWD=${PWD}, mine=${val}"
config="${base}/config.d/${pkg}"
log="output-${timestamp}.log"
print -- "Processing ${file} in ${dir}"
print -- "${name}.log"
```

```sh
# WRONG — the variable is the whole value, but braces were added anyway:
rm -- "${file}"
[[ -n "${val}" ]] && process "${val}"
print -- "${name}"

# RIGHT — bare, because the variable is the whole value:
rm -- "$file"
[[ -n "$val" ]] && process "$val"
print -- "$name"
```

**Always brace regardless of context:**

- Parameter expansion operators: `${var:-default}`, `${var##*/}`, `${#var}`, `${var/old/new}`, `${(U)var}`, `${var:t}`, etc.
- Array expansions: `"${array[@]}"`, `"${(@f)content}"`.
- Multi-digit positional parameters: `${10}`, `${11}`, ...
- Any case where omitting braces would cause the shell to parse the wrong variable name (adjacent letters, underscores, or digits).

**Single-character specials and single-digit positionals** (`$1`, `$?`, `$#`, `$$`, `$!`, `$-`, `$*`, `$@`) do not require braces when bare. The shell cannot misparse them. Brace them when they share a value with other text.

> **NOTE:** Braces in `${var}` are not a form of quoting. Double quotes must still be used. `${var}` without quotes is still an unquoted expansion.

#### Recursive application

Bracing and quoting rules apply at every interpolation depth. If a variable is interpolated into a larger fragment, it must be brace-delimited, with the containing fragment quoted at the depth where that fragment is evaluated. If that fragment is itself nested inside another expansion, the same rule still applies there.

Do not treat an inner expansion as exempt merely because the outer expression is already quoted. Do not treat a deeply nested context as exempt because the surrounding syntax looks complex enough to "obviously" be safe.

This rule is unconditional. It does not degrade with nesting depth, code complexity, or author confidence.

**Array expansion:** Always use `"${array[@]}"`, even in zsh-only code where bare `$array` is safe. Same rationale: one rule, no surprises.

**`SH_WORD_SPLIT`:** Do not set it in new code. It exists for sh/bash compatibility. If you find yourself wanting it, you have an array problem, not a quoting problem.

### 6.2 Variable Names

Lower-case. Prefer short single-word names: `path`, `file`, `count`, `result`, `config`, `dir`. When a compound name is unavoidable, consider an alternative without a separator, or fallback to underscore. As a documented last resort when an alternative is genuinely less unreadable without separation, use an underscore.

Loop variables should be named for what they iterate over:

```sh
for zone in "${zones[@]}"; do
    something-with "$zone"
done
```

### 6.3 Constants, Environment Variables, and `readonly`

Constants and anything exported to the environment should be **CAPITALIZED**, declared at the top of the file (executables) or function (sourced files). Use `readonly` to enforce read-only (works in both shells).

It is acceptable to set a constant at runtime or in a conditional (e.g., via `getopts` / `zparseopts`), but make it `readonly` immediately afterward.

Note: `declare` does not operate on global variables within functions in bash. Use `readonly` or `export` instead. In zsh-only code, `typeset -r` is also available at global scope.

If a value is being treated as a constant within its scope, name it as a constant — CAPITALIZED. This applies even when the constant is local to a function or fragment. Semantic role governs naming more than storage duration.

### 6.4 Declaration Keywords

**In function bodies (all code):** Use `local` exclusively. It works identically in both shells and is the universal standard for this guide.

**Choose declaration syntax by semantics.** Use `export` when it is cleanly equivalent in context. Use `typeset` when the code is already expressing declaration attributes and keeping the idiom coherent matters. Do not introduce shell-conditional branching between superficially similar declaration forms unless there is an actual semantic difference that must be represented.

**Outside function bodies, zsh-only code:** Use `typeset` (or its short-form aliases `integer`, `float`) rather than `declare`:

```zsh
typeset -i count=0
typeset -r PI=3.14159
typeset -a items
typeset -A map
```

**Outside function bodies, bash-only code:** Use `declare`:

```bash
declare -i count=0
declare -r PI=3.14159
declare -a items
declare -A map
```

**Outside function bodies, dual-compatible code:** Use `readonly` for constants. For global typed declarations where `local` is inappropriate, prefer a guard or just use `readonly` for constants.

### 6.5 Zsh: Associative Arrays

```zsh
function foo() {
    local -A config
    config=(
        host  localhost
        port  5432
        name  mydb
    )

    print -- "${config[host]}"
    local key val
    for key val in "${(kv)config[@]}"; do
        print -- "${key} => ${val}"
    done
}

```

In zsh, `${(kv)config[@]}` iterates keys and values together.

In bash, associative arrays use `declare -A` and the same bracket syntax for access (`"${config[host]}"`), but iteration differs:

```bash
declare -A config=([host]=localhost [port]=5432 [name]=mydb)

for key in "${!config[@]}"; do
    print -- "${key} => ${config[$key]}"
done
```

---

## 7. Variable Expansion

### 7.1 Command Substitution

Use `$(command)` — never backticks. Quote the result when appropriate (see §6.1).

```sh
flag="$(some-command and its args "$@" 'quoted separately')"
```

### 7.2 Zsh: Parameter Expansion Flags

In zsh-only code, every `$(echo "$x" | tr ...)` or `$(basename "$x")` spawns a subshell. Zsh's `${(flags)param}` system eliminates most of these:

```zsh
# Case manipulation — no fork
print -- "${(U)word}"       # uppercase
print -- "${(L)word}"       # lowercase
print -- "${(C)word}"       # capitalize first letter of each word

# Splitting on a delimiter — no fork
line="a:b:c"
parts=("${(@s|:|)line}")

# Joining
print -- "${(j|,|)parts}"

# Path components — no fork
filepath=/usr/local/bin/zsh
print -- "${filepath:t}"    # tail (basename): zsh
print -- "${filepath:h}"    # head (dirname):  /usr/local/bin
print -- "${filepath:e}"    # extension
print -- "${filepath:r}"    # root (strip extension)
```

### 7.3 Bash: Parameter Expansion

Bash supports `${var^^}` (uppercase), `${var,,}` (lowercase), and the standard `${var#pattern}`, `${var%pattern}`, `${var/pattern/replacement}` family — prefer these over forking `tr`, `sed`, or `cut`.

### 7.4 Path Component Builtins (Both Shells)

Both bash and zsh support:

```sh
filepath=/usr/local/bin/zsh
print -- "${filepath##*/}"      # basename equivalent: zsh
print -- "${filepath%/*}"       # dirname equivalent:  /usr/local/bin
```

In zsh-only code, `${filepath:t}` and `${filepath:h}` are more legible and preferred.

---

## 8. Printing and Output

### 8.1 `print` vs `printf`: Complementary Tools

This codebase provides a **`print` shim for bash** that duplicates zsh's `print` builtin, including `-P` (prompt expansion), `-u` (file descriptor targeting), `-l` (one item per line), `-z` (editor buffer), and `--` (end of options). This means `print` — with its full syntax — is available in both shells.

The distinction between `print` and `printf` is not about shell compatibility. It is about *what kind of output you are producing*:

- **`print`** (and `print -P`): Rich formatted output to the terminal. Use for user-facing messages, colorized status output, diagnostic messages, and interactive feedback.
- **`printf`**: Definitively certain plaintext. Use for machine-parseable output, output piped to files or other commands, and any context where format-string precision matters and decorative formatting does not.

```sh
# Terminal status message — use print
print -P "%F{green}✓%f Build succeeded in ${elapsed}s"

# Data written to a log file — use printf
printf '%s\t%s\t%d\n' "$timestamp" "$event" "$count" >> "$logfile"

# Error message to stderr — use print
print -u2 -- "error: config file not found: ${config}"
```

### 8.2 Colorized Output

Use `print -P` with prompt `%F{}` / `%f` expansion for colorized terminal output. This works in both shells (via the shim in bash). Colors serve as semantic registers:

| Color | Meaning |
|---|---|
| Green | Success |
| Red | Failure |
| Yellow | Errors and warnings |
| White | Key items |
| Teal | Console / system messages |
| Cyan | Alternate key items |

```sh
print -P "%F{green}✓%f Deployment complete"
print -P "%F{red}✗%f %F{yellow}Warning:%f ${message}"
```

Apply color to the message components that carry semantic weight, not only to a leading sigil. Color is part of the information architecture of user-facing output, not decoration applied afterward.

### 8.3 `echo` Is Banned

Do not use `echo` in scripts. Use `print` for terminal output and `printf` for plaintext. `echo -e` is not portable even across bash versions.

### 8.4 Multi-Line Output

Use here-documents with `cat` for multi-line plaintext output:

```sh
cat <<EOF
Usage: ${0##*/} [options] <file>

Options:
    -v    Verbose output
    -h    Show this help
EOF
```

### 8.5 Error Messages to stderr

Always send error messages to stderr:

```sh
print -u2 -- "error: something went wrong"
```

### 8.6 Message Style

Start user-facing status messages with a capital letter and a clear verb that communicates the action: "Create: …", "Activate: …", "Disable: …", "Remove: …", "Pause: …". Prefix dry-run output with `(Dry-run)` so the user can distinguish simulated from real operations:

```sh
print -- "Create: ${module}"
print -- "(Dry-run) Remove: ${file}"
```

### 8.7 End-of-Options: `--`

Use `--` before any argument to `print`, `rm`, `cp`, `mv`, `mkdir`, or other commands when that argument is a variable whose content you cannot predict. This prevents values beginning with `-` from being interpreted as flags.

```sh
# WRONG — if $name starts with -, print interprets it as a flag
print "$name"

# CORRECT
print -- "$name"

# Same principle for destructive commands
rm -- "$file"
mkdir -p -- "$dir"
```

Skip `--` only when the argument is a known literal that cannot start with `-`, or when the command does not accept `--` (rare).

For `print -P`, `print -u2`, and other flag-bearing invocations, `--` goes after all flags:

```sh
print -u2 -- "error: ${message}"
```

---

## 9. Tests and Conditionals

### 9.1 Always `[[ ]]`, Never `[ ]` or `test`

`[[ ]]` is preferred in both bash and zsh. It does not fork, handles empty expansions safely, and supports pattern matching and regex.

```sh
[[ "$filename" =~ ^[[:alnum:]]+name ]]
```

### 9.2 Testing Strings

Use `-z` (string length is zero) and `-n` (string length is not zero) explicitly. Use `==` for equality (not `=`, which can be confused with assignment):

```sh
if [[ -z "$val" ]]; then
    do-something
fi

if [[ "$val" == "target" ]]; then
    do-something
fi
```

Do not use filler characters (`"${val}X" == "targetX"`).

### 9.3 Pattern Matching in `[[ ]]`

Prefer glob matching when the pattern is simple enough:

```sh
[[ "$file" == *.log ]]        # glob — preferred when sufficient
```

Use regex only when the pattern genuinely requires it (anchoring, character classes, alternation). When using regex, **store complex patterns in a variable** to avoid quoting errors:

```sh
local re='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
[[ "$date" =~ $re ]]
```

Do not quote the regex operand inside `[[ =~ ]]` — in bash, quoting it converts the regex into a literal string match. In zsh, the behavior differs. Storing the pattern in a variable sidesteps this divergence entirely and is the recommended practice for all non-trivial regex.

In zsh, regex match groups go into `$match` array (1-indexed). In bash, they go into `$BASH_REMATCH` (0-indexed).

### 9.4 Arithmetic: Always `(( ))`

```sh
(( count > 0 ))
(( count + 1 == 5 ))
(( total = count * factor ))
```

Never use `[ "$x" -gt 0 ]`, `let`, `$[ ... ]`, or `expr`.

Do not use `<` or `>` inside `[[ ]]` for numeric comparisons — they perform lexicographical comparison.

**Caution with `(( ))` and `errexit`:** `(( count++ ))` returns exit status 1 when `count` is 0 pre-increment, because the expression evaluates to 0 (falsy). Under `errexit` this terminates the script. **Strongly prefer `(( count += 1 ))` over `(( count++ ))`** — the `+=` form is always safe because the result is always nonzero when incrementing from zero or above. If you do use `++` or `--`, be aware of this interaction and guard with `|| true` where necessary. Be consistent: pick one increment style per file.

---

## 10. Arrays

### 10.1 Use Real Arrays

Arrays store ordered collections of strings and can be safely expanded into individual elements. Do not use a single string for multiple command arguments:

```sh
# WRONG — relies on word splitting, breaks on spaces in values
flags='--foo --bar=baz'
mybinary ${flags}

# CORRECT
local -a flags
flags=(--foo --bar='baz')
flags+=(--greeting="Hello ${name}")
mybinary "${flags[@]}"
```

### 10.2 Array Indexing

**This is a critical divergence.** Bash arrays are 0-indexed; zsh arrays are 1-indexed by default.

In dual-compatible code, be highly aware of this and choose the best approach for the situation:

- **Iterate instead of indexing** when you do not actually need the index value — `for item in "${array[@]}"` works identically in both shells and sidesteps the problem entirely. Often the numeric index is irrelevant to the loop's purpose.
- **Use a shell-detection guard** when you genuinely need the first (or Nth) element:

```sh
if [[ -n "${ZSH_VERSION:-}" ]]; then
    first="${array[1]}"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    first="${array[0]}"
fi
```

- **Write a helper function** (e.g., `array::__first`) if the same indexed access pattern recurs very frequently in a codebase.
- **Restructure the algorithm** to avoid relying on specific index values — sometimes `shift`, associative arrays, or `$1`-style positional parameters are cleaner than array subscripting.

**Do not set `KSH_ARRAYS` in zsh** to change indexing — it causes more problems than it solves.

### 10.3 Array Expansion

In zsh, unquoted `$array` does not word-split — it expands to the elements as separate words. This is correct zsh behavior. However, **this guide mandates `"${array[@]}"` universally** — including in zsh-only code — for one consistent habit (see §6.1).

### 10.4 `"$@"` vs `"$*"`

Use `"$@"` unless you have a specific reason to use `$*`. `"$@"` retains arguments as-is. `"$*"` joins all arguments into a single string.

---

## 11. Globbing

### 11.1 Wildcard Expansion Safety

Use an explicit path when doing wildcard expansion of filenames. Filenames can begin with `-`:

```sh
# Safe:
./*

# Unsafe:
*
```

### 11.2 Zsh: Extended Globbing

In zsh-only code, `setopt extended_glob` unlocks powerful patterns:

```zsh
print -- ^*.txt              # everything NOT matching *.txt
print -- file<1-99>.txt      # numeric ranges
```

### 11.3 Zsh: `NULL_GLOB` and `(N)` Qualifier

By default in zsh, a glob with no matches is an error. Use `(N)` per-glob qualifier (preferred in functions) or `setopt null_glob`:

```zsh
for f in *.log(N); do
    process "$f"
done
```

### 11.4 Zsh: Glob Qualifiers Replace `find`

```zsh
print -- *(.)              # regular files only
print -- *(/)              # directories only
print -- **/*.py(.)        # recursive, regular files only
print -- **/*.log(N.m-1)   # .log files modified in last day, nullglob
print -- *(om)             # sort by modification time, newest first
print -- *(Lk+100)         # files larger than 100 KB
```

This replaces `find . -name "*.py" -type f` and similar — without forking.

### 11.5 Zsh: `zmv` for Bulk Renames

```zsh
autoload -Uz zmv
zmv -n '(*).txt' '$1.md'          # dry run
zmv '(*).txt' '$1.md'             # rename all .txt to .md
```

---

## 12. Pipelines, Loops, and Process Substitution

### 12.1 Pipes to `while`

Pipes create a subshell, so variables modified within a pipeline do not propagate to the parent shell **(in bash)**. Zsh runs the last element of a pipeline in the current shell by default, but for dual-compatible code, use process substitution:

```sh
local last='NULL'
while read -r line; do
    if [[ -n "$line" ]]; then
        last="$line"
    fi
done < <(your-command)

print -- "$last"
```

### 12.2 Bash: `readarray`

In bash 4+ only:

```bash
readarray -t lines < <(your-command)
for line in "${lines[@]}"; do
    …
done
```

### 12.3 Process Substitution

Both shells support `< <(cmd)` for feeding output into a loop without a subshell:

```sh
diff <(sort file1) <(sort file2)
```

### 12.4 Zsh: Multios

Zsh can write to multiple files and read from multiple sources without `tee`:

```zsh
print -- "log entry" > file1 > file2
cat < file1 < file2
```

Multios are enabled by default (`MULTIOS` option). Do not use in dual-compatible code.

### 12.5 Here-Strings

Both shells support here-strings. Prefer them over piping from `print`:

```sh
# Avoid — creates a pipeline:
print -- "input" | command

# Prefer:
command <<< "input"
command <<< "$val"
```

### 12.6 Line Input Discipline

When reading line-oriented input, use the most robust primitive available for the shell while preserving a shared baseline.

**Cross-shell baseline:** Always use `read -r` unless you intentionally need backslash-escape interpretation. Scope `IFS=` to the `read` command when preserving leading and trailing whitespace matters. Do not globally mutate `IFS`.

```sh
while IFS= read -r line; do
    process "$line"
done < "$file"
```

**Bash:** For full-file ingestion, `mapfile` (also called `readarray`) avoids subshell loops, preserves line boundaries, and is faster for large files:

```bash
mapfile -t lines < "$file"
for line in "${lines[@]}"; do
    process "$line"
done
```

**Zsh:** Zsh offers native ingestion via parameter expansion flags:

```zsh
lines=("${(@f)$(<$file)}")
for line in "${lines[@]}"; do
    process "$line"
done
```

`(@f)` splits on newlines and preserves empty elements. `$(<file)` reads the file without forking `cat`.

Use the common `while read` idiom first, but prefer shell-native primitives when the codebase already branches on shell. Do not artificially downgrade shell capabilities.

### 12.7 Subshell Awareness

Several common constructs silently create subshells, which means variable assignments inside them do not propagate to the parent:

- **Pipelines:** `cmd | while read …` runs the `while` in a subshell in bash (not in zsh by default, but do not rely on this in dual-compatible code).
- **Command substitution:** `$(cmd)` always forks a subshell.
- **Explicit subshells:** `( cmd )` always forks.

When you need variable state to survive, use process substitution (§12.1), `mapfile` (§12.2), or zsh parameter expansion (§12.6) instead of piping into a loop.

```sh
# BAD — count is lost after the pipeline
local count=0
find . -name "*.log" | while read -r f; do
    (( count += 1 ))
done
print -- "$count"  # always 0 in bash

# GOOD — process substitution keeps the loop in the current shell
local count=0
while read -r f; do
    (( count += 1 ))
done < <(find . -name "*.log")
print -- "$count"  # correct
```

---

## 13. `PIPESTATUS` / `pipestatus`

Bash uses `$PIPESTATUS` (uppercase, 0-indexed). Zsh uses `$pipestatus` (lowercase, 1-indexed). Both are volatile — overwritten by the next command.

```sh
tar -cf - ./* | ( cd "$dir" && tar -xf - )
if [[ -n "${BASH_VERSION:-}" ]]; then
    (( PIPESTATUS[0] != 0 || PIPESTATUS[1] != 0 )) && print -u2 "tar failed"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    (( pipestatus[1] != 0 || pipestatus[2] != 0 )) && print -u2 "tar failed"
fi
```

If you need to act on individual exit codes, assign the array to a local variable immediately after the pipeline.

---

## 14. Arithmetic

Always use `(( … ))` or `$(( … ))`. Never use `let`, `$[ … ]`, or `expr`.

```sh
local -i hundred="$(( 10 * 10 ))"
(( i += 3 ))
(( i -= 5 ))
```

Within `$(( … ))`, the `${var}` form is not required — the shell looks up `var` for you. This is a recommendation-only exception to the general brace-delimiting rule.

Declare variables as integers when possible (`local -i` in both shells; `integer` in zsh-only code).

---

## 15. Aliases

Avoid aliases in scripts. Use functions instead. Aliases require careful quoting and escaping, and mistakes are hard to notice.

```sh
# BAD — $RANDOM evaluated once at alias definition time
alias badname="echo prefix_${RANDOM}"

# GOOD
function random-name() {
    print -- "prefix_${RANDOM}"
}
```

Functions provide a superset of alias functionality and should always be preferred in scripts. For convenience entry points in library code, see functional aliases (§20.8).

---

## 16. Builtin Commands vs. External Commands

Prefer shell builtins over forking external processes. Both bash and zsh provide parameter expansion, arithmetic, and pattern matching that replace most uses of `sed`, `awk`, `tr`, `expr`, `basename`, `dirname`, `wc`, and `grep` for simple operations.

```sh
# Prefer:
addition="$(( X + Y ))"
substitution="${string/#foo/bar}"

# Over:
addition="$(expr "$X" + "$Y")"           # BAD: forks expr
substitution="$(echo "$string" | sed -e 's/^foo/bar/')"  # BAD: forks echo + sed
```

### Zsh: Additional Builtins and Modules

In zsh-only code, parameter expansion flags (§7.2) and glob qualifiers (§11.4) replace even more external commands. Additionally, `zsh/datetime`, `zsh/stat`, and `zsh/system` modules replace `date`, `stat`, and file-locking utilities:

```zsh
zmodload zsh/datetime
print -- "$EPOCHSECONDS"

zmodload zsh/stat
local -A fstat
zstat -H fstat -- "$file"
print -- "${fstat[size]}"
```

### When External Tools Are Appropriate

Do not contort shell code to avoid a clear external tool. When the task involves complex text transformation, columnar data processing, or sorting, `awk`, `sed`, and `sort` may be cleaner and faster than an elaborate chain of parameter expansions. The rule is: prefer builtins for simple operations; prefer the right tool for complex ones.

### Sourcing: `.` vs `source`

In dual-compatible code, use `.` (dot) rather than `source` for sourcing files. Both bash and zsh accept both forms, but their behavior differs: in zsh, `.` searches only `$PATH` (POSIX behavior), while `source` searches the current directory first. This inconsistency is a real bug source. Using `.` with an explicit path eliminates ambiguity:

```sh
# CORRECT — explicit path, consistent behavior
. "${dir}/lib.sh"
builtin . "${dir}/lib.sh"    # even safer in library code

# AVOID — behavior differs between shells
source lib.sh
```

In library internals where you want to guarantee the shell builtin and prevent a function or alias named `.` from intercepting the call, use `builtin .`.

### Command Resolution: `builtin` and `command`

When correctness depends on which command actually runs, control lookup explicitly:

- **`builtin cmd`** — guarantees the shell builtin, bypassing any function or alias with the same name. Use for `.`, `cd`, `printf`, and other builtins where a wrapper function might shadow the real thing.
- **`command cmd`** — bypasses functions and aliases, falling through to builtins and then external commands on `$PATH`. Use when you need the real `ls`, `grep`, or other external utility that might be aliased or wrapped.

```sh
# Ensure we get the real cd, not a wrapper
builtin cd -- "$dir"

# Ensure we get the external grep, not a function
command grep -r "pattern" .
```

---

## 17. Checking Return Values

Always check return values and give informative messages.

```sh
if ! mv -- "${files[@]}" "${dest}/"; then
    print -u2 -- "Unable to move ${files[*]} to ${dest}"
    exit 1
fi
```

Or:

```sh
mv -- "${files[@]}" "${dest}/"
if (( $? != 0 )); then
    print -u2 -- "Unable to move ${files[*]} to ${dest}"
    exit 1
fi
```

---

## 18. Trap Hygiene

### 18.1 Use `trap ... EXIT` for Cleanup

`EXIT` fires on normal exit, error exit, and most signals. This makes it the right choice for cleanup logic.

Do not rely on `ERR` or `INT` traps alone for cleanup — they miss normal exits and each other's signals respectively.

Prefer calling a **function** from traps rather than embedding complex shell fragments in the trap string. Trap strings are expanded at definition time and become fragile when quoting grows complex:

```sh
# FRAGILE — quoting breaks with special characters in paths
trap "rm -f -- '${tmp}'" EXIT

# ROBUST — function-based trap
function build::__cleanup() {
    rm -f -- "$tmp"
}
trap build::__cleanup EXIT
```

For simple single-command traps the string form is acceptable, but default to the function form for anything nontrivial.

### 18.2 Temporary File Discipline

Create temporary paths safely using `mktemp`. Never construct temporary paths manually:

```sh
# BAD — predictable, racy, insecure
tmpfile="/tmp/myapp.$$"

# GOOD
local tmp
tmp="$(mktemp)"
trap "rm -f -- '${tmp}'" EXIT

# For directories:
local tmpdir
tmpdir="$(mktemp -d)"
trap "rm -rf -- '${tmpdir}'" EXIT
```

Capture the temp path immediately and register a cleanup trap in the same block.

### 18.3 Traps in Sourced Code

In sourced library code, do not set traps at file scope — this is unencapsulated code (§1.1) and would clobber the caller's traps. Traps belong inside the functions that need them.

In zsh, `emulate -L zsh` combined with `setopt local_options` does not automatically localize traps. Be explicit about restoring prior trap state if the caller might have its own traps:

```zsh
function io::with-tempfile() {
    emulate -L zsh
    local tmp
    tmp="$(mktemp)"
    trap "rm -f -- '${tmp}'" EXIT

    "$@"
    local rc=$?

    rm -f -- "$tmp"
    trap - EXIT
    return "$rc"
}
```

### 18.4 `errtrace` / `err_return` Completes the Story

§1.2–1.4 mandate `errtrace` (bash) and `err_return` (zsh), which propagate ERR traps into functions and subshells. Without these options, a trap set in the main script would not fire when an error occurs inside a function — making error-handling traps unreliable.

Do not assume `errtrace` and `err_return` are semantically identical — they achieve similar goals through different mechanisms. `errtrace` makes bash inherit `ERR` traps into functions and subshells. `err_return` makes zsh propagate non-zero return status from functions to callers. Test error-handling behavior in both shells when writing dual-compatible code.

---

## 19. Option Parsing

### 19.1 Dual-Compatible: `getopts`

`getopts` is available in both bash and zsh and handles single-character options. Use it in dual-compatible code:

```sh
function greet() {
    local loud='false'
    local name='World'
    local OPTIND OPTARG flag

    while getopts 'ln:' flag; do
        case "$flag" in
            l) loud='true' ;;
            n) name="$OPTARG" ;;
            *) return 1 ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    if [[ "$loud" == 'true' ]]; then
        print -- "HELLO, ${name}!"
    else
        print -- "Hello, ${name}."
    fi
}
```

`getopts` does not support long options (`--verbose`). For dual-compatible long option parsing, use a manual `while`/`case` loop:

```sh
function build() {
    local verbose='false'
    local target=''

    while (( $# > 0 )); do
        case "$1" in
            -v|--verbose) verbose='true' ;;
            -t|--target) target="$2"; shift ;;
            --) shift; break ;;
            -*) print -u2 -- "Unknown option: $1"; return 1 ;;
            *) break ;;
        esac
        shift
    done

    # Remaining positional args are in "$@"
}
```

### 19.2 Zsh-Only: `zparseopts`

In zsh-specific functions, `zparseopts` provides concise long-option parsing with array-based flag detection:

```zsh
function io::load::file() {
    emulate -L zsh
    local QUIET VERBOSE FORCE
    local file

    zparseopts -D -E -K -- \
        {q,-quiet}=QUIET \
        {v,-verbose}=VERBOSE \
        {f,-force}=FORCE || return

    file="$1"
    [[ -n "$file" ]] || return 1

    (( ${#QUIET} )) || print -- "Loading ${file}"
    builtin . "$file"
}
```

`-D` removes parsed options from `$@`. `-E` allows interspersed options and arguments. `-K` preserves prior values of destination arrays (useful for defaults). The idiom `(( ${#FLAG} ))` tests whether the flag array is non-empty — this works because `zparseopts` populates the array only when the flag is present.

---

## 20. Library-Grade Conventions for Sourced Code

The following conventions apply especially to sourced shell code, loader internals, and other reusable modules. The governing principle: sourced code is an interactive runtime library, not disposable glue. Write it for future inspection — the reader should be able to re-enter the file months later and recover the architecture quickly.

### 20.1 Public Functions Must Carry Structured Docblocks

Functions that are user-facing, reused across modules, or nontrivial in behavior must be preceded by a structured docblock (§3.2). The reader should be able to recover the usage, arguments, options, side effects, and return behavior without reconstructing the implementation.

Use the full Blade form for complex functions. Use the ultra-compressed form for simple helpers. At minimum, document what the function does, how it is called, what arguments and options it accepts, and what it returns. When behavior differs in interactive versus non-interactive use, say so explicitly.

Document the public behavior. Do not restate obvious implementation details line by line.

### 20.2 Namespace Depth Should Reflect Conceptual Structure

Namespacing (§4.1) is not only for collision avoidance — it is a map of the design. A shallow namespace is appropriate for a single conceptual verb. A deeper namespace is appropriate when there is a real subsystem with internal operations.

Use deeper namespaces when they clarify ownership and layering. Do not flatten conceptually distinct operations into one crowded top-level namespace.

```sh
function io::err() {
    print -u2 -- "$*"
}

function io::err::no-file() {
    local name="$1"
    [[ -n "$name" ]] || return 1
    io::err "No such file: $name"
    return 1
}

function io::load::file() {
    local file="$1"
    [[ -f "$file" ]] || {
        io::err::no-file "$file"
        return 1
    }
    builtin . "$file"
}
```

If a function naturally reads as "operation within subsystem within module," encode that structure directly in its name.

### 20.3 Prefer Local Helper Functions for Single-Use Logic

When a helper is used only inside one function, define it locally inside that function rather than promoting it to global module scope. This keeps implementation details physically near the code that depends on them.

**Caveat:** In both bash and zsh, inner function definitions are still globally visible — this convention is about physical locality and readability, not lexical scoping.

```zsh
function io::load::label() {
    emulate -L zsh
    local path="$1"

    function io::load::__ext() {
        [[ "$1" == *.* ]] && print -- ".${1##*.}"
    }

    function io::load::__root() {
        local name="${1:t}"
        print -- "${name:r}"
    }

    print -- "$(io::load::__root "$path")$(io::load::__ext "$path")"
}
```

Do not promote a helper merely because it exists. Promote it when it is reused, part of the external module vocabulary, or important enough to deserve standalone testing and documentation.

### 20.4 Function Bodies Should Follow a Predictable Internal Order

Nontrivial functions should be organized in four phases:

1. **Parse options** — `zparseopts` (zsh), `getopts` (dual-compatible), or manual flag parsing.
2. **Normalize inputs and internal state** — canonicalize paths, validate arguments, set defaults.
3. **Define local helpers** needed only by this function.
4. **Execute main logic.**

This makes functions easier to scan and audit. The reader learns where to look for each concern.

```zsh
function io::load::demo() {
    emulate -L zsh

    # Phase 1: Parse options
    local QUIET VERBOSE
    local path

    zparseopts -D -E -K -- \
        {q,-quiet}=QUIET \
        {v,-verbose}=VERBOSE || return

    # Phase 2: Normalize inputs
    path="${1:a}"
    [[ -n "$path" ]] || return 1

    # Phase 3: Local helpers
    function io::load::__display-path() {
        local val="$1"
        val="${val/#$HOME/~}"
        print -- "$val"
    }

    # Phase 4: Main logic
    if [[ -f "$path" ]]; then
        (( ${#QUIET} )) || print -- "Loading $(io::load::__display-path "$path")"
        builtin . "$path"
        (( ${#VERBOSE} )) && print -- "Loaded successfully."
    else
        io::err "No such file: ${path}"
        return 1
    fi
}
```

This is not a rigid law for tiny functions, but it should be the default pattern for real module code.

### 20.5 Separate Status Output, Diagnostic Output, and Logs

Commands should distinguish between at least three output planes:

1. **Interactive status output:** Concise, human-facing progress or result indicators. Sent to stdout; may include terminal decoration.
2. **Diagnostic output:** Warnings and errors intended for stderr.
3. **Verbose or transcript output:** Captured details useful for debugging or later inspection. May go to a log file or only appear with `--verbose`.

Do not mix these casually. A clean command can be quiet in routine operation, precise in failure, and rich in verbose mode without conflating those responsibilities.

```zsh
function io::load::report() {
    emulate -L zsh
    local QUIET SILENT VERBOSE
    local log file

    zparseopts -D -E -K -- \
        {q,-quiet}=QUIET \
        {s,-silent}=SILENT \
        {v,-verbose}=VERBOSE \
        {l,-log}:=log || return

    file="$1"
    [[ -n "$file" ]] || return 1
    [[ -n "$log" ]] && log="${log[2]#=}"

    if [[ -f "$file" ]]; then
        (( ${#SILENT} )) || {
            (( ${#QUIET} )) || print -- "✓ ${file:t}"
        }

        (( ${#VERBOSE} )) && [[ -n "$log" ]] && {
            printf '%s\n' "Loaded: ${file}" >> "$log"
        }

        return 0
    fi

    (( ${#SILENT} )) || io::err "✗ ${file:t}"
    return 1
}
```

Verbosity should increase observability, not change basic semantics.

### 20.6 Use Canonical Paths Internally, Prettified Paths for Display

Internally, operate on normalized paths. Externally, display paths in a friendlier symbolic form when useful — replacing `$HOME` with `~` or the current working directory with `.`.

This separation avoids subtle bugs. Execution should use canonical values; presentation can be ergonomic.

```zsh
function io::path::display() {
    emulate -L zsh
    local path="${1:a}"

    path="${path/#$HOME/~}"
    path="${path/#${PWD:A}/.}"

    print -- "$path"
}

function io::path::source() {
    emulate -L zsh
    local file="${1:a}"

    [[ -f "$file" ]] || {
        io::err "No such file: $(io::path::display "$file")"
        return 1
    }

    builtin . "$file"
}
```

Never rely on prettified paths for actual filesystem operations.

### 20.7 Batch Operations Should Use a Normalized Status Model

When a command processes multiple items, use a small normalized set of statuses and aggregate them deterministically. Do not let raw command exit codes leak upward in an ad hoc way when the command is really reporting batch state.

Distinguish success, failure, warning, and neutral/skipped states, then derive one final aggregate result from that set.

```sh
function io::status::merge() {
    local current="$1"
    local next="$2"

    # Priority: failure > warning > neutral > success
    case "${current}:${next}" in
        1:*|*:1) return 1 ;;
        2:*|*:2) return 2 ;;
        -1:*|*:-1) return 255 ;;
        *) return 0 ;;
    esac
}

function io::load::many() {
    local item
    local final=0

    for item in "$@"; do
        if [[ -f "$item" ]]; then
            builtin . "$item" || {
                io::status::merge "$final" 1
                final="$?"
            }
        else
            io::status::merge "$final" 1
            final="$?"
        fi
    done

    case "$final" in
        255) return 0 ;;
        *) return "$final" ;;
    esac
}
```

The exact encoding can vary, but the aggregation should be explicit, stable, and documented.

### 20.8 Use Functional Aliases, Not Real Aliases

Real aliases are banned in scripts (§15). **Functional aliases** — thin wrapper functions that delegate to a properly namespaced implementation — may exist for convenience, discoverability, or typing speed. They must not contain the real logic.

```sh
function io::load::file() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    builtin . "$file"
}

function lf() { io::load::file "$@"; }  # Functional alias
```

Treat functional aliases as entry shortcuts, not as architecture. The real implementation belongs in the namespaced function for testability and inspectability.

### 20.9 Preserve Structured Data Until the String Boundary

Keep arrays as arrays, option bundles as option bundles, and path lists as path lists. Only stringify data at the boundary where a command, file, or display operation actually needs a string.

Premature flattening makes quoting brittle and obscures intent.

```zsh
function io::load::queue() {
    emulate -L zsh
    local -a files
    local file

    for file in "$@"; do
        [[ -f "$file" ]] && files+=("${file:a}")
    done

    (( ${#files} )) || return 0
    print -l -- "${files[@]}"
}
```

In shell, many bugs are string-shape bugs. Preserve data shape as long as possible.

### 20.10 Commands Should Be Terminal-Aware and Pipe-Safe

Shell utilities in this codebase are expected to behave sensibly both when attached to a terminal and when participating in pipelines. Check whether stdin or stdout is a terminal when that distinction changes behavior, formatting, or output mode.

Do not emit terminal-only decoration blindly into non-terminal output.

```sh
function io::print::status() {
    local message="$1"

    if [[ -t 1 ]]; then
        print -- "✓ ${message}"
    else
        print -- "$message"
    fi
}

function io::collect::paths() {
    local -a files
    local line

    if [[ ! -t 0 ]]; then
        while IFS= read -r line; do
            files+=("$line")
        done
    fi
    files+=("$@")

    print -l -- "${files[@]}"
}
```

A command should still be useful when redirected, piped, or embedded.

### 20.11 Wrap Tricky Shell Primitives in Named Verbs

If a shell primitive is subtle, repeated, or easy to misuse, wrap it in a namespaced function instead of open-coding it at every call site. This applies especially to sourcing, redirection-heavy capture, loadlist parsing, display normalization, and state aggregation.

A named wrapper centralizes semantics and makes later review easier.

```sh
function io::source::safe() {
    local file="$1"

    [[ -f "$file" ]] || {
        io::err "No such file: ${file}"
        return 1
    }

    builtin . "$file"
}
```

Prefer one well-defined verb over many near-duplicates scattered throughout the tree.

### 20.12 Documented Define-Then-Dispatch Is an Intentional Idiom

The following startup-fragment pattern is intentional in `rings`:

```sh
function namespace::entry() {
    ...
} && namespace::entry
```

Its purpose is narrow and specific:

- define the entrypoint
- dispatch only if the definition succeeded
- keep the top-level action explicit and minimal

This is not a license for arbitrary chaining. It is a declaration-then-dispatch idiom for sourced, loader-facing, or startup-facing fragments that encapsulate their real logic inside a function.

Restrict this idiom to immediate self-dispatch of the function just defined:

```sh
function namespace::entry() {
    ...
} && namespace::entry
```

Do not extend it into arbitrary follow-on blocks such as:

```sh
function namespace::entry() {
    ...
} && {
    function namespace::other() {
        ...
    }
}
```

Do not normalize this form away casually.

When this idiom is used, document it locally. Comments should explain what the function is the entrypoint for and why dispatch is gated with `&&`.

This idiom supports two compatible contracts at once: a file contract (such as `source env.sh`) and a callable contract (such as `packages::env`). That dual contract is intentional. The file may be sourced once during loading, then re-entered later through its callable interface.

---

## 21. String Operations Without Forks

Both shells support substring, replacement, and length operations. Prefer these over piping through `sed`/`awk`/`grep`:

```sh
str="Hello, World"

# Substring test — no grep fork
[[ "$str" == *World* ]] && print -- "found"

# Replacement (first occurrence)
print -- "${str/World/shell}"

# All occurrences
line="a::b::c"
print -- "${line//::/:}"

# Length
print -- "${#str}"
```

### Zsh Additions

```zsh
# Substring extraction
print -- "${str:7}"          # offset 7 to end
print -- "${str:7:5}"        # offset 7, length 5
print -- "${str: -5}"        # last 5 chars (space before - required)
```

---

## 22. Zsh: Startup Files

### 22.1 Load Order

```
/etc/zshenv   → ~/.zshenv      (always, every zsh)
/etc/zprofile → ~/.zprofile    (login shells only)
/etc/zshrc    → ~/.zshrc       (interactive shells only)
/etc/zlogin   → ~/.zlogin      (login shells, after zshrc)
~/.zlogout    → /etc/zlogout   (login shells, on exit)
```

### 22.2 What Goes Where

- `.zshenv`: Only `$ZDOTDIR` and `$PATH` adjustments that every zsh needs. Minimal. No options. No output.
- `.zshrc`: Interactive config — prompts, completion, aliases, key bindings, plugins.
- `.zprofile` / `.zlogin`: One-time login actions — `umask`, terminal setup, session environment variables.

### 22.3 Guard with Context Checks

```zsh
if [[ -o interactive ]]; then
    autoload -Uz compinit && compinit
fi
```

---

## 23. Zsh: Completion System

### 23.1 Initialize with Caching

```zsh
autoload -Uz compinit
# Regenerate cache at most once per day
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C    # skip security check when cache is fresh
fi
```

The glob `(#qN.mh+24)` requires EXTENDED_GLOB: `N` = nullglob, `.` = regular file, `mh+24` = older than 24 hours.

### 23.2 Style Completions

```zsh
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:warnings' format 'No completions for %d'
```

---

## 24. Tooling

### 24.1 `shfmt`

When using `shfmt` for automated formatting, use flags that match this guide's conventions:

```sh
shfmt -i 4 -ci
```

`-i 4` sets indent width to 4 spaces. `-ci` indents `case` bodies relative to the `case` arm. Do not enable auto-wrapping — this guide uses manual wrapping with one-item-per-line lists (§2.5) that automated wrapping would destroy.

---

## 25. Summary Principle

When in doubt, prefer the form that makes the code easier to reload mentally: clearer caller behavior, clearer ownership, clearer data shape, clearer output channel, clearer internal staging.

---

## Appendix A: Dual-Compatibility Quick Reference

| Feature | Bash | Zsh | Dual-Compatible |
|---|---|---|---|
| Safety options | `set -o errexit/errtrace/pipefail/nounset` | `setopt err_exit err_return pipe_fail no_unset` | `set -o` form |
| Option parsing | `getopts` (short opts only) | `zparseopts` (short + long) | `getopts` or manual `while`/`case` |
| Array indexing | 0-based | 1-based | Iterate; guard or helper when indexing |
| Array expansion | `"${array[@]}"` required | `$array` safe (no word-split) | `"${array[@]}"` (mandated universally) |
| First element | `${array[0]}` | `${array[1]}` | Guard, helper, or restructure |
| Pipe exit status | `$PIPESTATUS` (0-indexed) | `$pipestatus` (1-indexed) | Guard |
| Regex match groups | `$BASH_REMATCH` (0-indexed) | `$match` (1-indexed) | Guard |
| Terminal output | `print` (via shim) | `print` (builtin) | `print` / `print -P` |
| Plaintext output | `printf` | `printf` | `printf` |
| Basename | `"${path##*/}"` | `${path:t}` | `"${path##*/}"` |
| Dirname | `"${path%/*}"` | `${path:h}` | `"${path%/*}"` |
| Uppercase | `${var^^}` (bash 4+) | `${(U)var}` | Guard or helper |
| Lowercase | `${var,,}` (bash 4+) | `${(L)var}` | Guard or helper |
| Associative array | `declare -A` | `typeset -A` | Guard or helper |
| Read array from cmd | `readarray -t arr < <(cmd)` | `arr=("${(@f)$(cmd)}")` | Guard |
| Function-local vars | `local` | `local` | `local` (universally) |
| Integer declaration | `local -i` | `local -i` / `integer` | `local -i` |
| File ingestion | `mapfile -t arr < file` | `arr=("${(@f)$(<file)}")` | `while IFS= read -r` |
| Sourcing | `. file` or `source file` | `. file` (PATH only) or `source file` (cwd first) | `. "${path}/file"` with explicit path |

---

## Appendix B: Anti-Patterns

| Anti-Pattern | Why | Correct Alternative |
|---|---|---|
| `#!/bin/sh` | Falls back to POSIX sh; outside scope | `#!/usr/bin/env bash` or `#!/usr/bin/env zsh` |
| `local var=$(cmd)` | Masks exit status | `local var; var=$(cmd)` |
| `[[ ]]` with `-a` / `-o` | Not operators | Use `&&` / `\|\|` |
| `echo` in scripts | Not portable, inconsistent | `print` (terminal) or `printf` (plaintext) |
| Backticks | Legacy syntax | `$(...)` |
| `array[0]` in zsh | 1-indexed by default | `array[1]` or iterate |
| `grep` to test substring | Forks | `[[ "${str}" == *pattern* ]]` |
| `basename "$0"` | Forks | `"${0##*/}"` (dual) or `${0:t}` (zsh) |
| `dirname "$0"` | Forks | `"${0%/*}"` (dual) or `${0:h}` (zsh) |
| `wc -c <<< "$str"` | Forks | `${#str}` |
| `expr` | External process | `$(( … ))` |
| `let` | Quoting fragile | `(( … ))` |
| `$[ … ]` | Deprecated | `$(( … ))` |
| `[ … ]` / `test` | Inferior to `[[ ]]` | `[[ … ]]` |
| `SH_WORD_SPLIT` in zsh | Breaks zsh array semantics | Don't set it |
| `KSH_ARRAYS` in zsh | Causes more problems than it solves | Don't set it |
| String for command args | Word-splitting fragile | Use a real array |
| Aliases in scripts | Fragile quoting, not composable | Use functions |
| `;&` / `;;&` in `case` | Obscures control flow | Restructure the case statement |
| Bare code in sourced files | Leaks options and side effects | Encapsulate all code in functions |
| `declare` in function bodies | Inconsistent across shells | `local` (universally) |
| Traps at file scope in sourced code | Clobbers caller's traps | Set traps inside functions only |
| Missing `--` before variable args | Values starting with `-` parsed as flags | `print -- "${val}"`, `rm -- "${file}"` |
| `read` without `-r` | Backslash silently eaten | `read -r` unless escape interpretation is intended |
| `/tmp/file.$$` | Predictable, racy, insecure | `mktemp` or `mktemp -d` |
| `source lib.sh` (no path) | Behavior differs between bash and zsh | `. "${dir}/lib.sh"` with explicit path |
| Global `IFS=` mutation | Breaks word splitting for all subsequent commands | Scope to command: `IFS= read -r` |
| Complex trap strings | Quoting fragility | Call a function from the trap |
| `source .env` | Executes arbitrary code; violates the metadata contract | Parse as metadata, never source |
| `ln -s /absolute/path` | Breaks relocatable rings | Compute a relative target dynamically |
| Assuming `$PROFILE_D` in generic library code | Fails in non-login rings | Use `$RING_ROOT` |

---

## Appendix C: `rings` Project Conventions

The following rules are specific to the `rings` shell framework and do not apply to general shell code under this guide.

**Environment variables and paths:** Use the provided directory variables (`$ALIASES_D`, `$COMPLETIONS_D`, `$FUNCTIONS_D`, `$BIN`, `$LIB`, `$RING_ROOT`, `$PROFILE_D`, `$PACKAGES_D`, etc.) rather than constructing paths manually. Use `$RING_ROOT` for generic ring code. Use `$PROFILE_D` only when code specifically targets the login ring, where `$PROFILE_D == $RING_ROOT`. Do not assume `$PROFILE_D` exists in non-login rings. `$LIB` is exclusively for shared libraries supporting `$BIN`; never place module logic in `$LIB`.

**`.env` handling:** `.env` is directory-local rings metadata read by the loader before `.loadlist` (see `LOADER.md`). It is never sourced as shell code. Do not place shell exports in `.env`; package environment artifacts belong in `env.d/@pkg/`.

**`.loadlist` is the activation manifest:** It governs future-session activation. Always back up `.loadlist` edits as `.loadlist.bak-<timestamp>`. Stage multi-step operations and roll back on error.

**Batch mutation safety:** Follow §2.9 for every multi-file rewrite. Package migrations often involve untracked scaffolds; git is not a backup for those files. Copy or archive the target tree before running scripted rewrites, recursive renames, formatters, or generated replacement.

**Package lifecycle is unified under `packages::`.**  All package lifecycle operations — projection, reverse-projection, packaging, normalization, reconciliation, enable/disable/mute, install, remove, snap/rollback, inspection — live in the `packages::` namespace (see `PACKAGES.md` §10–§13). The former `bindings.d/` subsystem and its `bindings::` namespace are legacy; `bindings.d/` is slated for complete deletion. Do not write new code against `bindings::` verbs or reference `bindings.d/` as an active subsystem.

**Ownership forms for destructive operations:** Canonical `@pkg/` directories with a local `.loadlist` per domain. Flat convenience forms only where explicitly supported (aliases and completions at module roots).

**Symlinks:** All symlinks are relative. The repo is relocatable. Absolute paths are never used in symlink targets. Relative path computation must be dynamic — fixed-depth assumptions (e.g., hardcoding `../../`) are invalid.

**Package namespace conventions.** The full namespace is `packages::` for implementations and `pkgs::` for functional aliases. The canonical pairing is `packages::project` / `pkgs::project`, `packages::env` / `pkgs::env`, etc. The user-facing command surface uses `pkg` as a short invocation name (e.g., `pkg install`, `pkg ls`); this is a deliberate ergonomic abbreviation, not the functional alias namespace. The distinction: `pkg` is the CLI entry point, `pkgs::verb` is the functional alias, `packages::verb` is the implementation. Any prior reference to `pkg::` as a functional alias namespace is stale.

Use the documented callable surface. Do not derive callable names mechanically from path nesting or implementation seat. In `rings`, callable names follow package scope (see `CONSENSUS.md`). The specific exception is reserved `@core`: the `core::` portion may be elided in the public surface. `modules::reconcile` lives at `@core/@modules/`, but its callable name is `modules::reconcile`, not `core::modules::reconcile`.

**Ownership precedence:** Before writing an artifact, check ownership in this order: per-artifact override, `[ownership] default` in `.package`, then `default_ownership` in `.module` (see `PACKAGES.md` and `MODULES.md`). Registry-owned and module-owned are co-equal states.

**Authority ordering.** When guidance appears to conflict, resolve by priority:

1. Consensus
2. `CLAUDE.md`
3. `ARCHITECTURE.md`
4. `PACKAGES.md` and its addendums
5. `SHELL_STYLE_GUIDE.md` and its addendums

`PACKAGES.md` and `SHELL_STYLE_GUIDE.md` are co-equal (orthogonal concerns). If a real conflict appears between any authorities, do not normalize silently. Always note the tension. Always discuss it. Always attempt reconciliation.
