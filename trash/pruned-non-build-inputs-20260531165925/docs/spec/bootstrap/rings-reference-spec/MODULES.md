# MODULES — Layer 2: Module Semantics

> **Status:** Specification (pre-implementation).
> **Scope:** What modules are, how `@core` determines them, and the `.d`-suffix convention within `@core` scopes.
> **See also:** [`ARCHITECTURE.md`](./ARCHITECTURE.md) · [`LOADER.md`](./LOADER.md) · [`PACKAGES.md`](./PACKAGES.md)

-----

## 1. Definitions

Naming conventions and the layer model are established in [`ARCHITECTURE.md`](./ARCHITECTURE.md). `$RING_ROOT` names any ring root and is exported by `profile.sh` for every ring. `$PROFILE_D` is exported only when that ring is bound as the login ring, and equals `$RING_ROOT` in that case. Both are set during the layer 1 boot sequence; see [`LOADER.md`](./LOADER.md).

A **suffixed directory** is a directory whose name ends in `.d` — concretely `./env.d/`, `./env.d/secrets.d/`; by name `env.d`, `secrets.d`. A **prefixed directory** is a namespaced directory whose name begins with `@` — concretely `./packages.d/@fzf/`; by name `@fzf`.

A **module** is a top-level suffixed directory in rings-root confirmed by `@core` through reconciliation (§3). A **submodule** is a suffixed directory directly inside a module or another submodule — every ancestor up to rings-root must itself be a module or submodule. `custom.d` and `secrets.d` are module names; `./custom.d/` and `./env.d/secrets.d/` are their locations.

Within any `@core` scope, a **module-correspondent directory** (shortened: **correspondent directory**) is a prefixed-and-suffixed child — e.g., `@core/@env.d` — that maps to a module in rings-root. A prefixed child without the `.d` suffix — e.g., `@core/@formatting` — is an ordinary namespaced directory with no module correspondence.

At a glance:

```text
@core/@env.d                 → env.d
@core/@env.d/@secrets.d      → env.d/secrets.d
@core/@env.d/@secrets.d/@x   → correspondence stops; package scope begins
```

-----

## 2. The One-Way Boundary

A module's loadlist may contain any combination of submodules (`name.d/`), package scopes (`@name/`), and sourceable files, coexisting freely at any depth.

Module-space (layer 2) and package-space (layer 3) are distinct. Three rules define the boundary:

1. A prefixed directory is always contained in a module or another prefixed directory.
2. A prefixed directory is never a module, regardless of suffix.
3. A prefixed directory cannot contain a module.

The loader (layer 1) recurses into whatever its loadlist names — it does not distinguish `env.d/`, `@env/`, or `@env.d/` as anything but valid directories. `@core` (layer 2) scans only unprefixed suffixed directories when determining modules. `@packages.d` (layer 3) scans within prefixed scopes and considers them packages; it treats terminal suffixed directories within those packages as routing signals, not modules.

> In `./packages.d/@fzf/aliases.d/public.sh`: `@fzf/` is a package; `aliases.d/` inside it is a routing signal pointing to `./aliases.d/`; `public.sh` is routed to `./aliases.d/@fzf/public.sh`. See [`PACKAGES.md`](./PACKAGES.md) for full routing semantics.

-----

## 3. `@core` and Module Determination

`@core` lives at `./packages.d/@core/` and, once sourced by the loader, determines which top-level suffixed directories in rings-root are modules. It does this by identifying its own `@*.d/` children with rings-root's `*.d/` directories through naming correspondence:

- Each immediate `@*.d/` child corresponds to a top-level module: `@core/@env.d` ⟺ `env.d`.
- Nesting continues recursively: `@core/@env.d/@secrets.d` ⟺ `env.d/secrets.d`.
- The first prefixed child at any level lacking a `.d` suffix has no module correspondence and terminates the module chain at that branch.

