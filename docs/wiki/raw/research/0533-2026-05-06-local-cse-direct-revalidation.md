---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/local-cse/index.md
  - ../../binaryen/passes/local-cse/starshine-strategy.md
  - ../../binaryen/passes/local-cse/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/local_cse.mbt
  - ../../../../src/passes/local_cse_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/local-cse/index.md
  - ../../binaryen/passes/local-cse/starshine-strategy.md
  - ../../binaryen/passes/local-cse/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `local-cse` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `local-cse` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`local-cse` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass. It does not prove the still-gated aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` ordered neighborhood, and it does not widen the existing preset claim beyond the already-documented late local-cleanup neighborhood.
