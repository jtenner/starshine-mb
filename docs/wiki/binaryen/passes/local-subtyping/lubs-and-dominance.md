---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
---

# `local-subtyping`: LUBs and dominance

This page exists because the pass name still invites two common misunderstandings even after the 2026-04-22 source correction:

1. “Binaryen just picks the narrowest type it sees.”
2. “Binaryen either blindly edits the declaration or runs a huge helper rewrite.”

Both are wrong.
The reviewed `version_129` contract is smaller and more precise.

## Mental model first

A safe mental model is:

- start from the declared local type
- add concrete subtype facts from the values written into that local
- compute one common target type with a LUB
- if the target would only improve nullability, require structural dominance first
- then retag the declaration and the matching `local.get` / `local.tee` expressions directly

So the two key ideas are still:

- **least upper bounds**
- **structural dominance**

But dominance is narrower here than the older dossier said.
It is a guard, not a whole-helper rewrite engine.

## Part 1: why Binaryen uses a least upper bound

`LocalSubtyping.cpp` stores a `LUBFinder` per local.
It seeds that LUB with the current declared type for non-parameter vars and then notes concrete `local.set` / `local.tee` definition types.

The important consequence is:

- the pass is looking for one type that is compatible with every written-value fact together
- while still being as specific as possible

That is exactly what a least upper bound gives you.

## What the pass actually feeds into the LUB finder

After the 2026-04-22 correction, the source-backed list is:

- the local's existing declared type
- concrete `local.set` value types
- concrete `local.tee` result types

It does **not** feed in facts from:

- params
- tuple locals
- `local.get`
- `ref.as_non_null`
- `ref.cast`
- `br_on_cast*`
- global/table traffic

That is the single biggest correction from the older local reading.

## Example A: one obvious narrower subtype

Suppose a local is declared as a wide reference type, but every concrete value written into it is `(ref null $Child)`.
Then the LUB of the observed facts is still `(ref null $Child)`.

So the pass can narrow the local to that child type.

## Example B: two sibling subtypes

Suppose one definition writes `(ref null $Left)` and another writes `(ref null $Right)`.
If both share a common parent, the LUB may be that parent type.

This is the key beginner correction:

- Binaryen does **not** pick `$Left`
- Binaryen does **not** pick `$Right`
- Binaryen picks the best common type

That may still be narrower than the original declaration, but it may be wider than either individual leaf subtype.

## Example C: gets alone do not create a narrower target

Suppose a local is written once and then used many times in narrower contexts.
That does **not** matter to the LUB unless the written values themselves are narrower.

This is why the corrected dossier keeps saying the pass is **definition-driven** first.
The earlier “collect from gets too” story was too broad.

## Part 2: why dominance still matters

If the new type were always just a reference-subtype improvement with no nullability risk, the pass could stop after computing the LUB.
But non-nullability is trickier.

If Binaryen wants to tighten a local from nullable to non-null, it must know that all relevant gets are dominated by writes that establish the non-null value.
That is why `LocalSubtyping.cpp` still consults `LocalStructuralDominance`.

## Why simple textual order is not enough

A beginner might assume:

- “if the set appears earlier in the text than the get, it dominates the get.”

Binaryen is stricter than that.
`LocalStructuralDominance` works over structured control where:

- named blocks matter
- loops matter
- catches matter
- simple textual order is not a sufficient proof

So the helper is checking something more like:

- “is the non-null written state guaranteed on every structured path that reaches this get?”

That is a much better model.

## What dominance is **not** doing here

This is the second big correction from the older dossier.
The reviewed `version_129` pass does **not** use dominance to drive a broad `LocalUpdater(...).changeType(...)` rewrite with helper-added copy locals.

Instead, dominance is used for narrower tasks:

- guard whether a declaration may keep a non-nullability improvement
- guard whether a get can safely be retagged to that narrowed declaration type

So the right mental model is:

- LUB chooses the candidate type
- dominance decides whether the non-nullability part is actually safe to keep

## Why tuple locals are skipped today

`TypeUpdating::canHandleAsLocal(...)` still rejects tuple types.
That means the helper layer itself is telling `local-subtyping`:

- “I cannot safely represent this local type change today.”

So the pass refuses those locals before trying any rewrite.
Again, the helper boundary is real, but it is a support gate here, not a large rewrite engine.

## How `optimize-casts` fits in

This page also explains the scheduler order with `optimize-casts`.
Even after the source correction, the order still matters.

`local-subtyping` does not inspect `ref.cast` or `ref.as_non_null` itself in the reviewed source.
So if cleaner local definition types need to be exposed first, that job belongs to the left neighbor.

That is why the pass order remains meaningful:

- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`

## Easy-to-miss truths

If you only remember a few things from this page, remember these:

1. narrowing uses a **least upper bound**, not the narrowest leaf type
2. the pass's new evidence comes from **defs**, not gets
3. the helper layer is a support gate and dominance utility here, not a copy-local rewrite engine
4. structural dominance still matters for non-nullability safety
5. params and tuple locals are intentionally out of scope today
6. the older local `LocalUpdater` / `ref.as_non_null` reading was an overstatement now kept explicit in the correction note

## Porting checklist

A future Starshine port should preserve all of these points:

- declaration-seeded, def-fed LUB computation
- params stay out of scope unless a deliberate wider design lands
- tuple locals stay out of scope unless helper support grows
- reference-local-only narrowing
- dominance-gated non-nullability tightening
- direct declaration plus get/tee retagging
- no silent broadening to copy-local insertion or generic use-driven inference
