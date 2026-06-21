---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/research/0870-2026-06-20-heap-store-optimization-allocation-heavy-performance.md
  - ../../../raw/research/0869-2026-06-20-heap-store-optimization-exact-descriptor-cast-surface.md
  - ../../../raw/research/0868-2026-06-20-heap-store-optimization-unreachable-final-boundary.md
  - ../../../raw/research/0867-2026-06-20-heap-store-optimization-generic-dse-boundary.md
  - ../../../raw/research/0866-2026-06-20-heap-store-optimization-descriptor-br-on-non-null.md
  - ../../../raw/research/0865-2026-06-20-heap-store-optimization-descriptor-ref-as-non-null.md
  - ../../../raw/research/0864-2026-06-20-heap-store-optimization-descriptor-select.md
  - ../../../raw/research/0863-2026-06-20-heap-store-optimization-loop-backedge-local-read.md
  - ../../../raw/research/0862-2026-06-20-heap-store-optimization-br-table-local-escape.md
  - ../../../raw/research/0861-2026-06-20-heap-store-optimization-descriptor-later-field-global-write.md
  - ../../../raw/research/0860-2026-06-20-heap-store-optimization-descriptor-later-field-global-conflict.md
  - ../../../raw/research/0859-2026-06-20-heap-store-optimization-descriptor-later-field-local-read.md
  - ../../../raw/research/0858-2026-06-20-heap-store-optimization-descriptor-target-local-write-hazard.md
  - ../../../raw/research/0857-2026-06-20-heap-store-optimization-descriptor-target-local-hazard.md
  - ../../../raw/research/0856-2026-06-20-heap-store-optimization-descriptor-old-field-combinations.md
  - ../../../raw/research/0855-2026-06-20-heap-store-optimization-target-local-chain-variants.md
  - ../../../raw/research/0854-2026-06-20-heap-store-optimization-target-local-write-negative.md
  - ../../../raw/research/0853-2026-06-20-heap-store-optimization-subsequent-old-field-negative.md
  - ../../../raw/research/0852-2026-06-20-heap-store-optimization-subsequent-old-field-effects.md
  - ../../../raw/research/0851-2026-06-20-heap-store-optimization-core-chain-closeout.md
  - ../../../raw/research/0850-2026-06-20-heap-store-optimization-many-news-tee-barrier.md
  - ../../../raw/research/0849-2026-06-20-heap-store-optimization-many-fields-pattern-breaker.md
  - ../../../raw/research/0848-2026-06-20-heap-store-optimization-tee-later-chain.md
  - ../../../raw/research/0847-2026-06-20-heap-store-optimization-o4z-slot-evidence.md
  - ../../../raw/research/0846-2026-06-20-heap-store-optimization-br-table-table-side-stores.md
  - ../../../raw/research/0845-2026-06-20-heap-store-optimization-br-table-swap-wrappers.md
  - ../../../raw/research/0844-2026-06-20-heap-store-optimization-cross-family-store-swap.md
  - ../../../raw/research/0843-2026-06-20-heap-store-optimization-branch-wrapper-growth-boundaries.md
  - ../../../raw/research/0842-2026-06-20-heap-store-optimization-branch-wrapper-passive-boundaries.md
  - ../../../raw/research/0841-2026-06-20-heap-store-optimization-branch-wrapper-copy-boundaries.md
  - ../../../raw/research/0840-2026-06-20-heap-store-optimization-branch-wrapper-bulk-fill-boundaries.md
  - ../../../raw/research/0839-2026-06-20-heap-store-optimization-branch-wrapper-constructor-pingpong.md
  - ../../../raw/research/0838-2026-06-20-heap-store-optimization-branch-wrapper-table-global-swap.md
  - ../../../raw/research/0837-2026-06-20-heap-store-optimization-branch-wrapper-global-swap.md
  - ../../../raw/research/0836-2026-06-20-heap-store-optimization-deep-nested-growth-bulk-boundaries.md
  - ../../../raw/research/0835-2026-06-20-heap-store-optimization-nested-wrapped-growth-bulk-boundaries.md
  - ../../../raw/research/0834-2026-06-20-heap-store-optimization-nested-wrapped-growth-passive-boundaries.md
  - ../../../raw/research/0833-2026-06-20-heap-store-optimization-wrapped-growth-passive-boundaries.md
  - ../../../raw/research/0832-2026-06-20-heap-store-optimization-wrapped-passive-boundaries.md
  - ../../../raw/research/0831-2026-06-20-heap-store-optimization-wrapped-copy-boundaries.md
  - ../../../raw/research/0830-2026-06-20-heap-store-optimization-loop-wrapped-bulk-fill-boundaries.md
  - ../../../raw/research/0829-2026-06-20-heap-store-optimization-wrapped-bulk-fill-boundaries.md
  - ../../../raw/research/0828-2026-06-20-heap-store-optimization-mixed-index-copy-boundaries.md
  - ../../../raw/research/0827-2026-06-20-heap-store-optimization-multi-index-copy-boundaries.md
  - ../../../raw/research/0826-2026-06-20-heap-store-optimization-multi-index-bulk-boundaries.md
  - ../../../raw/research/0825-2026-06-20-heap-store-optimization-table-grow-bulk-boundaries.md
  - ../../../raw/research/0824-2026-06-20-heap-store-optimization-memory-grow-bulk-boundaries.md
  - ../../../raw/research/0823-2026-06-20-heap-store-optimization-memory-grow-data-boundaries.md
  - ../../../raw/research/0822-2026-06-20-heap-store-optimization-table-grow-elem-boundaries.md
  - ../../../raw/research/0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ../../../raw/research/0820-2026-06-20-heap-store-optimization-memory-size-data-segment-boundaries.md
  - ../../../raw/research/0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ../../../raw/research/0818-2026-06-20-heap-store-optimization-table-size-table-set-swap.md
  - ../../../raw/research/0817-2026-06-20-heap-store-optimization-global-set-value-read-swap.md
  - ../../../raw/research/0816-2026-06-20-heap-store-optimization-unrelated-global-swap.md
  - ../../../raw/research/0815-2026-06-20-heap-store-optimization-growth-store-swap-boundaries.md
  - ../../../raw/research/0814-2026-06-20-heap-store-optimization-nested-wrapper-swap.md
  - ../../../raw/research/0813-2026-06-20-heap-store-optimization-wrapped-constructor-pingpong.md
  - ../../../raw/research/0812-2026-06-20-heap-store-optimization-loop-wrapped-table-grow-swap.md
  - ../../../raw/research/0811-2026-06-20-heap-store-optimization-loop-wrapped-memory-grow-swap.md
  - ../../../raw/research/0810-2026-06-20-heap-store-optimization-loop-wrapped-table-size-swap.md
  - ../../../raw/research/0808-2026-06-20-heap-store-optimization-if-wrapped-table-grow-swap.md
  - ../../../raw/research/0809-2026-06-20-heap-store-optimization-if-wrapped-table-size-swap.md
  - ../../../raw/research/0807-2026-06-20-heap-store-optimization-if-wrapped-memory-grow-swap.md
  - ../../../raw/research/0806-2026-06-20-heap-store-optimization-block-wrapped-memory-grow-swap.md
  - ../../../raw/research/0805-2026-06-20-heap-store-optimization-block-wrapped-table-grow-swap.md
  - ../../../raw/research/0804-2026-06-20-heap-store-optimization-block-wrapped-swap.md
  - ../../../raw/research/0803-2026-06-20-heap-store-optimization-call-swap-negative.md
  - ../../../raw/research/0802-2026-06-20-heap-store-optimization-memory-grow-swap.md
  - ../../../raw/research/0801-2026-06-20-heap-store-optimization-table-grow-swap.md
  - ../../../raw/research/0800-2026-06-20-heap-store-optimization-table-size-swap.md
  - ../../../raw/research/0799-2026-06-20-heap-store-optimization-final-root-no-swap.md
  - ../../../raw/research/0798-2026-06-20-heap-store-optimization-active-catch-throw-negative.md
  - ../../../raw/research/0797-2026-06-20-heap-store-optimization-external-exits.md
  - ../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/research/0796-2026-06-20-heap-store-optimization-disappearing-bad-get.md
  - ../../../raw/research/0795-2026-06-20-heap-store-optimization-nested-control-sequence.md
  - ../../../raw/research/0794-2026-06-20-heap-store-optimization-in-function-catch-control.md
  - ../../../raw/research/0793-2026-06-20-heap-store-optimization-function-return-control.md
  - ../../../raw/research/0790-2026-06-20-heap-store-optimization-explicit-non-goals.md
  - ../../../raw/research/0789-2026-06-20-heap-store-optimization-core-chain-coverage.md
  - ../../../raw/research/0788-2026-06-20-heap-store-optimization-descriptor-loop-outer-branch.md
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
  - recursive region processing, shared later-set chain handling, swap logic, tee-plus-later-chain continuation, and root replacement.
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

