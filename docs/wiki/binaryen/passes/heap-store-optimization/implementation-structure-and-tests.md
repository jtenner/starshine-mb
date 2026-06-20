---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/research/0246-2026-04-22-heap-store-optimization-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./swap-safety-and-control-flow.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `heap-store-optimization` implementation structure and tests

## Scope

This page maps the source files and test surfaces that prove the `heap-store-optimization` contract.
For the compact validation and replay companion, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
It is deliberately more concrete than the overview:

- read [`./binaryen-strategy.md`](./binaryen-strategy.md) for the algorithm;
- read [`./wat-shapes.md`](./wat-shapes.md) for before/after shapes;
- read [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) for the local HOT implementation map.

## Upstream Binaryen owner file

The upstream owner is:

- `src/passes/HeapStoreOptimization.cpp`

In Binaryen `version_129` and the 2026-05-05 current-main recheck, that file owns the whole public pass implementation.
The key structure is small enough to keep in one mental model:

| Source area | What it proves |
| --- | --- |
| file header TODO | The pass is not yet generic GC dead-store elimination or load forwarding. |
| CFG walker declaration | The pass runs function-parallel with CFG basic blocks as the local reasoning unit. |
| `visitStructSet` / `visitBlock` action collection | The pass records only `struct.set` and `block` action sites. |
| `optimizeStructSet(...)` | Immediate `local.tee(struct.new ...)` forms can fold directly. |
| `optimizeBlock(...)` | Later local-set / local-get / struct-set chains are scanned root-by-root. |
| `trySwap(...)` | The constructor local-set can move across only a narrow safe blocker. |
| `optimizeSubsequentStructSet(...)` | The main legality proof: type/field match, local hazards, effect order, control-flow safety, default materialization, and side-effect preservation. |

The file's shape is the strongest evidence for the beginner rule: **this pass is constructor/store folding, not broad heap optimization**.

## Upstream helper surfaces

Binaryen's owner file depends on a small helper cluster:

- `src/cfg/cfg-traversal.h`
  - provides the CFG walker and action-list storage shape.
- `src/ir/effects.h`
  - backs the `EffectAnalyzer` / shallow-effect comparisons used to decide if moving a value changes observable behavior.
- `src/ir/local-graph.h`
  - provides `LazyLocalGraph::canMoveSet(...)`, the hard control-flow safety check for values that may branch around the moved local assignment.
- `src/passes/pass.cpp`
  - registers the public `heap-store-optimization` pass and places it in GC-gated optimize pipelines.
- `src/passes/passes.h`
  - declares the public constructor.

Do not attribute the pass to a larger Binaryen heap-analysis framework. The dedicated owner plus these helpers are the reviewed contract.

## Upstream lit coverage

The dedicated upstream lit file is:

- `test/lit/passes/heap-store-optimization.wast`

The important proof families are:

- immediate tee-wrapped positive rewrites;
- subsequent `local.set` / `struct.set` positive chains;
- repeated-store chains into one constructor;
- `struct.new_default` materialization;
- safe swap cases;
- effect-order negative cases;
- target-local read/write hazards;
- control-flow cases where `LazyLocalGraph` must prove or reject movement;
- unsupported non-goals around broader heap stores.

The lit file is also a useful teaching surface because it makes the pass's narrowness visible: examples center on `struct.set`, not `array.set`, linear-memory `store`, or general heap load forwarding.

## Current-main recheck result

The 2026-05-05 current-main recheck found no teaching-relevant drift from the earlier `version_129` dossier and refreshed the exact local line anchors used by the living dossier.
Current upstream `main` still teaches the same contract:

- generic heap dead-store elimination remains TODO;
- only `StructSet` and `Block` action sites are recorded;
- tee and later-local-set shapes are the positive families;
- local swapping remains narrow;
- `LazyLocalGraph::canMoveSet(...)` remains the control-flow safety proof for the hard case.

The recheck was focused on pass-contract surfaces, not a formal byte-for-byte diff of every helper.

## Starshine implementation owner

The active Starshine owner file is:

- [`../../../../../src/passes/heap_store_optimization.mbt`](../../../../../src/passes/heap_store_optimization.mbt)

Exact current entry points:

- [`src/passes/heap_store_optimization.mbt:2-24`](../../../../../src/passes/heap_store_optimization.mbt)
  - descriptor and public summary.
- [`src/passes/heap_store_optimization.mbt:312-354`](../../../../../src/passes/heap_store_optimization.mbt)
  - skip-local-set / control-flow predicates.
