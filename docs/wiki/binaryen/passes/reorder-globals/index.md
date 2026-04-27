---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md
  - ../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md
  - ../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-dependency-order.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../string-gathering/index.md
  - ../reorder-globals-always/index.md
  - ../directize/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `reorder-globals`

## Role

- `reorder-globals` is an upstream Binaryen late module / boundary-shaped global-layout pass.
- It now has an active direct Starshine module-pass port; `reorder-globals-always` remains boundary-only.
- On 2026-04-23, the reviewed official Binaryen `version_129` release page still showed publish date **2026-04-01**; a focused 2026-04-25 current-`main` owner/helper/test recheck did not surface teaching-relevant drift from this folder's `version_129` contract.
- In Binaryen `version_129`, it runs near the very end of the no-DWARF optimize pipeline.
- Its job is to reorder global declarations so that more index-sensitive globals get smaller indices, while still preserving import ordering and global-initializer dependency order.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `reorder-globals` after:
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
  - `string-gathering` when strings are enabled
- and before:
  - `directize`
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - slot `55`
- The saved Binaryen debug log shows it is tiny but real in that captured run:
  - `0.000166174` seconds
- The backlog already tracks it as slice `RG` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- The pass also matters as the explicit handoff target from `string-gathering`: Binaryen’s own scheduler comment says gathering happens right before `reorder-globals`, which then sorts the globals properly.
- The folder now also has a current-main raw source bridge, a dedicated implementation/test-map page, and a dedicated Starshine status/port-strategy page, so readers can move directly from reviewed upstream release/source/test surfaces to the active local module pass, remaining `always` sibling deferral, backlog slice, and numeric-`GlobalIdx` reindexing implementation.

## Beginner summary

A safe beginner mental model is:

- Binaryen looks at how often each global is used,
- keeps imports and initializer dependencies honest,
- tries a few dependency-safe candidate orders,
- estimates which order makes encoded global indices cheapest,
- and then keeps the cheapest one.

That is much closer to the real pass than either:

- “sort globals by raw use count”, or
- “repair the order after string-gathering”, or
- “always reorder globals for size”.

## Current durable takeaways

- `reorder-globals` is a **module-wide declaration-layout pass**, not a function-local rewrite pass.
- In `version_129`, the implementation lives in `src/passes/ReorderGlobals.cpp`.
- The public pass skips all work when there are fewer than `128` globals.
- The internal / test `reorder-globals-always` variant removes that cutoff and uses a smoothed synthetic cost model instead.
- Binaryen counts both `global.get` and `global.set` uses.
- It counts those uses in functions **and** in module-level code.
- Dependency constraints come from `GlobalGet` inside non-imported global initializers.
- Imports are always kept before defined globals.
- The pass tries four candidate strategies:
  - original-ish dependency-only order
  - raw-count greedy order
  - summed-dependent-count order
  - exponentially weighted dependent-count order
- Candidate orders are scored with the **true** observed use counts, not the synthetic search counts.
- Binaryen IR tracks globals by `Name`, so the pass reorders `module->globals` and refreshes maps instead of patching every use site manually.
- `string-gathering` and `reorder-globals` are intentionally different passes:
  - `string-gathering` does a narrow validity-first reorder
  - `reorder-globals` does the stronger late size/layout reorder

## Current repo caveat

- The current Starshine pass registry now splits the family explicitly:
  - `reorder-globals` is an active direct module pass implemented in `src/passes/reorder_globals.mbt`
  - `reorder-globals-always` remains a boundary-only tracked name
- The active pass implements the public production policy, including the `<128` total-global no-op, dependency-aware candidate ordering, true ULEB-size scoring, import-prefix preservation, and numeric `GlobalIdx` remapping across module/code/name surfaces.
- The public optimize/shrink presets still do not schedule the late-tail slot because neighboring `string-gathering` remains unimplemented; the active `directize` pass now has direct explicit-pass oracle signoff, but the full `string-gathering -> reorder-globals -> directize` tail still needs ordered replay before preset scheduling.

Keep preserving the distinction between the public pass and the `always` helper instead of collapsing them accidentally.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: scheduler placement, phase breakdown, helper dependencies, candidate-search structure, and the real “what this is not” facts.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner/helper/lit-test map plus the active Starshine numeric-`GlobalIdx` implementation, direct evidence, and remaining late-tail gap.
- [`./size-model-and-dependency-order.md`](./size-model-and-dependency-order.md)
  Focused guide to the use-count model, the dependency DAG, the under-`128` production cutoff, the `reorder-globals-always` variant, and the important internal use from `GlobalStructInference`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after WAT and module-shape catalog for the main positive, negative, bailout, and interaction families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status plus the local code/doc map for the active module pass, recorded direct evidence, remaining `string-gathering -> reorder-globals -> directize` scheduler slot, and the explicit split from `reorder-globals-always`.

## Current maintenance rule

- Treat this folder as the canonical home for future `reorder-globals` research and port planning.
- Keep it marked as an active direct Starshine module pass, while keeping `reorder-globals-always` and late-tail preset scheduling explicitly deferred until their own evidence lands.
- Keep the strategy page, implementation/test-map page, size/dependency page, and Starshine strategy page in sync whenever new evidence changes the answer to either:
  - “what does the pass actually optimize for?”
  - “when does Binaryen deliberately do nothing?”
  - “what exact local remap and late-tail landing story would a future Starshine port need to preserve?”

## Sources

- [`../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md`](../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md)
- [`../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md`](../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md)
- [`../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md`](../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md)
- [`../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md`](../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