- [`src/passes/heap_store_optimization_test.mbt:1265-7950`](../../../../../src/passes/heap_store_optimization_test.mbt)
  - focused positive and negative unit coverage for tee folds, many-fields independent tee roots, many-news independent tee-chain folds, tee-plus-later-chain folds, chains, repeated-store last-value folds, wrong-target-local no-folds, pattern-breaker local-copy chain negatives, defaults, descriptor constructors, immutable/mutable descriptor-global call movement, descriptor `local.get`, block-wrapped immutable descriptor-global movement, pure descriptor-`if` movement plus a call-condition negative, pure descriptor-`select` movement over immutable descriptor globals, descriptor `ref.as_non_null` trap-order no-fold behavior, explicit generic struct DSE and load-forwarding non-goal boundaries, descriptor block self-branch movement, branchless descriptor-loop movement, descriptor-loop outer-branch movement plus self-branching loop negatives, descriptor-global swap movement, explicit array-store boundaries, unreachable constructor/set-value no-fold boundaries, function-external return folds, safe external call folds, safe conditional external `throw` / `return_call` folds, active-catch `return_call` folds, in-function caught-call and active-catch `throw` negatives, loop-backedge target-local-read negatives, nested `drop(block(result ...))` control-sequence folds, escaping branch-valued store negatives, the `br_table` escaping-local negative and no-later-local-read Starshine-win fold, the one-disappearing-bad-get branch fold exception, ordinary memory/table store blocker folds, old-field side-effect preservation, subsequent-chain old-field side-effect preservation and side-effect conflict negatives, later-field call barriers, a directional later-field trap/local-state fold, target-local read and write hazards in moved values, descriptor target-local read/write hazards, descriptor later-field target-local-read folds, descriptor later-field same-global conflict negatives and unrelated-global positives, target-local chain hazards, default/descriptor old-field folds and descriptor later-field call barriers, trySwap constructor-operand/global-set ordering, final-root no-swap behavior, `memory.size`, `memory.grow`, `table.size`, and `table.grow` swap positives, block-wrapped `global.set` swap positives for `memory.size`, `memory.grow`, and `table.grow`, if-wrapped `global.set` swap positives for `table.size`, `memory.grow`, and `table.grow`, loop-wrapped `global.set` swap positives for `table.size`, `memory.grow`, and `table.grow`, nested mixed-wrapper `global.set` swap positives for `memory.grow`, same-kind growth/store no-swap boundaries including `table.size` across `table.set`, `memory.size` / `memory.grow` across bulk-memory writes, `memory.size` / `memory.grow` across passive data operations, `table.size` / `table.grow` across passive element operations, `table.grow` across table-bulk writes, and cross-index `memory.size` / `table.size` boundaries before bulk fills, same-index copies on different memories/tables, mixed-endpoint copies, and block/if/loop-wrapped bulk-fill, copy, passive init/drop, growth/passive init/drop barriers, nested mixed-wrapper growth/passive init/drop barriers, nested mixed-wrapper growth/bulk barriers, deeper growth/bulk barriers, and branch-containing wrapper global-write swap positives for memory-growing, table-size, and table-growing constructors, branch-containing constructor-local-set wrapper positives, branch-containing same-effect-family bulk-fill, copy, and passive init/drop no-fold barriers for memory-size, table-size, memory-grow, and table-grow constructors, `br_table`-wrapped cross-family ordinary-store positives and same-effect memory-fill negatives, table-side `br_table`-wrapped memory-store positives plus table-growth memory-store negatives, cross-family ordinary-store positives where memory-size crosses table-store and table-size crosses memory-store roots, mutable constructor `global.get` across unrelated `global.set` folds while preserving the same-global negative, the variant where the unrelated `global.set` value also reads the constructor-read global, call-valued constructor operand swap negatives, trapping constructor-operand `i32.load` swap negatives, direct constructor-local-set ping-pong no-fold behavior, wrapped constructor-local-set fold behavior, readonly prefixes, branches, wrapper flattening, raw-prefix guards, local-read hazards, and writeback repair.
