---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0217-2026-04-21-type-ssa-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./wat-shapes.md
---

# Upstream implementation structure and test map for `type-ssa`

## Why this page exists

The landing page explains what `type-ssa` is for.
This page answers a different question:

- which official Binaryen files actually define that contract?

For `type-ssa`, the answer is pleasantly small.
The real contract is mostly one implementation file, one registration file, one direct lit file, and one explicit refinalization dependency.

## Main upstream files

### 1. `src/passes/TypeSSA.cpp`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>

This is the real implementation.
It defines:

- the `createdTypes` map,
- the `getTargetType`, `setCreatedType`, and `getValue` helpers,
- the seed visitors for `struct.new`, `array.new`, `array.new_fixed`, `ref.as_non_null`, and `ref.cast`,
- local/global forwarding,
- direct-call operand and return-value retagging,
- and the final GC-only `ReFinalize` step.

If you only read one file for this pass, read this one.

### 2. `src/passes/pass.cpp`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>

This file matters because it proves that `type-ssa` is a real public Binaryen pass name.
That is the source-backed reason to track it as its own dossier instead of leaving it only as a contrast point inside `type-merging`.

### 3. `src/ir/ReFinalize.cpp`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>

This file matters because `type-ssa` explicitly invokes `ReFinalize` when a GC function changed.
That makes refinalization part of the real correctness contract, not just optional surrounding cleanup.

## Dedicated official test

### `test/lit/passes/type-ssa.wast`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>

This is the direct public proof surface for the pass.
It shows the main positive and preserved families Binaryen considers part of the contract:

- local and global forwarding from freshly created exact values,
- branch-value agreement through `if`,
- `try` result forwarding,
- direct call-operand sharpening,
- return-value sharpening,
- and preserved broader types when the proof is too weak.

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `TypeSSA.cpp` | core algorithm | `type-ssa` is a created-exact-type retagging pass, not generic SSA conversion |
| `pass.cpp` | public registration | `type-ssa` is a real user-visible Binaryen pass |
| `ReFinalize.cpp` | correctness dependency | parent types must be recomputed after successful GC retagging |
| `type-ssa.wast` | behavior oracle | the real public rewrite surface is local/global/control-value plus call/return retagging |

## Implementation outline

The reviewed `version_129` implementation is compact enough to summarize almost linearly:

1. define a function walker with a `createdTypes` map,
2. convert eligible created refs into exact non-null target types,
3. seed those types from constructor/cast-like nodes,
4. propagate them through `block` / `if` / some `try` values,
5. propagate them through `local.set` / `global.set`,
6. retag later `local.get` / `global.get`,
7. retag direct call operands and return values when subtype-safe,
8. refinalize changed GC functions.

That compactness is itself important.
`type-ssa` is a small specialized pass.

## What the test file proves best

## Local/global forwarding

The test demonstrates that a value freshly created at one exact heap type can be stored and later reloaded with that precision intact.

## Control-value propagation

The test also proves that matching branch results can carry a created type upward through wrappers like `if` and some `try` forms.

## Signature-facing retagging

The pass does not stop at local gets.
The test covers call and return edges too, which is important for later GC optimization passes.

## Preserved bailouts

The test file is also useful because of what it does **not** claim.
It does not present `type-ssa` as a broad flow-sensitive optimizer for every control form.
That matches the source's explicit conservatism around loops and mismatched joins.

## Current-main drift check

I did a narrow current-main spot check on:

- `src/passes/TypeSSA.cpp`
- `test/lit/passes/type-ssa.wast`

On the reviewed surfaces, current `main` still matched the tagged `version_129` behavior relevant to this dossier.
So the documented behavior here is not sitting on a known current-main drift.

## Relationship to nearby dossiers

This file/test map sharpens the split from neighboring pages:

- compared with [`../ssa/index.md`](../ssa/index.md), `type-ssa` is much smaller and never builds general SSA scaffolding,
- compared with [`../type-refining/index.md`](../type-refining/index.md), it does not aggregate field traffic across the closed world,
- compared with [`../type-generalizing/index.md`](../type-generalizing/index.md), it does not use a content oracle,
- compared with [`../type-merging/index.md`](../type-merging/index.md), it improves use precision rather than merging declarations.

## Porting checklist derived from the official file map

A future Starshine port should not be called faithful unless it has equivalents for:

- created exact-type seeding,
- conservative `block` / `if` / `try` value forwarding,
- local and global propagation,
- call-operand and return-value retagging,
- explicit `loop` no-propagation behavior,
- GC-only refinalization after changes,
- a dedicated test surface that locks the same families.

## Practical reading order

For future follow-up work, the best reading order is:

1. `pass.cpp` to confirm the public pass identity,
2. `TypeSSA.cpp` to understand the whole algorithm,
3. `type-ssa.wast` to see the real visible families,
4. `ReFinalize.cpp` only when the post-change repair story needs deeper confirmation.
