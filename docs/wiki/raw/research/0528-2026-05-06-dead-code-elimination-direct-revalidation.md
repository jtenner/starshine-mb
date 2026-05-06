---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/dead-code-elimination/index.md
  - ../../binaryen/passes/dead-code-elimination/starshine-strategy.md
  - ../../binaryen/passes/dead-code-elimination/starshine-hot-ir-strategy.md
  - ../../../../src/passes/dead_code_elimination.mbt
  - ../../../../src/passes/dead_code_elimination_test.mbt
  - ../../../../src/passes/dead_code_elimination_live_repro_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/dead-code-elimination/index.md
  - ../../binaryen/passes/dead-code-elimination/starshine-strategy.md
  - ../../binaryen/passes/dead-code-elimination/starshine-hot-ir-strategy.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `dead-code-elimination` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `dead-code-elimination` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dead-code-elimination`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups, for example `failures/case-000573-wasm-smith/failure.txt` reports `Recursion groups of size zero not supported`. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`dead-code-elimination` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass, but does not close `[DCE]003`: whole-command wall time, raw wasm/text-form drift, and ordered-prefix proof remain separate active work.