- [`src/passes/perf_test.mbt:6241-6320`](../../../../../src/passes/perf_test.mbt)
  - raw fast-skip and trace aggregation coverage for functions with no HSO candidates.
- [`src/cmd/cmd_wbtest.mbt:2514-3490`](../../../../../src/cmd/cmd_wbtest.mbt)
  - focused CLI replay fixtures for `--heap-store-optimization`.
- [`src/cmd/cmd_wbtest.mbt:6600-6634`](../../../../../src/cmd/cmd_wbtest.mbt)
  - debug-artifact replay coverage.
- [`../../../raw/research/0847-2026-06-20-heap-store-optimization-o4z-slot-evidence.md`](../../../raw/research/0847-2026-06-20-heap-store-optimization-o4z-slot-evidence.md)
  - refreshed generated O4z early/late slot replay on current `cmd.wasm`; Starshine direct HSO was exact-equal and normalized-equal to Binaryen at both slot predecessors with raw-fast-skip.
- [`../../../raw/research/0870-2026-06-20-heap-store-optimization-allocation-heavy-performance.md`](../../../raw/research/0870-2026-06-20-heap-store-optimization-allocation-heavy-performance.md)
  - added allocation-heavy candidate performance evidence using a 2000-function synthetic module with 6000 foldable `struct.set` roots. Both outputs validated and removed all `StructSet` roots, but Starshine remained slower than Binaryen on pass-local and whole-command timing, so HSO-I stays open.
