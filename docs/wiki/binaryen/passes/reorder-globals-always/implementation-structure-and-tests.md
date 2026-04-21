---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md
  - ../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./small-module-threshold-scoring-and-proof.md
  - ./wat-shapes.md
  - ../reorder-globals/index.md
---

# Upstream implementation structure and test map for `reorder-globals-always`

## Main implementation file

## `src/passes/ReorderGlobals.cpp`

This is still the real implementation file for the sibling.
It owns almost all of the contract that matters here:

- the function-parallel `UseCountScanner`
- module-code counting
- original-index bookkeeping
- dependency extraction from global initializers
- candidate-order generation
- public-vs-always cost scoring
- best-order selection
- and final declaration-list rebuild

That file structure proves the key point:

- `reorder-globals-always` is a sibling pass
- but it is not a sibling implementation file

The two public names are different policy surfaces built on one engine.

## `src/passes/pass.cpp`

This file proves the public pass surface.
It registers both:

- `reorder-globals`
- `reorder-globals-always`

That is the clearest official proof that the sibling is deliberate pass API surface, not a local repo invention.

## `src/passes/passes.h`

This header proves the constructor split explicitly:

- `createReorderGlobalsPass()`
- `createReorderGlobalsAlwaysPass()`

That matters for a future port because it suggests the right local design too:

- shared implementation core
- separate registry constructors

## Helper files that still matter

Even for the always sibling, these helpers matter because the engine is shared:

- `src/pass.h`
  - module-code traversal entrypoint used by the scanner
- `src/wasm-traversal.h`
  - tells you which module-code expression slots are actually scanned
- `src/support/topological_sort.h`
  - provides the dependency-aware order construction
- `src/wasm.h`
  - shows why reordering declarations is enough in Binaryen IR: global uses are name-based
- `src/passes/GlobalStructInference.cpp`
  - proves the sibling's real nested internal use after fresh-global creation

## Official lit files and what each one proves for the sibling

## `test/lit/passes/reorder-globals.wast`

This is the single most important file for `reorder-globals-always`.
It proves that the sibling exists to make the algorithm observable on small modules.

The file shows that the sibling preserves all of the real ordering rules while still making tiny examples informative. The refreshed folder's proof page now collects the exact `< 128` cutoff removal, exact `1.0 + (i / 128.0)` formula, and the strongest lit-backed examples in one place: [`./small-module-threshold-scoring-and-proof.md`](./small-module-threshold-scoring-and-proof.md).

- independent hot-global movement
- dependency barriers
- imports-first ordering
- original-order tie behavior
- non-greedy candidate wins

Without this file, it would be too easy to describe the sibling as a vague helper mode.

## `test/lit/passes/reorder-globals-real.wast`

This file is the complementary proof surface.
It shows why the sibling exists in the first place by making the public production behavior visible:

- below the threshold, ordinary `reorder-globals` intentionally does nothing
- above the threshold, the production pass uses the real cost model

That pairing gives a clean test split:

- `reorder-globals.wast` = sibling and small-module observability
- `reorder-globals-real.wast` = production cutoff and real-size behavior

## Practical source map for a future Starshine port

If the goal is a faithful `reorder-globals-always` port, the best reading order is:

1. `ReorderGlobals.cpp`
   - understand the shared engine and find where the always-vs-production split happens
2. `pass.cpp`
   - confirm public pass-name identity
3. `passes.h`
   - confirm separate constructor identity
4. `reorder-globals.wast`
   - understand why the sibling exists at all
5. `reorder-globals-real.wast`
   - keep the split from public production behavior honest
6. `GlobalStructInference.cpp`
   - keep the real nested-use story honest

## What this file map clarifies for beginners

Three things are easy to miss without the source map:

1. The sibling is a real pass name even though it reuses the same main implementation file.
2. The difference is small in code structure but large in user-facing semantics.
3. The official tests rely on the sibling to reveal small-module reorder cases that the default pass intentionally hides.

## Sources

- [`../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md`](../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md)
- [`../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md`](../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
