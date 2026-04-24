---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-dealign-primary-sources.md
  - ../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast
  - ../alignment-lowering/binaryen-strategy.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../alignment-lowering/index.md
supersedes:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
---

# `dealign`: exact rewrite surface and the split from `alignment-lowering`

## Why this page exists

The easiest mistake with `dealign` is to treat it as a smaller or cruder `alignment-lowering`.
It is not.

This page keeps the sibling split explicit and corrects the older over-broad visitor story.

## The exact rewrite surface

In reviewed Binaryen `version_129`, `dealign` directly rewrites these node families:

- `Load`
- `Store`
- `SIMDLoad`

For each visited node, the source-level rewrite is direct assignment:

- set the alignment immediate to `1`

That is the only field the pass intends to change.

## What it preserves

`dealign` preserves:

- access width
- scalar-vs-SIMD load opcode family
- signedness on scalar loads
- offset
- pointer child
- stored value child for stores
- result type
- surrounding control flow

If a future port changes any of those, it is already doing more than reviewed Binaryen `dealign`.

## Corrected scalar versus SIMD scope

### `dealign`

- scalar `Load` alignment metadata rewrite
- scalar `Store` alignment metadata rewrite
- `SIMDLoad` alignment metadata rewrite
- no reviewed `SIMDStore` visitor

### `alignment-lowering`

- ordinary scalar `Load` / `Store` legalization only
- no SIMD lowering surface in the reviewed `version_129` file
- extra locals, shifts, ors, reinterprets, and split accesses

So the sibling distinction is not just opposite direction. The exact node scopes are also different.

## The real split from `alignment-lowering`

### `dealign`

- weakens alignment promises
- preserves the same access node shape
- never inserts helper locals
- never changes the number of memory accesses
- never changes address arithmetic

### `alignment-lowering`

- starts from already-weak alignment
- preserves semantics by replacing one weakly aligned scalar access with several smaller aligned accesses
- often inserts helper locals
- changes the number of memory accesses
- rebuilds or splits bits explicitly

That is why it is wrong to teach `dealign` as “the front half of `alignment-lowering`” or to teach `alignment-lowering` as “fixing what `dealign` breaks.”

## Lit-backed proof versus source-confirmed proof

The dedicated `dealign.wast` file directly proves a small scalar `i32.load` / `i32.store` surface.
The implementation file proves that the same direct alignment assignment applies to the generic `Load` and `Store` AST node families and to `SIMDLoad`.

The honest source-strength summary is:

- scalar `i32` load/store examples: directly lit-backed
- broader scalar load/store family: source-confirmed through generic `Load` / `Store` visitors
- `SIMDLoad`: source-confirmed from the implementation
- `SIMDStore`: not part of reviewed `version_129` source

That is a useful example of the wiki rule to record proof strength instead of smoothing it away.

## What this pass is not

`dealign` is not:

- a general memory optimizer
- a legality repair pass
- a chunk-splitting transform
- an address simplifier
- a bulk-memory pass
- an atomic pass
- a SIMD-store pass in reviewed `version_129`

Its contract is far smaller than all of those.

## Shortest correct comparison

- `dealign` says: “mark these covered accesses as byte-aligned.”
- `alignment-lowering` says: “implement a weakly aligned scalar access using smaller aligned accesses.”

## Sources

- [`../../../raw/binaryen/2026-04-24-dealign-primary-sources.md`](../../../raw/binaryen/2026-04-24-dealign-primary-sources.md)
- [`../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md`](../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
- [`../alignment-lowering/binaryen-strategy.md`](../alignment-lowering/binaryen-strategy.md)
