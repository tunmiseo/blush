# Rings — Architecture

> **Status:** Specification (pre-implementation).
> **See also:** [`LOADER.md`](./LOADER.md) · [`MODULES.md`](./MODULES.md) · [`PACKAGES.md`](./PACKAGES.md) · [`COLLECTIONS.md`](./COLLECTIONS.md) · [`PROFILES.md`](./PROFILES.md)

-----

## 1. The Rings Tree

`rings` is a relocatable shell profile repository. Its root directory — rings-root, written `./` in path examples — is traditionally symlinked to `~/.profile.d`.

**Naming conventions.** A path written with a leading `./` points at a concrete location in the tree: `./env.d/` is that directory, `./env.d/@terraform/` is that path. The same name without `./` is a reference by name: `env.d/` as a directory, `env.d` as a module, `@terraform` as a package. The trailing `/` signals something is being treated concretely as a directory; dropping it names the thing.

`$RING_ROOT` names the root of any ring. `$PROFILE_D` is the compatibility/runtime name for the login ring, where `$PROFILE_D == $RING_ROOT`. A profile in `@profiles.d` is a separate layer-4 identity-bearing context, not the same concept. See [`LOADER.md`](./LOADER.md).

Modules and packages use different notations. A module is always suffixed and never prefixed: `env.d`, `packages.d`, `custom.d`. A package is always prefixed and may additionally carry a `.d` suffix: `@terraform`, `@core`, `@mine`. The significance of the `.d` suffix on a prefixed name within `@core` scopes is defined in [`MODULES.md`](./MODULES.md).

-----

## 2. Five Layers

Each layer adds semantics to the one below. Removing a higher layer loses its semantics; the layers beneath are unaffected.

**Layer 0 — Filesystem.** The POSIX filesystem: directories, files, symlinks. A symlink is a filesystem entry whose content is a path to another entry; a broken symlink is one whose target resolves to nothing. At this layer, `./env.d/` is just a directory and `./env.d/@terraform/` is just a path.

**Layer 1 — Loader.** `zload` (`io::load::zsh`, aliased `+`) and `bload` (`io::load::bash`) read loadlists, resolve entries to filesystem paths, read directory-local metadata, and source files into the running shell. The loader has no concept of modules or packages; it only understands paths, loadlists, and loader-local metadata such as `.env`. See [`LOADER.md`](./LOADER.md).

**Layer 2 — `@core`.** `./packages.d/@core/` determines which suffixed directories are modules by reconciling its own `@*.d/` hierarchy against rings-root's `*.d/` directories. Its reconciliation machinery may be organized under `./packages.d/@core/@modules/`; at this stage that is still organizational structure inside reserved `@core`, before layer 3 package semantics are in force. See [`MODULES.md`](./MODULES.md).

**Layer 3 — `@packages.d`.** `./packages.d/@core/@packages.d/` introduces package semantics over the modules `@core` determined — interpreting every `@`-prefixed directory as a package and managing routing between the registry and modules. See [`PACKAGES.md`](./PACKAGES.md).

**Layer 4 — Collections and Profiles.** Layer 3 owns package identity, routing, ownership, lifecycle, and per-package metadata. Layer 4 owns named membership objects over package ids and identity-bearing contexts that consume them. Layer 4 selects from layer 3 output; it does not redefine package identity. Collections are layer 4a; profiles are layer 4b. See [`COLLECTIONS.md`](./COLLECTIONS.md) and [`PROFILES.md`](./PROFILES.md).

Layer 3 carries layer 4 as payload: packages may declare collection membership in `.package`, but package semantics remain complete without collections or profiles.

At a glance:

- the loader recurses mechanically
- `@core` determines which directories are modules
- `@packages.d` interprets prefixed directories inside those modules as packages
- layer 4 names membership objects over package ids and identity-bearing contexts over those objects

-----

## 3. Bootstrap Sequence

`profile.sh` (in rings-root, sourced by `.zshrc` and equivalents) detects rings-root, exports `$RING_ROOT`, and, for the login ring, also exports `$PROFILE_D == $RING_ROOT`. It then invokes the loader. The loader makes a single pass through loadlists, sourcing `@core` then `@packages.d` code in sequence — same pass, strict order.

```
./             rings-root
  profile.sh   detects rings-root → exports $RING_ROOT / $PROFILE_D → invokes loader
  loader       reads loadlists, sources files                               [layer 1]
  @core        determines which directories are modules                     [layer 2]
  @packages.d  routes packages into modules                                 [layer 3]
  collections  establish named membership state over package ids           [layer 4a]
  profiles     establish identity-bearing context over collections         [layer 4b]
```

The loader continues to function independently of either — it sources whatever loadlist entries resolve to.

-----

## 4. Document Map

[`LOADER.md`](./LOADER.md) — **layer 1.** Loader algorithm, loadlist format and entry grammar, `setup_dir`, `.env` handling, boot chain, caching, and root variables.

[`MODULES.md`](./MODULES.md) — **layer 2.** Module and submodule semantics, `@core` reconciliation, the `.d`-suffix convention within `@core` scopes, the `@core/@modules` organizational clarification, and the one-way boundary between module-space and package-space.

[`PACKAGES.md`](./PACKAGES.md) — **layer 3.** Package semantics over canonical modules: the registry, routing, ownership, manifests, lifecycle, planning, external stow materialization, facets, and consolidation.

[`COLLECTIONS.md`](./COLLECTIONS.md) — **layer 4a.** Collection identity, membership semantics, authority, cache behavior, reconciliation, and query surfaces.

