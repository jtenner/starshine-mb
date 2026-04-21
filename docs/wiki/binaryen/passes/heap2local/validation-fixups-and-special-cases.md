---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
---

# `heap2local` validation fixups and special cases

This page covers the part of `heap2local` that is easiest to misunderstand:

- why the pass keeps emitting nullable placeholders
- why refinalization is mandatory
- how packed and atomic cases still behave correctly
- which special GC families are visible in the source even when the dedicated lit file does not cover all of them directly

## The most important mental model

`heap2local` is not trying to jump directly from:

- “GC allocation exists”

to:

- “final prettified local-only code”

Instead it often goes through an intentionally awkward but valid transitional form:

- field locals hold the data
- old ref traffic is replaced with `ref.null`
- surrounding block/cast/nullability types are widened or refinalized
- later cleanup passes can then remove the remaining dead wrappers

That is why the source can look surprisingly indirect.

## Why `ref.null` placeholders appear everywhere

When Binaryen deletes the actual heap allocation, the surrounding expression tree may still expect a reference-typed child for a moment.
So the pass often replaces the old allocation or stale `local.get` with `ref.null`.

That solves two problems at once:

1. it preserves a valid reference-typed shape immediately
2. it avoids accidentally reading the default value of a nondefaultable local

This is especially important for:

- stale local traffic after the original reference local is no longer meaningfully initialized
- casts/tests/blocks whose old type assumptions no longer hold after scalarization

## Nondefaultable locals are repaired in two layers

There are two separate repair layers, and both matter.

### Layer 1: in-pass rewrites

Inside `Struct2Local`, Binaryen may replace old `local.get`s with `ref.null` directly.
That prevents invalid reads of removed non-nullable state.

### Layer 2: generic pass-runner fixups

In `pass.h`, `Pass::requiresNonNullableLocalFixups()` defaults to `true`.
`Heap2LocalPass` does not override that.
So after the pass changes Binaryen IR, `PassRunner::handleAfterEffects(...)` runs:

- `TypeUpdating::handleNonDefaultableLocals(func, wasm)`

That helper makes locals valid for wasm's nondefaultable-local rules.
In practice, that means Binaryen can temporarily widen locals to a valid form and add `ref.as_non_null` where later uses still need the original stricter type.

Beginner lesson:

- if you only read `Heap2Local.cpp`, you see half the fixup story
- the other half lives in the generic pass framework

## Why `ReFinalize` is mandatory here

Several `heap2local` rewrites change expression types in ways that cannot be left stale.
The pass therefore calls `ReFinalize()` when necessary.

The important triggers are:

### 1. nullability changes

If a non-nullable flowing reference is replaced by something nullable like `ref.null`, parent expressions may need their types recomputed.

### 2. cast simplification

When `ref.cast` disappears or becomes explicit `unreachable`, the surrounding tree's types can change significantly.

### 3. array out-of-bounds rewrites

When a converted array access is proven OOB, Binaryen rewrites it to explicit `unreachable` after preserving side effects.
That unreachability must then propagate properly.

### 4. synthetic struct type substitution for arrays

`Array2Struct` rewrites array-typed flowing values to a new synthetic struct type.
That can temporarily invalidate surrounding type assumptions until refinalization repairs them.

## EH `pop` fixups are part of the pass boundary

`heap2local` often creates new blocks while replacing an allocation with local initialization sequences.
If the function contains `pop`, that can produce invalid nested-pop structure.

So after any successful rewrite in a function containing `pop`, Binaryen runs:

- `EHUtils::handleBlockNestedPops(func, wasm)`

That means EH repair is not an optional afterthought.
It is part of the real pass contract.

## Packed fields are not turned into plain untyped locals

Scalarizing a packed field does **not** mean forgetting the old load semantics.

Binaryen uses `Bits::makePackedFieldGet(...)` when replacing packed gets.
That preserves:

- zero-extension for unsigned gets
- sign-extension for signed gets

The dedicated lit file visibly tests this for:

- packed struct fields
- packed arrays

So packed-field correctness is part of the user-visible contract, not just a source detail.

## Why atomic accesses can still be optimized

At first glance, atomic GC field traffic looks like it should be untouchable.
Binaryen's reasoning is narrower:

- if the object never escapes the current function, no other thread can observe that object identity
- therefore those accesses cannot synchronize through that object with other threads

So the pass can lower some atomic object traffic to local operations while preserving the important result behavior.

The dedicated lit surface visibly covers:

- `struct.atomic.get`
- `struct.atomic.set`
- `array.atomic.get`
- `array.atomic.set`

The source also handles broader atomic/RMW/cmpxchg families that are easier to miss.

## RMW and cmpxchg are source-visible even when they are not prominent in the lit file

The pass source contains dedicated handling for:

- `StructRMW`
- `StructCmpxchg`
- `ArrayRMW`
- `ArrayCmpxchg`

Those families matter because they show that `heap2local` is not just a read/write replacement pass.
It also preserves read-modify-write result behavior when the allocation stays nonescaping and exclusive.

The important nuance is that some of this surface is much clearer in the source than in the dedicated `version_129` lit file.
So the dossier should state it honestly as source-backed behavior.

## Descriptor-bearing allocations are also more visible in source than in the lit test

`Heap2Local.cpp` contains explicit handling for:

- descriptor-bearing struct allocations
- `ref.get_desc`
- descriptor-based cast logic

The local Starshine tests already model some of these families.
But the upstream dedicated `heap2local.wast` file does not obviously exercise all of them directly.

Durable lesson:

- the source surface is wider than the most obvious lit examples
- future parity work should not shrink the pass contract down to only what one lit file happens to show visibly

## Current-main drift to keep in mind

A narrow 2026-04-20 direct comparison against current `main` found a few real changes after `version_129`:

### 1. array interaction precision improved

Current `main` is more precise about when a nonconstant array index is an analysis barrier.
It now distinguishes more carefully between:

- the optimized allocation flowing as the array `ref`
- the optimized allocation flowing as some other operand, especially `expected` in cmpxchg-like cases

### 2. cmpxchg handling is cleaner and more explicit

Current `main` more clearly separates:

- optimized-allocation-as-`ref`
- optimized-allocation-as-`expected`

and preserves some dynamic-index behavior via scratch locals in a later array case.

### 3. unreachable `ref.test` is left alone

Current `main` explicitly avoids rewriting unreachable `ref.test` to a concrete constant there.
That is a small validation-safety clarification.

### 4. the dedicated test file did not grow new matching coverage

The owning `heap2local.wast` file on `main` only changed a typo (`vaccum` -> `vacuum`).
So the drift is visible in source, but not yet obviously reflected in new dedicated lit coverage in that file.

## What a future port must preserve

A future Starshine port should preserve all of these special-case rules honestly:

- placeholder `ref.null` traffic is part of validation repair, not an accident
- nondefaultable-local fixups happen partly in the pass file and partly in the pass framework
- `ReFinalize` is mandatory for several cast/nullability/OOB/array-type transitions
- EH nested-pop repair is part of the real pass boundary
- packed access semantics must survive scalarization exactly
- atomic/RMW/cmpxchg and descriptor families are part of the source-level contract even when dedicated test coverage is uneven
- current `main` has already tightened some corner cases, so a future parity port should not assume `version_129` is the last word forever
