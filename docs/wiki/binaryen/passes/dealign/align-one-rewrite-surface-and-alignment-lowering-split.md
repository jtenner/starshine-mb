---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast
  - ../alignment-lowering/binaryen-strategy.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../alignment-lowering/index.md
---

# `dealign`: exact rewrite surface and the split from `alignment-lowering`

## Why this page exists

The easiest mistake with `dealign` is to assume it is just a smaller or cruder version of `alignment-lowering`.
That is not true.

This page exists to keep the sibling split explicit.

## The exact rewrite surface

In reviewed Binaryen `version_129`, `dealign` directly rewrites only these node families:

- `Load`
- `Store`
- `SIMDLoad`
- `SIMDStore`

For each visited node, the rewrite rule is:

- if `align > 1`, rewrite it to `1`
- else leave it alone

That means the pass changes exactly one field:

- the alignment immediate

## What it preserves

`dealign` preserves all of these things:

- access width
- scalar-vs-SIMD opcode family
- signedness on scalar loads
- offset
- pointer child
- stored value child
- result type
- surrounding control flow

So if a future port changes anything else, it is already doing more than the reviewed Binaryen pass.

## Scalar versus SIMD scope

One subtle but important fact is that `dealign` includes explicit SIMD visitors.
That matters because the neighboring `alignment-lowering` dossier is intentionally narrower.

### `dealign`

- scalar load/store alignment metadata rewrite
- SIMD load/store alignment metadata rewrite

### `alignment-lowering`

- ordinary scalar `Load` / `Store` legalization only
- no SIMD lowering surface in the reviewed `version_129` file
- extra locals, shifts, ors, reinterprets, and split accesses

So the sibling distinction is not just opposite direction.
It is also different scope.

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

That is why it is wrong to teach `dealign` as “the front half of alignment-lowering” or to teach `alignment-lowering` as “just fixing what `dealign` breaks.”
They are neighboring but distinct passes.

## Lit-backed proof versus source-confirmed proof

The dedicated `dealign.wast` file directly proves the scalar alignment-immediate rewrite surface.
The implementation file directly proves that the same rule also applies to `SIMDLoad` and `SIMDStore`.

So the honest source-strength summary is:

- scalar surface: directly lit-backed
- SIMD surface: source-confirmed from the implementation, but not isolated by a visibly dedicated lit family in the reviewed test file

That is a good example of the wiki rule to record uncertainty instead of smoothing it away.

## What this pass is not

`dealign` is not:

- a general memory optimizer
- a legality repair pass
- a chunk-splitting transform
- an address simplifier
- a bulk-memory pass
- an atomic pass

Its real contract is far smaller than all of those.

## Shortest correct comparison

If someone needs the one-line split:

- `dealign` says “pretend the access is only byte-aligned”
- `alignment-lowering` says “implement a weakly aligned scalar access using smaller aligned accesses”

## Sources

- [`../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md`](../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
- [`../alignment-lowering/binaryen-strategy.md`](../alignment-lowering/binaryen-strategy.md)
