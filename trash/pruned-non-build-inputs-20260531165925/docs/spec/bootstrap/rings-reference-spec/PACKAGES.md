# PACKAGES — Layer 3: Package Semantics

> **Status:** Specification (pre-implementation).
> **Scope:** Package semantics over canonical modules — the registry, routing, ownership, normalization, lifecycle, facets, and consolidation.
> **See also:** [`ARCHITECTURE.md`](./ARCHITECTURE.md) · [`LOADER.md`](./LOADER.md) · [`MODULES.md`](./MODULES.md)

-----

## 1. Motivation

A module is a unit of decomposition — `env.d`, `aliases.d`, `functions.d` together partition rings-root by category. The consequence is that artifacts for the same logical concern end up distributed: `@terraform`'s aliases live in `aliases.d`, its env variables in `env.d`, its functions in `functions.d`:

```
./aliases.d/@terraform/aliases.zsh
./completions.d/@terraform/completion.zsh
./env.d/@terraform/env.sh
./functions.d/@terraform/plan.sh
```

No single location answers "what does `@terraform` own?" and no single operation manages its lifecycle across modules. `packages.d` addresses this: a module-level registry where every package's artifacts are consolidated under one namespace.

```
./packages.d/@terraform/
├── aliases.zsh
├── completions.d/
│   └── completion.zsh
├── env.sh
└── functions.d/
    └── plan.sh
```

A package is a unit of consolidation. Keeping a package's actual files in `./packages.d/` and fanning-out symlinks into the respective modules is **projection**. Keeping the files in the module and fanning-in back-symlinks in `./packages.d/` is **reverse projection**. Both directions, and the system managing them, constitute **routing**.

The loader (layer 1) and `@core` (layer 2) are prerequisites — the loader enables recursive sourcing of directories and follows symlinks transparently; `@core` determines which directories are modules. `@packages.d` builds on both.

-----

## 2. Definitions

**Package.** A `@`-prefixed directory. Every prefixed directory is a package regardless of suffix. `@terraform`, `@core`, `@mine/@own` are packages; `@mine` and `@own` are package and subpackage respectively.

**Subpackage.** A package whose immediate parent is also a package.

**Organizing segment.** A literal `_` path segment used to group files without changing package scope. Organizing segments are erased when deriving package identity, callable namespace, lifecycle scope, and ownership scope.

**Registry.** `packages.d` — the module that consolidates all packages. It reflects the broader filesystem when consistent, and is expected to drift from it in normal operation, before reconciliation.

**Artifact.** Any file or unprefixed unsuffixed folder in the rings tree — an alias script, an env file, a function, a completion, a config, a binary.

**Ownership.** Exactly one location holds an artifact's actual file content at any given time; all other locations hold symlinks. An artifact is **registry-owned** when its content lives in `./packages.d/`; **module-owned** when it lives in the module.

**Modular component.** A suffixed, module-correspondent directory inside a package — the primary routing signal. `@terraform/aliases.d/` is a modular component naming `aliases.d` as the routing target. A modular component is not a module.

**Routing signal.** Any directory or filename convention inside package-space naming a module endpoint. Modular components are the primary form; singleton suffixes (§3.2) are the secondary form.

**Routing target.** The module location receiving routed artifacts: `./aliases.d/@terraform/` for a `@terraform/aliases.d/` modular component.

**Equivalent materializations.** Registry seats and module seats are co-equal filesystem materializations of the same package-scoped artifact. A registry-owned artifact stores real bytes in `packages.d` and projects into a module. A module-owned artifact stores real bytes in the module and back-symlinks into `packages.d`. Neither seat outranks the other when deriving package scope.

Three seats / views at a glance:

```text
Registry seat
  packages.d/@git/aliases.zsh

Projected module view, registry-owned
  aliases.d/@git/aliases.zsh
    → symlink to packages.d/@git/aliases.zsh

Projected module view, module-owned
  aliases.d/@git/aliases.zsh        # real file
  packages.d/@git/aliases.zsh
    → back-symlink to module file
```

**Projection (fan-out).** Actual files in `./packages.d/`; symlinks in modules pointing into the registry.

```
./packages.d/@git/aliases.zsh        # real file
./aliases.d/@git/aliases.zsh         # → ../../packages.d/@git/aliases.zsh
```

**Reverse projection (fan-in).** Actual files in the module; back-symlinks in `./packages.d/` pointing into the module.

```
./aliases.d/@git/aliases.zsh         # real file
./packages.d/@git/aliases.zsh        # → ../../aliases.d/@git/aliases.zsh
```

**Routing.** The full system of projecting and reverse-projecting package artifacts between `packages.d` and their module targets.

**Packaging.** Consolidating artifacts from across modules into a unified package representation in the registry. May be done by moving file content into `./packages.d/` (fan-in move, then fan-out projection), or by keeping content in place and recording back-symlinks in the registry (fan-in only). Not to be confused with consolidation of facets into a proper package (§14).

**Normalization.** Transforming arbitrary input — external plugins, flat files, unstructured directories — into the canonical package grammar. Idempotent, convergent, non-destructive.

```
# Before:
~/downloads/some-zsh-plugin/
├── plugin.zsh
├── functions/auth.zsh
└── completions/_some-tool

# After packages::normalize ~/downloads/some-zsh-plugin/:
./packages.d/@some-zsh-plugin/
├── plugin.zsh
├── functions.d/
│   └── auth.zsh
└── completions.d/
    └── _some-tool
```

**Ghost.** A symlink whose target path resolves to nothing — it points at something that no longer exists (i.e. a broken symlink). Ghosts are detected during projection and reconciliation; pruning is never silent.

**Orphan.** A node that had inbound references and no longer has them.

**Widow.** A node that had an outbound reference and no longer has it.

Ghosts, orphans, and widows are distinct: a ghost is an existing invalid symlink; orphan and widow describe lifecycle states implying prior valid linkage.

**Proper package.** `@P`'s root-level occurrence in a given module. In the registry: `packages.d/@P`. In `aliases.d`: `aliases.d/@P`. "Proper" means `@P` appears at root level in that module, not nested under another package.

**Facet.** An occurrence of `@P` outside its proper package — a `@P` subpackage nested under some other proper package in the same module. The path prefix preceding `@P` is the **prefixed-scope**. When `@P` appears more than once in a path, the outermost occurrence identifies the facet; inner occurrences are part of its subtree.

