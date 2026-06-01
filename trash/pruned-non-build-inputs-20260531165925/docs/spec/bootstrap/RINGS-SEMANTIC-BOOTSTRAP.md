# Semantic Bootstrap

> **Purpose:** Standalone primer. Read this to orient yourself in the `rings` project — its layered architecture, the bootstrap sequence, and the conventions that make the layers cohere. This is not part of the authority chain; it is what you read to get going.

-----

## 1. Four Layers

Rings has four conceptual layers. Each adds meaning to the one below it. No layer depends on the one above it for its own operation. Removing a higher layer loses that layer's semantics but breaks nothing underneath.

**Layer 0 — Filesystem.** The POSIX tree rooted at `$PROFILE_D` (symlinked from `~/.profile.d`). Suffixed directories (`*.d/`) and `@`-prefixed directories coexist. At this layer they are just directories — no semantics yet.

**Layer 1 — Loader.** `zload` (`io::load::zsh`) and `bload` (`io::load::bash`). Reads `.loadlist` manifests, resolves entries to filesystem paths, sources files. When an entry resolves to a directory, the loader enters it, ensures a `.loadlist` exists, and recurses. It treats suffixed directories (`*.d/`) and prefixed scopes (`@name/`) identically — mechanism only, no module or package semantics.

**Layer 2 — `@core.d`.** Invents the concept of modules. Maps its own `@*.d`-suffixed children to top-level `*.d/` directories in `$PROFILE_D`, creates those directories if they do not exist, cross-enriches them with hidden dotfolder symlinks, and reconciles its internal structure against the filesystem. `@core.d` has no concept of packages. It identifies itself with `$PROFILE_D` — the root — and its `@*.d` children with the root's `*.d/` directories.

**Layer 3 — `@packages.d`.** Invents the concept of packages. Considers every `@`-prefixed scope a package — uniformly, regardless of `.d` suffix. Scans the canonical module set (produced by `@core.d`) to determine projection targets. Projects package artifacts into modules by matching payload-type directories inside packages against the known module set. Manages lifecycle: enable, disable, mute, remove, snap, rollback, inspect. `@packages.d` does not decide what is a module. It receives the canonical module set from `@core.d` and revolves entirely around it.

The filesystem provides structure. The loader provides mechanism. `@core.d` provides module identity. `@packages.d` provides package semantics. Each is self-sufficient at its own layer.

-----

## 2. The `.d`-Suffix Convention

Inside `packages.d/`, all directories are `@`-prefixed. The one-way boundary (§2.1) means that `*.d/` directories inside package-space are payload-type routing signals for projection, not modules. But `@core.d` needs to express module hierarchy inside its own namespace — a space where only `@` scopes exist. The `.d` suffix on `@`-prefixed directory names is that signal.

**Rule.** Within `@core.d`, a child named `@name.d/` is a **module-correspondent**: it maps to a `*.d/` directory in `$PROFILE_D`. A child named `@name/` (no `.d` suffix) is a plain package with no module correspondence.

This convention applies within `@core.d` scopes wherever `@core.d/` appears — including `functions.d/@core.d/`, `aliases.d/@core.d/`, and other sibling-module occurrences, not only `packages.d/@core.d/`. `@packages.d` ignores the `.d` suffix — it treats `@env.d` and `@formatting` identically as packages. The loader also ignores the distinction — it recurses into any directory its `.loadlist` directs it to.

```
packages.d/@core.d/
├── @env.d/                    # module-correspondent → env.d/
├── @aliases.d/                # module-correspondent → aliases.d/
├── @functions.d/              # module-correspondent → functions.d/
├── @packages.d/               # module-correspondent → packages.d/
├── @formatting/               # plain package — no module correspondence
└── @inspect/                  # plain package — no module correspondence
```

**Only `@core.d` uses this convention.** Module creation is `@core.d`'s constitutional prerogative.

### 2.1 The One-Way Boundary

Module-space (`.d/` directories in `$PROFILE_D`) is above package-space (`@`-prefixed scopes). Inside a module, children may be sub-modules (`name.d/`), packages (`@name/`), or files. Inside a package, children may be sub-packages (`@name/`), payload-type directories (`name.d/`, used as projection routing signals), or files. A module never appears inside a package.

No layer enforces this boundary. The loader would recurse into a `*.d/` inside a package if a loadlist told it to. `@core.d` does not police the filesystem. `@packages.d` does not reject malformed structures. The boundary is an emergent property: the loader is not pointed at `*.d/` directories inside packages (no loadlist entries direct it there), `@core.d` does not look for modules inside packages, and `@packages.d` does not interpret `*.d/` inside packages as modules. Each layer simply does not look for the other's structures in the wrong space.

