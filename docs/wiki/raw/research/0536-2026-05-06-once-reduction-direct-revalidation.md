---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/once-reduction/index.md
  - ../../binaryen/passes/once-reduction/parity.md
  - ../../binaryen/passes/once-reduction/starshine-hot-ir-strategy.md
  - ../../../../src/passes/once_reduction.mbt
  - ../../../../src/passes/once_reduction_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/once-reduction/index.md
  - ../../binaryen/passes/once-reduction/parity.md
  - ../../binaryen/passes/once-reduction/starshine-hot-ir-strategy.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `once-reduction` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `once-reduction` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass once-reduction --out-dir .tmp/pass-fuzz-once-reduction`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`once-reduction` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass.

This does **not** close the broader source-surface gaps documented in the living dossier: Starshine still intentionally tracks the explicit once-global subset and does not yet model the upstream `@binaryen.idempotent` fake-once-global path or the full CFG / dominator strategy from Binaryen `OnceReduction.cpp`.
