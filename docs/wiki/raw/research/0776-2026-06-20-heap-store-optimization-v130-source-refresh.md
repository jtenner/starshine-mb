---
kind: research
status: active
created: 2026-06-20
sources:
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
| Pass registration and optimize-path slots | `pass.cpp` registers the pass and adds it in early/late no-DWARF optimize neighborhoods. | `src/passes/optimize.mbt` registers the hot pass and places it in `optimize` / `shrink`; `src/passes/pass_manager.mbt` dispatches the public pass name. | Covered structurally; final closeout still needs early/late O4z slot or neighborhood evidence. |
| Narrow action surface: `StructSet` and `Block` only | `HeapStoreOptimization.cpp` records only `StructSet` and `Block` action roots. Dedicated lit remains unchanged from `version_129`. | `src/passes/heap_store_optimization.mbt` processes HOT regions and `StructSet`/constructor patterns, not array/memory/table store DSE. | Covered as a non-goal boundary; keep explicit tests for array/memory/table/generic DSE boundaries. |
| Immediate tee fold | `optimizeStructSet(...)` calls `optimizeSubsequentStructSet(...)` for `local.tee(struct.new*)`. Lit covers tee forms. | `hso_try_fold_tee_wrapped_struct_set(...)` at `src/passes/heap_store_optimization.mbt:1777`; tests start at `heap_store_optimization_test.mbt:396` and include tee wrapper variants. | Covered, but HSO-C should re-run focused positive/negative tee tests against `version_130`. |
| Later local-set / local-get chain | `optimizeBlock(...)` scans block roots after `local.set(struct.new*)`, folds matching later `struct.set`, and keeps scanning. | `hso_process_region(...)` at `src/passes/heap_store_optimization.mbt:2028`, plus `hso_local_set_struct_new(...)` and `hso_struct_set_for_local(...)`. Tests include consecutive roots and chain forms at `:425` onward. | Covered, but HSO-C should classify any output drift from a fresh direct baseline. |
| Repeated stores / last value wins | Lit chain cases stay unchanged in `version_130`; source keeps scanning after a successful fold. | Consecutive-root, same-local, repeated same-field last-value, and wrong-target-local tests exist; `0789` added the latter two coverage guards. | Better covered after `0789`; HSO-C still needs broader lit chain review and debris/output-shape classification before closeout. |
| `struct.new_default` materialization | `isWithDefault()` path still builds explicit operands from default values before replacing a field. | `hso_build_default_struct_new_children(...)` / `hso_supported_struct_new(...)`; tests at `:490` and `:545`. | Covered; HSO-D should recheck descriptor/default combinations. |
| Descriptor constructor forms | `new_->desc` is still a movement barrier, but the barrier check is now directional `descEffects.orderedBefore(setValueEffects)`. | `hso_supported_struct_new(...)`, `hso_desc_operand_effects_for_node(...)`, `hso_try_fold_into_struct_new(...)`, descriptor tests at `:579`, `:606`, `:714`, and `:746`. | Partially covered. Follow-up `0780` fixed immutable descriptor-global call movement while preserving the mutable descriptor-global negative; follow-up `0784` fixed block-wrapped immutable descriptor-global and descriptor `local.get` operands; follow-up `0785` fixed pure descriptor-`if` operands and added a call-condition negative; follow-up `0786` fixed descriptor block self-branch overblocking; follow-up `0787` fixed branchless descriptor-loop overblocking and added a self-branching loop negative; follow-up `0788` fixed descriptor-loop outer-branch overblocking and passed native-build plus direct 10000-case compare signoff. Broader arbitrary descriptor operand expressions still need review against directional `orderedBefore(...)`. |
| Later field/descriptor/constructor effect barriers | Four checks changed from symmetric `invalidates(...)` to directional `orderedBefore(...)`. | `hso_mask_ordered_before(...)`, `hso_desc_operand_effects_for_node(...)`, `hso_struct_new_shallow_effects(...)`, and `hso_struct_new_operand_effect_mask(...)` model these barriers. | Active behavior gap candidate for HSO-D/E/G. Follow-up `0778` fixed one plain-constructor shallow-effect overblocking gap by making `struct.new` / `struct.new_default` wrapper effects empty. Follow-up `0779` fixed one later-field directional gap by allowing moved local-only values before a trapping later field operand. Follow-up `0780` fixed one descriptor operand/shallow-wrapper gap for immutable versus mutable descriptor globals and moved calls. Follow-up `0781` fixed one swap directionality gap where a constructor operand `global.get` must stay before a later mutable `global.set`. Follow-up `0782` fixed the complementary swap-side immutable descriptor `global.get` overblocking gap across an unrelated mutable `global.set`. Follow-up `0784` fixed descriptor `local.get` and block-wrapped immutable descriptor-global overblocking for moved-call folds. Follow-up `0785` fixed pure descriptor-`if` overblocking and preserved Binaryen's call-condition descriptor-`if` negative. Follow-up `0786` fixed descriptor block self-branch overblocking for moved-call folds through a descriptor block that branches to its own result. Follow-up `0787` fixed branchless descriptor-loop overblocking and locked the self-branching descriptor-loop negative; follow-up `0788` fixed descriptor-loop outer-branch overblocking by tracking active loop labels and passed native-build plus direct 10000-case compare signoff. Broader arbitrary descriptor operands, remaining later-field barriers, and broader swap directionality still need focused tests. |
| Old field side-effect preservation | Source still preserves replaced old-field effects when they matter. | `hso_try_fold_into_struct_new(...)` replaces or wraps old field values; tests added in follow-up `0778` cover old-field call preservation and the moved-call fold into plain `struct.new`. | Partially covered; descriptor/default combinations and broader old-field negative audit remain for HSO-D. |
| Target-local hazards | Source rejects moved values that read/write the target local before considering movement. | `hso_subtree_touches_local(...)`; negative tests at `:1893`, `:1932`, `:1967`. | Covered; HSO-E should add target-local write/read chain variants if missing. |
| Control-flow skip-local-set hazards | Source still uses `LazyLocalGraph::canMoveSet(...)`, with the one-bad-get exception when the bad get disappears in the optimized set. | `hso_subtree_may_skip_local_set(...)` and region owner predicates. Branch-related tests exist at `:640`, `:675`, `:786`, `:828`, `:1893`. | High-risk parity surface for HSO-F; refresh with safe function-external exits and unsafe in-function branch/catch negatives. |
| Swap legality | `trySwap(...)` still rejects final-element and constructor ping-pong swaps, but effect legality is now directional `firstEffects.orderedBefore(secondEffects)`. | `hso_struct_new_operand_effect_mask(...)` and `hso_root_can_swap_before_local_struct_new(...)`; tests include safe swaps, the `0781` constructor-global read versus later global-write negative, the `0782` immutable descriptor-global operand across unrelated global-write positive, and `0783` coverage for `memory.size` swap positives, trapping `i32.load` swap negatives, and constructor-local-set ping-pong no-fold behavior. | Partially covered. Follow-ups `0781` and `0782` fixed one underblock gap and one overblock gap in constructor-operand swap effect handling; `0783` added broader source-backed coverage without needing a code change. HSO-G should still test broader swap legality, table combinations, final-element blockers, and wrapper peeling drift. |
| Unreachable no-fold boundary | Source still rejects unreachable constructor/set pairs and leaves DCE to later passes. | Local pass has unreachable-tail repair; exact no-fold boundary needs explicit coverage. | HSO-H/J should lock this boundary as an explicit non-goal with tests. |

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