If the user violates this convention — placing a `.loadlist` inside a payload-type `*.d/` within a package and referencing it from a parent loadlist — the loader will recurse into it, `setup_dir` will create a `.loadlist`, and the system will accommodate the structure. `@packages.d` may flag it during reconciliation. The system never prevents, never imposes.

-----

## 3. Submodules

A **submodule** is a `*.d/` directory nested inside a module. `env.d/secrets.d/` is a submodule of `env.d/`. `aliases.d/extra.d/` is a submodule of `aliases.d/`.

### 3.1 Loader Support

The loader supports submodule recursion with no code changes. It recurses into `*.d/` entries at any depth via the same directory dispatch used for top-level directories.

Existing submodules in the live tree — `aliases.d/extra.d/`, `env.d/color.d/`, `init.d/make.d/`, `init.d/autoload.d/`, `install.d/make.d/`, `install.d/update.d/`, `plugins.d/history.d/`, `completions.d/hooks.d/` — confirm that this works today.

### 3.2 Identity

A `*.d/` directory is a module (or submodule) if it has a `.loadlist`. Pragmatically, this means it was listed in a parent's `.loadlist` at some point, since `io::load::setup_dir` creates `.loadlist` on entry. The `.loadlist` is evidence of the declaration — a consequence of having been listed in a parent loadlist — not the declaration itself.

For `@packages.d`'s purposes, testing `[[ -f "$dir/.loadlist" ]]` is a correct and cheap proxy for module identity. A `*.d/` directory that was never listed in any loadlist will not have a `.loadlist` (unless the user created one manually, which is itself a declaration of intent).

### 3.3 Module Children

A module's `.loadlist` may contain:

- `name.d/` — a submodule. The loader recurses into it.
- `@name/` — a package scope. The loader recurses into it.
- `file.sh` — a file. The loader sources it.

All three coexist at any level. There is no mutual exclusion between submodules and packages within a module. The live tree confirms this: `aliases.d/` contains both `extra.d/` (submodule) and `@bash/`, `@yabai/`, `@mac/`, `@functions/` (package scopes).

### 3.4 Representation in `@core.d`

`@core.d` represents the module hierarchy inside its own `@`-only namespace using the `.d`-suffix convention (§2). Submodules are nested `@*.d` children:

```
packages.d/@core.d/
├── @env.d/                         # → env.d/
│   ├── @secrets.d/                 # → env.d/secrets.d/
│   │   └── @vault/                 # package within secrets (no .d → stop)
│   └── @color/                     # package within env (no .d → stop)
├── @aliases.d/                     # → aliases.d/
│   ├── @extra.d/                   # → aliases.d/extra.d/
│   └── @bash/                      # package within aliases (no .d → stop)
└── @functions.d/                   # → functions.d/
```

`@core.d` follows `@*.d` children downward, creating corresponding `*.d/` directories in `$PROFILE_D` at each depth. When it encounters an `@` child without `.d` suffix, it stops — that child is a package, not a module-correspondent. The `.d` suffix chain *is* the module chain. The first `@` without `.d` is the package boundary.

This solves the depth problem without hardcoded limits, marker files, or interactive per-level proposals. The user controls the depth by choosing where to place `.d` suffixes in `@core.d`'s namespace. `@core.d/@env.d/@secrets.d/@vault/` — two levels of modules, then a package. `@core.d/@env.d/@secrets.d/@deep.d/@vault/` — three levels of modules, then a package. The naming convention carries the user's intent.

### 3.5 Projection into Submodules

