---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md
  - ../../../raw/research/0492-2026-05-05-reorder-types-port-readiness-and-validation.md
  - ../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md
  - ../../../raw/research/0438-2026-05-04-reorder-types-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md
  - ../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./ordering-cost-model-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `reorder-types`: implementation structure and tests

This page is the compact file/test map for the real Binaryen `version_129` `reorder-types` contract.
The immutable 2026-04-24 primary-source manifest is [`../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md), the 2026-05-04 current-main recheck is [`../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md), and the 2026-05-05 freshness refresh is [`../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md).

## Core implementation files

### `src/passes/ReorderTypes.cpp`

What it proves:

- the pass comment defines the real goal: reorder private types within a single large recursion group to minimize cumulative type-index size
- the implementation is a `GlobalTypeRewriter` subclass, not an ad hoc module rewrite
- the sort works over a predecessor graph of private types
- counts come from `typeInfo[type].useCount`
- successor weight is propagated backward
- Binaryen samples 21 factors from `0.0` to `1.0`
- each candidate order is topologically valid and then scored by encoded-index cost
- the public pass is GC-only and requires `--closed-world`

### `src/ir/type-updating.h` / `src/ir/type-updating.cpp`

What they prove:

- `GlobalTypeRewriter` is the shared engine `reorder-types` relies on
- the engine gathers used-IR heap types plus visibility
- public types are frozen out of the private reorder candidate pool
- predecessor edges are exactly private supertypes and private described types
- rebuilt private output types go into one single large recursion group
- public rec groups are kept distinct from the new rebuilt private group
- module code, declarations, locals, tables, globals, tags, type names, and preserved type indices are all remapped

### `src/ir/module-utils.h` / `src/ir/module-utils.cpp`

What they prove:

- `HeapTypeInfo` contains the fields the pass consumes: `useCount` and `visibility`
- `collectHeapTypeInfo(...)` is the counting surface used by the rewriter
- `UsedIRTypes` is the relevant inclusion mode here
- Binaryen also has broader binary-surface type-collection helpers, which matters because one shipped regression exists specifically to keep this pass aligned with the narrower used-IR inventory

### `src/passes/pass.cpp`

What it proves:

- `reorder-types` is a real public pass name
- the public description is “sorts private types by access frequency”
- `reorder-types-for-testing` is a hidden testing pass with an exaggerated cost function

## Neighboring context files

### `src/wasm-type-ordering.h`

What it proves:

- Binaryen has shared ordering helpers for heap-type topological order in neighboring passes
- even though `ReorderTypes.cpp` uses `support/topological_sort.h` directly, this file is useful context for how Binaryen thinks about supertype-constrained ordering more broadly

## Official test surface

### `test/lit/passes/reorder-types.wast`

What it proves:

- unconstrained private struct types reorder according to measured profitability
- supertype constraints override code-size preference when necessary
- successor-weight propagation can change which root type wins
- the testing-only exaggerated cost function is the intended lit harness surface
- a specific prior crash around mismatch between counted binary-surface types and the used-IR-types inventory is now locked down by regression

## What the lit file does **not** try to prove alone

The lit file is useful, but it is not the whole contract.
You still need the implementation files to understand:

- the public/private split
- the closed-world requirement
- the single-large-rec-group rebuild step
- the module-wide remap surface
- the exact 21-factor search

## Current Starshine-facing port checklist

The current local non-implementation and code map live in [`./starshine-strategy.md`](./starshine-strategy.md), and the implementation-readiness bridge lives in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
The 2026-05-04 current-main recheck did not change these implementation boundaries, and the 2026-05-05 freshness refresh only added the bridge.
If Starshine eventually implements `reorder-types`, the local port should preserve all of the following upstream-observable facts:

- module pass, not hot pass
- GC-only gate
- hard closed-world requirement
- private-only candidate pool
- predecessor edges from private supertypes and private described types
- multi-factor successor-weight search
- encoded-index cost scoring
- rebuild through a type-remap engine, not hand-edited declaration shuffling
- full declaration/code/metadata rewrite surface
- a test-only exaggerated-cost variant or equivalent harness coverage

## Sources

- [`../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md)
- [`../../../raw/research/0492-2026-05-05-reorder-types-port-readiness-and-validation.md`](../../../raw/research/0492-2026-05-05-reorder-types-port-readiness-and-validation.md)
- [`../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md)
- [`../../../raw/research/0438-2026-05-04-reorder-types-current-main-recheck.md`](../../../raw/research/0438-2026-05-04-reorder-types-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md)
- [`../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md`](../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md`](../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderTypes.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-type-ordering.h>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderTypes.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type-ordering.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-types.wast>
