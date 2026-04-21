---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../reorder-globals/index.md
  - ../remove-unused-types/index.md
  - ../minimize-rec-groups/index.md
---

# `reorder-types`: ordering, cost model, and boundaries

## The real teaching problem

The pass now has a precise source-backed shape:

1. which **private** types may move?
2. which topological orders are **legal**?
3. which legal order gives the smallest cumulative encoded type-index cost?

So the pass is not "sort by count" and it is not "just keep validation happy afterward."
The legality constraints shape the sort itself.

## Exact candidate pool

The candidate pool comes from `collectHeapTypeInfo(...)` with:

- `TypeInclusion::UsedIRTypes`
- `VisibilityHandling::FindVisibility`

That has three important consequences:

- Binaryen counts only used IR heap types here
- Binaryen knows which of those types are public vs private
- only private types are reorder candidates

This closes the old dossier's biggest uncertainty: public types do not participate in the reorder.

## Exact legality edges

For each private type, `GlobalTypeRewriter::getPrivatePredecessors()` adds predecessors for:

- its declared private supertype, if any
- its private described type, if any

That means the core legality story is just two edge families:

- supertype before subtype
- described type before descriptor

There is no evidence in `version_129` that `reorder-types` adds any broader custom constraint system beyond those edges and the inherited public/private split.

## Exact profitability model

`ReorderTypes.cpp` uses a two-stage profitability model.

### Stage 1: weight search

For 21 factors from `0.0` through `1.0`, Binaryen computes weights like this:

- start from direct `useCount`
- propagate `successorWeight * factor` back into each predecessor
- topologically sort with higher-weight types earlier

So successors can influence whether their predecessors are worth moving earlier too.

### Stage 2: real cost evaluation

Binaryen does not trust weight order alone.
It computes the total layout cost of each candidate order using index-byte width.

Normal mode uses:

- `bitsPerByte = 7`

Testing mode uses:

- `bitsPerByte = 1`

The testing mode exaggerates index-width jumps so tiny lit modules show visible reorderings.

## Why 21 factors matter

The pass does not assume one perfect successor-bias value.
It samples the whole `0.0 .. 1.0` range and keeps the cheapest outcome.

That gives a better beginner explanation than the old dossier's speculation:

- factor `0.0` means direct counts only
- larger factors increasingly care about downstream successor traffic
- the final result is whichever factor yields the smallest encoded-index cost

## Single-large-rec-group rebuild rule

The pass's most surprising boundary is in `GlobalTypeRewriter::rebuildTypes(...)`:

- reordered private output types are rebuilt into **one single large recursion group**

Why:

- the new types must stay distinct
- the rebuilt graph may have more recursive structure than the old private groups
- one large new group is the simple safe representation

So the pass does **not** preserve old private rec-group partitioning.
That is a crucial distinction from `minimize-rec-groups`.

## Public/private boundary

Public types are treated as frozen because Binaryen assumes they may still be:

- reflected on
- observed through linking
- boundary-visible even in a closed-world optimization run

`GlobalTypeRewriter` also preserves public rec groups separately and ensures the new private rebuilt group does not collide with them.

## Full-module rewrite boundary

The pass is only correct once all of these are updated consistently:

- function signatures
- local variable types
- expression result types
- expression heap-type fields
- tables
- element segments
- globals
- tags
- type names
- preserved type-index metadata

This is why the pass belongs in the same mental bucket as other module-wide type-remap passes, not as a tiny local reorder.

## Important contrasts with neighboring passes

### Not `remove-unused-types`

- `remove-unused-types`: which private types can disappear?
- `reorder-types`: what order should the surviving private types use?

### Not `minimize-rec-groups`

- `minimize-rec-groups`: how should recursion groups be repartitioned or branded?
- `reorder-types`: what private-type index order is cheapest under legality constraints?

### Related to `reorder-globals`, but stricter

Like `reorder-globals`, this is a size/layout pass.
Unlike `reorder-globals`, it also has to honor heap-type supertype and described-type edges and then rebuild types safely.

## What the lit tests prove about boundaries

The shipped `reorder-types.wast` proves at least four important boundaries:

- unconstrained private struct types reorder by measured profitability
- ordering constraints can override apparent code-size wins
- successor weighting can break ties or change which root type wins
- a past crash around used-IR-types collection versus broader binary-surface collection is now covered by regression

## Porting checklist

Before implementing `reorder-types` in Starshine, answer these in code and tests:

- Are you counting only used IR heap types?
- Are public types frozen?
- Are predecessor edges limited to private supertypes and private described types?
- Do you sample the same factor range?
- Do you compute real encoded-index cost rather than trusting raw counts?
- Do you rebuild reordered private types into one large new private rec group?
- Do you remap locals, code, declarations, and metadata together?

## Sources

- [`../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md`](../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderTypes.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-types.wast>