- [`../../../raw/research/0869-2026-06-20-heap-store-optimization-exact-descriptor-cast-surface.md`](../../../raw/research/0869-2026-06-20-heap-store-optimization-exact-descriptor-cast-surface.md)
  - refreshed the exact descriptor `ref.cast` surface blocker: Binaryen preserves `struct.set` for the exact descriptor-cast trap-order probe, while current Starshine still rejects the exact WAT during decode and the local `ref_cast_desc_eq` AST surface does not validate as an equivalent focused HSO fixture. This is not an accepted HSO non-goal.
- [`../../../raw/research/0868-2026-06-20-heap-store-optimization-unreachable-final-boundary.md`](../../../raw/research/0868-2026-06-20-heap-store-optimization-unreachable-final-boundary.md)
  - finalized HSO-H unreachable-boundary wording after a direct-root Binaryen `version_130` probe: HSO preserves `struct.set` for unreachable constructor and set-value shapes and leaves cleanup to later DCE; Starshine's `0792` focused tests cover the semantic boundary while the exact direct-root set-value spelling remains a local HOT/test-surface caveat.
- [`../../../raw/research/0867-2026-06-20-heap-store-optimization-generic-dse-boundary.md`](../../../raw/research/0867-2026-06-20-heap-store-optimization-generic-dse-boundary.md)
  - added HSO-H boundary coverage for the source-backed generic DSE/load-forwarding non-goal: Binaryen preserves repeated non-fresh-reference `struct.set` roots and a later `struct.get` after `struct.set`, and Starshine now has matching focused fail-closed tests.
