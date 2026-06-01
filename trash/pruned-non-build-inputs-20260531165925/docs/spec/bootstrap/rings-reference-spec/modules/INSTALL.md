# INSTALL — Package Acquisition Layer

> **Authority:** This document specifies manifest format, backend implementations, and install-layer behavior behind the acquisition interface. The acquisition *interface* — `packages::install`, its resolution order, and its delegation model — is defined in `PACKAGES.md` §8.3. This document describes the implementation behind that interface.

-----

## Goals

- Single declarative manifest for packages across sources (brew, cask, asdf, cargo, pip, npm, apt).
- Idempotent installs with detection, logging, and reversible operations.
- Alignment with `.loadlist` conventions: files are source-of-truth; caches are derived.

## Components

- **Manifest:** `install.d/.packages` — declarative package list with source and flag annotations.
- **Dispatcher:** `packages::install` (`pkgs::install`) — resolves an installation target and dispatches to exactly one backend. See `PACKAGES.md` §8.3 for the resolution contract.

Path discovery: rings does not assume fixed locations for `$BIN` and `$LIB`; executables live under `$BIN`, libraries under `$LIB`, and both are exported via env/paths at load.

-----

## `.packages` Format

Package manifests extend `.loadlist` conventions:

```
# install.d/.packages
@brew/ripgrep
@cask/kitty              --if=darwin

@brew:
  bat
  eza
  dust
```

- **Sources:** `@brew`, `@cask`, `@asdf`, `@cargo`, `@pip`, `@npm`, `@apt`
- **Flags:** `--defer`, `--if=darwin|linux`, `--optional`

Each entry declares a package and its acquisition backend. The `@source/name` form is self-contained; the `@source:` block form groups entries under a shared backend for readability.

-----

## Dispatcher and Backends

`packages::install` resolves targets in a fixed order (`PACKAGES.md` §8.3):

1. If `<pkg>::install` is defined → dispatch to that function.
2. Else if a manifest entry exists in `.packages` → dispatch to the declared backend.
3. Else → error (no installation target defined).

### Per-Package Installers

A package may provide its own installer by defining `<pkg>::install`, typically via an `install.sh` artifact. The callable name follows package scope, like other package verbs:

```
install.d/@terraform/install.sh    # defines terraform::install
```

When `packages::install terraform` is called and `terraform::install` exists, the dispatcher invokes it directly. The manifest is not consulted.

### Manifest Backends

When no per-package installer exists, the dispatcher reads the `.packages` manifest and delegates to the declared backend. Supported backends:

| Backend | Source | Detection |
|---------|--------|-----------|
| `brew`  | Homebrew formulae | `brew list` |
| `cask`  | Homebrew casks | `brew list --cask` |
| `asdf`  | asdf version manager | `asdf list` |
| `cargo` | Rust crates | `cargo install --list` |
| `pip`   | Python packages | `pip list` |
| `npm`   | Node packages | `npm list -g` |
| `apt`   | Debian packages | `dpkg -l` |

Each backend is responsible for: detection (is the package already installed?), installation, and status reporting for `packages::check`.

### Status Reporting

`packages::check` (`pkgs::check`) uses the same resolution model. If `<pkg>::install` exists, status is determined by the per-package function's contract; otherwise the backend is queried.

-----

## Workflow: Capturing a Manual Install

A common pattern is to capture a manual installation into a reusable per-package installer:

```sh
io::save terraform::install
packages::package install.d/@terraform/
```

This records the manual steps as `terraform::install`, then canonicalizes the artifact into the registry via `packages::package`.

-----

## Safety and Idempotency

- Detect existing installs; skip with clear status.
- Log actions; print dry-run plan when `--dry-run`.
- Installing a package does not activate it — `packages::enable` is the required activation verb (`PACKAGES.md` §8.2).
- Do not add `.loadlist` entries during install. Existing entries may still be updated elsewhere in the package lifecycle when files move.

-----

## Relationship to Init

After `packages::install` acquires a binary, the user calls `<pkg>::init` to configure it. These are the two per-package verbs:

- `<pkg>::install` — acquires artifacts
- `<pkg>::init` — configures environment

See `PACKAGES.md` §12 and `INIT.md` for the init contract.

## Relationship to Collections and Profiles

Host- and context-scoped installation belongs to layer 4 semantics, not to install-layer overlay files.

Collections answer **which packages** are in scope. Profiles answer **which identity-bearing context** is applying them, including host identity when present. Collection-scoped acquisition is a convenience flow over the collection query surface, not a second authorship mechanism for package membership:

- a command such as `install --under <collection>` may query `collections::members`
- host applicability is filtered through profile host identity and package `hosts` constraints

See `COLLECTIONS.md` and `PROFILES.md` for the semantic model.

## Relationship to External Materialization

Acquisition is not external materialization. Installing a package or backend does not itself place config or other artifacts into the locations an application expects outside the ring. That boundary belongs to `packages::stow`; see `PACKAGES.md` §8.1 and §11.

## Relationship to the Package Registry

`install.d/` is a module like any other in the rings module tree. A package's install artifacts live in `install.d/@pkg/` and package into the registry using the normal singleton-or-directory rules (`PACKAGES.md` §3.2 and §3.3).

Most user-facing packages have entries in both `packages.d/` (the integration — aliases, env, completions, functions, config) and `install.d/.packages` (the upstream binary). Pure-shell packages (`@core`, personal aliases) exist only in `packages.d/`. Install-only dependencies (libraries, build tools) may exist only in `install.d/`.

See `PACKAGES.md` §12 for the relationship to existing subsystems.

## Generation Management

Generation snapshots and rollback are system-wide operations managed by `packages::snap` and `packages::rollback` (`PACKAGES.md` §8.4). They act on the entire rings state via git, not on individual packages or the install layer alone.

-----

## Status

The install-layer architecture is settled. Implementation parity with this specification is in progress.
