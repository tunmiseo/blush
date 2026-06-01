# COLLECTIONS — Layer 4a: Collection Semantics

> **Status:** Specification (pre-implementation).
> **Scope:** Collection identity, membership, authority, cache semantics, reconciliation, and query surfaces.
> **See also:** [`ARCHITECTURE.md`](./ARCHITECTURE.md) · [`MODULES.md`](./MODULES.md) · [`PACKAGES.md`](./PACKAGES.md) · [`PROFILES.md`](./PROFILES.md)

-----

## 1. Definition

A **collection** is a named membership object over package ids.

Collections are:

- **nominal in identity** — `work` and `gpu-lab` remain distinct collections even when they currently select the same members
- **extensional in membership semantics** — what a collection selects is determined by the package ids in its membership set

Collections are about package selection, not package identity. They neither replace nor redefine the package model in layer 3.

-----

## 2. Relationship to the Layer Model

Collections are **layer 4a**.

Layer 3 owns package identity, routing, ownership, lifecycle, and per-package metadata. Layer 4a adds named membership objects over those package ids. A collection cannot exist without layer 3 package identities beneath it, and layer 3 package semantics do not depend on collections.

Collections are therefore successor-layer structure carried by the package layer, not new package semantics inside it.

-----

## 3. Package Identity and Membership Keys

Collection membership references **package ids**, not raw filesystem paths.

The canonical package id is the full scoped registry path from `packages.d/`, using `@`-prefixed segments:

```text
packages.d/@hashicorp/@vault/.package  ->  @hashicorp/@vault
```

An explicit `id` field in `.package` overrides the positional derivation when present. That override is rare and continuity-preserving — primarily for package moves or reorganizations where identity must remain stable across collection membership, dependency edges, or lifecycle references.

Duplicate ids are invalid ring-wide. Reconciliation must fail if two packages claim the same id.

-----

## 4. Realization

The collection subsystem lives under the `@packages.d` correspondent chain:

- correspondent seat: `packages.d/@core/@packages.d/@collections.d/`
- realized module seat: `packages.d/collections.d/`

`@collections.d` is an ordinary correspondent submodule beneath `@packages.d`, by the same recursive correspondent-submodule rule that governs nested `@*.d/` directories generally.

-----

## 5. Declared and Derived Collections

There are two collection kinds:

- **Declared collections** — membership is declared distributively in package manifests
- **Derived collections** — membership is authored centrally from a predicate or explicit member list

For declared collections, packages declare membership in `.package`:

```toml
[collections]
member = ["work", "personal"]
```

For derived collections, membership is authored centrally in a `.collection` file within the `@collections.d` context.

`.collection` files have two roles depending on collection kind:

- for a declared collection, `.collection` is **metadata-only**
- for a derived collection, `.collection` carries **metadata plus predicate definition or explicit member list**

Declared `.collection` files must not contain member lists.

-----

## 6. Authority and Cache

Declared collection membership is authoritative in `.package`.

`.collections` is the central cache within the `@collections.d` context. For declared collections it is rebuilt from `.package` declarations. It is not co-authoritative, and declared collections are not co-authored by `.collection` and `.package`.

The authority split is:

- **declared membership**: authoritative in `.package`
- **declared collection metadata**: authoritative in `.collection`
- **derived membership and metadata**: authoritative in `.collection`

Downstream readers use the central `.collections` cache rather than traversing the ring directly.

-----

## 7. Reconciliation

`collections::reconcile [<scope>]` refreshes collection state.

For declared collections, reconciliation:

- traverses `.package` declarations
- rebuilds the declared portion of `.collections` from authoritative membership declarations
- validates the resulting member ids against the current package set

For derived collections, reconciliation:

- evaluates or validates centrally authored membership definitions
- checks referenced ids against the current package set
- preserves unresolved references with warnings until the user explicitly prunes or edits them

Reconciliation never writes declared membership back into `.package` from the cache.

-----

## 8. Public Surfaces

### 8.1 Read / Query

- **`collections::members <name>`** — return the resolved package ids in a named collection
- **`collections::contains <name> <pkg>`** — test whether a package id is in a collection
- **`collections::list`** — list known collections
- **`collections::current`** — return the unnamed current collection

### 8.2 Maintenance

- **`collections::reconcile [<scope>]`** — refresh declared and derived collection state
- **`collections::prune <name>`** — remove unresolved or explicitly discarded derived members from a collection definition

-----

## 9. The Unnamed Current Collection

The unnamed current collection is the **persistent enabled set** — the packages whose presence in loadlists makes them reachable in future sessions.

It is not the current session's full live activation state. Session-local suppression through `packages::mute` may make the live shell diverge from the persistent enabled set without changing the unnamed current collection.

-----

## 10. Routing and Extension Points

Packages may contribute collection-related machinery beneath:

```text
@pkg/packages.d/collections.d/
  -> packages.d/collections.d/@pkg/
```

This is a valid but sparse extension point. Ordinary collection membership does not require it; `.package` declarations are sufficient for most packages.

-----

## 11. Properties

1. Collections are named membership objects over package ids.
2. Collection identity is nominal; collection membership is extensional.
3. Declared collection membership is distributed-first in `.package`.
4. `.collections` is a derived cache, not a second authority for declared membership.
5. Declared `.collection` files are metadata-only.
6. Derived collections are centrally authored and centrally authoritative.
7. The empty collection is a valid collection.
8. The unnamed current collection names the persistent enabled set, not the live session state.