```
./aliases.d/@bash/                  # @bash is proper in aliases.d
./aliases.d/@git/@bash/             # @bash is a facet; prefixed-scope = @git
./aliases.d/@terraform/@bash/       # @bash is a facet; prefixed-scope = @terraform
./aliases.d/@X/@Y/@bash/a/@bash/b   # one facet; prefixed-scope = @X/@Y; subtree includes inner @bash
```

**Focus.** The interpretive context for a namespace query. When `@P` is in focus, every occurrence of `@P` anywhere in the tree is relevant to `@P`. A path `./module.d/@A/@B` is simultaneously a subpackage of `@A` (when `@A` is in focus) and a facet of `@B` (when `@B` is in focus).

**Consolidation.** Gathering selected facets into `@P`'s proper package. Explicit and user-driven. Two modes: `--project` creates symlinks in the proper package without moving file content; `--reverse-project` moves content and creates backlinks at origin.

**Flat convenience view.** An optional symlink with a flattened filename that a user may reference in a loadlist. Never canonical; never replaces the structured projection.

```
# Structured (canonical):
./aliases.d/@terraform/@cloud/aliases.zsh

# Flat convenience view (optional, alongside):
./aliases.d/cloud.terraform.aliases.zsh    # → @terraform/@cloud/aliases.zsh
```

**External stow linking.** Module-specific downstream linking from a module to external system paths — separate from routing, not part of the core model. Example: `./config.d/@yabai/yabairc` → `~/.config/yabai/yabairc`. See §11.

-----

## 3. Package Grammar

### 3.1 Package Root

```
packages.d/@pkg[/@subpkg/...]
```

Every `@`-prefixed segment is a package or subpackage. Depth is arbitrary; nesting encodes grouping, versioning, sub-tool decomposition — entirely at the user's discretion. A parent may hold its own artifacts alongside subpackage directories. Deleting a parent deletes its subpackages.

The literal `_` segment may appear between package segments. It organizes the filesystem tree and does not create package scope.

```text
@a/_/@b
@a/_/_/@b
```

derive the same package scope:

```text
@a/@b
```

No other underscore-bearing segment has this rule. `___`, `_helpers_`, and `helpers_` are ordinary path names, not organizing segments.

**Private packages.** A package whose name begins with `_` — such as `@_schema` or `@_backend` — is private: not part of the public surface and not intended for use outside the owning package. The `@_` prefix is an ordinary `@`-prefixed name; it has no relation to the bare `_` organizing-segment rule.

All `@`-prefixed namespaces follow the same grammar — `@bash`, `@core`, `@terraform` are treated identically by the routing system. The only explicit special cases for `@core` are: hidden dotfolder enrichment (§9.2) and the module-correspondent `.d`-suffix convention ([`MODULES.md`](./MODULES.md) §4).

**Manifest and metadata boundary.** The canonical manifest lives at `packages.d/@pkg/.package` and defines id, version, ownership, provides, depends, hosts, stow, lifecycle, and origin. `.package` is package identity and manifest; `.env` is directory-local rings metadata read by the loader when entering a directory; `env.d` holds durable exported environment artifacts. `[stow]` in `.package` may be a simple target list or a richer per-target options table.

**Module discovery.** The module space is open-ended. A module is recognized when a `<module>.d/` directory exists in `$RING_ROOT` or a singleton payload names it. Users can define their own modules (`cloud.d/`, `secrets.d/`, etc.) and the routing engine discovers them by scanning `*.d/` directories — it does not hardcode a routing table. If a singleton names a module that does not yet exist, routing is confirmed interactively during normalization.

```
./packages.d/@hashicorp/
├── @terraform/
│   ├── aliases.d/
│   │   └── aliases.zsh
│   └── env.sh
├── @vault/
│   └── aliases.zsh
└── env.sh               # @hashicorp's own artifact
```

Shell-specific sub-namespaces use standard `@pkg/@subpkg` grammar. A bash-only completion for `@terraform` lives at `./packages.d/@terraform/@bash/completions.bash` and projects to `./completions.d/@terraform/@bash/completions.bash`.

### 3.2 Payload Representation

An artifact inside a package takes one of two forms:

**(A) Singleton.** A single file at the package root with a module-correspondent basename:

```
./packages.d/@docker/env.sh
./packages.d/@git/aliases.zsh
```

**(B) Modular component (promoted).** A suffixed, module-correspondent directory containing one or more artifacts:

```
./packages.d/@docker/env.d/env.sh
./packages.d/@docker/env.d/secrets.sh
```

The two forms are mutually exclusive within a package for the same payload class — `env.sh` and `env.d/` cannot coexist in the same package. In the module view, `./env.d/@docker/env.sh` is valid — that `env.d/` is the module directory, not a modular component inside the package.

A singleton may also be the collapsed form of a same-named subpackage leaf. For a singleton-eligible concern named `tool`, these forms are equivalent representations of the same concern:

```text
packages.d/@pkg/tool.sh
packages.d/@pkg/@tool/tool.sh
```

The root file is the collapsed singleton form. The subpackage path is the promoted form. Promotion remains identity-retaining: `tool.sh` promotes to `@tool/tool.sh`, not to `@tool/main.sh`.

If both forms exist for the same concern, reconciliation treats them as a collision between equivalent representations, not as two independent package identities.

### 3.3 Singleton Eligibility

Singleton collapse is the default; directory-only is the exception. The exceptions:

- `config.d/` — application configuration tree
- `meta.d/` — package metadata
- `data.d/` — static data payloads

Everything else — including user-defined modules — is singleton-eligible. Singleton eligibility does not imply automatic module creation; if the corresponding module does not exist, routing is confirmed interactively during normalization.

### 3.4 Promotion

When a singleton gains additional artifacts, it promotes to modular component form. Promotion is **identity-retaining** — `env.sh` becomes `env.d/env.sh`, never `env.d/main.sh` — and follows a stage → commit pattern:

```
# Before:
./packages.d/@pkg/env.sh

# After:
./packages.d/@pkg/env.d/env.sh
./packages.d/@pkg/env.d/credentials.sh
```

When multiple artifacts claim the same singleton slot, promotion to modular component form is the preferred resolution.

-----

## 4. Ownership

