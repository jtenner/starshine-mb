# Binaryen `heap-store-optimization` current-main source and code-map capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest and Starshine code-map refresh for the `docs/wiki/binaryen/passes/heap-store-optimization/` dossier

## Scope

This file extends the earlier 2026-04-22 source manifest for `heap-store-optimization` with a focused current-`main` recheck and an exact current Starshine owner/test map.

Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md`

## Provenance

### Prior tagged oracle retained

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Prior manifest: `docs/wiki/raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`
  - The earlier manifest records the release page observed on 2026-04-22 with publish date **2026-04-01**.

### Official current-main source files consulted

- `HeapStoreOptimization.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/HeapStoreOptimization.cpp>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/refs/heads/main/src/passes/HeapStoreOptimization.cpp>
  - Key reviewed locations in current `main`:
    - header / generic-heap-optimization TODO around line 25,
    - CFG walker declaration around line 29,
    - action collection for `StructSet` and `Block` around lines 55-63,
    - immediate `local.tee(struct.new ...)` handling around lines 74-92,
    - block-local `local.set(struct.new ...)` scan and swap loop around lines 94-174,
    - `trySwap(...)` local motion guard around lines 177-194,
    - `optimizeSubsequentStructSet(...)` safety and fold body around lines 197-334.
- `heap-store-optimization.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap-store-optimization.wast>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/refs/heads/main/test/lit/passes/heap-store-optimization.wast>
  - Key reviewed test families: direct tee fold, subsequent-set chains, default materialization, swap cases, effect-order negatives, and local-control-flow hazards.
- `pass.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed for continued public registration and scheduler terminology.
- `local-graph.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
  - Reviewed as the helper surface behind the current source's `canMoveSet(...)` query.
- `effects.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
  - Reviewed as the source of the effect-order checks used by the pass.

## Durable observations from current-main sources

- The current upstream source still teaches the same contract as the earlier `version_129` dossier: `heap-store-optimization` is constructor/store folding for `struct.set` into a fresh `struct.new` family, not generic heap dead-store elimination.
- The generic dead-store / load-forwarding TODO remains visible in the owner file.
- Current `main` still records only `StructSet` and `Block` action sites for the pass.
- The immediate tee form and later local-set chain remain the two central positive families.
- `trySwap(...)` remains a small local motion step, not a general code-motion pass.
- `LazyLocalGraph::canMoveSet(...)` remains the hard control-flow safety proof for values whose control flow might skip a moved local assignment.
- No teaching-relevant current-main drift was observed for the pass contract while preparing this 2026-04-25 refresh.

## Starshine source surfaces rechecked

Current exact local code locations for the active Starshine pass:

- `src/passes/heap_store_optimization.mbt:2-24`
  - descriptor and public summary.
- `src/passes/optimize.mbt:197-199`
  - active hot-pass registry entry.
- `src/passes/optimize.mbt:253-257` and `src/passes/optimize.mbt:392-396`
  - `optimize` preset placements.
- `src/passes/optimize.mbt:265-269` and `src/passes/optimize.mbt:405-409`
  - `shrink` preset placements.
- `src/passes/pass_manager.mbt:7045-7058`
  - raw fast-skip lane for `heap-store-optimization`.
- `src/passes/pass_manager.mbt:8697`
  - hot-pass dispatcher case.
- `src/passes/heap_store_optimization.mbt:312-354`
  - skip-local-set / local-control-flow predicates.
- `src/passes/heap_store_optimization.mbt:560-631`
  - trapless readonly and reorderable subtree predicates.
- `src/passes/heap_store_optimization.mbt:761-792`
  - root swap guard.
- `src/passes/heap_store_optimization.mbt:914-970`
  - supported constructor family, including descriptor and default forms.
- `src/passes/heap_store_optimization.mbt:1296-1468`
  - wrapper flattening and unreachable-tail repair helpers.
- `src/passes/heap_store_optimization.mbt:1653-1775`
  - shared fold-into-constructor proof and rewrite.
- `src/passes/heap_store_optimization.mbt:1777-1827`
  - tee-wrapped fold rewrite.
- `src/passes/heap_store_optimization.mbt:2028-2218`
  - recursive HOT-region processing, later-set chain handling, swap logic, and root replacement.
- `src/passes/heap_store_optimization.mbt:2220-2241`
  - public run function, effect-summary requirement, mutation marking.
- `src/passes/heap_store_optimization_test.mbt:396-1967`
  - focused positive, negative, writeback, branch, wrapper, descriptor, default, and raw-prefix regressions.
- `src/passes/perf_test.mbt:6241-6320`
  - raw fast-skip trace/perf regressions.
- `src/cmd/cmd_wbtest.mbt:2514-3490` and `src/cmd/cmd_wbtest.mbt:6600-6634`
  - CLI replay and debug-artifact coverage for `--heap-store-optimization`.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
