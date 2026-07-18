---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
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

- [`src/passes/heap_store_optimization_test.mbt:1265-7989`](../../../../../src/passes/heap_store_optimization_test.mbt)
  - focused positive and negative unit coverage for tee folds, many-fields independent tee roots, many-news independent tee-chain folds, tee-plus-later-chain folds, chains, repeated-store last-value folds, wrong-target-local no-folds, pattern-breaker local-copy chain negatives, defaults including a narrow plain-default double-call Starshine win, descriptor constructors, immutable/mutable descriptor-global call movement, mutable descriptor-global pure-value folding, descriptor `local.get`, block-wrapped immutable descriptor-global movement, pure descriptor-`if` movement plus a call-condition negative, pure descriptor-`select` movement over immutable descriptor globals, descriptor-select call-condition no-fold behavior, descriptor-if trapping-condition no-fold behavior, descriptor block `br_if` call-condition no-fold behavior, later-field select, `if`, and block `br_if` call-condition no-fold behavior, trapping later-field select- and if-condition no-fold behavior, descriptor `ref.as_non_null` trap-order no-fold behavior, descriptor block `br_if` trap-condition no-fold behavior, explicit generic struct DSE and load-forwarding non-goal boundaries, descriptor block self-branch movement, branchless descriptor-loop movement, descriptor-loop outer-branch movement plus self-branching loop negatives, descriptor-global swap movement, explicit array-store boundaries, unreachable constructor/set-value no-fold boundaries, function-external return folds, safe external call folds, safe conditional external `throw` / `return_call` folds, active-catch `return_call` folds, in-function caught-call and active-catch `throw` negatives, loop-backedge target-local-read negatives, nested `drop(block(result ...))` control-sequence folds, escaping branch-valued store negatives, the `br_table` escaping-local negative and no-later-local-read Starshine-win fold, the one-disappearing-bad-get branch fold exception, ordinary memory/table store blocker folds, old-field side-effect preservation, plain and descriptor old-field plus later-field call barriers, subsequent-chain old-field side-effect preservation and side-effect conflict negatives, later-field call barriers, a directional later-field trap/local-state fold, target-local read and write hazards in moved values, descriptor target-local read/write hazards, descriptor later-field target-local-read folds, descriptor later-field same-global conflict negatives and unrelated-global positives, target-local chain hazards, default/descriptor old-field folds and descriptor later-field call barriers plus the narrow default-descriptor double-call Starshine win, trySwap constructor-operand/global-set ordering, final-root no-swap behavior, `memory.size`, `memory.grow`, `table.size`, and `table.grow` swap positives, block-wrapped `global.set` swap positives for `memory.size`, `memory.grow`, and `table.grow`, if-wrapped `global.set` swap positives for `table.size`, `memory.grow`, and `table.grow`, loop-wrapped `global.set` swap positives for `table.size`, `memory.grow`, and `table.grow`, nested mixed-wrapper `global.set` swap positives for `memory.grow`, same-kind growth/store no-swap boundaries including `table.size` across `table.set`, `memory.size` / `memory.grow` across bulk-memory writes, `memory.size` / `memory.grow` across passive data operations, `table.size` / `table.grow` across passive element operations, `table.grow` across table-bulk writes, and cross-index `memory.size` / `table.size` boundaries before bulk fills, same-index copies on different memories/tables, mixed-endpoint copies, and block/if/loop-wrapped bulk-fill, copy, passive init/drop, growth/passive init/drop barriers, nested mixed-wrapper growth/passive init/drop barriers, nested mixed-wrapper growth/bulk barriers, deeper growth/bulk barriers, and branch-containing wrapper global-write swap positives for memory-growing, table-size, and table-growing constructors, branch-containing constructor-local-set wrapper positives, branch-containing same-effect-family bulk-fill, copy, and passive init/drop no-fold barriers for memory-size, table-size, memory-grow, and table-grow constructors, `br_table`-wrapped cross-family ordinary-store positives and same-effect memory-fill negatives, table-side `br_table`-wrapped memory-store positives plus table-growth memory-store negatives, cross-family ordinary-store positives where memory-size crosses table-store and table-size crosses memory-store roots, cross-family growth positives where memory-size crosses table-grow and table-size crosses memory-grow roots, mutable constructor `global.get` across unrelated `global.set` folds while preserving the same-global negative, the variant where the unrelated `global.set` value also reads the constructor-read global, call-valued constructor operand swap negatives, trapping constructor-operand `i32.load` swap negatives, trapping old-field `i32.div_s`, `i32.trunc_f32s`, `ref.as_non_null`, `i32.load`, and `table.get` preservation before intervening mutable globals, side-effectful old-field growth/global/passive-drop preservation positives, memory/table store, memory/table fill, memory/table copy and memory/table init old-field preservation boundaries before intervening mutable globals, direct constructor-local-set ping-pong no-fold behavior, wrapped constructor-local-set fold behavior, readonly prefixes, branches, wrapper flattening, raw-prefix guards, local-read hazards, and writeback repair.
- [`src/passes/perf_test.mbt:6241-6320`](../../../../../src/passes/perf_test.mbt)
  - raw fast-skip and trace aggregation coverage for functions with no HSO candidates.
- [`src/cmd/cmd_wbtest.mbt:2514-3490`](../../../../../src/cmd/cmd_wbtest.mbt)
  - focused CLI replay fixtures for `--heap-store-optimization`.
- [`src/cmd/cmd_wbtest.mbt:6600-6634`](../../../../../src/cmd/cmd_wbtest.mbt)
  - debug-artifact replay coverage.
- [research note 0847](./index.md)
  - refreshed generated O4z early/late slot replay on current `cmd.wasm`; Starshine direct HSO was exact-equal and normalized-equal to Binaryen at both slot predecessors with raw-fast-skip.
- [research note 0909](./index.md)
  - added focused HSO-D/G table-init old-field boundary coverage: Binaryen preserves an overwritten value-producing `table.init` constructor field before an intervening unrelated mutable `global.set` and leaves the later `struct.set`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `267/267`.
