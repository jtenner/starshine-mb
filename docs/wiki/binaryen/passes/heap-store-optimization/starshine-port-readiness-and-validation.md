---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md
  - ../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md
  - ../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./swap-safety-and-control-flow.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md
  - ../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md
---

# Current Starshine `heap-store-optimization` validation bridge

This page is the compact health-check companion to the main Starshine strategy page.

Use it when you want to answer two questions quickly:

1. where the current local implementation is wired;
2. how the repo currently proves that wiring still works.

## Short version

Current Starshine keeps `heap-store-optimization` active as a hot pass.
The local implementation is still meant to fold a fresh `struct.set` back into a nearby `struct.new`, not to become generic GC heap dead-store elimination.

The practical validation surfaces are:

- unit tests for the constructor/store fold families
- perf tests for raw fast-skip behavior
- CLI replay tests for `--heap-store-optimization`
- the current-main Binaryen source spotcheck that keeps the dossier honest about upstream drift
- the refreshed `pass-fuzz-compare` direct parity lane

## Exact local code map

Read this page together with:

- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./swap-safety-and-control-flow.md`](./swap-safety-and-control-flow.md)
- [`./wat-shapes.md`](./wat-shapes.md)

The current local proof surfaces are:

- [`src/passes/heap_store_optimization.mbt:2-24`](../../../../../src/passes/heap_store_optimization.mbt)
  - descriptor and public summary.
- [`src/passes/optimize.mbt:194-196`](../../../../../src/passes/optimize.mbt)
  - active registry entry.
- [`src/passes/optimize.mbt:282-305`](../../../../../src/passes/optimize.mbt)
  - `optimize` and `shrink` preset placement.
- [`src/passes/pass_manager.mbt:7264-7274`](../../../../../src/passes/pass_manager.mbt)
  - raw fast-skip lane.
- [`src/passes/pass_manager.mbt:8097-8099`](../../../../../src/passes/pass_manager.mbt)
  - hot-pass dispatch arm.
- [`src/passes/heap_store_optimization.mbt:312-354`](../../../../../src/passes/heap_store_optimization.mbt)
  - skip-local-set and control-flow predicates.
- [`src/passes/heap_store_optimization.mbt:560-631`](../../../../../src/passes/heap_store_optimization.mbt)
  - trapless readonly and reorderable subtree predicates.
- [`src/passes/heap_store_optimization.mbt:761-792`](../../../../../src/passes/heap_store_optimization.mbt)
  - root-swap legality.
- [`src/passes/heap_store_optimization.mbt:914-970`](../../../../../src/passes/heap_store_optimization.mbt)
  - supported constructor family.
- [`src/passes/heap_store_optimization.mbt:1296-1468`](../../../../../src/passes/heap_store_optimization.mbt)
  - wrapper flattening and unreachable-tail repair.
- [`src/passes/heap_store_optimization.mbt:1653-1775`](../../../../../src/passes/heap_store_optimization.mbt)
  - shared fold-into-constructor proof and rewrite.
- [`src/passes/heap_store_optimization.mbt:1777-1827`](../../../../../src/passes/heap_store_optimization.mbt)
  - tee-wrapped fold rewrite.
- [`src/passes/heap_store_optimization.mbt:2028-2218`](../../../../../src/passes/heap_store_optimization.mbt)
  - region recursion, later-set chains, swaps, and root replacement.
- [`src/passes/heap_store_optimization.mbt:2220-2241`](../../../../../src/passes/heap_store_optimization.mbt)
  - run function, effect summary requirement, mutation marking.

## Validation ladder

### 1. Unit coverage

The focused unit suite in `src/passes/heap_store_optimization_test.mbt` is the first stop.
It covers:

- tee folds
- later constructor/store chains
- `struct.new_default` materialization
- safe and unsafe swaps
- branch and loop control-flow families
- descriptor-aware constructor families
- writeback cleanup and wrapper flattening

### 2. Perf and no-candidate behavior

`src/passes/perf_test.mbt` keeps the raw no-candidate fast path honest.
That matters because this pass is allowed to skip work when there is no plausible constructor/store pair.

### 3. CLI replay

`src/cmd/cmd_wbtest.mbt` proves the pass still resolves through the command layer for the checked-in replay fixtures.

### 4. Binaryen oracle check

The current-main source spotcheck in [`../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md`](../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md) keeps the upstream contract visible while the local implementation evolves.

The refreshed direct oracle lane in [`../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md`](../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md) ran:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization`

Result: 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures.

## What this page does not claim

- It does not claim generic heap dead-store elimination.
- It does not claim load forwarding.
- It does not claim ordered no-DWARF preset parity for the repeated `heap-store-optimization` slots.

If any of those become true later, the bridge should grow with them instead of pretending the current contract already had them.
