---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../gufa-cast-all/index.md
---

# `type-generalizing` call-ref, casts, and boundary rules

## Why this page exists

The easiest way to misunderstand this family is to blur three things together:

- `call_ref` target narrowing
- cast-target tightening
- broader GC/type optimization families nearby

This page separates them.

## The single most important `call_ref` rule

For `call_ref`, Binaryen does **not** say:

- if the possible target set gets smaller, rewrite somehow

It says something stricter:

- if the possible target set collapses to **exactly one signature**, rewrite
- otherwise, leave the original broader typing alone

That rule makes the family much easier to implement and much safer to teach.

## The `call_ref` decision tree

In `version_129`, the visitor logic is basically:

1. ask the oracle for possible contents of the target expression
2. if there is no oracle result, bail
3. if the contents are impossible, rewrite the target to `unreachable`
4. otherwise collect reachable function signatures
5. if the signature set is empty, also rewrite the target to `unreachable`
6. if the signature set has more than one member, bail
7. if the signature set has exactly one member:
   - rewrite the target type to that non-nullable function signature
   - rewrite the result type if the signature result is a subtype of the current result

That is the whole core contract.

## Why impossible `call_ref` becomes `unreachable`

This is a strong source-backed fact that beginners might not guess.
The family is not limited to nicer types.
It can also say:

- this call target cannot possibly be a callable function in the closed world

and then rewrite the target expression to `unreachable`.

So the pass sometimes crosses from pure retagging into real semantic simplification.

## Why multiple signatures force a bailout

This is a good example of Binaryen choosing conservatism over cleverness.
Even if all remaining signatures are "similar," the pass does not try to invent a join or a synthetic wrapper.
It simply refuses to narrow.

That makes the family:

- smaller
- easier to reason about
- easier to keep correct under refinalization

## The cast split

The second public sibling exists for one reason:

- it enables `visitRefCast` tightening through the `optimizeCasts` flag

This does **not** mean:

- insert new casts
- optimize all cast expressions everywhere
- perform the same job as `gufa-cast-all`

It means something smaller:

- when a `ref.cast` already exists, and the oracle proves its input is confined to a narrower heap-type cone, tighten the cast target type

## How this differs from `gufa-cast-all`

This distinction is important enough to state directly.

### `type-generalizing-with-optimizing-casts`

- reuses an oracle
- only touches existing `ref.cast`
- tightens the cast target type
- does not insert new cast nodes

### `gufa-cast-all`

- also reuses an oracle family
- can insert **new** `ref.cast` nodes after refinalization
- has a different public sibling identity and a different teaching surface

So even though both families talk about oracle-backed cast precision, they are not the same pass.

## `struct.get` and `struct.set` are narrower than they sound too

The family also does not try to rewrite every GC field access in fancy ways.
It uses the oracle to make a narrow subtype choice and only when that choice is a subtype of the current visible type.

That means beginners should remember two separate boundary rules:

- not every receiver proof changes the visible field type
- not every cast proof changes the visible cast target

The subtype check is real and deliberate.

## Why refinalization matters so much here

This family changes expression types in place.
That makes post-change `ReFinalize` an essential part of the contract.

Without refinalization, parent nodes could still carry stale types after:

- narrower `struct.get` result types
- narrower `call_ref` target types
- narrower `call_ref` result types
- narrower `ref.cast` targets

So one of the easiest implementation mistakes would be treating this as a purely local rewrite pass with no need for whole-function type repair.

## Beginner-friendly boundary table

| Situation | What Binaryen does |
| --- | --- |
| `call_ref` has exactly one possible signature | narrow target and maybe result |
| `call_ref` has multiple possible signatures | bail |
| `call_ref` has no possible callable contents | rewrite target to `unreachable` |
| plain experimental pass sees `ref.cast` | leave it alone |
| optimizing-casts sibling sees narrowable `ref.cast` | tighten target type |
| user wants new casts inserted where none exist | not this family |

## What a future Starshine port must not blur together

A correct port should keep these separations explicit:

1. impossible-target `call_ref` rewrite versus ordinary target narrowing
2. single-signature narrowing versus mixed-signature bailout
3. plain sibling versus optimizing-casts sibling
4. existing-cast tightening versus new-cast insertion
5. this family versus broader neighbors like `type-refining` and `gufa-cast-all`

## Most useful beginner sentence

If someone wants the simplest correct summary of the hard part, use this:

- Binaryen `type-generalizing` narrows `call_ref` only when the closed world proves one reachable signature, and its cast-optimizing sibling only tightens casts that already exist.
