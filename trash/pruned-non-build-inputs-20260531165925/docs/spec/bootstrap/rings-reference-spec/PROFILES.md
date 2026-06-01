# PROFILES — Layer 4b: Profile Semantics

> **Status:** Specification (pre-implementation).
> **Scope:** Profile identity, collection references, identity state, drift semantics, and profile public surfaces.
> **See also:** [`ARCHITECTURE.md`](./ARCHITECTURE.md) · [`COLLECTIONS.md`](./COLLECTIONS.md) · [`PACKAGES.md`](./PACKAGES.md)

-----

## 1. Definition

A **profile** is a named identity-bearing context that references one or more collections and carries identity-scoped state.

Two profiles may select the same packages and still remain distinct if they represent different identities, hosts, or context defaults.

Profiles are about identity and context, not package declaration. Packages do not declare profile membership.

-----

## 2. Relationship to the Layer Model

Profiles are **layer 4b**.

Layer 4b awakens after collections. Profiles depend on collections, and therefore transitively on layer 3 package identity, but collections do not know profiles exist.

The asymmetry is intentional:

- packages declare collection membership
- profiles consume collections
- packages do not declare profile membership

-----

## 3. Registry-First Exception

Profiles are a deliberate **registry-first exception** to the filesystem-first posture that otherwise characterizes distributed package and module semantics.

A package can truthfully declare collection membership because that is a package property. A package cannot truthfully declare profile membership because a profile is an external identity context, not a package property.

Profiles are therefore defined centrally.

-----

## 4. Realization

The profile subsystem lives under the `@packages.d` correspondent chain:

- correspondent seat: `packages.d/@core/@packages.d/@profiles.d/`
- realized module seat: `packages.d/profiles.d/`

`@profiles.d` is an ordinary correspondent submodule beneath `@packages.d`, by the same recursive correspondent-submodule rule that governs nested `@*.d/` directories generally.

-----

## 5. Profile Definition

Profiles are defined centrally as TOML documents under `@profiles.d`.

A profile definition may include:

- `name`
- collection reference(s)
- identity fields
- prompt or presentation state
- stow preferences
- environment defaults
- host identity

Secret-bearing identity values are references through `@secrets.d`; profiles never store secret content directly.

-----

## 6. Active Profile and Public Surface

The active profile is tracked centrally inside the `@profiles.d` context. The current implementation uses `.current` as the active-profile reference.

The public profile surface is:

- **`profiles::current`** — return the active profile name
- **`profiles::identity [<field>]`** — read declared identity state from the active profile
- **`profiles::list`** — enumerate known profiles
- **`profiles::status`** — compare the active profile to the current persistent enabled set
- **`profiles::switch <profile>`** — make another profile the persistent context
- **`profiles::apply [<profile>]`** — align the current session to a profile, or reapply the active one

`profiles::identity` reads declared profile state. It does not imply that every field is already materialized into the current session or external tools unless the relevant profile application step has run.

-----

## 7. `profiles::switch`

`profiles::switch` is the persistent profile-changing verb.

At contract level, it:

1. computes the desired persistent enabled set from the profile's collection references
2. delegates mutation through package planning and application
3. applies the profile's identity state
4. updates the active-profile reference only after successful package apply and identity application

`profiles::switch` changes future-session persistence. It does not forcibly realign current-session mute state.

-----

## 8. `profiles::apply`

`profiles::apply` is the stronger session-alignment verb.

It does everything `profiles::switch` does and additionally realigns current-session activation to the profile declaration. When called with no argument, it reapplies the active profile.

-----

## 9. Drift and Status

Profiles are declarative checkpoints, not continuous enforcers.

Manual package operations may change the persistent enabled set without mutating the active profile definition. That divergence is **drift**.

`profiles::status` is read-only drift detection. It compares the current persistent enabled set against what the active profile would produce and ignores session-local mutes.

-----

## 10. Host Applicability

Host applicability is part of the first-pass profile model, but only minimally.

- profiles may carry host identity
- packages may carry `hosts` constraints in `.package`
- effective selection or installation under a profile uses intersection semantics:
  - the package is selected by collection
  - and package `hosts` constraints match profile host identity when either side specifies one

This document does not define a richer host taxonomy, precedence lattice, or host algebra.

-----

## 11. Relationship to `$PROFILE_D`

`$PROFILE_D` names the login ring's root path at layer 1. A profile in `@profiles.d` is a layer-4 identity-bearing context.

The two uses of "profile" share an English word but do not occupy the same semantic domain.

-----

## 12. Properties

1. Profiles are named identity-bearing contexts.
2. Profiles are centrally defined and registry-first by design.
3. Profiles reference collections; collections do not reference profiles.
4. `profiles::switch` is persistent.
5. `profiles::apply` adds current-session alignment on top of `switch`.
6. Manual drift under an active profile is allowed and observable.
7. Secret-bearing values are referenced through `@secrets.d`, not stored inline.
