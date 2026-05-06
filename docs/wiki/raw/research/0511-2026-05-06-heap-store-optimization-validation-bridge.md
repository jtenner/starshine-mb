# 0511-2026-05-06-heap-store-optimization-validation-bridge

## Question

What current-main source anchors and local replay surfaces should the `heap-store-optimization` dossier trust for validation and health checks?

## Answer

The reviewed official Binaryen `main` sources still match the narrow `version_129` contract:

- `HeapStoreOptimization.cpp` still centers on the TODO-labeled constructor/store fold, `StructSet` / `Block` action sites, `trySwap(...)`, the later-chain constructor fold, and a lazily created `LazyLocalGraph`.
- `pass.cpp` still registers `heap-store-optimization` and still places it in the GC-gated early and late optimize pipelines.
- The dedicated `heap-store-optimization.wast` test file still teaches the same tee, subsequent-set, default-constructor, swap, control-flow, and `remove-unused-names` interaction families.

The local Starshine implementation points at the same validation surfaces as the living dossier already claimed:

- registry/preset wiring in `src/passes/optimize.mbt`
- raw fast-skip and dispatch plumbing in `src/passes/pass_manager.mbt`
- HOT implementation and rewrite helpers in `src/passes/heap_store_optimization.mbt`
- focused unit, perf, and CLI replay coverage in `src/passes/heap_store_optimization_test.mbt`, `src/passes/perf_test.mbt`, and `src/cmd/cmd_wbtest.mbt`

## Primary-source anchors reviewed

- `HeapStoreOptimization.cpp`:
  - TODO at `L1023-L1024`
  - `requiresNonNullableLocalFixups() == false` and `ignoreBranchesOutsideOfFunc = true` at `L1060-L1074`
  - `StructSet`-driven chain scan at `L1195-L1219`
  - `LazyLocalGraph` construction at `L1626-L1628`
- `pass.cpp`:
  - pass registration at `L2632-L2636`
  - early and late GC-gated pipeline placement at `L3451-L3454` and `L3594-L3597`
- `heap-store-optimization.wast`:
  - `remove-unused-names` interaction note at `L2233-L2241`
  - `struct.new_default` family coverage at `L3437-L3456`
  - swap / blocker negative cases at `L2768-L2800`

## Follow-up

The living wiki can now point readers at a compact validation bridge page instead of repeating the same source-spotcheck details in every strategy page.