- [`../../../raw/research/0866-2026-06-20-heap-store-optimization-descriptor-br-on-non-null.md`](../../../raw/research/0866-2026-06-20-heap-store-optimization-descriptor-br-on-non-null.md)
  - probed an HSO-D/F descriptor branch boundary: Binaryen preserves `struct.set` when the descriptor operand is a `br_on_non_null` block that can fall through to `unreachable` before a later call-valued store. A focused Starshine AST fixture currently hits a HOT CFG/verifier surface blocker for this descriptor-typed branch-result shape, so this is an open local-surface blocker rather than HSO parity evidence or an accepted non-goal.
- [`../../../raw/research/0865-2026-06-20-heap-store-optimization-descriptor-ref-as-non-null.md`](../../../raw/research/0865-2026-06-20-heap-store-optimization-descriptor-ref-as-non-null.md)
  - added HSO-D descriptor trap-boundary coverage: Binaryen preserves `struct.set` when the descriptor operand is `ref.as_non_null` over a nullable descriptor global because folding would move a later call before a possible descriptor trap. Starshine already matched.
- [`../../../raw/research/0863-2026-06-20-heap-store-optimization-loop-backedge-local-read.md`](../../../raw/research/0863-2026-06-20-heap-store-optimization-loop-backedge-local-read.md)
  - added HSO-F loop-backedge target-local-read coverage: Binaryen preserves `struct.set` when a branch-valued store can jump to a loop header that reads the fresh-struct local before the next `local.set`; Starshine already matched.
- [`../../../raw/research/0862-2026-06-20-heap-store-optimization-br-table-local-escape.md`](../../../raw/research/0862-2026-06-20-heap-store-optimization-br-table-local-escape.md)
  - added `br_table` control-flow coverage for HSO-F: Starshine matches Binaryen's escaping-local negative, and the no-later-local-read variant is documented as a narrow Starshine better-than-Binaryen fold that extends the one-disappearing-bad-get reasoning to `br_table` values.
- [`../../../raw/research/0861-2026-06-20-heap-store-optimization-descriptor-later-field-global-write.md`](../../../raw/research/0861-2026-06-20-heap-store-optimization-descriptor-later-field-global-write.md)
  - fixed descriptor later-field global-write barriers: Binaryen folds when a later constructor field writes `$g0` and the moved value reads or writes unrelated `$g1`, but preserves `struct.set` for same-global read/write conflicts. Starshine now normalizes non-skipping structural control out of reorder masks before applying the precise global-only movement allowance.
- [`../../../raw/research/0860-2026-06-20-heap-store-optimization-descriptor-later-field-global-conflict.md`](../../../raw/research/0860-2026-06-20-heap-store-optimization-descriptor-later-field-global-conflict.md)
  - fixed descriptor later-field same-global conflict handling for later-field reads: Binaryen folds when a later constructor field reads mutable global `$g0` and the moved value writes unrelated `$g1`, but preserves `struct.set` when both touch `$g0`. Starshine now checks precise same-global read/write conflicts before value-prefix mutation and includes peeled prefix roots in later-field/descriptor reorder checks.