Layer 2 machinery may be organized under `./packages.d/@core/@modules/`. That `@modules` subtree is organizational structure inside reserved `@core`, not a package-semantic namespace and not part of the module-correspondent naming rule. Layer 3 package semantics are not yet in force there.

Determination proceeds through two complementary scans.

**Outward.** `@core` walks its own tree. For each `@*.d/` child: if the corresponding suffixed directory exists in rings-root, it is confirmed as a module; otherwise reconciliation offers creation of the counterpart.

**Inward.** `@core` scans rings-root for top-level suffixed directories (excluding its own subtree). For each: if a corresponding `@core/.../@name.d` path already exists, both are confirmed; otherwise reconciliation offers adoption into `@core`.

After both scans, `@core`'s `@*.d/` hierarchy and rings-root's suffixed directories mirror each other to the extent the user approves. At shell startup, `@core` checks for inconsistency and displays a notice if found. The notice signals that reconciliation should be run explicitly via `modules::reconcile`. Running `modules::reconcile` triggers the outward and inward scans and applies any approved changes. Reconciliation is not triggered automatically at startup.

**Downstream.** `@core` then scans each module for a `@core` scope and validates its `@*.d/` children against the confirmed module set. New modules enter only through the outward and inward scans above.

`@packages.d` (layer 3) uses the output of this process as its routing targets.

-----

## 4. The `.d`-Suffix Convention for `@core` Scopes

Within any `@core` scope, `@name.d/` is a module-correspondent directory; `@name/` is a plain package with no module correspondence. The convention applies wherever `@core` appears as a top-level module subdirectory: `./packages.d/@core/`, `./functions.d/@core/`, `./aliases.d/@core/`, and so on. The `@*.d/` children of `./packages.d/@core/` are authoritative — `@core` subdirectories in other modules are validated against them during downstream scanning (§3), not the reverse.

To `@packages.d` and the loader, `@name.d/` and `@name/` are equally packages. The convention is strictly `@core`'s.

```text
./packages.d/@core/
├── @modules/                       ← layer-2 organizational machinery
├── @env.d/                         ← module-correspondent
├── @aliases.d/                     ← module-correspondent
├── @functions.d/                   ← module-correspondent
├── @packages.d/                    ← module-correspondent
├── @templates.d/                   ← module-correspondent
└── @formatting/                    ← plain package; no module correspondence
```

The `@*.d/` chain traces the full submodule hierarchy; the first unsuffixed prefixed child ends it:

| `@core` path | Corresponds to |
|----------------|----------------|
| `@core/@env.d` | `env.d` |
| `@core/@env.d/@secrets.d` | `env.d/secrets.d` |
| `@core/@env.d/@secrets.d/@vault` | `env.d/secrets.d` — then the prefixed scope `@vault` |

-----

## 5. Submodules

A submodule is a suffixed directory whose parent is a confirmed module or submodule. The loader's recursive semantics handle submodule loading without any additional mechanism. `@core` represents each as a nested `@*.d/` descendant.

Submodule examples: `aliases.d/extra.d` · `completions.d/hooks.d` · `env.d/color.d` · `init.d/autoload.d` · `init.d/make.d` · `install.d/make.d` · `install.d/update.d` · `plugins.d/history.d`

### 5.1 Comprehensive Example

```text
./                                        ← rings-root ($RING_ROOT)
├── aliases.d/                            ← module
│   └── extra.d/                          ← submodule of aliases.d
├── env.d/                                ← module
│   └── secrets.d/                        ← submodule of env.d
├── functions.d/                          ← module
├── templates.d/                          ← module
├── packages.d/                           ← module
│   ├── secrets.d/                        ← submodule of packages.d
│   ├── @fzf/                             ← prefixed directory (see PACKAGES.md)
│   ├── @terraform/                       ← prefixed directory (see PACKAGES.md)
│   └── @core/                            ← core component
│       ├── @modules/                     ← layer-2 machinery
│       ├── @packages.d/                  ← correspondent → packages.d
│       │   └── @secrets.d/               ← correspondent → packages.d/secrets.d
│       ├── @aliases.d/                   ← correspondent → aliases.d
│       │   └── @extra.d/                 ← correspondent → aliases.d/extra.d
│       ├── @env.d/                       ← correspondent → env.d
│       │   └── @secrets.d/               ← correspondent → env.d/secrets.d
│       ├── @functions.d/                 ← correspondent → functions.d
│       └── @templates.d/                 ← correspondent → templates.d
```

