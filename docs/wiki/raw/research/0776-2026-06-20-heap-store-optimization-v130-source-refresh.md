---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0847-2026-06-20-heap-store-optimization-o4z-slot-evidence.md
  - ./0846-2026-06-20-heap-store-optimization-br-table-table-side-stores.md
  - ./0845-2026-06-20-heap-store-optimization-br-table-swap-wrappers.md
  - ./0844-2026-06-20-heap-store-optimization-cross-family-store-swap.md
  - ./0843-2026-06-20-heap-store-optimization-branch-wrapper-growth-boundaries.md
  - ./0842-2026-06-20-heap-store-optimization-branch-wrapper-passive-boundaries.md
  - ./0841-2026-06-20-heap-store-optimization-branch-wrapper-copy-boundaries.md
  - ./0840-2026-06-20-heap-store-optimization-branch-wrapper-bulk-fill-boundaries.md
  - ./0839-2026-06-20-heap-store-optimization-branch-wrapper-constructor-pingpong.md
  - ./0838-2026-06-20-heap-store-optimization-branch-wrapper-table-global-swap.md
  - ./0837-2026-06-20-heap-store-optimization-branch-wrapper-global-swap.md
  - ./0836-2026-06-20-heap-store-optimization-deep-nested-growth-bulk-boundaries.md
  - ./0835-2026-06-20-heap-store-optimization-nested-wrapped-growth-bulk-boundaries.md
  - ./0834-2026-06-20-heap-store-optimization-nested-wrapped-growth-passive-boundaries.md
  - ./0833-2026-06-20-heap-store-optimization-wrapped-growth-passive-boundaries.md
  - ./0832-2026-06-20-heap-store-optimization-wrapped-passive-boundaries.md
  - ./0831-2026-06-20-heap-store-optimization-wrapped-copy-boundaries.md
  - ./0830-2026-06-20-heap-store-optimization-loop-wrapped-bulk-fill-boundaries.md
  - ./0829-2026-06-20-heap-store-optimization-wrapped-bulk-fill-boundaries.md
  - ./0828-2026-06-20-heap-store-optimization-mixed-index-copy-boundaries.md
  - ./0827-2026-06-20-heap-store-optimization-multi-index-copy-boundaries.md
  - ./0826-2026-06-20-heap-store-optimization-multi-index-bulk-boundaries.md
  - ./0825-2026-06-20-heap-store-optimization-table-grow-bulk-boundaries.md
  - ./0824-2026-06-20-heap-store-optimization-memory-grow-bulk-boundaries.md
  - ./0823-2026-06-20-heap-store-optimization-memory-grow-data-boundaries.md
  - ./0822-2026-06-20-heap-store-optimization-table-grow-elem-boundaries.md
  - ./0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ./0820-2026-06-20-heap-store-optimization-memory-size-data-segment-boundaries.md
  - ./0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ./0818-2026-06-20-heap-store-optimization-table-size-table-set-swap.md
  - ./0817-2026-06-20-heap-store-optimization-global-set-value-read-swap.md
  - ./0816-2026-06-20-heap-store-optimization-unrelated-global-swap.md
  - ./0815-2026-06-20-heap-store-optimization-growth-store-swap-boundaries.md
  - ./0814-2026-06-20-heap-store-optimization-nested-wrapper-swap.md
  - ./0813-2026-06-20-heap-store-optimization-wrapped-constructor-pingpong.md
  - ./0812-2026-06-20-heap-store-optimization-loop-wrapped-table-grow-swap.md
  - ./0811-2026-06-20-heap-store-optimization-loop-wrapped-memory-grow-swap.md
  - ./0810-2026-06-20-heap-store-optimization-loop-wrapped-table-size-swap.md
  - ./0809-2026-06-20-heap-store-optimization-if-wrapped-table-size-swap.md
  - ./0808-2026-06-20-heap-store-optimization-if-wrapped-table-grow-swap.md
  - ./0807-2026-06-20-heap-store-optimization-if-wrapped-memory-grow-swap.md
  - ./0806-2026-06-20-heap-store-optimization-block-wrapped-memory-grow-swap.md
  - ./0805-2026-06-20-heap-store-optimization-block-wrapped-table-grow-swap.md
  - ./0804-2026-06-20-heap-store-optimization-block-wrapped-swap.md
  - ./0803-2026-06-20-heap-store-optimization-call-swap-negative.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/heap-store-optimization/wat-shapes.md
  - ../../binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md
  - ./0775-2026-06-20-heap-store-optimization-recursive-handoff-plan.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` `version_130` source refresh

Question: does the active `heap-store-optimization` audit need a fresh release oracle after the older dossier anchored itself to Binaryen `version_129` plus a 2026-05-05 current-main no-drift check?

## Answer

Yes. The local release oracle is now Binaryen `version_130`:

```text
wasm-opt version 130 (version_130)
```

A fresh source/lit refresh found a small but behavior-relevant source drift from `version_129` to `version_130`:

- `test/lit/passes/heap-store-optimization.wast` is byte-identical between `version_129` and `version_130`.
- `src/passes/HeapStoreOptimization.cpp` is not byte-identical. Four movement checks changed from broad symmetric `invalidates(...)` checks to directional `orderedBefore(...)` checks:
  - `trySwap(...)`: `firstEffects.orderedBefore(secondEffects)` now decides whether the earlier constructor set must stay before the blocker.
  - later constructor operands: `operandEffects.orderedBefore(setValueEffects)` now decides whether a later field operand must stay before the moved store value.
  - descriptor operand: `descEffects.orderedBefore(setValueEffects)` now decides whether the descriptor must stay before the moved store value.
  - shallow constructor effects: `structNewEffects.orderedBefore(setValueEffects)` now decides whether the constructor wrapper/allocation must stay before the moved store value.
- The `version_130` `pass.cpp` still registers `heap-store-optimization` and still schedules it twice in the no-DWARF optimize path under the same early and late GC-gated neighborhoods.

This invalidates the older local shorthand “use `version_129` as the current source oracle.” For the active recursive audit, use `version_130` as the release oracle and treat the `orderedBefore(...)` drift as a source-backed behavior family to test and classify before final closeout.

## Source commands

```sh
wasm-opt --version
python3 - <<'PY'
from pathlib import Path
from urllib.request import urlopen
base=Path('.tmp/hso-v130-refresh'); base.mkdir(parents=True, exist_ok=True)
files={
'HeapStoreOptimization-v129.cpp':'https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/HeapStoreOptimization.cpp',
'HeapStoreOptimization-v130.cpp':'https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/HeapStoreOptimization.cpp',
'heap-store-optimization-v129.wast':'https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/heap-store-optimization.wast',
'heap-store-optimization-v130.wast':'https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/heap-store-optimization.wast',
'pass-v130.cpp':'https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp',
}
for name,url in files.items():
    with urlopen(url, timeout=30) as r:
        (base/name).write_bytes(r.read())