Ownership is per artifact, not per package. A single package may have some artifacts registry-owned and others module-owned. Ownership is decided by where the real files for a given artifact or file group will be edited and inspected — not by package name.

**Registry-owned.** Actual file in `./packages.d/`; module contains a symlink.

```
./packages.d/@terraform/aliases.zsh        # real file
./aliases.d/@terraform/aliases.zsh         # → ../../packages.d/@terraform/aliases.zsh
```

**Module-owned.** Actual file in the module; `./packages.d/` contains a back-symlink.

```
./aliases.d/@terraform/aliases.zsh         # real file
./packages.d/@terraform/aliases.zsh        # → ../../aliases.d/@terraform/aliases.zsh
```

Both modes coexist naturally. Tools may default to registry-owned placement for newly created artifacts when no more specific policy is present. That default does not give registry-owned any higher semantic status than module-owned.

Registry-owned placement applies when `packages.d` is the authoring and inspection location for that file group. Module-owned placement applies when the module directory is.

Examples:

- Alias files edited in `aliases.d/@pkg/` → module-owned.
- Function files edited in `functions.d/@pkg/` → module-owned.
- A file group authored in `packages.d/@pkg/` → registry-owned.

**`.loadlist` files are artifacts.** A `.loadlist` file is an artifact like any other file. Ownership is decided per `.loadlist`, not by special case.

For each `.loadlist`, only one path holds the real bytes. Any corresponding path is a projection or reverse-projection of that same `.loadlist` artifact.

This rule applies both to:

- package-internal `.loadlist` files inside a package tree
- module-correspondent `.loadlist` files such as `env.d/.loadlist` and `packages.d/@core/@env.d/.loadlist`

Choose ownership by deciding where the real `.loadlist` should be edited.

The reason is simple:

- the same tree must load the same way regardless of which corresponding path reaches it
- corresponding paths must not change recursion or source order
- if two corresponding `.loadlist` paths contain different bytes, they do not represent the same loading behavior

**Ownership resolution — most-specific explicit policy wins.**

1. **Per artifact.** A sidecar or manifest override for one artifact.
2. **Per package.** `[ownership] default = "registry" | "module"` in `packages.d/@pkg/.package`.
3. **Per module.** `default_ownership` in `.module` (see [`MODULES.md`](./MODULES.md) §8), or equivalent directory-local policy in `.env`.

Migration note: older trees may still use the former `PACKAGES_OWNERSHIP` / `.envrc` convention. That mechanism is superseded by explicit ownership policy in `.package`, `.module`, and directory-local `.env` metadata.

Implementations may also treat existing on-disk ownership as observed state during reconciliation, but explicit policy resolves in the order above.

Interactive override (`--module` / `-m`, `--registry` / `-r`) wins for the current operation.

```
# @terraform: aliases.d prefers module-owned; functions.d and completions.d registry-owned.

./aliases.d/@terraform/aliases.zsh          # real file (module-owned)
./packages.d/@terraform/aliases.zsh         # back-symlink

./functions.d/@terraform/plan.sh            # symlink (registry-owned)
./packages.d/@terraform/functions.d/plan.sh # real file

./completions.d/@terraform/completion.zsh   # symlink (registry-owned)
./packages.d/@terraform/completions.d/completion.zsh  # real file
```

In practice, ownership decides where the actual bytes live. That determines where an artifact is naturally edited, inspected, and reconciled.

-----

## 5. Projection Rules

Projection reconciles equivalent materializations. The registry seat and the module seat are co-equal views of the same package-scoped artifact.

For example:

```text
packages.d/@a/_/@d/functions.d/tool.sh
functions.d/@a/@d/tool.sh
```

refer to the same artifact when `functions.d/` routes to the functions module and `_` is erased from package scope.

The registry path is useful for consolidation and lifecycle. The module path is useful for loading, editing, and module-local ownership. Ownership decides which seat holds the real bytes; it does not change package scope.

### 5.1 Structured Projection

The modular component (or singleton suffix) determines the target module and is stripped during projection.

```
# Singleton:
./packages.d/@docker/env.sh          → ./env.d/@docker/env.sh
./packages.d/@git/aliases.zsh        → ./aliases.d/@git/aliases.zsh

# Modular component:
./packages.d/@docker/env.d/env.sh    → ./env.d/@docker/env.sh
./packages.d/@docker/env.d/secrets.sh → ./env.d/@docker/secrets.sh

# Deep namespace (full prefixed-scope mirrored):
./packages.d/@hashicorp/@terraform/aliases.d/aliases.zsh
→ ./aliases.d/@hashicorp/@terraform/aliases.zsh
```

### 5.2 Submodule Routing

```
./packages.d/@vault/env.d/secrets.d/api-keys.sh
→ ./env.d/secrets.d/@vault/api-keys.sh
```

If the submodule does not exist, the system confirms interactively whether to create it.

### 5.3 Directory Semantics

`@pkg-namespace/` directories in projected paths are real directories created on demand. Only leaf artifacts are symlinked. Empty `@pkg-namespace/` directories are removed during reconciliation.

### 5.4 Projection Modes

Leaf projection is the default mode. Tree projection is allowed only as explicit opt-in with `projection.mode = "tree"`.

Tree mode mounts a whole subtree as a symlinked directory and therefore weakens the semantic boundary between projected module space and package space. It is appropriate only for whole-unit subtrees that are not expected to grow module-local structure, scoped overlays, or later fine-grained reconciliation.

If a folded subtree contains `.env` or `.loadlist`, that is syntactically valid but semantically warning-worthy: those files indicate local module structure that tree folding erodes. `packages::plan` must warn when it encounters folded trees.

### 5.5 Reconciliation States

| State | Action |
|-------|--------|
| Valid symlink, correct target | No-op |
| Symlink exists, target missing (ghost) | Warn, prompt before pruning |
| No symlink, registry artifact exists | Create symlink |
| Symlink target differs from canonical | Repair |
| Real file where symlink expected | Report collision, ask user |

Ghost pruning is never silent.

### 5.6 Flat Convenience Views

Flat views are optional injective flattenings of an artifact's path — additional symlinks, never replacements, never canonical.

Naming rule: reverse namespace segments, join with dots, append module type — most specific first:

```
./aliases.d/@terraform/@cloud/aliases.zsh          # canonical
./aliases.d/cloud.terraform.aliases.zsh            # flat view → @terraform/@cloud/aliases.zsh
```