- [research note 0908](./index.md)
  - added focused HSO-D/G memory-init old-field boundary coverage: Binaryen preserves an overwritten value-producing `memory.init` constructor field before an intervening unrelated mutable `global.set` and leaves the later `struct.set`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `266/266`.
- [research note 0907](./index.md)
  - added focused HSO-D/G table-copy old-field boundary coverage: Binaryen preserves an overwritten value-producing `table.copy` constructor field before an intervening unrelated mutable `global.set` and leaves the later `struct.set`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `265/265`.
- [research note 0906](./index.md)
  - added focused HSO-D/G memory-copy old-field boundary coverage: Binaryen preserves an overwritten value-producing `memory.copy` constructor field before an intervening unrelated mutable `global.set` and leaves the later `struct.set`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `264/264`.
- [research note 0905](./index.md)
  - added focused HSO-D/G table-fill old-field boundary coverage: Binaryen preserves an overwritten value-producing `table.fill` constructor field before an intervening unrelated mutable `global.set` and leaves the later `struct.set`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `263/263`.
- [research note 0904](./index.md)
  - added focused HSO-D/G memory-fill old-field boundary coverage: Binaryen preserves an overwritten value-producing `memory.fill` constructor field before an intervening unrelated mutable `global.set` and leaves the later `struct.set`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `262/262`.
- [research note 0903](./index.md)
  - added focused HSO-D/G passive-element old-field positive coverage: Binaryen folds an overwritten value-producing `elem.drop` constructor field while preserving `elem.drop` under `drop`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `261/261`.
- [research note 0902](./index.md)
  - added focused HSO-D/G passive-data old-field positive coverage: Binaryen folds an overwritten value-producing `data.drop` constructor field while preserving `data.drop` under `drop`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `260/260`.
- [research note 0901](./index.md)
  - added focused HSO-D/G table-store old-field boundary coverage: Binaryen preserves an overwritten value-producing `table.set` constructor field before an intervening unrelated mutable `global.set` and leaves the later `struct.set`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `259/259`.
- [research note 0900](./index.md)
  - added focused HSO-D/G memory-store old-field boundary coverage: Binaryen preserves an overwritten value-producing `i32.store` constructor field before an intervening unrelated mutable `global.set` and leaves the later `struct.set`; Starshine already matched, so no implementation change was needed. Focused HSO tests passed `258/258`.
- [research note 0899](./index.md)
  - fixed HSO-D/G mutable-global old-field parity: Binaryen folds an overwritten value-producing old field that writes `$g0` across an unrelated `$g1` root write, preserving the old `$g0` write under `drop`; Starshine now relies on exact-global conflict analysis instead of rejecting every constructor old-field global write. Focused HSO tests passed `257/257`; direct 10000-case compare normalized `10000/10000` with `0` mismatches.
- [research note 0898](./index.md)
  - added focused HSO-D/G side-effectful old-field coverage for the table-growth counterpart: Binaryen folds an overwritten `table.grow` constructor field across an unrelated mutable `global.set` while preserving `table.grow` under `drop`; Starshine already matched, so no implementation change was needed.
- [research note 0897](./index.md)
  - added focused HSO-D/G side-effectful old-field coverage: Binaryen folds an overwritten `memory.grow` constructor field across an unrelated mutable `global.set` while preserving `memory.grow` under `drop`; Starshine already matched, so no implementation change was needed.
- [research note 0896](./index.md)
  - added focused HSO-D/G table-trap old-field coverage: Binaryen preserves `table.get` in an overwritten constructor field and leaves the later `struct.set` when an unrelated mutable `global.set` intervenes; Starshine already matched, so no implementation change was needed.
- [research note 0895](./index.md)
  - added focused HSO-D/G memory-trap old-field coverage: Binaryen preserves `i32.load` in an overwritten constructor field and leaves the later `struct.set` when an unrelated mutable `global.set` intervenes; Starshine already matched, so no implementation change was needed.
- [research note 0894](./index.md)
  - added focused HSO-D/G reference-trap old-field coverage: Binaryen preserves `ref.as_non_null(global.get)` in an overwritten constructor field and leaves the later `struct.set` when an unrelated mutable `global.set` intervenes; Starshine already matched, so no implementation change was needed.
- [research note 0893](./index.md)
  - fixed the same HSO-D/G trapping old-field parity gap for exact non-saturating float-to-int truncation: Binaryen preserves `i32.trunc_f32_s` in an overwritten constructor field and leaves the later `struct.set` when a mutable `global.set` intervenes; Starshine now marks exact `i32`/`i64.trunc_f32`/`trunc_f64` nodes as trapping for HSO effect and reorderability checks.
- [research note 0892](./index.md)
  - fixed a focused HSO-D/G parity gap for trapping old-field preservation: Binaryen preserves `i32.div_s` in an overwritten constructor field and leaves the later `struct.set` when a mutable `global.set` intervenes; Starshine now marks exact integer div/rem nodes as trapping for HSO effect and reorderability checks.
- [research note 0923](./index.md)
  - added focused HSO-D/G coverage for ordinary direct-call old-field boundaries before unrelated mutable `global.set` and unrelated `table.set`; Binaryen preserves the call, intervening store root, and later `struct.set`, and Starshine already matched.
- [research note 0924](./index.md)
  - added focused HSO-G coverage for the indirect-call constructor-operand boundary before unrelated `table.set`; Binaryen preserves `call_indirect`, `table.set`, and later `struct.set`, and Starshine already matched.
- [research note 0925](./index.md)
  - added focused HSO-D/G coverage for indirect-call old-field boundaries before unrelated mutable `global.set` and unrelated `table.set`; Binaryen preserves `call_indirect`, the intervening store root, and later `struct.set`, and Starshine already matched.
- [research note 0926](./index.md)
  - added focused HSO-D/G coverage for indirect-call constructor-operand and old-field boundaries before unrelated `i32.store`; Binaryen preserves `call_indirect`, the intervening memory store, and later `struct.set`, and Starshine already matched.
