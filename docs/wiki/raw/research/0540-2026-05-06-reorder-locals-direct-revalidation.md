---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/reorder-locals/parity.md
  - ../../binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../src/passes/reorder_locals_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/reorder-locals/parity.md
  - ../../binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `reorder-locals` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `reorder-locals` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass reorder-locals --out-dir .tmp/pass-fuzz-reorder-locals`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`reorder-locals` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass.

This does **not** close `[RL]003` or make the pass preset-ready. The Starshine pass remains explicit-only; public `optimize` / `shrink` scheduling still waits on the neighboring local-pass slots and the broader multivalue-call writeback boundary documented in the living pages.