Loadlist entries referencing flat views are updated when the underlying artifact moves.

### 5.7 Comprehensive Example

Registry view — showing package anatomy, modular components, singletons, and subpackages:

```text
./packages.d/                             ← registry (module)
├── @terraform/                           ← package
│   ├── aliases.zsh                       ← singleton (suffix names target: aliases.d)
│   ├── env.sh                            ← singleton (suffix names target: env.d)
│   ├── completions.d/                    ← modular component → completions.d
│   │   └── _terraform                    ← artifact
│   └── functions.d/                      ← modular component → functions.d
│       ├── plan.sh                       ← artifact
│       └── fmt.sh                        ← artifact
├── @hashicorp/                           ← package
│   └── @vault/                           ← subpackage of @hashicorp
│       └── env.d/                        ← modular component → env.d
│           └── api-keys.sh               ← artifact
└── @core/                              ← core package (see MODULES.md for correspondent semantics)
    ├── @aliases.d/                       ← module-correspondent package
    └── @formatting/                      ← plain package (no .d suffix → no module correspondence)
```

Module-side view — showing where projections land and the two ownership directions:

```text
./aliases.d/                              ← module (routing target)
├── @terraform/                           ← package
│   └── aliases.zsh                       ← symlink → ../../packages.d/@terraform/aliases.zsh (registry-owned)
├── @git/                                 ← package
│   └── aliases.zsh                       ← real file (module-owned; back-symlink in registry)
├── @bash/                                ← package (proper in aliases.d)
└── @dev/                                 ← package
    └── @bash/                            ← facet of @bash; prefixed-scope = @dev

./env.d/                                  ← module (routing target)
├── @terraform/                           ← package
│   └── env.sh                            ← symlink → ../../packages.d/@terraform/env.sh
└── secrets.d/                            ← submodule
    └── @vault/                           ← package (routed into submodule; §5.2)
        └── api-keys.sh                   ← symlink → ../../../packages.d/@hashicorp/@vault/env.d/api-keys.sh

./functions.d/                            ← module (routing target)
└── @terraform/                           ← package
    ├── plan.sh                           ← symlink → ../../packages.d/@terraform/functions.d/plan.sh
    └── fmt.sh                            ← symlink → ../../packages.d/@terraform/functions.d/fmt.sh
```

-----

## 6. Operations

All mutating operations follow a uniform model: interactive walkthrough → compiled plan → confirmation → execution with backups. `--dry-run` stops after the plan. `--yes` skips confirmation.

`packages::plan --json` emits the versioned plan document that `packages::apply --from <file>` consumes. That document is the contract between planning and execution, validates against `spec/schemas/plan-v1.json`, and is the only machine contract between planning and apply time. Free-text output is a rendering for humans. Operations are structured, not narrative:

```json
{
  "op": "symlink_create",
  "src": "packages.d/@bash/aliases.zsh",
  "dst": "aliases.d/@bash/aliases.zsh",
  "owner": "registry",
  "context": ["package", "projection"],
  "mode": "leaf"
}
```

Allowed `op` values include `symlink_create`, `symlink_remove`, `dir_create`, `file_move`, `stow_external`, `unstow_external`, and `hook_run`. Optional `"note"` may carry human text, but tools must not depend on it.

### 6.1 Packaging (Fan-In)

Move artifacts from a module into `./packages.d/`. Leave symlinks at original locations.

```
$ packages::package aliases.d/@terraform/

── Discovery ──
  ./aliases.d/@terraform/aliases.zsh
    → Package: @terraform | Payload: aliases.d (singleton eligible)
    → Canonical: ./packages.d/@terraform/aliases.zsh
    Accept? [Y/n]

── Plan ──
  Move:        ./aliases.d/@terraform/aliases.zsh → ./packages.d/@terraform/aliases.zsh
  Create link: ./aliases.d/@terraform/aliases.zsh → ../../packages.d/@terraform/aliases.zsh
  Loadlist:    no change (@terraform/ entry resolves via symlink)

  Execute? [Y/n]
```

If the original path was in a loadlist, the symlink preserves it — no edit needed. If normalization changes the filename, the reference is updated with a backup.

### 6.2 Projection (Fan-Out)

Create symlinks in modules pointing to artifacts in `./packages.d/`.

```
$ packages::project @terraform

── Plan ──
  ./packages.d/@terraform/aliases.zsh
    → ./aliases.d/@terraform/aliases.zsh     (module-owned; aliases.d prefers module)
  ./packages.d/@terraform/completions.d/completion.zsh
    → ./completions.d/@terraform/completion.zsh  (symlink)
  ./packages.d/@terraform/functions.d/plan.sh
    → ./functions.d/@terraform/plan.sh           (symlink)

  Execute? [Y/n]
```

Projection never adds loadlist entries. Activation is the user's decision — see `packages::enable`, §8.2.

### 6.3 Reverse Projection

Move file content from `./packages.d/` to module locations; replace registry entries with back-symlinks.

```
$ packages::reverse-project @terraform

── Plan ──
  Move: ./packages.d/@terraform/functions.d/plan.sh → ./functions.d/@terraform/plan.sh
  Back-symlink: ./packages.d/@terraform/functions.d/plan.sh → ../../../functions.d/@terraform/plan.sh

  Skipping: aliases.zsh (already module-owned)

  Execute? [Y/n]
```

### 6.4 Normalization

Transform arbitrary input into the canonical package grammar. See §7 for input recognition rules.

```
$ packages::normalize ~/downloads/some-zsh-plugin/

── Discovery ──
  plugin.zsh          → plugins.d/ entry point       Accept? [Y/n]
  functions/auth.zsh  → functions.d/ artifact         Accept? [Y/n]
  completions/_tool   → completions.d/ artifact        Accept? [Y/n]
  README.md           → data.d/ (unknown, preserved)   Accept, or assign? [Y/module]
  Namespace: @some-zsh-plugin (from directory name)    Accept or rename? [Y/rename]

── Plan ──
  ./packages.d/@some-zsh-plugin/
  ├── plugin.zsh              → ./plugins.d/@some-zsh-plugin/plugin.zsh
  ├── functions.d/auth.zsh   → ./functions.d/@some-zsh-plugin/auth.zsh
  ├── completions.d/_tool     → ./completions.d/@some-zsh-plugin/_tool
  └── data.d/README.md

  Execute? [Y/n]
```

