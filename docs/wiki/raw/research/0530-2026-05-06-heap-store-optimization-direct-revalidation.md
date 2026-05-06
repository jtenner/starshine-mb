---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/heap_store_optimization.mbt
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `heap-store-optimization` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `heap-store-optimization` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`heap-store-optimization` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass, but it does not change the documented ordered-pipeline constraints: the pass still needs exact-slot and nested-rerun evidence before broader no-DWARF preset claims should be expanded.
