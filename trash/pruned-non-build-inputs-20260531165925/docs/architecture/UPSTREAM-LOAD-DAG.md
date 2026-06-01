

# Upstream Load DAG & Bottom-Up Porting Sequence

> **Status: active architecture reference.** Moved from `notes/real-dag.md` on 2026-05-29.
> Documents upstream `ble.sh` load order, the feedback arcs, and the bottom-up port order.
> The feedback-arc inversions sketched here are now **settled rings rules** in
> [`CONSENSUS.md`](../agents/CONSENSUS.md) §13 — that section is authoritative where this
> note and it differ. Per-row closure authority is the ledger
> (`src/@ble/@test/@oracle/classification/upstream.tsv`), not the phase numbering below.
> The phase sequence is historical porting guidance; several phases are already executed
> (e.g. `@syntax/@parse` is now the ported incremental engine, not the clean-room scanner
> this note's contemporaries described).

Load order is clear: `def → util → decode → color → canvas → history → edit → (cmdspec, syntax, complete)`. 


**Confirmed load order** (from `out/ble.sh` section headers):

```
def → util → decode → color → canvas → history → edit → (cmdspec, syntax, complete)
```

**What each module actually owns:**

- `def.sh` (139 lines): pure hook registry — `blehook/declare` for every event name used across all modules. No calls, no logic.
- `util.sh` (8791 lines): `ble/util/*` AND `ble/term/*` live here — they are one module. Also contains: `bleopt`, the idle task scheduler, `conditional-sync`, stty management.
- `decode.sh` (4700 lines): key input, keymap stack, CSI parsing, readline binding, `has-input`, and widget dispatch stubs (some `ble/widget/` functions start here).
- `color.sh`: SGR/face system.
- `canvas.sh` (3569 lines): panel-based rendering, textmap, cursor tracking. Calls util and color.
- `history.sh` (2346 lines): shell history, background async loading.
- `edit.sh` (12180 lines): buffer, textarea, prompt, info bar, the bulk of `ble/widget/*` implementations, attach/detach lifecycle. Integration layer.
- `syntax`, `complete`, `cmdspec`: loaded lazily on first use from edit, not at startup.

---

**The structural DAG (dominant hierarchy):**

```
def
 └── util/term
      ├── decode
      ├── color
      └── canvas (← needs util + color)
           ↓
         history (← needs util + canvas indirectly via edit)
           ↓
          edit  (← integration: consumes everything above)
           ├── syntax  (lazy)
           ├── complete (lazy)
           └── cmdspec  (lazy)
```

More precisely, decode/color/canvas are parallel branches all consuming util, and history/edit are downstream of all three.

---

**The confirmed feedback arcs** (calls in function bodies that go against the dominant direction):

1. **`util/conditional-sync` → `ble/decode/has-input`** (`util.sh:4804`): the default stop-condition string is `'! ble/decode/has-input'`. Every async operation in util yields to the input layer via this string.

2. **`util/idle.do` → `ble/edit/info/immediate-default`, `ble/edit/info/immediate-show`** (`util.sh:6307`, `util.sh:6331`): the idle task runner calls up to the edit info bar for debug display.

3. **`history.sh` → `ble/decode/has-input`**: background history operations poll `ble/decode/has` for interrupt, same pattern as conditional-sync.

4. **`decode.sh` → `ble/edit/info/default`, `ble/edit/info/show`**: the keylogger and readline bind code display status via the edit info bar.

---

**To your question — can this be modeled as DAG + recurrences?**

Yes, and your characterization of *why* the feedback arcs exist is exactly right. Every single one is a yield/interrupt/telemetry signal, not structural data flow. None of them pass state that the lower module needs to be defined or to operate. `history` doesn't need `decode` to exist to manage history — it just needs `has-input` to be callable when it wants to be interruptible. That's architecturally honest; the boundary wrapper for `has-input` during porting can return `false` (never interrupt) and the module functions correctly, just without cooperative cancellation.

**One correction to your framing:** `syntax` is not mid-hierarchy — it's above `edit`, loaded lazily. The mid-level is `decode + color + canvas` as parallel consumers of `util`, all feeding into `history` and then `edit`. The term layer is not a separate module — it's physically inside `util.sh`.

## The True Bottom-Up Porting Sequence

*Based on reading `def.sh`, `util.sh`, `decode.sh`, `color.sh`, `canvas.sh`, `history.sh`, `edit.sh`, `lib/core-syntax-def.sh`, `lib/core-cmdspec-def.sh`, and `out/ble.sh`.*

---

### The Actual Upstream Structure

**Compiled load order** (from `out/ble.sh` section headers):

```
def → util → decode → color → canvas → history → edit
                                                   ↓ lazy via ble-import -d
                                         cmdspec, syntax, complete
```

**Module ownership — what lives where:**

| Source file | Namespaces owned |
|---|---|
| `def.sh` (139 lines) | `blehook/*` — hook registry and all event declarations |
| `util.sh` (8791 lines) | `ble/util/*` AND `ble/term/*` — one file, interleaved |
| `decode.sh` (4700 lines) | `ble/decode/*`, stub roots of `ble/widget/*` |
| `color.sh` | `ble/color/*` |
| `canvas.sh` (3569 lines) | `ble/canvas/*` |
| `history.sh` (2346 lines) | `ble/history/*` |
| `edit.sh` (12180 lines) | `ble/edit/*`, `ble/prompt/*`, `ble/textarea/*`, bulk of `ble/widget/*` |
| `lib/core-syntax-def.sh` | Stub + autoload registration for `ble/syntax/*`; calls `ble/color/defface` |
| `lib/core-cmdspec-def.sh` | Stub + deferred import of `lib/core-cmdspec.sh`; calls only `ble/util/*` |
| `lib/core-complete-def.sh` | Stub + deferred import of `lib/core-complete.sh` |

**The confirmed feedback arcs** — calls inside function bodies that go against the dominant load direction:

| From | To | Location | What it does |
|---|---|---|---|
| `util/conditional-sync` | `ble/decode/has-input` | `util.sh:4804` | Default stop-condition for async ops; `local __ble_continue=${2:-'! ble/decode/has-input'}` |
| `util/idle.do/.call-task` | `ble/edit/info/immediate-default` | `util.sh:6307` | Idle debug display |
| `util/idle.do/.call-task` | `ble/edit/info/immediate-show` | `util.sh:6331` | Idle debug display |
| `history.sh` | `ble/decode/has-input` | `history.sh` | Interrupt polling during async history load |
| `decode.sh` | `ble/edit/info/default` | `decode.sh` | Keylogger status display |
| `decode.sh` | `ble/edit/info/show` | `decode.sh` | Keylogger status display |

Every feedback arc is a yield, interrupt check, or debug display signal — none carry structural state that the lower module requires to function.

---

### Phase 1: Zero-Dependency Roots

#### 1. @hook (from `def.sh`)

The hook registry: `blehook/declare` and the event name declarations used by every subsequent module. 139 lines, no cross-module calls.

This is the unconditional prerequisite. Every other module either invokes hooks or registers into them at load time.

All eight closure criteria are trivially satisfied: no external ble:: calls, pure data structure initialization, testable in a single shell invocation.

---

#### 2. @util + @term

**Critical structural note:** `ble/term/*` is defined inside `util.sh`. There is no separate upstream `term.sh` source file. The two namespaces are interleaved across 8791 lines. Rings separates them into distinct packages by design, but that separation is a rings-specific decomposition decision, not a reflection of upstream boundaries. They must be ported as a coordinated unit.

**The feedback arcs in `util.sh`** produce exactly three stubs needed for `@util` to achieve closure:

1. `ble/decode/has-input` → `return 1` (no input pending — async operations will run to completion without interrupt)
2. `ble/edit/info/immediate-default` → no-op
3. `ble/edit/info/immediate-show` → no-op

These stubs are replaced, not revised, when `@decode` and `@edit` are ported.

The `ble/term/visible-bell:canvas/*` function bodies inside `util.sh` call `ble/canvas/put.draw` and `ble/canvas/panel/*`, but visible-bell is only invoked during an attached session. Two additional stubs cover this for Phase 1 headless testing.

**Closure criteria:**

1. **Upstream slice identified:** `ble/util/*` and `ble/term/*` in `util.sh`
2. **Rings equivalent exists:** `@util` and `@term` namespaces with `::` naming
3. **Internal callees present:** bash builtins and `@hook`; the five stubs above for the feedback arcs
4. **External boundaries are true boundaries:** OS process operations, fd management, TTY stty — all external
5. **No stubs in implementation:** array, string, file, msleep, conditional-sync, stty — all ported verbatim from upstream bodies
6. **Surface settled:** general-purpose stable API
7. **Testable headless:** yes — all primitive operations exercise without a PTY; idle and conditional-sync testable with mock tasks
8. **Downstream-stable:** an array append or string split does not drift based on widget design

---

### Phase 2: Style and Terminal Capabilities

#### 3. @color

`color.sh` calls only `ble/util/*` (Phase 1 ✓). No feedback arcs. Face definitions, g-value encoding, and SGR lookup are entirely self-contained.

**Boundary stubs required: zero.**

**Closure criteria:**

1. Upstream slice: `ble/color/*` in `color.sh`
2. Rings equivalent: `@color` namespace
3. Internal callees: `@util` only
4. External boundaries: none — pure data computation
5. No stubs: color tables, face maps, and `g2sgr` conversion ported verbatim
6. Surface settled: `ble/color/face2sgr`, `ble/color/g2sgr`, `ble/color/defface`
7. Testable: iterate all face names, diff SGR output strings against upstream
8. Downstream-stable: ANSI color encoding doesn't change based on keymap or widget logic

---

### Phase 3: Rendering and Input Pipeline

These three packages depend only on Phase 1–2 and are fully parallelizable with each other.

#### 4. @canvas

`canvas.sh` calls `ble/util/*` (Phase 1 ✓) and `ble/color/*` (Phase 2 ✓). No upward feedback arcs originate from canvas itself. The Unicode width tables (`canvas.c2w.sh`, `canvas.emoji.sh`, `canvas.GraphemeClusterBreak.sh`) are data-only files with no ble:: dependencies and port as part of this package.

**Boundary stubs required: zero.**

**Closure criteria:**

1. Upstream slice: `ble/canvas/*` in `canvas.sh` plus the four Unicode table files
2. Rings equivalent: `@canvas` namespace
3. Internal callees: `@util`, `@color` — both present
4. External boundaries: terminal fd write — a real OS boundary
5. No stubs: panel layout, `trace-text`, cursor tracking, textmap — ported verbatim
6. Surface settled: `ble/canvas/put.draw`, `ble/canvas/flush`, `ble/canvas/panel/*`
7. Testable: render to a buffer, diff output strings against upstream
8. Downstream-stable: rendering geometry doesn't change based on what keys trigger which widgets

---

#### 5. @decode

`decode.sh` loads **second** in upstream — immediately after `util`, before `color` and `canvas`. Its position in the original document (Phase 4, after the editor) inverts the actual source order and gets the dependency direction wrong. `@decode` provides `ble/decode/has-input`, which `@history` (Phase 4) calls directly. Decode must be ported before history.

**Cross-module calls from `decode.sh`:**
- `ble/util/*` — Phase 1 ✓
- `ble/color/face` — Phase 2 ✓ (inside function bodies; deferred runtime call)
- `ble/edit/info/default`, `ble/edit/info/show` — **feedback arc to Phase 5**

**Boundary stubs required: two** (both `ble/edit/info` variants → no-op or stderr passthrough for debug purposes).

`ble/widget/` stubs in `decode.sh` (lines 1719, 1722, 2039, 2732) are dispatch infrastructure that routes to widget implementations in `edit.sh`. Port the dispatch shells here; widget bodies are a Phase 5 concern.

**Closure criteria:**

1. Upstream slice: `ble/decode/*` in `decode.sh` (4700 lines)
2. Rings equivalent: `@decode` namespace
3. Internal callees: `@util`, `@color` present; two `edit/info` stubs
4. External boundaries: host readline binding, TTY fd read
5. No stubs in implementation: CSI parsing, keymap stack, `has-input`, readline bind — verbatim
6. Surface settled: `ble/decode/attach`, `ble/decode/has-input`, `ble/decode/keymap/*`
7. Testable: feed raw byte sequences, assert key event output; `has-input` testable against real fd
8. Downstream-stable: CSI decoding rules and keymap lookup are independent of widget implementations

---

#### 6. @syntax (stub layer + autoload registration)

`lib/core-syntax-def.sh` is the load-time layer for syntax. Reading it directly: it declares public state variables, provides stub implementations of `ble/highlight/layer:syntax/update` and `ble/highlight/layer:syntax/getg`, registers the real functions for autoload from `lib/core-syntax.sh`, and calls `ble/color/defface` for syntax face definitions via `blehook/eval-after-load color_defface`.

Dependencies: `@util` (Phase 1 ✓) and `@color` (Phase 2 ✓). No dependency on `@edit` or `@decode`.

The real parser (`lib/core-syntax.sh`) loads lazily on first call. The stub layer is sufficient for Phase 3 — it allows `@edit` to be ported against real (if no-op) syntax stubs, and `core-syntax.sh` is integrated when `@edit` is closed in Phase 5.

**Boundary stubs required: zero** for the def layer. The stubs ARE the def layer.

---

#### 7. @cmdspec (stub layer)

`lib/core-cmdspec-def.sh` (84 lines) provides `ble/cmdspec/opts` and `ble/cmdspec/opts#load` against a gdict, plus a deferred import of the real command specification database. Dependencies: `@util` only.

**Boundary stubs required: zero.**

---

### Phase 4: History

#### 8. @history

`history.sh` calls `ble/util/*` (Phase 1 ✓) and `ble/decode/has-input` (Phase 3 ✓ — **now real**, not stubbed).

This is why `@history` is not Phase 1. The original document claimed it "reads/writes to `~/.bash_history` and never calls the UI." The first half is correct. The second half is wrong. `history.sh` calls `ble/decode/has-input` for cooperative interrupt handling during async background history loading. Without Phase 3 decode present, the stub from Phase 1 (`has-input` returns 1) means history operations run to completion but cannot be interrupted by user input. That stub behavior is correct for Phase 1 testing of `@util`; it is not a substitute for a ported `@decode`.

By Phase 4, `@decode` is real. `@history` ports with no stubs at all.

**Boundary stubs required: zero** (Phase 3 has closed `has-input`).

**Closure criteria:**

1. Upstream slice: `ble/history/*` in `history.sh` (2346 lines)
2. Rings equivalent: `@history` namespace
3. Internal callees: `@util`, `@decode/has-input` — both present in Phase 4
4. External boundaries: `~/.bash_history` filesystem, `builtin history`
5. No stubs: file parsing, array management, async background load, search — verbatim
6. Surface settled: `ble/history/add`, `ble/history/get`, `ble/history/initialize`, `ble/history/set`
7. Testable: point at a dummy history file, validate in-memory array state and search results
8. Downstream-stable: history file format is independent of editor widget design

---

### Phase 5: Editor Integration

#### 9. @edit

`edit.sh` (12180 lines) is the integration layer. It consumes every package above and **closes all outstanding feedback arc stubs**:

- `ble/edit/info/immediate-default`, `ble/edit/info/immediate-show` → real info bar (closes Phase 1 `@util` stubs)
- `ble/edit/info/default`, `ble/edit/info/show` → real info bar (closes Phase 3 `@decode` stubs)
- `ble/decode/widget/dispatch` → routes to the real widget implementations defined in this file
- `ble/syntax/parse`, `ble/syntax/highlight` → calls Phase 3 stub layer, triggers autoload of real parser
- `ble/history/*` → calls Phase 4 history (real)
- `ble/canvas/panel/*` → calls Phase 3 canvas (real)

Rings decomposes `edit.sh` into sub-packages (`@buffer`, `@textarea`, `@prompt`, `@info`, `@widget/*`). The decomposition boundaries must be drawn from the upstream body — the porting order within Phase 5 follows internal data flow within `edit.sh`.

**No boundary stubs needed.** All dependencies are real by Phase 5.

---

### Phase 6: High-Level Orchestration

#### 10. @complete

The most dependent package. Requires `@syntax` (Phase 3/5 real engine), `@cmdspec` (Phase 3 stub + real engine), `@edit` (Phase 5), and `@canvas` (Phase 3) for menu rendering.

No mocking required at this stage.

---

### Corrected Phase Table

| Phase | Package | Requires | Stubs to write |
|---|---|---|---|
| 1 | @hook | — | none |
| 1 | @util + @term | @hook | 5: `has-input`→1, `info/immediate-*`→noop×2, `canvas/visible-bell`→noop×2 |
| 2 | @color | @util | none |
| 3 | @canvas | @util, @color | none |
| 3 | @decode | @util, @color | 2: `edit/info/default`→noop, `edit/info/show`→noop |
| 3 | @syntax (def layer) | @util, @color | none (stubs are the def layer itself) |
| 3 | @cmdspec (def layer) | @util | none |
| 4 | @history | @util, @decode | none (has-input is real) |
| 5 | @edit | everything above | none — this phase closes all outstanding stubs |
| 6 | @complete | @edit + all | none |

---

### Note

- There is no `term.sh` in upstream. `ble/term/*` is defined inside `util.sh`. The rings separation is intentional but must be acknowledged as a design decision, not a clean upstream boundary.

**@history in Phase 1:** History calls `ble/decode/has-input`. It belongs in Phase 4, after decode is closed.

**@syntax in Phase 1:** The real syntax engine (`lib/core-syntax.sh`) loads lazily after the editor initializes. The stub/def layer is Phase 3; the full engine integrates in Phase 5. Treating @syntax as a Phase 1 primitive inverts its position in the compiled output.

**@decode in Phase 4:** Decode is the second module loaded in upstream — before color and canvas. It provides `has-input`, which history depends on. Placing it after edit misreads the source order and the dependency direction.