Properties: idempotent · safe (backups) · atomic (stage → commit or revert) · convergent · non-destructive (unknown files go to `data.d/`, never discarded).

### 6.5 Reconciliation

Validate consistency of the registry and all projections.

```
$ packages::reconcile

── Registry ──
  ✓ @terraform/aliases.zsh → ./aliases.d/@terraform/aliases.zsh (valid)
  ✗ @docker/aliases.zsh → target missing
    → Prune ghost symlink? [Y/n/skip]

── Modules ──
  ✓ ./aliases.d/@git/aliases.zsh → ./packages.d/@git/aliases.zsh (valid)
  ⚠ ./functions.d/@terraform/plan.sh is a real file (expected symlink)
    → Drift detected. Fan-in to restore registry ownership? [Y/n/skip]

── Loadlists ──
  ✓ aliases.d loadlist: all entries resolve
  ⚠ completions.d loadlist:8: @docker/ → target missing
    → Remove stale entry? [Y/n]
```

Optionally scoped: `packages::reconcile aliases.d` · `packages::reconcile @terraform` · `packages::reconcile aliases.d/@git/aliases.zsh`.

### 6.6 Chain Resolution

When the artifact being packaged is itself a symlink, its content may already sit at the end of a chain. In a chain `A → B → C (content)`: A is the entry point, C holds the content, B is intermediate.

A link resolving outside any module or `./packages.d/` is externally managed — its content lives outside rings-root.

**Package by reference.** The registry entry is a symlink to B. The chain is preserved through the registry.

```
# Before: A → B → C (content)
# After:  A → registry → B → C (content)
```

**Package by copy.** C's content is copied into the registry as an independent file. A is redirected; B is orphaned.

```
# After:  A → registry (copy of C's content)
# B is now an orphan.
```

The user always chooses:

```
  Package by:
    (r) Reference — registry points to B; A stays linked through B.
    (c) Copy — content copied into registry; A becomes independent; B will be orphaned.
    (s) Skip
    Choose [r/c/s]:
```

Chain operation properties:

- Reference packaging creates no orphans or ghosts.
- Copy packaging orphans B.
- Ghost propagation is transitive — deleting a mid-chain node makes everything upstream a ghost.
- No moves when chains exist.
- No operation modifies anything it does not own.

-----

## 7. Input Recognition

The normalizer infers module targets from filename conventions; when it cannot infer, it asks.

| Input | Inferred target |
|-------|----------------|
| `*-aliases.{zsh,bash,sh}`, `*.aliases.*` | `aliases.d` |
| `*-env.sh`, `*.env.sh` | `env.d` |
| `plugin.zsh` | `plugins.d` |
| `_*` (underscore-prefixed) | `completions.d` (confirmed) |
| `functions/`, `functions.d/` | `functions.d` |
| `bin/` | executable payload |
| extensionless `+x` file | `bin` candidate (confirmed) |
| `config/`, `config.d/` | `config.d` |
| `install.sh`, `install/` | `install.d` |
| `package.toml`, `package.json` | boundary marker only; not a rings artifact |

Namespace inference from flat filenames:

```
git-aliases.zsh              → @git        (split before known suffix)
docker-compose-aliases.zsh   → @docker-compose (best guess; confirmed)
```

All accepted inputs normalize to the canonical grammar — no exceptions. Users may propose any module name; if it does not exist, the system creates it.

-----

## 8. Command Interface

All commands live in the `packages::` namespace. `pkgs::` is a convenience functional alias. Every `packages::` function supports `--help`.

### 8.1 Structural Operations

**`packages::project <pkg>`** — Fan-out. Create relative symlinks from `./packages.d/@pkg/` into modules (§5.1). Respects per-module ownership preferences (§4).

**`packages::project::hidden <pkg>`** — Create hidden dotfolder cross-links for `@core` module enrichment (§9.2). `@core`-only; separate from general projection.

**`packages::reverse-project <pkg>`** — Move file content from registry to modules; replace registry entries with back-symlinks.

**`packages::package <path>`** — Fan-in. Move artifacts from a module into `./packages.d/`; leave symlinks at original locations.

**`packages::normalize <path>`** — Canonicalize arbitrary input (§6.4, §7).

**`packages::plan [<scope>] --json`** — Compile a versioned plan document without mutating the tree.

**`packages::apply --from <file>`** — Apply a previously generated plan document after schema validation.

**`packages::stow <pkg>`** — Perform rings-level external materialization from declared `[stow]` targets. This is not a GNU Stow wrapper; the semantic center is external materialization from ring-owned artifacts.

**`packages::reconcile [<scope>]`** — Validate and repair projections, back-symlinks, ghosts, and stale flat views. Reports broken loadlist references.

**`packages::make-flat <pkg> [<module>]`** — Generate flat convenience view symlinks (§5.6).

**`packages::register <path>`** — Front door for importing artifacts. Orchestrates discovery, classification, and delegation:
1. Already in `./packages.d/` → skip.
2. Module artifact → infer `@namespace`, delegate to `packages::package`.
3. External or unstructured → delegate to `packages::normalize`.
4. After placement, propose projection and enablement (gated by confirmation or `--enable`).

Loadlist entries are never added implicitly.

### 8.2 Lifecycle Operations

**`packages::enable <pkg>`** — Append the minimal missing loadlist entries to make the package reachable. Additive, recursive, minimal — the only operation that adds new loadlist entries.

```
$ packages::enable @terraform

── Plan ──
  Append to aliases.d loadlist:      @terraform/
  Append to completions.d loadlist:  @terraform/
  Append to functions.d loadlist:    @terraform/
  (env.d/@terraform/env.sh already reachable)

  Execute? [Y/n]
```

**`packages::mute <pkg>`** — Runtime-only suppression for the current session. Unalias, unbind, unfunction. No filesystem changes. Effects return on next session.

**`packages::disable <pkg>`** — Remove matching loadlist entries across modules. Backs up each loadlist before editing. Does not delete artifacts or symlinks.

**`packages::remove <pkg>`** — Disable + delete artifacts and projections.

Permanence gradient: `mute (session) → disable (future sessions) → remove (delete)`.

Lifecycle hooks are declared in `.package` and run in order. Failure stops the sequence unless the hook entry carries a `?` suffix for best effort.

Hook resolution rules:

