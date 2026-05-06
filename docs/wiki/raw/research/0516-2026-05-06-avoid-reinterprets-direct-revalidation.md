---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/avoid-reinterprets/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/avoid_reinterprets.mbt
  - ../../../../src/passes/avoid_reinterprets_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/avoid-reinterprets/index.md
  - ../../binaryen/passes/avoid-reinterprets/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `avoid-reinterprets` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `avoid-reinterprets` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass avoid-reinterprets --out-dir .tmp/pass-fuzz-avoid-reinterprets`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures were Binaryen parser/canonicalization failures on wasm-smith inputs using empty recursion groups, represented by failure metadata such as `.tmp/pass-fuzz-avoid-reinterprets/failures/case-000029-wasm-smith/failure-metadata.json` with `Recursion groups of size zero not supported`. Starshine still produced its raw output artifact for those cases; they were not semantic mismatches.

A separate smoke probe before the revalidation confirmed that `optimize-instructions` still has active mismatches and remains in AUD001, so this note only closes the `avoid-reinterprets` AUD002 revalidation row.

## Conclusion

`avoid-reinterprets` is re-proven for direct pass parity under the refreshed harness. Keep the pass active-partial and direct-only: the indirect helper-local family remains unimplemented and outside public presets, but the direct active pass no longer belongs in the post-fuzzer-change revalidation backlog.