General-purpose packages like `@fzf` and `@terraform` belong at the root of `packages.d` — not inside the `@core` hierarchy. The `@core` tree mirrors the module hierarchy; for package routing semantics, see [`PACKAGES.md`](./PACKAGES.md).

Layer 4 uses the same recursive correspondent-submodule rule. Under the `@packages.d` correspondent chain, `@collections.d` and `@profiles.d` are ordinary correspondent submodules:

```text
packages.d/@core/@packages.d/@collections.d  -> packages.d/collections.d
packages.d/@core/@packages.d/@profiles.d     -> packages.d/profiles.d
```

They are realized as submodules of `packages.d/`, not as new top-level peers of `packages.d/`.

This is not a layer-4-specific exception and not a new module theorem. It is the ordinary recursive rule applied one level deeper beneath `@packages.d`.

-----

## 6. Execution Order

The loader sources `@core` code (layer 2) then `@packages.d` code (layer 3) in a single pass. `@core` acts first; `@packages.d` acts after, using the modules `@core` determined. See [`ARCHITECTURE.md`](./ARCHITECTURE.md) §3.

-----

## 7. Bundled Modules

`@core` ships a default set of module-correspondent directories. Module identity is determined by correspondence and the scanning process, not by this list.

`aliases.d` · `comm.d` · `completions.d` · `config.d` · `database.d` · `env.d` · `functions.d` · `help.d` · `init.d` · `install.d` · `kbd.d` · `network.d` · `options.d` · `packages.d` · `paths.d` · `plugins.d` · `preferences.d` · `prompts.d` · `templates.d` · `venvs.d`

New modules may be added by creating a suffixed directory in rings-root or a correspondent directory under `@core`. Reconciliation creates the counterpart only after approval.

-----

## 8. Module Manifest

A module may declare metadata in `.module` at its root. The file is optional and advisory. `@core` reconciliation remains authoritative.

```toml
[module]
name = "env.d"
provides = ["environment"]
order = 20
description = "Environment variables and exports"
default_ownership = "registry"   # "registry" | "module"
```

Fields:

- `provides`: capability tags used by tooling for ordering and matching
- `order`: integer, lower loads earlier, default 50
- `description`: human note
- `default_ownership`: default module-side ownership policy for routed artifacts

For login-ring startup acceleration, non-interactive reconciliation writes `$PROFILE_D/.modules.json` via `modules::reconcile --check --apply --json`.

-----

## 9. Properties

1. `@core` authoritatively determines which directories are modules.
2. Within any `@core` scope, `@name.d/` signals a module-correspondent directory; `@name/` signals a plain scoped directory.
3. The module set is not fixed — it is determined from `@core`'s hierarchy, reconciled against rings-root at runtime.
4. `@core/@modules/` is layer-2 organizational structure inside reserved `@core`, not a layer-3 package-space rule.
5. Higher layers do not couple to lower ones — the loader does not interpret module or package semantics; `@core` likewise disregards package semantics while determining modules.
6. The outward and inward scans are convergent — repeated reconciliation drives `@core`'s hierarchy and rings-root toward mutual consistency.
7. Module recognition is voluntary — newly discovered suffixed directories result in a proposal, not an automatic change.
8. Submodule depth is unbounded — the `@*.d/` chain traces submodules until the first unsuffixed prefixed child.