- `namespace::verb` resolves to a callable rings function after load
- `./path` is authored relative to `packages.d/@pkg/` and resolved through actual ownership and projection state at execution time
- bare words are allowed; `packages::plan` resolves them to absolute executable paths and records both the token and the resolved path, and `packages::apply` executes the recorded path rather than performing a fresh `PATH` lookup

### 8.3 Acquisition

**`packages::install [<spec>]`** — Dispatcher:
1. If `<pkg>::install` is defined → dispatch to it.
2. Else if a manifest entry exists → dispatch to the declared backend.
3. Else → error.

`<pkg>::install` acquires artifacts; `<pkg>::init` configures the environment. See [`INSTALL.md`](./modules/INSTALL.md) for manifest format and backend implementations.

**`packages::check [<spec>]`** — Report installation status using the same resolution.

### 8.4 Snapshots and Remotes

**`packages::snap [<message>]`** — git-backed snapshot of rings state.

**`packages::rollback`** — Restore the previous snapshot.

**`packages::push <pkg> <remote>`** — Synchronize a package's reconciled representation to a configured rings remote for another device or environment. It is not a public publishing verb.

### 8.5 Introspection

**`packages::ls`** — List all packages with ownership mode per artifact.

**`packages::inspect <pkg>`** — Full package state: registry paths, projections, back-symlinks, loadlist references, flat views.

```
$ pkgs::inspect @terraform

  ── Registry ──
    ./packages.d/@terraform/
    ├── aliases.zsh          → ./aliases.d/@terraform/aliases.zsh (back-symlink)
    ├── completions.d/
    │   └── completion.zsh   (real file → ./completions.d/@terraform/completion.zsh)
    ├── env.sh               → ./env.d/@terraform/env.sh (back-symlink)
    └── functions.d/
        └── plan.sh          (real file → ./functions.d/@terraform/plan.sh)

  ── Loadlist references ──
    aliases.d loadlist:5        @terraform/
    completions.d loadlist:12   @terraform/
    functions.d loadlist:8      @terraform/
```

Every `--json` form wraps its command-specific payload in a versioned envelope:

```json
{
  "schema_version": "1",
  "command": "packages::where",
  "package": "@bash",
  "generated_at": "2026-04-14T09:00:00Z",
  "data": {}
}
```

Examples:

- `packages::where --json` emits `data.occurrences`
- `packages::facets --json` emits `data.facets`
- `packages::doctor --json` emits `data.violations`

### 8.6 Universal Flags

`--help` · `--dry-run` · `--yes` · `--verbose`

-----

## 9. The `@core` Package

Rings itself is a package. `./packages.d/@core/` contains rings' own infrastructure — loader helpers, routing functions, introspection tools, and per-module management. Its module-determination semantics are in [`MODULES.md`](./MODULES.md); this section covers its package behavior.

### 9.1 Self-Hosting

`@core`'s own functions are projected into modules like any other package content, then sourced by the loader via loadlist. The routing system is loaded by the loader it serves.

### 9.2 Module Enrichment — Hidden Cross-Links

`@packages.d` creates hidden dotfolder symlinks inside each sibling module, giving it local access to its `@core` infrastructure:

```
./aliases.d/.functions   → ./functions.d/@core/@aliases.d
./aliases.d/.help        → ./help.d/@core/@aliases.d
./aliases.d/.aliases     → ./aliases.d/@core/@aliases.d

./packages.d/.functions  → ./functions.d/@core/@packages.d
```

Rule: `.X-module` in `this-module.d/` points to `<X-module>.d/@core/@<this-module>.d/`. Applies to submodules as well:

```
./aliases.d/secrets.d/.functions → ./functions.d/@core/@aliases.d/@secrets.d
```

All cross-link symlinks are relative. Enrichment is `@core`-only. Cross-links point to module locations — if `@core` is reverse-projected, the cross-links still resolve. Encapsulated as `packages::project::hidden`, separate from general projection. No package, no cross-links.

### 9.3 Dual Structure of `./packages.d/@core/`

Inside `./packages.d/@core/`, prefixed `@name.d/` children name module correspondents; unprefixed `name.d/` children are modular components routing `@core`'s own artifacts into those modules. They project differently:

```
./packages.d/@core/@aliases.d/setup.sh  → ./aliases.d/setup.sh         # to the module root
./packages.d/@core/aliases.d/setup.sh   → ./aliases.d/@core/setup.sh  # into the module
```

The unprefixed `name.d/` children are produced by `@packages.d` during routing — not placed manually.

`templates.d` is the canonical example of the distinction; see §9.4.

### 9.4 Templates Module

Provide `templates.d` as a first-class module via the correspondent seat:

- Correspondent seat: `packages.d/@core/@templates.d/`
- Reconciled module view: `templates.d/`

Seeds owned by the templates module itself live under the correspondent seat, for example `packages.d/@core/@templates.d/@xdg/.package`, and project to `templates.d/@xdg/`.

Seeds contributed by unrelated packages live under that package's own modular component, for example `packages.d/@minimal/templates.d/`, and project to `templates.d/@minimal/`.

Interpretation:

- `packages.d/@core/@templates.d/@xdg` = a seed owned by the templates module itself
- `packages.d/@minimal/templates.d/...` = `@minimal`'s contribution to the templates module

Use canonical package names for canonical seeds when context is clear. Do not use `@core` as a template name; use `@base` or `@starter`.

### 9.5 The Closure Principle

In a fully reconciled rings tree, every non-infrastructure artifact in a module is owned by a package. Modules classify by kind; packages own. `@core` is the default owner for rings' own content — an artifact at a module root with no `@` scope is implicitly `@core`'s.

Infrastructure — loadlists, `.env`, and hidden cross-link symlinks — is not artifact content in the package sense.

When reconciliation finds an unscoped artifact at a module root, it treats that artifact as a candidate for adoption into `@core`. Adoption respects the module's ownership preference. Accepted and declined proposals are recorded; subsequent sweeps are idempotent.

### 9.6 `@rings`

`@rings` is a framework package, not constitutional machinery. Once vendored into a ring, it behaves as that ring's own package content rather than as a shared live authority.

### 9.7 Package Internal Helper Files

