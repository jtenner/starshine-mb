# Binaryen `heap-store-optimization` current-main recheck

_Status:_ immutable focused source recheck and code-map refresh for the `docs/wiki/binaryen/passes/heap-store-optimization/` dossier

This file captures a 2026-05-05 current-`main` recheck of the upstream `heap-store-optimization` surfaces. It narrows the earlier 2026-04-25 code-map refresh to two questions:

- did current `main` drift in any teaching-relevant way from the existing Binaryen `version_129` contract?
- did any of the exact local Starshine code anchors used by the living dossier move?

## Pages this manifest supports

- `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md`

## Primary sources rechecked

- `HeapStoreOptimization.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/HeapStoreOptimization.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/HeapStoreOptimization.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- dedicated lit test
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap-store-optimization.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap-store-optimization.wast>
- helper surfaces also checked for source-context continuity
  - `local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>

## Recheck result

The reviewed current-`main` sources still support the same teaching-level contract as the existing dossier:

- the pass still focuses on folding `struct.set` back into a nearby fresh `struct.new` family;
- the generic dead-store / load-forwarding TODO remains visible in the owner file;
- the visitor surface still centers on `StructSet` and `Block` action sites;
- the tee fold, block-local subsequent-set scan, constructor swap, and `LazyLocalGraph`-backed control-flow safety story are unchanged;
- the dedicated lit file still covers the same positive and negative families.

No teaching-relevant current-`main` drift was recorded for the reviewed upstream contract.

## Local code-map refresh

The 2026-05-05 recheck also refreshed the exact local Starshine anchors used by the living dossier:

- `src/passes/heap_store_optimization.mbt:2-20`
- `src/passes/optimize.mbt:194-196`
- `src/passes/optimize.mbt:282-305`
- `src/passes/pass_manager.mbt:7264-7274`
- `src/passes/pass_manager.mbt:8097-8099`
- `src/passes/heap_store_optimization.mbt:312-354`
- `src/passes/heap_store_optimization.mbt:560-631`
- `src/passes/heap_store_optimization.mbt:761-792`
- `src/passes/heap_store_optimization.mbt:914-970`
- `src/passes/heap_store_optimization.mbt:1296-1468`
- `src/passes/heap_store_optimization.mbt:1653-1775`
- `src/passes/heap_store_optimization.mbt:1777-1827`
- `src/passes/heap_store_optimization.mbt:2028-2218`
- `src/passes/heap_store_optimization.mbt:2220-2241`
- `src/passes/heap_store_optimization_test.mbt:396-1967`
- `src/passes/perf_test.mbt:6241-6320`
- `src/cmd/cmd_wbtest.mbt:2514-3490`
- `src/cmd/cmd_wbtest.mbt:6600-6634`

## Source provenance

- [`../../research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md`](../../research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md)
