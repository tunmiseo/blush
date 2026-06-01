# @term Upstream→Rings Decomposition Map

> **Status: active reference.** Moved from `notes/term-decomposition.md` on 2026-05-29.
> Maps upstream `ble/term/*` symbols (which live inside `util.sh`) to their rings `@term`
> package homes and subpackages. Symbol-level closure authority is the ledger plus
> `src/@ble/@test/@oracle/translation/symbols.tsv`; this is the design map, not the proof.

The character constants in `def.sh` are the first thing to address: `_ble_term_nl`, `_ble_term_FS`, `_ble_term_SOH`, `_ble_term_DEL`, `_ble_term_IFS`, `_ble_term_CR`, `_ble_term_blank` carry the `_ble_term_` prefix but are not terminal state — they are fundamental string constants. They belong in `@util`, not `@term`. That mislabeling is upstream's, not something to port faithfully.

Everything else maps as follows.

---

### `@term/_term.bash` — private capability machinery

| Upstream | Rings |
|---|---|
| `ble/init:term/tput` | `ble::term::__tput` |
| `ble/init:term/define-cap` | `ble::term::__probe-cap` |
| `ble/init:term/define-cap.2` | `ble::term::__probe-cap2` |
| `ble/init:term/define-sgr-param` | `ble::term::__probe-sgr` |
| `ble/init:term/register-varname` | absorbed into `__probe-cap` |

---

### `@term/term.bash` — capability init + core I/O

| Upstream | Rings |
|---|---|
| `ble/init:term/initialize` + `ble/term/.initialize` | `ble::term::probe` (define-then-dispatch) |
| `ble/term/DA2R.hook` | `ble::term::__da2r-hook` |
| `ble/term/put` | `ble::term::put` |
| `ble/term/cup` | `ble::term::cup` |
| `ble/term/flush` | `ble::term::flush` |
| `ble/term/quote-passthrough` | `ble::term::passthrough` |

**Capability state globals** — all `_ble_term_*` variables set by `ble::term::probe` keep their names. They are `@term`'s public state and the substrate `@color` reads directly.

---

### `@term/attach.bash` — lifecycle + inline subgroups

| Upstream | Rings |
|---|---|
| `ble/term/initialize` | `ble::term::initialize` |
| `ble/term/attach` | `ble::term::attach` |
| `ble/term/detach` | `ble::term::detach` |
| `ble/term/enter` | `ble::term::enter` |
| `ble/term/leave` | `ble::term::leave` |
| `ble/term/enter-for-widget` | `ble::term::enter-for-widget` |
| `ble/term/leave-for-widget` | `ble::term::leave-for-widget` |
| `ble/term/enter-altscr` | `ble::term::altscr::enter` |
| `ble/term/leave-altscr` | `ble::term::altscr::leave` |
| `ble/term/update-winsize` (+ variants) | `ble::term::winsize::update` |
| `ble/term/cursor-state/.update` | `ble::term::cursor::__update` |
| `ble/term/cursor-state/set-internal` | `ble::term::cursor::__set` |
| `ble/term/cursor-state/.update-hidden` | `ble::term::cursor::__update-hidden` |
| `ble/term/cursor-state/hide` | `ble::term::cursor::hide` |
| `ble/term/cursor-state/reveal` | `ble::term::cursor::reveal` |
| `ble/term/bracketed-paste-mode/.init` | `ble::term::paste::__init` |
| `ble/term/bracketed-paste-mode/enter` | `ble::term::paste::enter` |
| `ble/term/bracketed-paste-mode/leave` | `ble::term::paste::leave` |
| `ble/term/synchronized-update-mode/resolve-auto` | `ble::term::sync::resolve` |
| `ble/term/rl-convert-meta/enter` | `ble::term::convert-meta::enter` |
| `ble/term/rl-convert-meta/leave` | `ble::term::convert-meta::leave` |
| `_ble_term_attached` | `_ble_term_attached` |

---

### `@term/@stty/`

| Upstream | Rings |
|---|---|
| `ble/term/stty/.initialize-flags` | `ble::term::stty::__initialize-flags` |
| `ble/term/stty/initialize` | `ble::term::stty::initialize` |
| `ble/term/stty/enter` | `ble::term::stty::enter` |
| `ble/term/stty/leave` | `ble::term::stty::leave` |
| `ble/term/stty/finalize` | `ble::term::stty::finalize` |
| `ble/term/stty/TRAPEXIT` | `ble::term::stty::__trap-exit` |

---

### `@term/@da/` — terminal identification (DA1/DA2/CPR/DECSTBM)

These are all asynchronous probe protocols; they belong together.

| Upstream | Rings |
|---|---|
| `ble/term/DA2/request` | `ble::term::da::request` |
| `ble/term/DA2/initialize-term` | `ble::term::da::__initialize-term` |
| `ble/term/DA1/notify` | `ble::term::da::notify-da1` |
| `ble/term/DA2/notify` | `ble::term::da::notify-da2` |
| `ble/term/test-DECSTBM.hook1` | `ble::term::da::__decstbm-hook1` |
| `ble/term/test-DECSTBM.hook2` | `ble::term::da::__decstbm-hook2` |
| `ble/term/test-DECSTBM` | `ble::term::da::test-decstbm` |
| `ble/term/CPR/request.buff` | `ble::term::da::cpr-request-buff` |
| `ble/term/CPR/request.draw` | `ble::term::da::cpr-request-draw` |
| `ble/term/CPR/notify` | `ble::term::da::cpr-notify` |
| `_ble_term_TERM`, `_ble_term_TERM_done` | unchanged |
| `_ble_term_DA1R`, `_ble_term_DA2R` | unchanged |

---

### `@term/@mok/` — modifyOtherKeys

| Upstream | Rings |
|---|---|
| `ble/term/modifyOtherKeys/.update` | `ble::term::mok::__update` |
| `ble/term/modifyOtherKeys/.supported` | `ble::term::mok::__supported` |
| `ble/term/modifyOtherKeys/enter` | `ble::term::mok::enter` |
| `ble/term/modifyOtherKeys/leave` | `ble::term::mok::leave` |
| `ble/term/modifyOtherKeys/reset` | `ble::term::mok::reset` |

---

### `@term/@bell/`

| Upstream | Rings |
|---|---|
| `ble/term/audible-bell` | `ble::term::bell::audible` |
| `ble/term/visible-bell` | `ble::term::bell::visible` |
| `ble/term/visible-bell:term/{init,show,update,clear}` | `ble::term::bell::term::{init,show,update,clear}` |
| `ble/term/visible-bell:canvas/{init,show,update,clear}` | `ble::term::bell::canvas::{init,show,update,clear}` |
| `ble/term/visible-bell/defface.hook` | `ble::term::bell::__defface-hook` |
| `ble/term/visible-bell/{.show,.update,.clear}` | `ble::term::bell::{__show,__update,__clear}` |
| `ble/term/visible-bell/.erase-previous-visible-bell` | `ble::term::bell::__erase-prev` |
| `ble/term/visible-bell/{.create-workerfile,.worker}` | `ble::term::bell::{__create-workerfile,__worker}` |
| `ble/term/visible-bell/cancel-erasure` | `ble::term::bell::cancel` |
| `ble/term/visible-bell/erase` | `ble::term::bell::erase` |