**Private scope is the package, not the file.** In a package, the unit of privacy is the package: an `@name/` directory and the files it directly owns. The usual shell source shape is `_name.bash` for private internals and `name.bash` for the public surface when the package is Bash-specific; other shell modules use the matching source extension for their runtime. When a package has no separate private internals, it may collapse to a singleton source file, `name.bash`; that singleton file is the file form of the package concern. This file-directory equivalence affects package identity and routing, but it does not make privacy file-local for normal multi-file packages.

A `__`-prefixed function owned by `@name/` may be called by files directly owned by `@name/`, including both `_name.bash` and `name.bash`. It must not be called by sibling packages, cousin packages, parent packages, or outside code.

**Subpackages.** A subpackage such as `@prompt/@render/` has its own privacy boundary. A parent must not call a child package's `__` helpers. Siblings must not call each other's `__` helpers. A child may use an immediate parent private helper through a child-owned wrapper, and should normally shadow the parent helper name:

```bash
# @prompt/_prompt.bash
function ble::prompt::__width() {
    ...
}

# @prompt/@render/_render.bash
function ble::prompt::render::__width() {
    ble::prompt::__width "$@"
}

# @prompt/@render/render.bash
function ble::prompt::render::line() {
    ble::prompt::render::__width "$text"
}
```

Use a different child-private name only when the child helper's behavior is meaningfully different and reusing the parent name would misdescribe it.

**Single-file packages.** When a package has only one directly owned source file and no private/public pair, `__` helpers in that file are private to that package's direct source file. If the package later gains more directly owned files, privacy expands to the package directory, not to unrelated subpackages.

The key rule: `name.bash` is either the public surface in a private/public pair, or the singleton source file when the package has collapsed to one file. The package owns all direct contents of `@name/`; nested `@child/` directories are separate packages with controlled immediate-parent private access.

### 9.8 Package-Scoped Composition

Package-scoped composition is a call-direction discipline over the package tree. It is not a new package kind, not an import system, not manifest metadata, and not loader behavior.

Composition follows package scope, not filesystem seat, routing seat, registry ownership, or module ownership. Registry-owned, module-owned, projected, and reverse-projected materializations obey the same package boundary because callable namespace and package identity follow package scope, not where the real bytes currently live.

The two directed flows are:

```text
parent private → child private wrapper → child public
child public   → parent public
```

Immediate sibling reuse is allowed through the sibling package's own public surface:

```text
sibling public → sibling consumer
```

The rules:

1. A package owns its direct files.
2. A nested `@child/` is a separate package boundary.
3. `__` helper privacy is defined by §9.7.
4. A child may use only its immediate parent's private helpers.
5. A child should wrap parent-private helpers in child-private helpers.
6. A parent may compose from only its immediate children's public functions.
7. A package may call an immediate sibling's public functions when those functions are owned directly by the sibling package.
8. A package must not call sibling private helpers.
9. A package must not call sibling descendants directly.
10. A package must not call grandchildren or deeper descendants directly.
11. A package must not call descendant internals.
12. A child must not use its parent's public API as implementation substrate.
13. Runtime global visibility does not create permission to call across package boundaries.

Private support descends by wrapper:

```bash
# @prompt/_prompt.bash
function ble::prompt::__width() {
    ...
}

# @prompt/@render/_render.bash
function ble::prompt::render::__width() {
    ble::prompt::__width "$@"
}

# @prompt/@render/render.bash
function ble::prompt::render::line() {
    ble::prompt::render::__width "$text"
}
```

Public behavior ascends by immediate child surface:

```bash
# @prompt/@render/render.bash
function ble::prompt::render::line() {
    ...
}

# @prompt/prompt.bash
function ble::prompt::draw() {
    ble::prompt::render::line "$text"
}

# @ble/ble.bash
function ble::redraw() {
    ble::prompt::draw "$text"
}
```

Skipped-level calls break the package boundary:

```bash
# Wrong from @ble:
function ble::redraw() {
    ble::prompt::render::line "$text"
}
```

The root package should not know which child of `@prompt` renders a line. `@prompt` owns that subtree and summarizes it through `ble::prompt::draw`.

Sibling reuse is sibling-public-only:

```text
@C/
  @A/
    A.bash
  @B/
    _B.bash
    B.bash
    @foo/
      foo.bash
      @bar/
        bar.bash
```

If `@A` and `@B` are immediate children of `@C`, `@A` may call public functions owned directly by `@B`. `@A` must not call functions owned by `@B`'s subpackages or any private helper in `@B`'s subtree.

```bash
# Allowed from @C/@A:
B::foo "$@"

# Forbidden from @C/@A:
B::__foo "$@"
B::foo::bar "$@"
B::foo::baz "$@"
B::foo::bar::qux "$@"
```

The ownership distinction is the rule. If `B::foo` is defined by files directly owned by `@B`, then it is `@B`'s public surface even when it internally composes `@B/@foo`, `@B/@foo/@bar`, or other children. Siblings may call that public surface; they may not bypass it.

-----

## 10. Safety

**Collision detection.** Any projection can collide with an existing file or another package's symlink. The system detects collisions before creating symlinks, reports the conflict, and lets the user decide. For declarative, line-oriented files (e.g., loadlists), an append option may be offered alongside overwrite, skip, and reverse-project. Append is never offered for executable shell scripts.

**Loadlist protection.** Every edit is backed up as `.loadlist.bak-<timestamp>` before modification; backups are pruned on success. The system updates existing entries only when files move. `packages::enable` is the only operation that adds new entries. Flat view references are tracked and updated when underlying artifacts move.

**Non-destructive normalization.** Unknown files route to `data.d/` — never discarded, never silently ignored.

**Atomicity.** Mutating operations stage changes and revert on failure. Either the full operation completes or it reverts.

-----

## 11. Module-Specific Policy

The package grammar (§3) is uniform. Individual modules may define additional linking rules for platform conventions.

Two distinct linking mechanisms:

- **Routing:** `packages.d` ↔ `module.d/`. Uniform across all modules (this document).
- **External stow linking:** `module.d/` → external system paths (`~/.config/`, `~/Library/Preferences/`). Module-specific; operated by module adapters; does not affect the core model.

**`config.d/@pkg`** — Default stow target: `$XDG_CONFIG_HOME/<pkg>/`. Additional targets (e.g., `~/.<pkg>rc`) may be proposed interactively. Bare `config.d/<app>` directories are a pre-normalization state; `packages::normalize` or `packages::package` handles migration.

