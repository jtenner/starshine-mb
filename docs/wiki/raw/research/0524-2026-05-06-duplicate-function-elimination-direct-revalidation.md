---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/duplicate-function-elimination/starshine-strategy.md
  - ../../binaryen/passes/duplicate-function-elimination/parity.md
  - ../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/duplicate-function-elimination/starshine-strategy.md
  - ../../binaryen/passes/duplicate-function-elimination/parity.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `duplicate-function-elimination` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `duplicate-function-elimination` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --out-dir .tmp/pass-fuzz-duplicate-function-elimination`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`duplicate-function-elimination` is re-proven for direct explicit-pass parity under the refreshed harness. Keep the pass documented as an active module pass with Starshine-local cleanup extras, and keep preset scheduling / multi-iteration Binaryen behavior as separate scheduler work rather than an AUD002 direct-pass blocker.