- [`src/passes/heap_store_optimization.mbt:560-631`](../../../../../src/passes/heap_store_optimization.mbt)
  - trapless readonly / reorderable subtree predicates.
- [`src/passes/heap_store_optimization.mbt:761-823`](../../../../../src/passes/heap_store_optimization.mbt)
  - constructor operand effect summary and root-swap legality guard.
- [`src/passes/heap_store_optimization.mbt:914-986`](../../../../../src/passes/heap_store_optimization.mbt)
  - supported constructor family: `struct.new`, `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc`, plus shallow constructor wrapper effect classification.
- [`src/passes/heap_store_optimization.mbt:1296-1468`](../../../../../src/passes/heap_store_optimization.mbt)
  - HOT wrapper flattening and unreachable-tail repair helpers.
- [`src/passes/heap_store_optimization.mbt:1653-1775`](../../../../../src/passes/heap_store_optimization.mbt)
  - shared fold-into-constructor proof and rewrite.
- [`src/passes/heap_store_optimization.mbt:1777-1827`](../../../../../src/passes/heap_store_optimization.mbt)
  - tee-wrapped fold rewrite.
- [`src/passes/heap_store_optimization.mbt:2028-2218`](../../../../../src/passes/heap_store_optimization.mbt)
  - recursive region processing, later-set chain handling, swap logic, and root replacement.
- [`src/passes/heap_store_optimization.mbt:2220-2241`](../../../../../src/passes/heap_store_optimization.mbt)
  - run function, required effect summary, mutation marking.

The local file implements the same semantic goal as Binaryen but with HOT-region traversal, HOT effect masks, and writeback-safe wrapper cleanup rather than Binaryen's CFG action-list walker.

## Starshine registry and dispatcher

The active pass is wired through:

- [`src/passes/optimize.mbt:194-196`](../../../../../src/passes/optimize.mbt)
  - active hot-pass registry entry.
- [`src/passes/optimize.mbt:282-293`](../../../../../src/passes/optimize.mbt)
  - `optimize` preset placements.
- [`src/passes/optimize.mbt:294-305`](../../../../../src/passes/optimize.mbt)
  - `shrink` preset placements.
- [`src/passes/pass_manager.mbt:7264-7274`](../../../../../src/passes/pass_manager.mbt)
  - raw fast-skip lane.
- [`src/passes/pass_manager.mbt:8097-8099`](../../../../../src/passes/pass_manager.mbt)
  - hot-pass dispatcher case.

## Starshine tests and replay evidence

Current local proof surfaces include:

- [`src/passes/heap_store_optimization_test.mbt:476-2700`](../../../../../src/passes/heap_store_optimization_test.mbt)
  - focused positive and negative unit coverage for tee folds, chains, defaults, descriptor constructors, immutable/mutable descriptor-global call movement, descriptor `local.get`, block-wrapped immutable descriptor-global movement, pure descriptor-`if` movement plus a call-condition negative, descriptor block self-branch movement, branchless descriptor-loop movement plus self-branching loop negatives, descriptor-global swap movement, old-field side-effect preservation, later-field call barriers, a directional later-field trap/local-state fold, trySwap constructor-operand/global-set ordering, `memory.size` swap positives, trapping `i32.load` swap negatives, constructor-local-set ping-pong no-fold behavior, readonly prefixes, branches, wrapper flattening, raw-prefix guards, local-read hazards, and writeback repair.
- [`src/passes/perf_test.mbt:6241-6320`](../../../../../src/passes/perf_test.mbt)
  - raw fast-skip and trace aggregation coverage for functions with no HSO candidates.
- [`src/cmd/cmd_wbtest.mbt:2514-3490`](../../../../../src/cmd/cmd_wbtest.mbt)
  - focused CLI replay fixtures for `--heap-store-optimization`.
- [`src/cmd/cmd_wbtest.mbt:6600-6634`](../../../../../src/cmd/cmd_wbtest.mbt)
  - debug-artifact replay coverage.

## What is not covered by this page

This page does not claim full future-proof parity if upstream implements the owner-file TODOs for generic dead-store elimination or load forwarding.
If that happens, the pass contract would materially expand and should get a new source-correction note.

It also does not claim that Starshine's wrapper-cleanup machinery exists upstream. Those helpers are local HOT/writeback survival work.

## Sources

- [`../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md)
- [`../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md`](../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
