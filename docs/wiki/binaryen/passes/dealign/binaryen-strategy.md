---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
  - ./wat-shapes.md
  - ../alignment-lowering/index.md
---

# Binaryen `dealign` strategy

## What the pass really is

Binaryen `dealign` is a **tiny module pass that weakens selected memory-access alignment metadata to `1`**.

That sounds trivial, and it is.
But the exact smallness matters.
The reviewed `version_129` pass does **not**:

- split loads or stores into smaller accesses
- rewrite address arithmetic
- legalize misaligned accesses through extra locals and shifts
- touch every memory instruction family
- chase profitability or runtime speed

Instead, it does one small thing:

- if a visited memory access currently has `align > 1`, set its alignment immediate to `1`

So the right mental model is:

- **alignment-metadata pessimization / normalization**
- not a general memory optimization pass

## Public surface

`pass.cpp` registers the public pass name:

- `dealign`

with the short description:

- `force all loads and stores to have align=1`

That public summary is close, but the implementation is a little more exact than the wording suggests.
The real visitor surface includes:

- `Load`
- `Store`
- `SIMDLoad`
- `SIMDStore`

and does not directly include other memory-oriented instruction families.

## Module-pass shape

The implementation is not a function pass class registered directly against the pass runner.
Instead it is a tiny module pass wrapper around a per-function postwalk.

Important consequences:

- the pass first checks whether the module even has a memory
- if there is no memory, it exits immediately
- otherwise it iterates defined functions and runs the small walker on each one

This is a useful teaching detail because it shows how narrow the real surface is: `dealign` is about function-body memory accesses, not global initializers, data segments, or module-level memory metadata.

## Exact rewrite rule

The helper logic is tiny:

- take a mutable `Address align`
- if `align > 1`, assign `align = 1`
- otherwise do nothing

That yields several durable consequences.

### What changes

- only the alignment immediate

### What does not change

- opcode kind
- width
- signedness
- offset
- pointer expression
- value expression
- result type
- control flow
- explicit trap structure

That is why this pass is best taught as a metadata rewrite.

## Positive rewrite surface

In reviewed `version_129`, `dealign` directly rewrites only these AST node families:

- scalar loads
- scalar stores
- SIMD loads
- SIMD stores

If a node in those families already has `align=1`, it stays unchanged.
If it has any stronger alignment, the pass rewrites that alignment to `1`.

## Negative surface

The pass does **not** directly visit or rewrite:

- atomics
- bulk-memory instructions
- `memory.copy`, `memory.fill`, `memory.init`, `data.drop`
- tables
- GC instructions
- control nodes
- address computations outside the current access node

That negative surface matters because the public pass name is broad enough that readers may otherwise assume “all memory ops” are in scope.

## Why the pass exists conceptually

The best way to understand `dealign` is by contrast with `alignment-lowering`.

### `alignment-lowering`

- starts from already-weak alignment
- preserves semantics by splitting ordinary scalar loads/stores into smaller aligned accesses
- uses fresh locals, bit assembly, and special unreachable handling

### `dealign`

- starts from ordinary accesses that may claim stronger alignment
- weakens the alignment promise to `1`
- preserves everything else unchanged

So although the two passes sit near the same conceptual area, they do very different work.

A useful beginner summary is:

- `dealign` changes what the IR *claims* about alignment
- `alignment-lowering` changes how the IR *implements* weak alignment

## SIMD versus scalar scope

One subtle but important difference from `alignment-lowering` is that reviewed `dealign` includes explicit `SIMDLoad` and `SIMDStore` visitors.

That means the sibling split is not just “same scope, opposite direction.”
It is also:

- `dealign`: scalar + SIMD alignment metadata rewrite
- `alignment-lowering`: ordinary scalar `Load` / `Store` legalization only

The dedicated lit file visibly proves the scalar surface.
SIMD coverage is source-confirmed from `DeAlign.cpp`; it is not the strongest separately isolated lit-backed family in the reviewed file.
That uncertainty should stay explicit in the docs.

## Test-backed visible behavior

The dedicated `dealign.wast` file proves several core facts.

### Scalar loads and stores become `align=1`

The file includes ordinary scalar load/store examples for:

- `i32`
- `i64`
- `f32`
- `f64`

with larger alignments that become `align=1` in the golden output.

### Already-`align=1` accesses stay unchanged

The same test also includes accesses already at `align=1`.
Those remain unchanged, confirming the pass is not rebuilding nodes pointlessly.

### Offsets stay intact

The printed output changes the alignment immediate, not the offset or address child.
So the pass is not performing address canonicalization.

## What a faithful port must preserve

A future Starshine port should preserve all of these source-backed properties:

- explicit public pass identity: `dealign`
- early no-memory bailout
- per-defined-function walk rather than a broad module rewrite
- narrow visitor surface: `Load`, `Store`, `SIMDLoad`, `SIMDStore`
- exact rule: only mutate when `align > 1`
- preserve offsets, types, widths, and child expressions unchanged
- keep the conceptual split from `alignment-lowering` explicit

## What this pass does not promise

`dealign` does not promise better performance, better compression, or legality repair by itself.
If anything, the pass is easier to think of as making alignment information less informative.

That is part of why the neighboring `alignment-lowering` docs needed this dossier: the sibling passes solve different problems, and confusing them leads to the wrong implementation plan.

## Shortest correct summary

If someone remembers only one sentence, it should be this:

> Binaryen `dealign` is a tiny module pass that walks defined functions and rewrites visited scalar/SIMD load/store alignment immediates down to `1`, without changing any other part of the memory access.

## Sources

- [`../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md`](../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