- [`../../../raw/research/0859-2026-06-20-heap-store-optimization-descriptor-later-field-local-read.md`](../../../raw/research/0859-2026-06-20-heap-store-optimization-descriptor-later-field-local-read.md)
  - fixed a descriptor later-field local-read overblock: Binaryen folds a call-valued `struct.set` into `struct.new_desc` even when a later constructor field reads the target local, because the moved value itself has no local-state effects. Focused HSO tests passed `213/213`; direct 10000-case compare normalized `10000/10000` with `0` mismatches.
- [`../../../raw/research/0858-2026-06-20-heap-store-optimization-descriptor-target-local-write-hazard.md`](../../../raw/research/0858-2026-06-20-heap-store-optimization-descriptor-target-local-write-hazard.md)
  - added descriptor target-local write hazard coverage: Binaryen preserves `struct.set` when a `struct.new_desc` chain's moved value writes a replacement descriptor-constructed struct to the fresh-struct target local; focused HSO tests passed `212/212`, and no implementation change was needed.
- [`../../../raw/research/0857-2026-06-20-heap-store-optimization-descriptor-target-local-hazard.md`](../../../raw/research/0857-2026-06-20-heap-store-optimization-descriptor-target-local-hazard.md)
  - added descriptor target-local read hazard coverage: Binaryen preserves `struct.set` when a `struct.new_desc` chain's moved value reads the fresh-struct target local; focused HSO tests passed `211/211`, and no implementation change was needed.
- [`../../../raw/research/0856-2026-06-20-heap-store-optimization-descriptor-old-field-combinations.md`](../../../raw/research/0856-2026-06-20-heap-store-optimization-descriptor-old-field-combinations.md)
  - added default/descriptor old-field combination coverage: Binaryen folds safe `struct.new_default_desc` chain stores into `struct.new_desc`, but preserves a descriptor `struct.set` when a later constructor field call orders before the moved call; focused HSO tests passed `210/210`, and no implementation change was needed.
- [`../../../raw/research/0855-2026-06-20-heap-store-optimization-target-local-chain-variants.md`](../../../raw/research/0855-2026-06-20-heap-store-optimization-target-local-chain-variants.md)
  - added target-local chain coverage: Binaryen preserves both stores when an early moved value writes the target local, but folds an earlier harmless store before a later target-local-read hazard; focused HSO tests passed `208/208`, and no implementation change was needed.
- [`../../../raw/research/0854-2026-06-20-heap-store-optimization-target-local-write-negative.md`](../../../raw/research/0854-2026-06-20-heap-store-optimization-target-local-write-negative.md)
  - added coverage for the source-backed target-local write hazard where the moved set value overwrites the same fresh-struct local; focused HSO tests passed `206/206`, and no implementation change was needed.
- [`../../../raw/research/0853-2026-06-20-heap-store-optimization-subsequent-old-field-negative.md`](../../../raw/research/0853-2026-06-20-heap-store-optimization-subsequent-old-field-negative.md)
  - added coverage for the subsequent-chain counterpart of Binaryen's old-field side-effect conflict negative; focused HSO tests passed `205/205`, and no implementation change was needed.
- [`../../../raw/research/0852-2026-06-20-heap-store-optimization-subsequent-old-field-effects.md`](../../../raw/research/0852-2026-06-20-heap-store-optimization-subsequent-old-field-effects.md)
  - added coverage for Binaryen's `$side-effect-subsequent-ok` family; focused HSO tests passed `204/204`, and no implementation change was needed.
- [`../../../raw/research/0851-2026-06-20-heap-store-optimization-core-chain-closeout.md`](../../../raw/research/0851-2026-06-20-heap-store-optimization-core-chain-closeout.md)
  - classifies the currently source-backed HSO-C core-chain family as behavior-parity covered after repeated-store, wrong-target-local, tee-plus-later-chain, many-fields, pattern-breaker, and many-news coverage/fixes, with no residual debris/output-shape drift in the latest direct lanes.

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
