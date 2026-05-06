---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/code-pushing/starshine-strategy.md
  - ../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/code-pushing/starshine-strategy.md
  - ../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `code-pushing` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `code-pushing` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-pushing --out-dir .tmp/pass-fuzz-code-pushing`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups, for example `failures/case-000573-wasm-smith/failure.txt` reports `Recursion groups of size zero not supported`. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`code-pushing` is re-proven for direct explicit-pass parity under the refreshed harness. This does not change the intentionally narrow implementation scope: Starshine still has only the const-like single-consuming-arm HOT subset plus the local dead-block flattening helper, and public preset placement remains blocked on broader `code-pushing` parity plus ordered-neighborhood replay around `tuple-optimization` and `simplify-locals-nostructure`.
