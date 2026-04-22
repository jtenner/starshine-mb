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
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
---

# Binaryen `local-subtyping` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The primary-source manifest for this refreshed dossier is [`../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md).
- The 2026-04-22 review corrected an earlier local overread: the real pass is smaller than the first 2026-04-20 dossier taught.

Primary source URLs:

- Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `LocalSubtyping.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `lubs.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- `type-updating.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- `local-structural-dominance.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- `local-subtyping.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>

## High-level intent

Binaryen uses `local-subtyping` to make eligible local declarations more specific when the concrete values written into them are already more specific than the declaration.

That sentence is true but incomplete.
The reviewed `version_129` implementation is deliberately narrow.

It is not:

- generic local-flow type inference
- a `local.get` evidence collector
- a `ref.as_non_null` or `ref.cast` collector
- parameter narrowing
- tuple-local narrowing
- a `LocalUpdater`-driven copy-local rewrite pass
- a pass that ends with `ReFinalize()` in the reviewed source body

Instead, the real contract is:

- look only at non-parameter locals
- seed one LUB per original local from the declared local type
- collect additional concrete subtype facts from `local.set` / `local.tee` definitions
- compute one candidate LUB per local
- narrow only helper-supported reference locals
- require structural dominance before keeping a non-nullability tightening
- retag the declaration plus matching `local.get` / `local.tee` expression types directly

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| GC-gated scheduling | Run only in the GC local-cleanup cluster | This pass is about reference local declarations, not general locals cleanup |
| Seed one LUB per local | Initialize from the current declared type for non-parameter vars | Keeps the current declaration as the baseline instead of inventing new types |
| Collect definition facts | Note concrete `local.set` / `local.tee` value types | Learns how narrow the written values already are |
| Compute candidate type | Ask each `LUBFinder` for one common type | Narrow conservatively across all written values |
| Helper support gate | Require `TypeUpdating::canHandleAsLocal(...)` and a reference local | Skip unsupported locals such as tuples and non-refs |
| Dominance gate | If the improvement is non-nullability, require `dominatesAll(...)` | Avoid making the declaration non-null when some gets can still see the nullable state |
| Retag declaration and users | Update the local declaration plus matching `local.get` / `local.tee` types | Keep expression typing aligned with the narrower declaration |

## Phase 1: scheduler placement and gating

In `pass.cpp`, Binaryen places `local-subtyping` inside the GC-only local cleanup cluster.

The canonical no-DWARF neighborhood is:

- `heap2local`
- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

That placement is meaningful.
`pass.cpp` comments explicitly that `LocalSubtyping` must run before `CoalesceLocals`, or coalescing can force common supertypes and make subtyping opportunities disappear.

## Phase 2: one `LUBFinder` per original local

At function entry, `LocalSubtyping.cpp` creates a `LUBFinder` for each original local index.
It snapshots the original local count before mutation.

Then it seeds only the non-parameter locals with their current declared type.
That seed step matters because it means:

- every candidate narrowing starts from the actual declaration
- if the pass learns nothing more specific, the declaration stays unchanged
- the computed answer stays anchored to the local's current type contract

## Phase 3: parameters stay out of scope

The reviewed pass only seeds locals starting at `numParams` and only rewrites locals in that same range.

That keeps parameters out of scope entirely in `version_129`.
A faithful Starshine port should preserve that conservatism first.

## Phase 4: fact collection is definition-driven, not use-driven

This is the biggest source correction in the refreshed dossier.
The reviewed pass does **not** gather new evidence from `local.get` or `ref.as_non_null`.

### `visitLocalSet`

The collector logic lives in `visitLocalSet`.
For non-parameter locals, if the set value type is concrete, Binaryen notes:

- the `local.tee` result type for tees
- otherwise the assigned value type

That means the pass watches what concrete values flow **into** a local.
It does not infer new candidate types from where gets are later consumed.

## Phase 5: narrowing still uses a least upper bound

After collection, Binaryen asks each `LUBFinder` for its `getLUB()`.
That means it is searching for one type that satisfies all the written-value facts together while still being as specific as possible.

This is not:

- “pick the narrowest leaf type seen”
- “pick the last assigned type”
- “pick whatever one use site seems to want most”

A good beginner rule is:

- Binaryen narrows to the best **common** type for the declaration, based on the values written into that local.

## Phase 6: only helper-supported reference locals can change

Before applying a candidate type, `LocalSubtyping.cpp` checks:

- the local's current type is a reference type
- `TypeUpdating::canHandleAsLocal(currentType)`
- `TypeUpdating::canHandleAsLocal(candidateType)`

`type-updating.h` keeps the important current rule explicit:

- tuple types are not handled here

So even if a tuple local looked narrowable in theory, this pass intentionally skips it today.

## Phase 7: nullability tightening is dominance-gated

The reviewed pass still uses `LocalStructuralDominance`, but in a narrower way than the older dossier taught.

If the candidate type differs from the current type only by nullability, Binaryen requires:

- `LocalStructuralDominance(func, wasm).dominatesAll(localIndex, candidateType)`

If that proof fails, Binaryen keeps the local declaration nullable.

That means dominance is part of correctness here, but as a guard on non-nullability tightening, not as a generic whole-function local rewrite engine.

## Phase 8: the pass rewrites declarations and expression types directly

When Binaryen accepts a narrower type, it directly updates the local declaration stored in the function.

Then it retags matching local expression types.
The important expression families are:

- `local.get`
- `local.tee`

This is another key correction.
The reviewed pass does **not** call `LocalUpdater(...).changeType(...)` here.
So the real `version_129` strategy is smaller and more direct than the earlier local summary suggested.

## Phase 9: some gets may stay wider

`visitLocalGet` still matters in the reviewed pass, but not as a collector.
It matters as a repair step after declaration narrowing.

When a get still cannot safely adopt the narrowed type, Binaryen can leave that get's expression type at the local's original wider type.
The important case is non-nullability: an undominated get should not be retagged to a non-null type just because some later definitions proved non-null in another region.

So the pass is not simply “change the declaration and every get follows automatically.”
It still keeps some per-get conservatism.

## What the pass does **not** do

A future Starshine port should avoid accidentally broadening this pass beyond the reviewed upstream contract.
`local-subtyping` in `version_129` does **not**:

- narrow params
- narrow tuple locals
- collect evidence from `local.get`
- collect evidence from `ref.as_non_null`
- directly inspect `ref.cast`, `ref.test`, or `br_on_cast*`
- call `LocalUpdater(...).changeType(...)`
- rely on helper-added copy locals as part of this pass's contract
- end with `ReFinalize()` in the reviewed pass body

## Why the shipped test matters

`test/lit/passes/local-subtyping.wast` is a great guide to the real scope.
It exercises the families that the smaller source-backed reading predicts:

- narrowing from set-driven concrete reference values
- common-parent LUB behavior from sibling definitions
- tee retagging
- non-nullability cases where dominance matters
- preserved param and tuple boundaries

That dedicated test surface supports the corrected, smaller interpretation of the pass.

## The most important porting lessons

If Starshine ports `local-subtyping`, preserve these facts first:

1. GC-gated scheduler placement after `optimize-casts` and before `coalesce-locals`
2. non-parameter-local-only scope
3. tuple-local exclusion unless helper support grows first
4. definition-driven LUB collection from `local.set` / `local.tee`
5. reference-local-only narrowing
6. dominance-gated non-nullability tightening
7. direct declaration plus `local.get` / `local.tee` retagging
8. no silent broadening to `LocalUpdater`, copy-local insertion, `ref.as_non_null`, or generic use-driven inference unless a newer source or deliberate local design doc says so

Those are the durable upstream truths after the 2026-04-22 source correction.
