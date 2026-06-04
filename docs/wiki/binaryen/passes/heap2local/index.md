---
kind: entity
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0531-2026-05-06-heap2local-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md
  - ../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md
  - ../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md
  - ../../../raw/research/0245-2026-04-22-heap2local-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
  - ../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md
  - ../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md
  - ../../../../../src/passes/heap2local.mbt
  - ../../../../../src/passes/heap2local_test.mbt
  - ../../../../../src/passes/heap2local_primary_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Heap2Local.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap2local.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/Heap2Local.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap2local.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./validation-fixups-and-special-cases.md
  - ./wat-shapes.md
  - ./parity.md
  - ./starshine-hot-ir-strategy.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../heap-store-optimization/index.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
---

# `heap2local`

## Role

- `heap2local` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is only:
  - `replace GC allocations with locals`

That description is true, but too small.

A better beginner summary is:

- Binaryen finds a freshly created GC object that never escapes the current function,
- proves that every reachable use is exclusive to that exact allocation,
- lowers small fixed-size arrays into synthetic structs first,
- scalarizes the surviving struct fields into locals,
- folds some direct ref operations (`ref.is_null`, `ref.eq`, `ref.test`, `ref.cast`, `ref.get_desc`) using exact knowledge of the allocation,
- and then repairs nullability, expression types, and EH shape so the result still validates.

So this is **not** a generic heap-to-stack pass for all GC traffic.
It is a conservative, shape-driven scalarization pass for nonescaping, exclusive allocations.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `heap2local` as the strongest remaining implemented landing-page target.
- In the canonical no-DWARF `-O` / `-Os` function scheduler, it sits in the middle GC/local cleanup cluster:
  - `... -> remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals -> ...`
- That placement is meaningful:
  - earlier cleanup reduces noisy control/local traffic first
  - `heap2local` turns some GC object traffic into ordinary locals
  - later cast/subtyping/local-cleanup passes can exploit the newly scalarized shapes
- The saved generated-artifact `-O4z` audit put `heap2local` in the expensive-but-successful cluster rather than the corruption cluster:
  - `17.00x` wall ratio
  - `3.66x` pass ratio
- The saved Binaryen debug log contains `18` `running pass: heap2local` lines, so nested reruns matter here too.

## Most important durable takeaways

- Upstream `heap2local` is not just “replace a local-held struct with field locals.”
- The real safety contract is:
  1. **no escape from the function**
  2. **exclusive use** at every reachable use site
- Arrays are only handled when they are small fixed struct-like shapes:
  - constant size
  - size `< 20`
  - analyzable indexed access
- Upstream Binaryen lowers arrays through an explicit **array -> synthetic struct -> locals** pipeline.
- The pass handles more than `struct.get` / `struct.set`:
  - comparisons and null checks
  - tests and casts
  - descriptor reads and descriptor-based cast cases
  - packed field semantics
  - atomic and RMW/cmpxchg corner cases
- Validation repair is part of the real pass contract, not optional polish:
  - `ReFinalize`
  - `EHUtils::handleBlockNestedPops`
  - generic nondefaultable-local fixups through the pass framework

## Biggest beginner correction

The easy wrong mental model is:

- `heap2local` is Binaryen's generic escape-analysis stack-allocation pass

The safer mental model is:

- `heap2local` is a conservative **GC scalarization** pass for exact fresh allocations whose identity never matters outside the function and never mixes with another possible value.

That difference matters a lot.
It explains why the pass happily optimizes some direct local, tee, block, and small-array shapes, but immediately gives up on call escapes, return escapes, if-else mixes, ambiguous local provenance, and most dynamic array indexing.

## What the pass sounds like versus what it actually does

What it sounds like:

- replace GC objects with locals

What it actually is in `version_129`:

- a function-parallel pass with reusable per-function `Parents`, `BranchTargets`, and `LazyLocalGraph` analysis,
- an `EscapeAnalyzer` that tracks child-parent flow and branch-sent values,
- a struct rewrite engine that introduces locals, scratch temps, nullable placeholders, and exact rewrites for direct ref operations,
- a separate array-to-struct lowering stage for small fixed-size arrays,
- and mandatory type / local / EH repair afterwards.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the real `Heap2Local.cpp` structure, helper analyses, scheduler placement, and the multi-stage array + struct algorithm.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source-confirmed owner-file, helper, lit-test, and Starshine code-map page for `heap2local`, including exact local registry, dispatcher, candidate-analysis, rewrite, focused-test, and preset line ranges.
- [`./validation-fixups-and-special-cases.md`](./validation-fixups-and-special-cases.md)
  - Focused guide to the easiest parts to misunderstand: nondefaultable locals, `ReFinalize`, packed fields, atomics, descriptor families, and the small but real post-`version_129` drift on current `main`.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering positive struct/array flows, bailout shapes, explicit trap families, and the important source-only corner cases.
- [`./parity.md`](./parity.md)
  - Current in-tree Starshine parity state, focused coverage, and the current boundary between active Starshine parity and broader upstream-only fixup surface.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current Starshine HOT-IR strategy, now with an exact MoonBit registry / dispatcher / candidate-analysis / rewrite / test map so readers can move directly from the dossier into `src/passes/heap2local.mbt`.
- [`../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md)
  - Immutable current-main source bridge and exact Starshine code-map refresh for this dossier.
- [`../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md`](../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md)
  - Immutable primary-source manifest for the official Binaryen release, source, and lit-test surfaces re-checked in the earlier run.

## Freshness note

A 2026-04-22 re-check of the official Binaryen GitHub release surfaces recorded `version_129` as the reviewed release anchor for this dossier, with the release page showing publish date **2026-04-01**.

A 2026-04-25 current-main code-map refresh did not find new teaching-relevant drift beyond the already-recorded source caveat. A narrow direct source comparison still finds **real but limited** post-`version_129` drift in current `main`:

- array interaction checks are slightly more precise
- `array.cmpxchg` / `struct.cmpxchg` expected-vs-ref handling is more refined
- `visitRefTest` now explicitly skips unreachable code

The important nuance is that the dedicated `heap2local.wast` file on `main` changed only by a typo fix (`vaccum` -> `vacuum`).
So the drift is visible in the owning source file, but not yet matched by obvious new dedicated lit coverage in that test file.

Current durable rule:

- treat Binaryen `version_129` as the released semantic oracle for this dossier
- keep a small note that current trunk has already tightened a few array/cmpxchg/unreachable corner cases

## Current maintenance rule

- 2026-05-06 direct revalidation: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --out-dir .tmp/pass-fuzz-heap2local` compared 6759/10000 cases with 6759 normalized matches, 0 mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures. See [`../../../raw/research/0531-2026-05-06-heap2local-direct-revalidation.md`](../../../raw/research/0531-2026-05-06-heap2local-direct-revalidation.md).
- Treat this folder as the canonical home for future `heap2local` parity and scheduler research.
- Keep the main correction explicit:
  - upstream `heap2local` is conservative GC scalarization, not generic stack allocation
- Keep the array-first, exclusivity-proof, and validation-repair stories explicit whenever future docs or code changes touch this pass.
- Keep the 2026-05-08 backlog-closure boundary explicit too: the old `[H2L]002` neighbor-slot work is done, while nondefaultable-local repair remains an upstream/source-contract note until Starshine accepts that validator surface.
- Keep the exact local navigation path explicit too: registry / preset placement in `src/passes/optimize.mbt`, dispatch in `src/passes/pass_manager.mbt`, rewrite logic in `src/passes/heap2local.mbt`, proof coverage in the focused local test files, and the line-range map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
- Keep the current-main drift note explicit unless a future released Binaryen tag absorbs those changes.

## Sources

- [`../../../raw/research/0531-2026-05-06-heap2local-direct-revalidation.md`](../../../raw/research/0531-2026-05-06-heap2local-direct-revalidation.md)
- [`../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md)
- [`../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md`](../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md)
- [`../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md`](../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md)
- [`../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md`](../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md)
- [`../../../../../src/passes/heap2local.mbt`](../../../../../src/passes/heap2local.mbt)
- [`../../../../../src/passes/heap2local_test.mbt`](../../../../../src/passes/heap2local_test.mbt)
- [`../../../../../src/passes/heap2local_primary_test.mbt`](../../../../../src/passes/heap2local_primary_test.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Heap2Local.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap2local.wast>
- Narrow freshness-check surfaces:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Heap2Local.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap2local.wast>