PY
(diff -u .tmp/hso-v130-refresh/HeapStoreOptimization-v129.cpp .tmp/hso-v130-refresh/HeapStoreOptimization-v130.cpp > .tmp/hso-v130-refresh/hso-cpp-v129-v130.diff || true)
(diff -u .tmp/hso-v130-refresh/heap-store-optimization-v129.wast .tmp/hso-v130-refresh/heap-store-optimization-v130.wast > .tmp/hso-v130-refresh/hso-wast-v129-v130.diff || true)
wc -l .tmp/hso-v130-refresh/*.diff .tmp/hso-v130-refresh/HeapStoreOptimization-v130.cpp .tmp/hso-v130-refresh/heap-store-optimization-v130.wast
grep -n "heap-store-optimization\|HeapStoreOptimization" .tmp/hso-v130-refresh/pass-v130.cpp | head -20
grep -n "StructSet\|Block\|trySwap\|optimizeSubsequentStructSet\|orderedBefore\|canMoveSet\|isWithDefault\|desc" .tmp/hso-v130-refresh/HeapStoreOptimization-v130.cpp | head -120
```

Observed results:

```text
wasm-opt version 130 (version_130)
   38 .tmp/hso-v130-refresh/hso-cpp-v129-v130.diff
    0 .tmp/hso-v130-refresh/hso-wast-v129-v130.diff
  376 .tmp/hso-v130-refresh/HeapStoreOptimization-v130.cpp
 1684 .tmp/hso-v130-refresh/heap-store-optimization-v130.wast
228:  registerPass("heap-store-optimization",
230:               createHeapStoreOptimizationPass);
669:    addIfNoDWARFIssues("heap-store-optimization");
744:    addIfNoDWARFIssues("heap-store-optimization");
```

## Behavior/source/lit/local matrix

| Binaryen `version_130` family | Source/lit evidence | Current Starshine map | Audit status |
|---|---|---|---|
| Pass registration and optimize-path slots | `pass.cpp` registers the pass and adds it in early/late no-DWARF optimize neighborhoods. | `src/passes/optimize.mbt` registers the hot pass and places it in `optimize` / `shrink`; `src/passes/pass_manager.mbt` dispatches the public pass name. Follow-up `0847` refreshed generated O4z predecessor artifacts for the current `_build/wasm/debug/build/cmd/cmd.wasm`; Starshine direct HSO replay at the first top-level early/late HSO slots was exact-equal and normalized-equal to Binaryen with raw-fast-skip. | Structurally covered and current generated slot evidence captured; final closeout still needs the wider final validation/compare ladder and remaining source-backed behavior families. |
| Narrow action surface: `StructSet` and `Block` only | `HeapStoreOptimization.cpp` records only `StructSet` and `Block` action roots. Dedicated lit remains unchanged from `version_129`. `trySwap(...)` can still cross ordinary memory/table blockers to reach a later fresh-struct `struct.set`; it is not optimizing those stores themselves. | `src/passes/heap_store_optimization.mbt` processes HOT regions and `StructSet`/constructor patterns, not array/memory/table store DSE. Follow-up `0790` added explicit array-store boundary coverage; follow-up `0791` superseded the ordinary-memory boundary claim and fixed Starshine to fold through ordinary memory/table blockers like Binaryen. | Better covered after `0791`; generic DSE/load-forwarding wording, future-Binaryen reopening criteria, and unreachable no-fold coverage still need final HSO-H review. |
| Immediate tee fold | `optimizeStructSet(...)` calls `optimizeSubsequentStructSet(...)` for `local.tee(struct.new*)`. Lit covers tee forms. | `hso_try_fold_tee_wrapped_struct_set(...)` at `src/passes/heap_store_optimization.mbt:1777`; tests start at `heap_store_optimization_test.mbt:396` and include tee wrapper variants. | Covered, but HSO-C should re-run focused positive/negative tee tests against `version_130`. |
| Later local-set / local-get chain | `optimizeBlock(...)` scans block roots after `local.set(struct.new*)`, folds matching later `struct.set`, and keeps scanning. | `hso_process_region(...)` at `src/passes/heap_store_optimization.mbt:2028`, plus `hso_local_set_struct_new(...)` and `hso_struct_set_for_local(...)`. Tests include consecutive roots and chain forms at `:425` onward. | Covered, but HSO-C should classify any output drift from a fresh direct baseline. |
| Repeated stores / last value wins | Lit chain cases stay unchanged in `version_130`; source keeps scanning after a successful fold. | Consecutive-root, same-local, repeated same-field last-value, and wrong-target-local tests exist; `0789` added the latter two coverage guards. | Better covered after `0789`; HSO-C still needs broader lit chain review and debris/output-shape classification before closeout. |
| `struct.new_default` materialization | `isWithDefault()` path still builds explicit operands from default values before replacing a field. | `hso_build_default_struct_new_children(...)` / `hso_supported_struct_new(...)`; tests at `:490` and `:545`. | Covered; HSO-D should recheck descriptor/default combinations. |
| Descriptor constructor forms | `new_->desc` is still a movement barrier, but the barrier check is now directional `descEffects.orderedBefore(setValueEffects)`. | `hso_supported_struct_new(...)`, `hso_desc_operand_effects_for_node(...)`, `hso_try_fold_into_struct_new(...)`, descriptor tests at `:579`, `:606`, `:714`, and `:746`. | Partially covered. Follow-up `0780` fixed immutable descriptor-global call movement while preserving the mutable descriptor-global negative; follow-up `0784` fixed block-wrapped immutable descriptor-global and descriptor `local.get` operands; follow-up `0785` fixed pure descriptor-`if` operands and added a call-condition negative; follow-up `0786` fixed descriptor block self-branch overblocking; follow-up `0787` fixed branchless descriptor-loop overblocking and added a self-branching loop negative; follow-up `0788` fixed descriptor-loop outer-branch overblocking and passed native-build plus direct 10000-case compare signoff. Broader arbitrary descriptor operand expressions still need review against directional `orderedBefore(...)`. |
| Later field/descriptor/constructor effect barriers | Four checks changed from symmetric `invalidates(...)` to directional `orderedBefore(...)`. | `hso_mask_ordered_before(...)`, `hso_desc_operand_effects_for_node(...)`, `hso_struct_new_shallow_effects(...)`, and `hso_struct_new_operand_effect_mask(...)` model these barriers. | Active behavior gap candidate for HSO-D/E/G. Follow-up `0778` fixed one plain-constructor shallow-effect overblocking gap by making `struct.new` / `struct.new_default` wrapper effects empty. Follow-up `0779` fixed one later-field directional gap by allowing moved local-only values before a trapping later field operand. Follow-up `0780` fixed one descriptor operand/shallow-wrapper gap for immutable versus mutable descriptor globals and moved calls. Follow-up `0781` fixed one swap directionality gap where a constructor operand `global.get` must stay before a later mutable `global.set`. Follow-up `0782` fixed the complementary swap-side immutable descriptor `global.get` overblocking gap across an unrelated mutable `global.set`. Follow-up `0784` fixed descriptor `local.get` and block-wrapped immutable descriptor-global overblocking for moved-call folds. Follow-up `0785` fixed pure descriptor-`if` overblocking and preserved Binaryen's call-condition descriptor-`if` negative. Follow-up `0786` fixed descriptor block self-branch overblocking for moved-call folds through a descriptor block that branches to its own result. Follow-up `0787` fixed branchless descriptor-loop overblocking and locked the self-branching descriptor-loop negative; follow-up `0788` fixed descriptor-loop outer-branch overblocking by tracking active loop labels and passed native-build plus direct 10000-case compare signoff. Broader arbitrary descriptor operands, remaining later-field barriers, and broader swap directionality still need focused tests. |
| Old field side-effect preservation | Source still preserves replaced old-field effects when they matter. | `hso_try_fold_into_struct_new(...)` replaces or wraps old field values; tests added in follow-up `0778` cover old-field call preservation and the moved-call fold into plain `struct.new`. | Partially covered; descriptor/default combinations and broader old-field negative audit remain for HSO-D. |
| Target-local hazards | Source rejects moved values that read/write the target local before considering movement. | `hso_subtree_touches_local(...)`; negative tests at `:1893`, `:1932`, `:1967`. | Covered; HSO-E should add target-local write/read chain variants if missing. |
| Control-flow skip-local-set hazards | Source still uses `LazyLocalGraph::canMoveSet(...)`, with the one-bad-get exception when the bad get disappears in the optimized set. The dedicated lit also marks plain `return` in the moved set value safe because the taken return exits the function, marks a call caught by an in-function `try_table` unsafe, and includes nested `drop(block(result ...))` branch-sequence families. Local `version_130` probes in `0797` show conditional external `throw` and `return_call` values fold, `return_call` also folds inside `try_table`, and conditional `throw` inside an active catch remains negative. | `hso_subtree_may_skip_local_set(...)`, `hso_subtree_may_escape_to_active_catch(...)`, nested child/region traversal, and region owner/active-catch predicates. Branch-related tests exist at `:640`, `:675`, `:786`, `:828`, `:1893`; follow-up `0793` added the function-external return fold positive, follow-up `0794` added the in-function caught-call negative, follow-up `0795` added safe external call, nested control-sequence first-store fold, and escaping branch-valued store negatives, follow-up `0796` added the exact one-disappearing-bad-get positive, follow-up `0797` added conditional external `throw`, external `return_call`, and active-catch `return_call` positives, and follow-up `0798` added focused active-catch `throw` negative coverage. | Better covered after `0793`-`0798`; HSO-F still needs broader in-function branch/catch negatives beyond the covered caught-call, active-catch throw, escaping branch-valued store, and one-disappearing-bad-get families. The exact one-disappearing-bad-get exception is now implemented rather than an accepted non-goal. |
| Swap legality | `trySwap(...)` still rejects final-element and constructor ping-pong swaps, but effect legality is now directional `firstEffects.orderedBefore(secondEffects)`. | `hso_struct_new_operand_effect_mask(...)` and `hso_root_can_swap_before_local_struct_new(...)`; tests include safe swaps, the `0781` constructor-global read versus later same-global write negative, the `0782` immutable descriptor-global operand across unrelated global-write positive, `0783` coverage for `memory.size` swap positives, trapping constructor-operand `i32.load` swap negatives, and constructor-local-set ping-pong no-fold behavior, plus `0791` coverage for crossing ordinary `i32.store` and `table.set` blockers when the constructor has no ordered operand effects, plus `0799` coverage for the final-root no-swap boundary, `0800` coverage for a `table.size` constructor operand crossing an unrelated mutable `global.set`, `0801` coverage for a table-growing constructor operand crossing the same unrelated global-write blocker, `0802` coverage for a memory-growing constructor operand crossing that unrelated global-write blocker, `0803` coverage for a call-valued constructor operand not crossing that unrelated global-write blocker, plus `0804` coverage for a memory.size constructor operand crossing a block-wrapped unrelated global write, plus `0805` coverage for table.grow crossing that same block-wrapped unrelated global write shape, plus `0806` coverage for memory.grow crossing that same block-wrapped unrelated global write shape, plus `0807` coverage for memory.grow crossing an if-wrapped unrelated global write shape, plus `0808` coverage for table.grow crossing that same if-wrapped unrelated global write shape, plus `0809` coverage for table.size crossing that same if-wrapped unrelated global write shape, plus `0810` coverage for table.size crossing a branchless loop-wrapped unrelated global write shape, plus `0811` coverage for memory.grow crossing that same branchless loop-wrapped unrelated global write shape, plus `0812` coverage for table.grow crossing that same branchless loop-wrapped unrelated global write shape, plus `0813` coverage for the constructor-ping-pong distinction where direct constructor `local.set` roots remain barriers but `block` / `if` / branchless `loop` wrappers around unrelated constructor assignments still fold, plus `0814` coverage for nested mixed `block` / `if` / branchless `loop` wrappers around unrelated global writes, plus `0815` coverage for same-kind growth/store no-swap boundaries where `memory.grow` does not cross `i32.store` and `table.grow` does not cross `table.set`, plus `0823` coverage where `memory.grow` also does not cross passive data operations (`memory.init` / `data.drop`), plus `0824` coverage where `memory.grow` does not cross memory-bulk writes (`memory.fill` / `memory.copy`), plus `0825` coverage where `table.grow` does not cross table-bulk writes (`table.fill` / `table.copy`), plus `0816` coverage for mutable `global.get $a` constructor operands crossing `global.set $b` when `$a != $b`, `0817` coverage where the unrelated `global.set $b` value also reads `$a`, `0818` coverage where `table.size` does not cross `table.set`, `0819` coverage where `memory.size` does not cross bulk-memory writes (`memory.fill` / `memory.copy`), `0820` coverage where `memory.size` also does not cross passive data operations (`memory.init` / `data.drop`), `0821` coverage where `table.size` does not cross table bulk / passive element operations (`table.init` / `elem.drop`), `0822` coverage where `table.grow` does not cross those same table bulk / passive element operations, and `0826` coverage where Binaryen keeps the no-fold boundary even when `memory.size $ma` would cross `memory.fill $mb` or `table.size $ta` would cross `table.fill $tb` with different indices, plus `0827` coverage for matching cross-index copy boundaries with `memory.copy $mb $mb` and `table.copy $tb $tb`, plus `0828` coverage for mixed-endpoint copy boundaries, plus `0829` coverage for block/if-wrapped bulk-fill barriers, plus `0830` coverage for loop-wrapped bulk-fill barriers, plus `0831` coverage for block/if/loop-wrapped copy barriers, plus `0832` coverage for block/if/loop-wrapped passive init/drop barriers, plus `0833` coverage for the side-effecting memory.grow/table.grow counterparts across block/if/loop-wrapped passive init/drop barriers, plus `0834` coverage for nested mixed-wrapper growth/passive init/drop barriers, plus `0835` coverage for nested mixed-wrapper growth/bulk `memory.fill`, `memory.copy`, `table.fill`, and `table.copy` barriers, plus `0836` coverage for deeper `block(block(if ...))`, `if(block(block ...))`, and `loop(block(block ...))` growth/bulk barriers, plus `0837` and `0838` coverage for branch-containing unrelated global-write wrappers that still fold after the wrapper branch exits to the wrapper end, covering `memory.grow`, `table.size`, and `table.grow` constructor operands, plus `0839` coverage where branch-containing wrappers around unrelated constructor local-set roots still fold while preserving the direct constructor ping-pong no-fold boundary, plus `0840` coverage where branch-containing wrappers around same-effect-family `memory.fill` / `table.fill` roots still block folds for `memory.size` / `table.size` constructors, plus `0841` coverage where branch-containing wrappers around same-effect-family `memory.copy` / `table.copy` roots still block those folds, plus `0842` coverage where branch-containing wrappers around passive data/element roots (`memory.init`, `data.drop`, `table.init`, and `elem.drop`) still block those folds for `memory.size` / `table.size` constructors, plus `0843` coverage where branch-containing wrappers around bulk-memory/table and passive data/element roots still block folds for side-effecting `memory.grow` / `table.grow` constructors, plus `0844` coverage where cross-family ordinary stores (`memory.size` across `table.set` and `table.size` across `i32.store`) still fold, plus `0845` coverage where a `br_table`-ending wrapper preserves that cross-family `memory.size` / `table.set` fold while same-effect-family `memory.fill` remains a barrier, plus `0846` coverage where a `br_table`-ending wrapper preserves the table-side `table.size` / `i32.store` fold while side-effecting `table.grow` crossing that memory-store wrapper remains a no-fold boundary. | Partially covered. Follow-ups `0781` and `0782` fixed one underblock gap and one overblock gap in constructor-operand swap effect handling; `0783` added broader source-backed coverage without needing a code change; `0791` fixed memory/table blocker overblocking while preserving constructor ping-pong; `0799` added final-root no-swap coverage; `0800` added table-size/global-set swap coverage; `0801` added table-grow/global-set swap coverage; `0802` added memory-grow/global-set swap coverage; `0803` added call-valued constructor operand/global-set no-swap coverage; `0804` added memory.size/block-wrapped-global-set swap coverage; `0805` added matching table.grow/block-wrapped-global-set swap coverage; `0806` added matching memory.grow/block-wrapped-global-set swap coverage; `0807` added memory.grow/if-wrapped-global-set swap coverage; `0808` added matching table.grow/if-wrapped-global-set swap coverage; `0809` added matching table.size/if-wrapped-global-set swap coverage; `0810` added matching table.size/loop-global-set swap coverage for a branchless loop wrapper; `0811` added matching memory.grow/loop-global-set swap coverage; `0812` added matching table.grow/loop-global-set swap coverage; `0813` added wrapped constructor-local-set ping-pong coverage while keeping the direct-root negative covered. `0814` added nested mixed-wrapper global-write swap coverage. `0815` added same-kind growth/store no-swap coverage for memory and table effects. `0816` fixed the mutable-global granularity gap for unrelated global writes and passed direct 10000-case compare. `0818` added the same-family `table.size`/`table.set` no-swap boundary, including a Binaryen probe with different table indices. `0819` added same-kind memory-size/bulk-memory no-swap boundaries for `memory.fill` and `memory.copy`; `0820` extended that boundary to passive data operations with `memory.init` and `data.drop`; `0821` added matching table-size/table-bulk and passive-element boundaries for `table.init` and `elem.drop`; `0822` added the side-effecting table.grow counterpart for those same element/table roots; `0823` added the side-effecting memory.grow counterpart for passive data roots; `0824` added the side-effecting memory.grow counterpart for memory-bulk `memory.fill` / `memory.copy` roots; `0825` added the side-effecting table.grow counterpart for table-bulk `table.fill` / `table.copy` roots; `0826` added cross-index memory/table bulk-fill no-fold coverage for `memory.size $ma` across `memory.fill $mb` and `table.size $ta` across `table.fill $tb`; `0827` added the matching cross-index copy boundaries for `memory.copy $mb $mb` and `table.copy $tb $tb`; `0828` added mixed-endpoint copy boundaries for `memory.copy $mb $ma`, `memory.copy $ma $mb`, `table.copy $tb $ta`, and `table.copy $ta $tb`. `0829` added wrapper-negative bulk-fill boundaries where block/if-wrapped `memory.fill` / `table.fill` still prevent folding constructor `memory.size` / `table.size` operands; `0830` extended that same no-fold boundary to branchless loop-wrapped `memory.fill` / `table.fill`; `0831` added block/if/loop-wrapped copy-root no-fold boundaries for `memory.copy` / `table.copy`; `0832` added block/if/loop-wrapped passive init/drop no-fold boundaries for `memory.init`, `data.drop`, `table.init`, and `elem.drop`; `0833` added the side-effecting memory.grow/table.grow counterparts for those same wrapped passive roots. `0834` added nested mixed-wrapper growth/passive no-fold coverage for `block(if ...)`, `if(block ...)`, and `loop(block ...)` roots, `0835` added the same nested mixed-wrapper coverage for side-effecting growth/bulk-memory and bulk-table roots, and `0836` added deeper `block(block(if ...))`, `if(block(block ...))`, and `loop(block(block ...))` growth/bulk barriers. `0839` added branch-containing wrapper coverage for the constructor ping-pong positive side while preserving the direct-root negative. `0840` added branch-containing wrapper coverage for the same-effect-family bulk-fill negative side, preserving `struct.set` before `memory.fill` / `table.fill` wrappers when the constructor observes `memory.size` / `table.size`; `0841` added the matching same-effect-family copy-root negative side for branch-containing `memory.copy` / `table.copy` wrappers. `0842` added the matching passive data/element-root negative side for branch-containing `memory.init`, `data.drop`, `table.init`, and `elem.drop` wrappers. `0843` added the side-effecting `memory.grow` / `table.grow` counterparts for branch-containing bulk-memory/table and passive data/element roots. `0844` added cross-family ordinary-store positives for `memory.size` across `table.set` and `table.size` across `i32.store`. `0845` added `br_table` wrapper coverage for a cross-family ordinary-store positive and a same-effect-family memory-fill negative. `0846` added table-side `br_table` wrapper coverage for the `table.size` / `i32.store` positive and the side-effecting `table.grow` / `i32.store` negative. HSO-G should still test broader swap legality and additional distinct wrapper/effect variants beyond the covered roots. |
| Unreachable no-fold boundary | Source still rejects unreachable constructor/set pairs and leaves DCE to later passes. | Local pass has unreachable-tail repair; follow-up `0792` added focused no-fold coverage for unreachable constructor operands and unreachable set-value operands. | Better covered after `0792`; HSO-H/J still need final non-goal wording and exact local-surface caveats. |

## Local code map refresh

Current local anchors observed during this slice:

- `src/passes/heap_store_optimization.mbt:312` — `hso_subtree_may_skip_local_set(...)`
- `src/passes/heap_store_optimization.mbt:560` — `hso_subtree_is_trapless_readonly(...)`
- `src/passes/heap_store_optimization.mbt:605` — `hso_subtree_is_trapless_reorderable(...)`
- `src/passes/heap_store_optimization.mbt:761` — `hso_root_can_swap_before_local_struct_new(...)`
- `src/passes/heap_store_optimization.mbt:881` — `hso_build_default_struct_new_children(...)`
- `src/passes/heap_store_optimization.mbt:914` — `hso_supported_struct_new(...)`
- `src/passes/heap_store_optimization.mbt:975` — `hso_struct_new_shallow_effects(...)`
- `src/passes/heap_store_optimization.mbt:1653` — `hso_try_fold_into_struct_new(...)`
- `src/passes/heap_store_optimization.mbt:1777` — `hso_try_fold_tee_wrapped_struct_set(...)`
- `src/passes/heap_store_optimization.mbt:1874` — `hso_local_set_struct_new(...)`
- `src/passes/heap_store_optimization.mbt:1899` — `hso_struct_set_for_local(...)`
- `src/passes/heap_store_optimization.mbt:2028` — `hso_process_region(...)`

Current focused test anchors begin at `src/passes/heap_store_optimization_test.mbt:396` and run through the existing negative target-local tests and later swap/wrapper coverage at `:2612`.

## Required follow-up

1. Baseline a fresh direct `heap-store-optimization` compare against local `wasm-opt version_130` before behavior changes.
2. Add directional movement tests for descriptor, later-field, shallow-constructor, and swap barriers. These tests should distinguish `orderedBefore(...)` from old symmetric `invalidates(...)` behavior.
3. Keep older current-main no-drift notes as historical support for stable lit/source shape, but no longer describe `version_129` as the current source oracle.