- [research note 0932](./index.md)
  - added focused HSO-D/G coverage for indirect-call constructor operands before unrelated `memory.grow` and `table.grow`; Binaryen preserves `call_indirect`, the intervening growth root, and later `struct.set`, and Starshine already matched.
- [research note 0934](./index.md)
  - added focused HSO-D/G coverage for indirect-call old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves `call_indirect`, the intervening growth root, and later `struct.set`, and Starshine already matched.
- [research note 0928](./index.md)
  - added focused HSO-G coverage for ordinary direct-call constructor operands before unrelated `i32.store` and unrelated `table.set`; Binaryen preserves the call, intervening store root, and later `struct.set`, and Starshine already matched.
- [research note 0936](./index.md)
  - added focused HSO-D/G coverage for block-wrapped ordinary direct-call constructor/old-field boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the block-wrapped call, intervening store root, and later `struct.set`, and Starshine already matched.
- [research note 0937](./index.md)
  - added focused HSO-D/G coverage for block-wrapped ordinary direct-call constructor/old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the block-wrapped call, intervening growth root, and later `struct.set`, and Starshine already matched.
- [research note 0938](./index.md)
  - added focused HSO-D/G coverage for block-wrapped `call_indirect` constructor boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the block-wrapped indirect call, intervening store root, and later `struct.set`, and Starshine already matched.
- [research note 0939](./index.md)
  - added focused HSO-D/G coverage for block-wrapped `call_indirect` constructor boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the block-wrapped indirect call, intervening growth root, and later `struct.set`, and Starshine already matched.
- [research note 0940](./index.md)
  - added focused HSO-D/G coverage for block-wrapped `call_ref` constructor boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the block-wrapped typed-function-reference call, intervening store root, and later `struct.set`, and Starshine already matched.
- [research note 0941](./index.md)
  - added focused HSO-D/G coverage for block-wrapped `call_ref` constructor boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the block-wrapped typed-function-reference call, intervening growth root, and later `struct.set`, and Starshine already matched.
- [research note 0942](./index.md)
  - added focused HSO-D/G coverage for block-wrapped `call_ref` old-field boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the overwritten block-wrapped typed-function-reference call, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0943](./index.md)
  - added focused HSO-D/G coverage for block-wrapped `call_ref` old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the overwritten block-wrapped typed-function-reference call, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0944](./index.md)
  - added focused HSO-D/G coverage for block-wrapped `call_indirect` old-field boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the overwritten block-wrapped indirect call, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0945](./index.md)
  - added focused HSO-D/G coverage for block-wrapped `call_indirect` old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the overwritten block-wrapped indirect call, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0946](./index.md)
  - added focused HSO-D/G coverage for if-wrapped direct-call old-field boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the overwritten if-wrapped direct call, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0947](./index.md)
  - added focused HSO-D/G coverage for if-wrapped direct-call old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the overwritten if-wrapped direct call, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0977](./index.md)
  - recorded the now-fixed HSO-D/G growth-root parity gap: Binaryen drops an overwritten pure branch-containing outer-block/inner-loop old field and folds the later same-field store across unrelated `memory.grow` and `table.grow` roots. Follow-up `0978` added encoded wasm coverage and the contained-control droppable-old-field implementation.
- [research note 0976](./index.md)
  - recorded the matching now-fixed ordinary-store parity gap: Binaryen drops the overwritten pure branch-loop old field and folds across unrelated `i32.store` and `table.set`; follow-up `0978` added encoded wasm coverage and the contained-control droppable-old-field implementation.
