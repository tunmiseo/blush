# INIT — Per-Package Initialization

> **Authority:** This document specifies the init module and package: script layout, unit contract, retained module-level helpers, and boot relationship. The canonical init interface — `<pkg>::init` as the per-package verb — is defined in `PACKAGES.md` §12.

-----

## Role

`init.d/` (@init) holds per-package initialization scripts. Each script defines a `<pkg>::init` function that performs one-time or idempotent configuration after a package is installed. There is no orchestrator and no manifest — just functions that get called when the user invokes them.

`<pkg>::install` and `<pkg>::init` form the two per-package verbs:

- `<pkg>::install` — acquires artifacts (see `INSTALL.md`)
- `<pkg>::init` — configures environment

-----

## Layout

Canonical form (target state after normalization):

```
init.d/
├── .loadlist
├── @asdf/
│   └── init.sh          # defines asdf::init
├── @gh/
│   └── init.sh          # defines gh::init
├── @editor/
│   └── set-editor.sh    # defines editor::init
└── ...
```

In practice, users frequently create flat init scripts directly:

```
init.d/
├── .loadlist
├── asdf.init.sh          # defines asdf::init
├── gh.init.sh            # defines gh::init
└── ...
```

This is a common and expected working state, not an error. `packages::normalize` or `packages::package` will upgrade flat artifacts into `@`-namespaced canonical form when the user is ready. The tools flag inconsistencies for the user's consideration — normalization is always interactive or explicitly invoked.

-----

## How It Works

1. `packages::install @brew/asdf` installs the binary.
2. The user calls `asdf::init` to configure it.
3. The init function is idempotent — safe to re-run.

Init functions are defined in-session when `init.d/` is sourced by `zload` or `bload` (via the `.loadlist`). They do nothing on source — execution happens only when the user calls them or flags them for source execution.

-----

## Unit Contract

Each init script defines:

- **`<pkg>::init`** — e.g., `asdf::init`, `gh::init`. This is the canonical form, following the universal `<pkg>::verb` convention (symmetric with `<pkg>::install`).

The legacy `init::<pkg>` form (e.g., `init::asdf`) is deprecated but may be encountered in existing code. New init scripts should use `<pkg>::init`.

Requirements:

- **Idempotent:** running the function twice produces no additional side effects.
- **Artifact targeting:** init functions that create shell artifacts should target the canonical `packages.d/@pkg/` structure (or the module, if reverse-projected).
- **Config exceptions:** for packages whose config targets fall outside the conventional `config.d/` external-materialization defaults, `<pkg>::init` is responsible for establishing the non-standard links. The generic `config.d/` machinery handles the common case (`$XDG_CONFIG_HOME/<pkg>/`); `<pkg>::init` handles the rest. See `PACKAGES.md` §11 for config/stow policy and §12 for the install/init relationship.

-----

## `init status` / `init::status`

`<pkg>::init` is the canonical per-package lifecycle verb. Separately, the `init.d` module may expose a module entry function such as `init`, with subcommands like `init status`, for module-level introspection and helper operations.

Within that model, `init::status` is a module-level helper behind `init status`, not part of the deprecated `init::<pkg>` per-package pattern.

`init status` shows which init units have been run. It uses timestamp stamps at `$XDG_STATE_HOME/rings/init/stamps/` (or `~/.local/state/rings/init/stamps/`).

-----

## Relationship to Profiles

`<pkg>::init` remains a layer-3 per-package verb. Profile awareness is optional.

When a package's initialization needs identity- or context-scoped behavior, it may consult the stable layer-4 read surfaces:

- `profiles::current`
- `profiles::identity`

Those surfaces are read surfaces only; profile application remains owned by the profile layer.

Profile application does not belong to package init, and this document does not define a profile-owned init dispatcher.

-----

## Boot Relationship

```
profile.sh
  → sources modules via {z,b}load
     → env artifacts export module variables (FUNCTIONS_D, etc.)
     → init functions become available but are not auto-invoked, unless flagged in the loadlist.
  → may prompt during first-boot setup
  → continues normal boot
```

`profile.sh` is sourced, not executed. Module variable export is handled by env artifacts, not by init. Init functions become available after sourcing; they execute only if flagged for execution in a loadlist or when the user explicitly calls them. This document does not define a stronger boot-time init orchestrator contract than that.

-----

## Scope Boundary

Package-safe mutation utilities and any future dispatcher are separate architectural concerns, not specified here. This document covers the per-package `<pkg>::init` contract, retained module-level `init` helpers, and init-module layout only.
