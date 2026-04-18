---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
  - ../late-pipeline-dispatch.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `heap-store-optimization`

- Active hot pass in the Starshine registry.
- Current summary: Fold exact struct.set writes into nearby struct.new allocations when local and effect ordering stays safe.
- Current Binaryen terminology check: the current `wasm_opt::Pass` docs still expose `HeapStoreOptimization`, so this maintenance run found no non-GitHub evidence of a rename or deprecation even though the Debian manpage excerpt is less detailed for this pass.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster and the 2026-04-18 non-GitHub terminology check until dedicated strategy and parity pages land.
