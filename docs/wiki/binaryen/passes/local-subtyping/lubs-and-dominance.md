---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
---

# `local-subtyping`: LUBs and dominance

This page exists because the pass name invites two very common misunderstandings:

1. “Binaryen just picks the narrowest type it sees.”
2. “Binaryen just edits the local declaration and is done.”

Both are wrong.

## Mental model first

A safe mental model is:

- the pass collects evidence that a local can be more specific
- it converts that evidence into one common target type
- then it asks the local type-updating helper to realize that target safely in the actual control structure

The first half is about **least upper bounds**.
The second half is about **structural dominance**.

You need both pieces to understand the real pass.

## Part 1: why Binaryen uses a least upper bound

`LocalSubtyping.cpp` stores a `LUBFinder` per local and feeds it subtype facts.

The important consequence is:

- the pass is looking for one type that is compatible with every observed concrete use/def fact
- while still being as specific as possible

That is exactly what a least upper bound gives you.

## What the pass feeds into the LUB finder

For non-parameter locals, Binaryen notes subtype facts from:

- the local's existing declared type
- concrete `local.get` types
- concrete `local.set` value types
- `local.tee` result types
- the non-null form of `ref.as_non_null(local.get ...)`

It does **not** feed in facts from:

- params
- tuple locals
- `ref.cast`
- `br_on_cast*`
- global/table traffic

So the pass's world is intentionally small.

## Example A: one obvious narrower subtype

Suppose a local is declared as a wide reference type, but every concrete get/set already uses `(ref null $Child)`.

Then the LUB of the observed facts is still `(ref null $Child)`.

So the pass can narrow the local to that child type.

## Example B: two sibling subtypes

Suppose one assignment is `(ref null $Left)` and another is `(ref null $Right)`.

If both share a common parent, the LUB may be that parent type.

This is the key beginner correction:

- Binaryen does **not** pick `$Left`
- Binaryen does **not** pick `$Right`
- Binaryen picks the best common type

That may still be narrower than the original declaration, but it may be wider than either individual leaf subtype.

## Example C: nullable plus non-null evidence

Suppose the pass sees:

- plain nullable `local.get`s
- and also `ref.as_non_null(local.get ...)`

Then the result depends on all the facts together.

If the plain nullable gets remain part of the observed concrete traffic, the common type may stay nullable.

So one `ref.as_non_null` does **not** automatically force the whole local to become non-null.

## Example D: dead-code / `unreachable` traffic does not pollute the result

The visitor logic only records concrete types.

That means clearly non-concrete traffic, especially `unreachable`, does not automatically widen the LUB.

This is one reason the shipped tests include trapping and dead-code-shaped cases.

## Part 2: why the type update needs structural dominance

If the new type were just a metadata tweak, the pass could stop after computing the LUB.

But changing a local type can affect:

- later `local.get` types
- `local.set` compatibility
- `local.tee` result types
- local default values and where a narrowed type is actually available
- which parts of the function are guaranteed to have already seen a suitable assignment

That is why `LocalSubtyping.cpp` delegates the actual rewrite to:

- `TypeUpdating::LocalUpdater`
- with `LocalStructuralDominance`

## Why simple textual order is not enough

A beginner might assume:

- “if the set appears earlier in the text than the get, it dominates the get.”

Binaryen is stricter than that.

`LocalStructuralDominance` documents a structured-control notion of dominance where:

- named blocks matter
- loops matter
- catch bodies matter in the default mode used here
- unnamed blocks do not matter because branches cannot target them

So the helper is checking something more like:

- “is this narrower local state guaranteed on every structured path that reaches this use?”

That is a much better model.

## Why the helper may add a copy local

The comments in `type-updating.h` explain that changing one local's type can require a split rewrite.

If some users are safely dominated by narrower assignments but other users are not, Binaryen may:

- keep the original local
- add a new copy local with the narrower type
- assign into that copy local only where the narrower type is valid
- rewrite only the dominated users to the copy local

This is a core part of the pass.

So the real rewrite is sometimes:

- “change one local type”

but sometimes:

- “introduce a second local that carries the narrower type only in the region where it is safe.”

That is why a future Starshine port must not reduce the pass to a header edit.

## Why params are skipped today

The source comment about params is much easier to understand once dominance is in view.

If Binaryen narrowed params too, it would need to reason much more carefully about:

- the incoming function ABI type
- named block parameter behavior
- where a more specific param view is valid

Upstream simply chooses not to solve that here.

That is the honest current contract.

## Why tuple locals are skipped today

`TypeUpdating::canHandleAsLocal(...)` rejects tuple types.

That means the helper layer itself is telling `local-subtyping`:

- “I cannot safely update this kind of local today.”

So the pass refuses those locals before trying any rewrite.

Again, the helper boundary is part of the real meaning of the pass.

## How `optimize-casts` fits in

This page also explains the scheduler order with `optimize-casts`.

`local-subtyping` does not inspect `ref.cast` itself.

So if a function only has useful refinement knowledge hidden inside cast operations, `local-subtyping` alone may see very little.

`optimize-casts` runs first and can materialize or expose better local traffic.
Then `local-subtyping` can use the smaller set of facts it actually understands.

That is why the pass order is meaningful:

- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`

## Easy-to-miss truths

If you only remember a few things from this page, remember these:

1. narrowing uses a **least upper bound**, not the narrowest leaf type
2. the pass only looks at a tiny set of local/ref sites
3. the real complexity is in the **type updater**, not the collector
4. structural dominance decides where the narrower type is actually safe
5. the updater may introduce a **copy local**
6. params and tuple locals are intentionally out of scope today

## Porting checklist

A future Starshine port should preserve all of these points:

- LUB-based combination of subtype facts
- non-concrete facts do not widen the result
- params stay out of scope unless a deeper helper port lands
- tuple locals stay out of scope unless the helper layer grows
- type updates are dominance-aware
- named blocks and catch bodies are treated as real structure hazards
- the pass may need copy-local insertion, not just local-header mutation

## Sources

- [`../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md`](../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
