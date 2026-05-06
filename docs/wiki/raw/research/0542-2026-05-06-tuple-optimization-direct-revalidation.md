---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/tuple-optimization/index.md
  - ../../binaryen/passes/tuple-optimization/parity.md
  - ../../binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md
  - ../../../../src/passes/tuple_optimization.mbt
  - ../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/tuple-optimization/index.md
  - ../../binaryen/passes/tuple-optimization/parity.md
  - ../../binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `tuple-optimization` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `tuple-optimization` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-smoke`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization`

The full pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`tuple-optimization` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass.

This does **not** close `[TO]005` or make the pass preset-ready. The Starshine pass remains explicit-only for the relevant no-DWARF optimize-path slot work; exact `code-pushing -> tuple-optimization -> simplify-locals-nostructure` slot proof, full debug-artifact compare, and runtime debt are still tracked separately.