- [research note 0948](./index.md)
  - added focused HSO-D/G coverage for if-wrapped `call_indirect` old-field boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the overwritten if-wrapped indirect call, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0949](./index.md)
  - added focused HSO-D/G coverage for if-wrapped `call_indirect` old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the overwritten if-wrapped indirect call, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0950](./index.md)
  - added focused HSO-D/G coverage for if-wrapped `call_ref` old-field boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the overwritten if-wrapped typed-function-reference call, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0951](./index.md)
  - added focused HSO-D/G coverage for if-wrapped `call_ref` old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the overwritten if-wrapped typed-function-reference call, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0952](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped direct-call old-field boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the overwritten loop-wrapped direct call, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0953](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped direct-call old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the overwritten loop-wrapped direct call, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0954](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped `call_indirect` old-field boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the overwritten loop-wrapped indirect call, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0955](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped `call_indirect` old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the overwritten loop-wrapped indirect call, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0956](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped `call_ref` old-field boundaries before unrelated `i32.store` and `table.set`; Binaryen preserves the overwritten loop-wrapped typed-function-reference call, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0957](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped `call_ref` old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the overwritten loop-wrapped typed-function-reference call, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0958](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped ordinary direct-call constructor operands before unrelated `i32.store` and `table.set`; Binaryen preserves the loop-wrapped direct call constructor operand, intervening store root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0959](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped ordinary direct-call constructor operands before unrelated `memory.grow` and `table.grow`; Binaryen preserves the loop-wrapped direct call constructor operand, intervening growth root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0960](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped `call_indirect` constructor operands before unrelated `i32.store` and `table.set`; Binaryen preserves the loop-wrapped indirect call constructor operand, intervening store root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0961](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped `call_indirect` constructor operands before unrelated `memory.grow` and `table.grow`; Binaryen preserves the loop-wrapped indirect call constructor operand, intervening growth root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0962](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped `call_ref` constructor operands before unrelated `i32.store` and `table.set`; Binaryen preserves the loop-wrapped typed-function-reference call constructor operand, intervening store root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0963](./index.md)
  - added focused HSO-D/G coverage for branchless loop-wrapped `call_ref` constructor operands before unrelated `memory.grow` and `table.grow`; Binaryen preserves the loop-wrapped typed-function-reference call constructor operand, intervening growth root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0964](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop direct-call constructor operands before unrelated `i32.store` and `table.set`; Binaryen preserves the wrapped call, `br_if`, intervening store root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0965](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop direct-call constructor operands before unrelated `memory.grow` and `table.grow`; Binaryen preserves the wrapped call, `br_if`, intervening growth root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0966](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop `call_indirect` constructor operands before unrelated `i32.store` and `table.set`; Binaryen preserves the wrapped indirect call, `br_if`, intervening store root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0967](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop `call_indirect` constructor operands before unrelated `memory.grow` and `table.grow`; Binaryen preserves the wrapped indirect call, `br_if`, intervening growth root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0968](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop `call_ref` constructor operands before unrelated `i32.store` and `table.set`; Binaryen preserves the wrapped typed-function-reference call, `br_if`, intervening store root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0969](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop `call_ref` constructor operands before unrelated `memory.grow` and `table.grow`; Binaryen preserves the wrapped typed-function-reference call, `br_if`, intervening growth root, and later other-field `struct.set`, and Starshine already matched.
- [research note 0970](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop direct-call old fields before unrelated `i32.store` and `table.set`; Binaryen preserves the wrapped old-field call, `br_if`, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0971](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop direct-call old fields before unrelated `memory.grow` and `table.grow`; Binaryen preserves the wrapped old-field call, `br_if`, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0972](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop `call_indirect` old fields before unrelated `i32.store` and `table.set`; Binaryen preserves the wrapped old-field indirect call, `br_if`, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0973](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop `call_indirect` old fields before unrelated `memory.grow` and `table.grow`; Binaryen preserves the wrapped old-field indirect call, `br_if`, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0974](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop `call_ref` old fields before unrelated `i32.store` and `table.set`; Binaryen preserves the wrapped typed-function-reference old field, `br_if`, intervening store root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0975](./index.md)
  - added focused HSO-D/G coverage for branch-containing outer-block/inner-loop `call_ref` old fields before unrelated `memory.grow` and `table.grow`; Binaryen preserves the wrapped typed-function-reference old field, `br_if`, intervening growth root, and later same-field `struct.set`, and Starshine already matched.
- [research note 0929](./index.md)
  - added focused HSO-D/G coverage for the ordinary direct-call old-field counterpart before unrelated `i32.store`; Binaryen preserves the call, intervening memory store, and later `struct.set`, and Starshine already matched.
- [research note 0931](./index.md)
  - added focused HSO-D/G coverage for ordinary direct-call constructor operands before unrelated `memory.grow` and `table.grow`; Binaryen preserves the call, intervening growth root, and later `struct.set`, and Starshine already matched.
- [research note 0935](./index.md)
  - added focused HSO-D/G coverage for ordinary direct-call old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves the call, intervening growth root, and later `struct.set`, and Starshine already matched.
- [research note 0930](./index.md)
  - added focused HSO-D/G coverage for typed-function-reference `call_ref` constructor-operand and old-field boundaries before unrelated `i32.store`; Binaryen preserves `call_ref`, the intervening memory store, and later `struct.set`, and Starshine already matched.
- [research note 0933](./index.md)
  - added focused HSO-D/G coverage for typed-function-reference `call_ref` constructor and old-field boundaries before unrelated `memory.grow` and `table.grow`; Binaryen preserves `call_ref`, the intervening growth root, and later `struct.set`, and Starshine already matched.
- [research note 1022](./index.md)
  - added HSO-D/E/G default-descriptor catchable result-wrapper store-value boundary: Binaryen preserves `struct.new_default_desc`, the intervening call store, the result-typed `try_table` / direct-call store, the descriptor read, and the later `struct.set`; Starshine now blocks folds whose moved value contains a catchable `try_table` escape.
- [research note 1021](./index.md)
  - added coverage-only HSO-D/G descriptor later-field old-field evidence: Binaryen folds pure same-field stores into immutable-descriptor `struct.new_desc` across a non-tail later-field result-typed `try_table`, preserving overwritten call or exact trapping `i32.div_s` old fields under `drop`; Starshine already matches.
- [research note 1020](./index.md)
  - added coverage-only HSO-D/G later-field old-field evidence for the `1018` tail-call boundary: Binaryen preserves `struct.new`, old-field call/trap effects, a result-typed `try_table` / `return_call`, and the later `struct.set`; Starshine already matches.
- [research note 1019](./index.md)
  - added coverage-only HSO-D/G later-field old-field evidence: Binaryen folds pure same-field stores into plain `struct.new` across non-tail later-field result-typed `try_table` wrappers while preserving overwritten call or exact trapping `i32.div_s` old fields under `drop`; Starshine already matches.
- [research note 1018](./index.md)
  - fixed HSO-D/E/F/G later-field tail-call result-wrapper behavior: Binaryen preserves `struct.new`, the result-typed `try_table`, and later `struct.set` for `return_call`, `return_call_indirect`, and `return_call_ref` even with pure moved set values; Starshine now blocks folding across later-field tail/throw escapes while preserving non-tail pure folds.
- [research note 1017](./index.md)
  - added coverage-only HSO-D/E later-field evidence for indirect-call result-typed `try_table` constructor fields: Binaryen folds pure set values into `struct.new`, but preserves `call_indirect` moved values that would move before the later-field wrapper, and Starshine already matches.
- [research note 1016](./index.md)
  - added coverage-only HSO-D/E later-field evidence for typed-function-reference result-typed `try_table` constructor fields: Binaryen folds pure set values into `struct.new`, but preserves `call_ref` moved values that would move before the later-field wrapper, and Starshine already matches.
- [research note 1015](./index.md)
  - added coverage-only HSO-D/E later-field evidence for result-typed `try_table` constructor fields: Binaryen folds pure set values into `struct.new`, but preserves effectful call-valued set values that would move before the later-field wrapper, and Starshine already matches.
- [research note 1014](./index.md)
  - added coverage-only HSO-D/E/F/G evidence for the descriptor result-typed `try_table` mutable descriptor-global `return_call_ref` boundary; Binaryen preserves `struct.new_desc`, the mutable descriptor read, dropped result wrapper, typed-function-reference tail call, and later `struct.set`, and Starshine already matches.
- [research note 1013](./index.md)
  - added coverage-only HSO-D/E/F/G evidence for descriptor result-typed `try_table` mutable descriptor-global `return_call` and `return_call_indirect` boundaries; Binaryen preserves `struct.new_desc`, the mutable descriptor read, dropped result wrapper, tail call, and later `struct.set`, and Starshine already matches.
- [research note 1012](./index.md)
  - added coverage-only HSO-D/E/F/G evidence for descriptor result-typed `try_table` mutable descriptor-global `call_ref` boundaries; Binaryen preserves `struct.new_desc`, the mutable descriptor read, dropped result wrapper, catchable typed-function-reference call, and later `struct.set`, and Starshine already matches.
- [research note 1011](./index.md)
  - added coverage-only HSO-D/E/F/G evidence for descriptor result-typed `try_table` mutable descriptor-global boundaries; Binaryen preserves `struct.new_desc`, the mutable descriptor read, dropped result wrapper, catchable direct/indirect calls, and later `struct.set`, and Starshine already matches.
- [research note 1010](./index.md)
  - added coverage-only HSO-D/F/G evidence for descriptor result-typed `try_table` `call_ref` old-field boundaries; Binaryen preserves the overwritten old-field typed-function-reference call, dropped result wrapper, catchable `call_ref`, descriptor read, and later `struct.set`, and Starshine already matches.
- [research note 1009](./index.md)
  - added coverage-only HSO-D/F/G evidence for descriptor result-typed `try_table` `call_indirect` old-field boundaries; Binaryen preserves the overwritten old-field indirect call, dropped result wrapper, catchable indirect call, descriptor read, and later `struct.set`, and Starshine already matches.
- [research note 1008](./index.md)
  - added coverage-only HSO-D/F/G evidence for descriptor result-typed `try_table` `call_ref` set-value folds; Binaryen folds the pure immutable-descriptor `struct.new_desc` across the dropped result wrapper while preserving the catchable typed-function-reference call and descriptor read, and Starshine already matches after `1005`.
- [research note 1007](./index.md)
  - added coverage-only HSO-D/F/G evidence for descriptor result-typed `try_table` `call_indirect` set-value folds; Binaryen folds the pure immutable-descriptor `struct.new_desc` across the dropped result wrapper while preserving the catchable indirect call and descriptor read, and Starshine already matches after `1005`.
- [research note 1006](./index.md)
  - added coverage-only HSO-D/F/G evidence for descriptor result-typed `try_table` direct-call old-field boundaries; Binaryen preserves the overwritten direct-call constructor field, wrapper, catchable direct call, descriptor read, and later `struct.set`, and Starshine already matches after `1005`.
- [research note 1005](./index.md)
  - fixed HSO-D/F/G descriptor result-wrapper overblocking: Binaryen folds a pure `struct.new_desc` using an immutable descriptor global across a dropped result-typed `try_table` with a catchable direct call, while preserving existing result-typed tail-call/throw no-fold boundaries; focused HSO tests passed `374/374`, native `src/cmd` build passed with pre-existing warnings, and direct 10000-case HSO compare normalized `10000/10000` with `0` mismatches/failures.
- [research note 1004](./index.md)
  - added coverage-only HSO-D/F/G evidence for result-typed `try_table` `call_ref` old-field boundaries; Binaryen preserves the overwritten `call_ref` constructor field, wrapper, catchable typed-function-reference call, and later `struct.set`, and Starshine already matches.
- [research note 1003](./index.md)
  - added coverage-only HSO-D/F/G evidence for result-typed `try_table` `return_call_ref` old-field boundaries; Binaryen preserves the overwritten `call_ref` constructor field, wrapper, typed-function-reference tail call, and later `struct.set`, and Starshine already matches.
- [research note 1002](./index.md)
  - added coverage-only HSO-D/F/G evidence for result-typed `try_table` indirect `return_call` old-field boundaries; Binaryen preserves the overwritten constructor-field call, wrapper, indirect tail call, and later `struct.set`, and Starshine already matches.
- [research note 1001](./index.md)
  - added coverage-only HSO-D/F/G evidence for result-typed `try_table` direct `return_call` old-field boundaries; Binaryen preserves the overwritten constructor-field call, wrapper, tail call, and later `struct.set`, and Starshine already matches.
- [research note 1000](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed `try_table` `return_call_indirect` set-value boundaries; Binaryen preserves the wrapper, indirect tail call, constructor, and later `struct.set`, and Starshine already matches.
- [research note 0999](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed `try_table` direct `return_call` set-value boundaries; Binaryen preserves the wrapper, tail call, constructor, and later `struct.set`, and Starshine already matches.
- [research note 0998](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed `try_table` ordinary cross-store boundaries that also contain catchable indirect calls; Binaryen preserves the wrapper, `call_indirect`, `table.set` / `i32.store`, and later `struct.set`, and Starshine already matches.
- [research note 0997](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed `try_table` ordinary cross-store boundaries that also contain catchable direct calls; Binaryen preserves the wrapper, direct `call`, `table.set` / `i32.store`, and later `struct.set`, and Starshine already matches.
- [research note 0996](./index.md)
  - added coverage-only HSO-F/G evidence for a result-typed `try_table` containing `return_call_ref`; Binaryen preserves the wrapper, tail call, constructor, and later `struct.set`, and Starshine already matches instead of extending the direct-root `return_call_ref` Starshine-win classification.
- [research note 0995](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed `try_table` ordinary cross-store boundaries that also contain typed-function-reference calls; Binaryen preserves the wrapper, `call_ref`, `ref.as_non_null`, `table.set` / `i32.store`, and later `struct.set`, and Starshine already matches.
- [research note 0994](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed same-effect `try_table` fill boundaries that also contain typed-function-reference calls; Binaryen preserves the wrapper, `call_ref`, `ref.as_non_null`, `memory.fill` / `table.fill`, and later `struct.set`, and Starshine already matches.
- [research note 0993](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed same-effect `try_table` fill boundaries that also contain potentially catchable indirect calls; Binaryen preserves the wrapper, `call_indirect`, `memory.fill` / `table.fill`, and later `struct.set`, and Starshine already matches.
- [research note 0992](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed same-effect `try_table` fill boundaries followed by caught throws; Binaryen preserves the wrapper, fill, `throw`, and later `struct.set`, and Starshine already matches.
- [research note 0991](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed same-effect `try_table` fill boundaries that also contain catchable calls; Binaryen preserves the wrapper, call, `memory.fill` / `table.fill`, and later `struct.set`, and Starshine already matches.
- [research note 0990](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed `try_table` cross-family ordinary-store folds; Binaryen preserves the wrapper plus `table.set` / `i32.store`, removes the later `struct.set`, and Starshine already matches.
- [research note 0989](./index.md)
  - added coverage-only HSO-F/G evidence for result-typed `try_table` cross-family growth folds; Binaryen preserves the wrapper plus `table.grow` / `memory.grow`, removes the later `struct.set`, and Starshine already matches.
- [research note 0988](./index.md)
  - added coverage-only HSO-F/G evidence for the table-side result-typed `try_table` / `table.fill` same-effect boundary; Binaryen preserves `table.size`, the wrapper, `table.fill`, and later `struct.set`, and Starshine already matches.
- [research note 0987](./index.md)
  - added coverage-only HSO-F/G evidence for the table-side result-typed `try_table` / unrelated-global-set fold; Binaryen preserves `table.size`, the wrapper, and `global.set`, removes the later `struct.set`, and Starshine already matches.
- [research note 0986](./index.md)
  - added coverage-only HSO-F/G evidence for the result-typed `try_table` / `memory.fill` same-effect boundary; Binaryen preserves `memory.size`, the wrapper, `memory.fill`, and later `struct.set`, and Starshine already matches after `0985`.
- [research note 0985](./index.md)
  - fixed an HSO-F/G parity gap for result-typed non-throwing `try_table` wrappers before unrelated mutable-global writes; Binaryen folds while preserving the catch-target block wrapper, and Starshine now rejects block-wrapper peeling when any lifted root contains a nested `try_table`.
- [research note 0984](./index.md)
  - fixed an HSO-D/F/G parity gap for `struct.new_desc` followed by a catchable-call `try_table`; Binaryen preserves the descriptor constructor, caught call, and later `struct.set`, so Starshine now blocks branch-skip constructor-local swaps across `try_table` bodies that may escape to their local catch.
- [research note 0983](./index.md)
  - added coverage-only HSO-D/G evidence for `struct.new_desc` across a non-throwing `try_table` body that performs an unrelated mutable `global.set`; Binaryen folds the later value into the descriptor constructor while preserving `try_table`, `global.set`, and descriptor `global.get`, and Starshine already matches.
- [research note 0982](./index.md)
  - added coverage-only HSO-G/F boundary coverage for a constructor local followed by a catchable-call `try_table` before the later `struct.set`; Binaryen preserves the constructor local, `try_table`, `call`, and `struct.set`, and Starshine already matches.
- [research note 0981](./index.md)
  - added coverage-only HSO-G/F boundary coverage for a constructor local followed by a catch-taken `try_table` / `throw` before the later `struct.set`; Binaryen preserves the constructor local, `try_table`, `throw`, and `struct.set`, and Starshine already matches.
- [research note 0980](./index.md)
  - added coverage-only HSO-G tests for non-throwing `try_table` bodies with a branch fully contained inside an inner block before an unrelated `global.set`; Binaryen folds this family and Starshine already matches for `memory.size` / `table.size` constructor operands.
- [research note 0979](./index.md)
  - added coverage-only HSO-G tests for nested inert `block(block(try_table ...))` wrappers around the non-throwing unrelated-global-set family from `0927`; Starshine already folds `memory.size` / `table.size` constructor operands and removes the redundant `struct.set` while preserving the wrapper side effect.
- [research note 0927](./index.md)
  - fixed the HSO-G `0922` parity gap for `memory.size` / `table.size` constructors crossing a block-wrapped, non-throwing `try_table` body that only performs unrelated `global.set`; the implementation keeps direct `try_table` roots inside their block wrapper during swaps so catch-label depths remain valid.
- [research note 0922](./index.md)
  - historical gap note superseded for the covered `memory.size` / `table.size` non-throwing `try_table` / unrelated `global.set` positives by `0927`; arbitrary throwing `try_table` bodies and broader catch/branch wrappers remain open.
- [research note 0921](./index.md)
  - added focused HSO-F/H coverage and classification for the active-catch counterpart of the direct `return_call_ref` set-value boundary; Binaryen preserves the dead store inside `try_table`, while Starshine keeps validating output and drops the dead store as a narrow better-than-Binaryen cleanup.
- [research note 0920](./index.md)
  - added focused HSO-F/H coverage and classification for a direct `return_call_ref` set value; Binaryen preserves the dead `struct.set`, while Starshine emits validating output that drops it as a narrow better-than-Binaryen cleanup.
- [research note 0919](./index.md)
  - added focused HSO-F coverage for a `return_call_ref` branch inside an active `try_table` catch region; Binaryen still folds into `struct.new_default`, and Starshine already matched.
- [research note 0918](./index.md)
  - added focused HSO-F coverage for a `return_call_ref` branch that exits the function from the moved `struct.set` value; Binaryen folds into `struct.new_default`, and Starshine already matched.
- [research note 0917](./index.md)
  - added focused HSO-D/G coverage for a `call_ref`-valued overwritten constructor field before an unrelated `table.set`; Binaryen preserves the later `struct.set`, and Starshine already matched.
- [research note 0916](./index.md)
  - added focused HSO-G coverage for a `call_ref`-valued constructor operand before an unrelated `table.set`; Binaryen preserves the later `struct.set`, and Starshine already matched.
- [research note 0915](./index.md)
  - added focused HSO-D/G coverage for a `call_ref`-valued overwritten constructor field before an unrelated mutable `global.set`; Binaryen preserves the later `struct.set`, and Starshine already matched.
- [research note 0914](./index.md)
  - added focused HSO-G coverage for the typed-function-reference call root: Binaryen preserves a `call_ref`-valued constructor operand before an unrelated mutable `global.set` and leaves the later `struct.set`; Starshine already matched.
- [research note 0913](./index.md)
  - added focused HSO-G coverage for cross-family growth-root `try_table` wrapper boundaries: Binaryen preserves `memory.size` before `try_table` / `table.grow` and `table.size` before `try_table` / `memory.grow`; Starshine already matched.
- [research note 0912](./index.md)
  - added focused HSO-G coverage for same-effect `try_table` wrapper boundaries: Binaryen preserves `memory.size` before `try_table` / `memory.fill` and `table.size` before `try_table` / `table.fill`; Starshine already matched.
- [research note 0911](./index.md)
  - added focused HSO-G coverage for a `try_table` wrapper boundary: Binaryen preserves `table.size`, `try_table` / `i32.store`, and the later `struct.set`; Starshine already matched.
- [research note 0910](./index.md)
  - added focused HSO-G coverage for the memory-side `try_table` wrapper boundary: Binaryen preserves `memory.size`, `try_table` / `table.set`, and the later `struct.set`; Starshine already matched.
- [research note 0891](./index.md)
  - added focused HSO-G coverage for the indirect-call constructor-operand no-swap boundary: Binaryen preserves `call_indirect` before an unrelated `global.set` and leaves the later `struct.set`; Starshine already matched.
- [research note 0890](./index.md)
  - added focused HSO-D/E coverage for a narrow plain-default Starshine win: Binaryen folds only the first call-valued store after `struct.new_default`, but Starshine folds both call-valued stores into the materialized `struct.new` while preserving call order.
- [research note 0889](./index.md)
  - added focused HSO-D/E coverage for a narrow default-descriptor Starshine win: Binaryen folds only the first call-valued store after `struct.new_default_desc`, but Starshine folds both call-valued stores into the materialized `struct.new_desc` while preserving call order and only crossing an immutable descriptor `global.get`.
- [research note 0888](./index.md)
  - added focused HSO-G coverage for cross-family growth swap positives: Binaryen folds when a `memory.size` constructor operand crosses `table.grow`, and when a `table.size` constructor operand crosses `memory.grow`, preserving the growth root while removing the later `struct.set`. Starshine already matched.
- [research note 0881](./index.md)
  - added focused HSO-D/E coverage for a trapping descriptor-if boundary: Binaryen preserves `struct.set` when the descriptor operand is an `if` whose condition is `i32.load`, because folding a call-valued later store would move the call before a possible trap. Starshine already matched.
- [research note 0885](./index.md)
  - added focused HSO-D coverage for descriptor old-field side-effect preservation: Binaryen folds a call-valued later store into `struct.new_desc` while preserving the overwritten old field's call under `drop`. Starshine already matched.
- [research note 0887](./index.md)
  - added focused HSO-D/E coverage for the plain-constructor counterpart to descriptor old-field/later-field barriers: Binaryen preserves `struct.set` when folding would move a call-valued replacement store before a call-valued later constructor field, even though the overwritten old field also has call side effects. Starshine already matched.
- [research note 0886](./index.md)
  - added focused HSO-D/E coverage for descriptor old-field preservation interacting with a later-field call barrier: Binaryen preserves `struct.set` when folding would move a later call before a later constructor-field call, even though the overwritten old field also has call side effects. Starshine already matched.
- [research note 0884](./index.md)
  - added focused HSO-D/E coverage for a trapping descriptor block `br_if` boundary: Binaryen preserves `struct.set` when a value-carrying descriptor block's `br_if` condition is `i32.load`, because folding a call-valued later store would move the call before a possible trap. Starshine already matched.
- [research note 0880](./index.md)
  - added focused HSO-D/E coverage for a trapping descriptor-select boundary: Binaryen preserves `struct.set` when the descriptor select condition is `i32.load`, because folding a call-valued later store would move the call before a possible trap. Starshine already matched.
- [research note 0879](./index.md)
  - added focused HSO-D/E coverage for a trapping later-field select boundary: Binaryen preserves `struct.set` when the select condition is `i32.load`, because folding a call-valued later store would move the call before a possible trap. Starshine already matched.
- [research note 0883](./index.md)
  - added focused HSO-D/E coverage for a trapping later-field block `br_if` boundary: Binaryen preserves `struct.set` when a value-carrying later-field `br_if` condition is `i32.load`, because folding a call-valued later store would move the call before a possible trap. Starshine already matched.
- [research note 0878](./index.md)
  - added focused HSO-D/E coverage for the pure later-field block `br_if` positive: Binaryen folds a call-valued later store through a value-carrying later-field `br_if` when branch operands are pure. Starshine already matched.
- [research note 0877](./index.md)
  - fixed the complementary pure descriptor block `br_if` positive: Binaryen folds a call-valued later store through a value-carrying descriptor `br_if` when branch operands are pure; Starshine now summarizes branch/drop children with descriptor-specific effects and folds the store.
- [research note 0876](./index.md)
  - added focused HSO-D/E coverage for an effectful branch-containing descriptor boundary: Binaryen preserves `struct.set` when the descriptor operand is a block with a value-carrying `br_if` whose condition is a call. Starshine already matched.
- [research note 0875](./index.md)
  - added focused HSO-D/E coverage for an effectful branch-containing later-field boundary: Binaryen preserves `struct.set` when a later constructor field is a block with a value-carrying `br_if` whose condition is a call. Starshine already matched.
- [research note 0874](./index.md)
  - added focused HSO-D/E coverage for an effectful later-field `if` boundary: Binaryen preserves `struct.set` when a later constructor field `if` condition is a call. Starshine already matched.
- [research note 0873](./index.md)
  - added focused HSO-D/E coverage for an effectful later-field select boundary: Binaryen preserves `struct.set` when a later constructor field select condition is a call. Starshine already matched.
- [research note 0872](./index.md)
  - added focused HSO-D/E coverage for an effectful descriptor-select boundary: Binaryen preserves `struct.set` when the descriptor operand selects between immutable descriptor globals but the select condition is a call. Starshine already matched.
- [research note 0871](./index.md)
  - added focused HSO-D/E coverage for mutable descriptor-global barriers: Binaryen folds a pure moved value across the mutable descriptor `global.get`, but preserves `struct.set` for a call-valued moved value. Starshine already matched both shapes.
- [research note 0870](./index.md)
  - added allocation-heavy candidate performance evidence using a 2000-function synthetic module with 6000 foldable `struct.set` roots. Both outputs validated and removed all `StructSet` roots, but Starshine remained slower than Binaryen on pass-local and whole-command timing, so HSO-I stays open.
- [research note 0869](./index.md)
  - refreshed the exact descriptor `ref.cast` surface blocker: Binaryen preserves `struct.set` for the exact descriptor-cast trap-order probe, while current Starshine still rejects the exact WAT during decode and the local `ref_cast_desc_eq` AST surface does not validate as an equivalent focused HSO fixture. This is not an accepted HSO non-goal.
- [research note 0868](./index.md)
  - finalized HSO-H unreachable-boundary wording after a direct-root Binaryen `version_130` probe: HSO preserves `struct.set` for unreachable constructor and set-value shapes and leaves cleanup to later DCE; Starshine's `0792` focused tests cover the semantic boundary while the exact direct-root set-value spelling remains a local HOT/test-surface caveat.
- [research note 0867](./index.md)
  - added HSO-H boundary coverage for the source-backed generic DSE/load-forwarding non-goal: Binaryen preserves repeated non-fresh-reference `struct.set` roots and a later `struct.get` after `struct.set`, and Starshine now has matching focused fail-closed tests.
- [research note 0866](./index.md)
  - probed an HSO-D/F descriptor branch boundary: Binaryen preserves `struct.set` when the descriptor operand is a `br_on_non_null` block that can fall through to `unreachable` before a later call-valued store. A focused Starshine AST fixture currently hits a HOT CFG/verifier surface blocker for this descriptor-typed branch-result shape, so this is an open local-surface blocker rather than HSO parity evidence or an accepted non-goal.
- [research note 0865](./index.md)
  - added HSO-D descriptor trap-boundary coverage: Binaryen preserves `struct.set` when the descriptor operand is `ref.as_non_null` over a nullable descriptor global because folding would move a later call before a possible descriptor trap. Starshine already matched.
- [research note 0863](./index.md)
  - added HSO-F loop-backedge target-local-read coverage: Binaryen preserves `struct.set` when a branch-valued store can jump to a loop header that reads the fresh-struct local before the next `local.set`; Starshine already matched.
- [research note 0862](./index.md)
  - added `br_table` control-flow coverage for HSO-F: Starshine matches Binaryen's escaping-local negative, and the no-later-local-read variant is documented as a narrow Starshine better-than-Binaryen fold that extends the one-disappearing-bad-get reasoning to `br_table` values.
- [research note 0861](./index.md)
  - fixed descriptor later-field global-write barriers: Binaryen folds when a later constructor field writes `$g0` and the moved value reads or writes unrelated `$g1`, but preserves `struct.set` for same-global read/write conflicts. Starshine now normalizes non-skipping structural control out of reorder masks before applying the precise global-only movement allowance.
- [research note 0860](./index.md)
  - fixed descriptor later-field same-global conflict handling for later-field reads: Binaryen folds when a later constructor field reads mutable global `$g0` and the moved value writes unrelated `$g1`, but preserves `struct.set` when both touch `$g0`. Starshine now checks precise same-global read/write conflicts before value-prefix mutation and includes peeled prefix roots in later-field/descriptor reorder checks.
- [research note 0859](./index.md)
  - fixed a descriptor later-field local-read overblock: Binaryen folds a call-valued `struct.set` into `struct.new_desc` even when a later constructor field reads the target local, because the moved value itself has no local-state effects. Focused HSO tests passed `213/213`; direct 10000-case compare normalized `10000/10000` with `0` mismatches.
- [research note 0858](./index.md)
  - added descriptor target-local write hazard coverage: Binaryen preserves `struct.set` when a `struct.new_desc` chain's moved value writes a replacement descriptor-constructed struct to the fresh-struct target local; focused HSO tests passed `212/212`, and no implementation change was needed.
- [research note 0857](./index.md)
  - added descriptor target-local read hazard coverage: Binaryen preserves `struct.set` when a `struct.new_desc` chain's moved value reads the fresh-struct target local; focused HSO tests passed `211/211`, and no implementation change was needed.
- [research note 0856](./index.md)
  - added default/descriptor old-field combination coverage: Binaryen folds safe `struct.new_default_desc` chain stores into `struct.new_desc`, but preserves a descriptor `struct.set` when a later constructor field call orders before the moved call; focused HSO tests passed `210/210`, and no implementation change was needed.
- [research note 0855](./index.md)
  - added target-local chain coverage: Binaryen preserves both stores when an early moved value writes the target local, but folds an earlier harmless store before a later target-local-read hazard; focused HSO tests passed `208/208`, and no implementation change was needed.
- [research note 0854](./index.md)
  - added coverage for the source-backed target-local write hazard where the moved set value overwrites the same fresh-struct local; focused HSO tests passed `206/206`, and no implementation change was needed.
- [research note 0853](./index.md)
  - added coverage for the subsequent-chain counterpart of Binaryen's old-field side-effect conflict negative; focused HSO tests passed `205/205`, and no implementation change was needed.
- [research note 0852](./index.md)
  - added coverage for Binaryen's `$side-effect-subsequent-ok` family; focused HSO tests passed `204/204`, and no implementation change was needed.
- [research note 0851](./index.md)
  - classifies the currently source-backed HSO-C core-chain family as behavior-parity covered after repeated-store, wrong-target-local, tee-plus-later-chain, many-fields, pattern-breaker, and many-news coverage/fixes, with no residual debris/output-shape drift in the latest direct lanes.

## What is not covered by this page

This page does not claim full future-proof parity if upstream implements the owner-file TODOs for generic dead-store elimination or load forwarding.
If that happens, the pass contract would materially expand and should get a new source-correction note.

It also does not claim that Starshine's wrapper-cleanup machinery exists upstream. Those helpers are local HOT/writeback survival work.

## Sources

- [research note 0448](./index.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
