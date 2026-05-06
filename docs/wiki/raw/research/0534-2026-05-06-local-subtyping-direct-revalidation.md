---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/local-subtyping/index.md
  - ../../binaryen/passes/local-subtyping/starshine-strategy.md
  - ../../binaryen/passes/local-subtyping/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/local_subtyping.mbt
  - ../../../../src/passes/local_subtyping_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/local-subtyping/index.md
  - ../../binaryen/passes/local-subtyping/starshine-strategy.md
  - ../../binaryen/passes/local-subtyping/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `local-subtyping` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `local-subtyping` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`local-subtyping` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass. It does not close the documented full-Binaryen-contract gaps around get-aware dominance analysis, non-null fallback, get/tee retagging, repeated refinalization, or the broader ordered-neighborhood proof around `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse`.