`@packages.d` determines its projection targets by scanning the canonical module set — the `*.d/` directories (including submodules) established by `@core.d`. This scan is dynamic: `@packages.d` reads the present state of `$PROFILE_D` (or equivalently, `@core.d`'s `@*.d` hierarchy, which should be consistent after reconciliation) each time it runs. No hardcoded module list.

When `@packages.d` examines a package's internal structure, it matches payload-type `*.d/` directories and singleton suffixes against the canonical module set. If `secrets.d/` is a recognized submodule (because `@core.d` established it), a package containing `secrets.d/api-keys.sh` routes that artifact to `env.d/secrets.d/@<pkg>/api-keys.sh`.

If a package contains a `*.d/` directory that does not appear in the canonical module set, `@packages.d` flags it during normalization and asks the user — the same interactive discovery model defined in PACKAGES.md §7.4.

-----

## 4. The Bootstrap Sequence

The four layers execute in order. Each acts on what is present when it wakes. No layer waits for or depends on a higher layer.

### 4.1 Step 1 — The Loader

`profile.sh` detects rings-root, exports `$PROFILE_D`, and invokes the loader. The loader reads `$PROFILE_D/.loadlist`, which lists the top-level `*.d/` directories. The loader enters each, reads its `.loadlist`, recurses into subdirectories and `@` scopes, sources files. By the end of this step, all shell functions — including `@core.d`'s and `@packages.d`'s — are in the running shell.

The loader does not know it just loaded infrastructure that will retroactively interpret the structure it traversed. It sourced files. It is done.

### 4.2 Step 2 — `@core.d` Awakens

`@core.d`'s functions were sourced in step 1. They execute. `@core.d` performs two operations:

**Outward projection — scanning itself.** `@core.d` reads its own children in `packages.d/@core.d/`. Every `@*.d` child is a module-correspondent. For each:

- If the corresponding `*.d/` exists in `$PROFILE_D`: confirm the mapping, enrich with hidden cross-links.
- If it does not exist: create it, add it to the root `.loadlist` if not already present, enrich.
- Recurse into `@*.d` children looking for nested `@*.d` (submodules). Apply the same rule at each depth.

**Inward adoption — scanning `$PROFILE_D`.** `@core.d` scans `$PROFILE_D` for `*.d/` directories (and nested `*.d/` submodules within them). For each:

- If a corresponding `@core.d/@*.d` exists: already mapped. No action.
- If not: propose adoption. "I see `sexy.d/` — create `@core.d/@sexy.d/`?" The user decides.

These two scans converge: after reconciliation, `@core.d`'s `@*.d` hierarchy and `$PROFILE_D`'s `*.d/` hierarchy mirror each other.

`@core.d` identifies itself with `$PROFILE_D`. Its `@*.d` children *are* the root's modules, by declaration. This identification is `@core.d`'s constitutional act — the moment the concept of "module" comes into existence.

`@core.d` has no concept of packages. `@vault/` inside `@core.d/@env.d/@secrets.d/` is a directory `@core.d` does not claim. `@formatting/` inside `@core.d` is a directory without `.d` — not a module, not `@core.d`'s concern. `@core.d` rests.

### 4.3 Step 3 — `@packages.d` Awakens

`@packages.d`'s functions were also sourced in step 1. They execute after `@core.d` has established the canonical module set.

`@packages.d` has one principle: everything `@`-prefixed is a package. No exceptions. No `.d` suffix check. `@packages.d` scans the tree and declares:

- `@core.d` — package.
- `@core.d/@env.d` — subpackage of `@core.d`.
- `@core.d/@env.d/@secrets.d` — subpackage of `@env.d`.
- `@core.d/@env.d/@secrets.d/@vault` — subpackage of `@secrets.d`.
- `@core.d/@formatting` — subpackage of `@core.d`.
- `@terraform` — package.

All packages, uniformly. The `.d` suffix is transparent to `@packages.d`.

`@packages.d` then performs its core function: for each package, it scans for payload-type `*.d/` directories and singleton suffixes inside the package, matches them against the canonical module set (which `@core.d` just produced), and projects artifacts into the corresponding modules. `@terraform/functions.d/plan.sh` → `functions.d/@terraform/plan.sh`. `@vault/secrets.d/api-keys.sh` → `env.d/secrets.d/@vault/api-keys.sh` (if `secrets.d/` is a recognized submodule).

`@packages.d` identifies `packages.d/` with `@core.d/@packages.d`. This is the self-referential moment: `@packages.d` considers the directory it lives in to be both a module (because `@core.d` said so) and the package registry it manages. It considers the other top-level `*.d/` directories to be projections — views of canonical package state. It compromises via reverse projection: where module-centric ownership exists (real files in modules, not symlinks), `@packages.d` records back-symlinks in the registry rather than overwriting. The registry reflects the truth even when it does not localize it.

### 4.4 Coexistence

After both layers have acted:

- `@core.d` owns the module hierarchy. It decides what is a module, what is a submodule, based on `.d` suffixes in its own namespace and `*.d/` directories in `$PROFILE_D`. It cross-enriches. It does not think about packages.
- `@packages.d` owns the package hierarchy. It decides what is a package based on `@` prefixes. It projects, reconciles, manages lifecycle. It does not decide what is a module — it consumes the canonical module set that `@core.d` produced.
- The `@*.d` directories are simultaneously modules (per `@core.d`) and packages (per `@packages.d`). These are not conflicting claims. They are two lenses on the same filesystem. Neither needs the other's vocabulary.
- The loader sees none of this. It sourced files from loadlists.

-----

## 5. Invariants

These are the invariants that hold across the bootstrap.

1. **Module identity is `@core.d`'s prerogative.** No other component creates, removes, or reclassifies modules. `@packages.d` consumes the canonical module set; the loader recurses into whatever it is told to. The user may create `*.d/` directories independently; `@core.d` discovers and proposes adoption.

2. **Within any `@core.d/` scope, the `.d` suffix on a prefixed child signals module correspondence.** Thus `@name.d/` is a module-correspondent package wherever `@core.d/` appears as a package. `@name/` remains a plain package.

3. **The canonical module set is dynamic.** `@packages.d` determines projection targets by scanning the current state of `$PROFILE_D` (or `@core.d`'s `@*.d` hierarchy) each time it runs. No hardcoded module list exists anywhere in the system.

4. **The one-way boundary is emergent.** No layer enforces it. Each layer simply does not look for the other's structures in the wrong space. The system accommodates violations without preventing them.

5. **`@core.d` identifies with the root.** `@core.d`'s `@*.d` hierarchy mirrors `$PROFILE_D`'s `*.d/` hierarchy. Reconciliation converges both directions. After reconciliation, they are consistent.

6. **No layer depends on a higher layer.** Removing `@packages.d` loses package semantics; modules and the loader still work. Removing `@core.d` loses module identity and enrichment; the loader still recurses into `*.d/` directories. Removing the loader... you source files by hand.

7. **No imposition.** `@core.d` proposes adoption of unrecognized `*.d/` directories. The user may decline. Declined directories remain plain scopes — the loader recurses into them, but `@core.d` does not enrich them and `@packages.d` does not treat their internal structure as submodule projection targets.

-----

## 6. Worked Examples

### 6.1 User Creates a Submodule

The user creates `env.d/secrets.d/`, adds `secrets.d/` to `env.d/.loadlist`, and puts `@vault/env.sh` inside `secrets.d/`.

**Loader:** Next shell load, the loader enters `secrets.d/`, `setup_dir` creates `.loadlist`, the loader sources `@vault/env.sh`. Works immediately.

**`@core.d`:** On next reconciliation, `@core.d` scans `$PROFILE_D` and finds `env.d/secrets.d/` — a `*.d/` inside a module with a `.loadlist`. `@core.d` checks whether `@core.d/@env.d/@secrets.d/` exists. It does not. `@core.d` proposes: "I see `secrets.d/` inside `env.d/`. Create `@core.d/@env.d/@secrets.d/`?" User accepts. `@core.d` creates the mapping and enriches `secrets.d/` with hidden cross-links.

**`@packages.d`:** On next run, `@packages.d` scans the canonical module set and finds `secrets.d/` as a recognized submodule. If any package contains `secrets.d/` as a payload-type directory, `@packages.d` can now project into `env.d/secrets.d/`.

### 6.2 `@core.d` Creates a Module from Its Own Structure

A developer adds `@core.d/@help.d/` to `packages.d/@core.d/`, containing help-system functions and documentation artifacts.

**`@core.d`:** On next reconciliation, `@core.d` scans itself and finds `@help.d/` — an `@*.d` child. It checks whether `help.d/` exists in `$PROFILE_D`. It does not. `@core.d` creates `help.d/`, adds `help.d/` to the root `.loadlist`, and enriches all existing modules with `.help` hidden cross-links (`aliases.d/.help → help.d/@core.d/@aliases.d`, etc.).

**Loader:** Next shell load, the loader finds `help.d/` in the root `.loadlist`, enters it, recurses. The help system is active.

**`@packages.d`:** Sees `@core.d/@help.d` as a package. Scans the canonical module set and finds `help.d/` as a recognized module. Any package with `help.d/` payload-type content can now project there.

### 6.3 The Full Mirror

After complete reconciliation, `@core.d`'s internal structure and `$PROFILE_D` mirror each other:

```
$PROFILE_D/                          packages.d/@core.d/
├── env.d/                    ↔      ├── @env.d/
│   ├── secrets.d/            ↔      │   ├── @secrets.d/
│   │   └── @vault/           ↔      │   │   └── @vault/
│   └── @history/             ↔      │   └── @history/
├── aliases.d/                ↔      ├── @aliases.d/
│   ├── extra.d/              ↔      │   ├── @extra.d/
│   └── @bash/                ↔      │   └── @bash/
├── functions.d/              ↔      ├── @functions.d/
├── packages.d/               ↔      ├── @packages.d/
├── help.d/                   ↔      ├── @help.d/
├── completions.d/            ↔      ├── @completions.d/
└── config.d/                 ↔      └── @config.d/
```

Left: module-space. `*.d/` = module or submodule. `@name/` = package.

Right: package-space. Everything `@`-prefixed. `.d` suffix = module-correspondent. No `.d` = plain package.

`@core.d` reads the right column and materializes the left. It reads the left column and reconciles the right. After convergence, the two are structurally isomorphic — the same hierarchy expressed in two notations, one for each layer's native grammar.

`@packages.d` reads the right column as packages and the left column as projection targets. It never decides which `*.d/` directories exist — that decision was made by `@core.d` and the user together.

The loader reads the left column via `.loadlist` manifests and sources files. It has no awareness of the right column. The right column's existence is invisible to it — projection produces symlinks that the loader follows transparently.