[`PROFILES.md`](./PROFILES.md) — **layer 4b.** Profile identity, collection references, active-profile semantics, drift, host applicability, and profile public surfaces.

-----

## 5. Package Identity

A **package** is an abstract entity with stable identity. It is not a directory. The directory `packages.d/@pkg/` is the registry materialization. Module projections are additional materializations.

The canonical manifest lives at `packages.d/@pkg/.package` and defines id, version, ownership, provides, depends, hosts, stow, lifecycle, and origin. Loaders and package tools resolve identity first, then enumerate representations. All verbs operate on the abstract identity.

Packages may also declare collection membership in `.package`. Collection membership references package ids, not raw paths. The canonical id is the full scoped registry path unless overridden by an explicit `id` field in `.package`. That override is rare and continuity-preserving. Duplicate ids fail reconciliation ring-wide. Collection and profile semantics themselves are defined in their own layer-4 documents.

-----

## 6. Reserved `@core` Ontology

Inside `packages.d/@core/` there are three distinct kinds of children:

- `@*.d/` children are **module-correspondent packages**. They create and reconcile top-level modules.
- Unprefixed suffixed children like `functions.d/` or `templates.d/` are **modular components of the `@core` package**. They project to `name.d/@core/` and do not create or reconcile a module.
- Unprefixed unsuffixed children are ordinary artifacts or directories, handled by the package's own rules.

The distinction matters immediately for `templates.d`: `packages.d/@core/@templates.d/` reconciles the module `templates.d/`, while `packages.d/@core/templates.d/` is only a modular component projecting to `templates.d/@core/`.

See [`MODULES.md`](./MODULES.md) for module correspondence and [`PACKAGES.md`](./PACKAGES.md) for projection behavior.

-----

## 7. Ownership, Metadata, and Lifecycle

Ownership precedence is explicit and ordered:

1. Per artifact override
2. Per package default in `.package`
3. Per module default in `.module` (defined in [`MODULES.md`](./MODULES.md) §8)

Implementations may observe existing on-disk ownership during reconciliation, but explicit policy resolves in the order above. Registry-owned and module-owned are co-equal first-class states.

The metadata boundary is:

- `.package` = package identity and manifest
- `.env` = directory-local rings metadata read when entering a directory
- `env.d` = durable exported environment artifacts

Lifecycle hooks are authored against the package seat and resolved through actual ownership and projection state at execution time. `namespace::verb` resolves as a rings function, `./path` resolves relative to `packages.d/@pkg/`, and bare words are frozen to absolute executable paths at plan time.

See [`PACKAGES.md`](./PACKAGES.md) for ownership examples, lifecycle resolution rules, and operation-level consequences.

-----

## 8. Plans, JSON, and External Materialization

All mutating package operations compile a plan before execution. The plan document is the contract between planning and application. Free-text output is only a human rendering.

JSON-emitting commands use a versioned envelope:

```json
{
  "schema_version": "1",
  "command": "packages::where",
  "package": "@bash",
  "generated_at": "2026-04-14T09:00:00Z",
  "data": {}
}
```

Plan operations use explicit op codes; the full vocabulary is defined in [`PACKAGES.md`](./PACKAGES.md) §6. Examples: `symlink_create`, `file_move`, `stow_external`, `hook_run`.

`packages::stow` performs rings-level external materialization. `packages::push <pkg> <remote>` synchronizes a package's reconciled representation to another rings remote; it is not a public publishing verb.

See [`PACKAGES.md`](./PACKAGES.md) for the plan schema, JSON envelope, and command semantics.

-----

## 9. Tree Folding and Facets

Leaf projection is the default. Tree projection is allowed only as explicit opt-in with `projection.mode = "tree"`.

Tree folding weakens the semantic boundary between projected module space and package space. It is therefore permitted only for whole-unit subtrees whose projected side is not expected to carry module-local structure, scoped overlays, or later fine-grained reconciliation.

Presence of `.env` or `.loadlist` inside a folded subtree is syntactically valid but must trigger a plan warning. `packages::plan` must warn when it encounters folded trees.

Facets make the risk visible: paths like `aliases.d/@work/@bash/` are natural in leaf mode but become harder to reason about once a subtree is folded into a single symlink mount.

-----

## 10. Framework and Ring Terminology

Use the terms with no collapse:

- **`rings`** = the binary, application, and orchestrator
- **`@rings`** = the framework package for rings-level creation and management machinery
- **a ring** = an instantiated fork rooted at `$RING_ROOT`, with its own `@core`, packages, modules, remotes, and state

`@rings` is framework-only. It contains no constitutional machinery inside a ring and may be vendored into a ring if desired.

A host may have many rings. One may be bound as the login ring. That is a binding, not a type.

-----

## 11. Templates Module

Provide `templates.d` as a first-class module via the correspondent seat:

- Correspondent seat: `packages.d/@core/@templates.d/`
- Reconciled module view: `$RING_ROOT/templates.d/`

The module view is not a symlink; it is created during module reconciliation. Seeds owned by the templates module itself live under the correspondent seat, for example `packages.d/@core/@templates.d/@xdg/.package`, while seeds contributed by unrelated packages live under their own modular component, for example `packages.d/@minimal/templates.d/`.

A seed under the templates correspondent belongs to the templates module itself. A seed under another package's `templates.d/` belongs to that package and is projected into the templates module as a contribution.

Do not use `@core` as a template name. Use `@base` or `@starter`. `@core` remains reserved to mean the `@core` package for that ring.

See [`PACKAGES.md`](./PACKAGES.md) for the full templates-module routing examples.