```
./config.d/@yabai/yabairc
~/.config/yabai/yabairc  → ./config.d/@yabai/yabairc   # external stow link
~/.yabairc               → ./config.d/@yabai/yabairc   # additional target
```

**`plist.d/@pkg`** — macOS preference plists; similar downstream linking to `~/Library/Preferences/`.

**`install.d/@pkg`** — Install scripts and metadata. The flat `.packages` manifest coexists as a compact index.

-----

## 12. Relationships to Existing Subsystems

**Loader and loadlist.** The loader sources files without distinguishing real files from symlinks. `packages::enable` is the only operation that adds new loadlist entries; the system edits existing entries only when files move. The loader recognizes both `@pkg` and `@pkg/` in `.loadlist` entries. Generated tools emit the form without the trailing `/`; when an existing `.loadlist` already uses one spelling, tools preserve it rather than imposing a preference.

**Install layer (`install.d`).** The install layer acquires external applications; the package registry manages module artifacts. They coexist:
- `./packages.d/@terraform/` — the shell integration (aliases, env, completions, functions, config, install scripts).
- `install.d/.packages` entry `@brew/terraform` — how to acquire the upstream binary.

**Bindings.** `bindings.d` is subsumed. Do not write new code against `bindings::` verbs.

| Prior `bindings::` | New `packages::` |
|--------------------|-----------------|
| `bindings::ls` | `packages::ls` |
| `bindings::scan <n>` | `packages::inspect <n>` |
| `bindings::plan <n>` | `packages::inspect <n>` + `--dry-run` |
| `bindings::disable <n>` | `packages::disable <n>` |
| `bindings::pause <n>` | `packages::mute <n>` |
| `bindings::remove <n>` | `packages::remove <n>` |

**Init (`init.d`).** The per-package initialization verb is `<pkg>::init`. The legacy `init::<pkg>` form is deprecated. `init::register` is deprecated — that responsibility belongs to env artifacts. No `packages::init` dispatcher is defined.

-----

## 13. Properties

1. Every artifact has exactly one entry in `packages.d` — either a real file or a symlink to one.
2. Exactly one location holds an artifact's file content. All others hold symlinks.
3. A module symlink is derived from registry state (or is a backlink). Deleting the symlink does not delete the artifact.
4. After normalization, `packages.d` has an entry for every artifact. Partial inconsistency before normalization is normal.
5. No ghost symlinks. Pruning is never silent.
6. Loadlist entries are never added implicitly. `packages::enable` is required.
7. All symlinks are relative. Path computation is dynamic — no hardcoded depths.
8. All operations are idempotent.
9. The canonical grammar is singular; flat views are optional and secondary.
10. Promotion is identity-retaining and exclusive.
11. The filesystem encodes state — no external metadata files required.
12. No clobbering without consent.
13. Operations are atomic — failures revert.
14. Facet discovery is read-only; consolidation is explicit and user-driven.

-----

## 14. Faceted Discovery and Consolidation

The registry is perpetually incomplete. These commands traverse the live module tree directly, surfacing facets regardless of registry state. All follow rings interaction conventions: plan → inspect → apply, no implicit mutation, composable, deterministic diff before execution.

Facet handling is also where tree folding fails most obviously. A folded subtree makes projected module space behave too much like package space, weakening local collision reasoning, module-local enrichment, explicit ownership, and reconciliation composability.

### 14.1 Discovery

**`packages::facets <pkg>`** — Every occurrence of `@pkg` outside its proper package, across all modules. Includes the proper package in each module (scope = —) for completeness.

```
$ packages::facets @bash

PKG     SCOPE               MODULE   PATH
@bash   —                   env.d    @bash/env.sh
@bash   @windows/@terraform env.d    @windows/@terraform/@bash/funtime/aliases.sh
@bash   @dev                aliases  @dev/@bash/aliases.zsh
```

Flags: `--module=env.d` · `--depth=2` · `--no-proper` · `--only-proper` · `--json`

**`packages::where <pkg>`** — All occurrences grouped by scope.

```
$ packages::where @bash
@bash
@windows/@terraform/@bash
@dev/@bash
```

**`packages::tree <pkg>`** — Proper package only.

### 14.2 Consolidation

**`packages::consolidate <pkg>`** — Discover → select → plan → apply.

**Phase 1 — Discovery.** Roughly equivalent to `packages::facets @pkg`.

**Phase 2 — Selection.** Interactive picker (default); or `--select=all`, `--select=pattern`, `--stdin`.

**Phase 3 — Plan.** Structured diff, no mutation:

```
CONSOLIDATION PLAN: @bash / MODE: project

ADD (symlink): @bash/@windows/@terraform/@funtime/aliases.sh
ADD (symlink): @bash/@ci/env.sh
UNCHANGED:     @bash/env.sh
COLLISIONS:    none
```

**Phase 4 — Apply.** User confirms, then executes.

**The rewrite rule.** A facet at `<prefixed-scope>/@P/<tail-scope>` consolidates to `@P/<prefixed-scope>/<tail-scope>`. Scope is preserved — it encodes provenance. When `<tail-scope>` is empty, `<prefixed-scope>/@P/` rewrites to `@P/<prefixed-scope>/`.

**Ownership modes.** `--project` (default): symlinks in the proper package, no file movement. `--reverse-project`: actual files move into the proper package, backlinks created at origin.

**Collision resolution.** Interactive: skip, qualify (preserve deeper scope), overwrite. Batch: `--on-collision=skip|qualify|overwrite`.

**Error conditions.** A consolidation that would create a symlink loop (A → B → A) is rejected. A rewrite that would place an artifact outside the target package's tree is rejected. Both are fatal — no partial application.

**Typical workflow:**

```
packages::facets @bash        # discover
packages::where @bash         # inspect
packages::consolidate @bash   # consolidate
packages::package env.d/@bash # then package normally
```

**Scriptable:**

```sh
packages::facets @bash --json \
  | jq '.[] | select(.scope == "@dev")' \
  | packages::consolidate @bash --stdin --project --yes
```

-----

See also: [`MODULES.md`](./MODULES.md) · [`LOADER.md`](./LOADER.md) · [`ARCHITECTURE.md`](./ARCHITECTURE.md) · [`CONSENSUS.md`](../agents/CONSENSUS.md) · [`SHELL_STYLE_GUIDE.md`](../style/SHELL_STYLE_GUIDE.md)
