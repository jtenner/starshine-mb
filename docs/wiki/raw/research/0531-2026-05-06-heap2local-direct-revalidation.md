---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/heap2local/index.md
  - ../../binaryen/passes/heap2local/parity.md
  - ../../binaryen/passes/heap2local/starshine-hot-ir-strategy.md
  - ../../../../src/passes/heap2local.mbt
  - ../../../../src/passes/heap2local_test.mbt
  - ../../../../src/passes/heap2local_primary_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/heap2local/index.md
  - ../../binaryen/passes/heap2local/parity.md
  - ../../binaryen/passes/heap2local/starshine-hot-ir-strategy.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `heap2local` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `heap2local` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --out-dir .tmp/pass-fuzz-heap2local`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`heap2local` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass, but it does not change the documented ordered-pipeline constraints: `[H2L]002` remains active for Binaryen-style non-nullable-local / refinalization fixups and the wider `optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighborhood proof.
