---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/simplify-locals/index.md
  - ../../binaryen/passes/simplify-locals/parity.md
  - ../../binaryen/passes/simplify-locals/validation-and-signoff.md
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/simplify_locals_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/simplify-locals/index.md
  - ../../binaryen/passes/simplify-locals/parity.md
  - ../../binaryen/passes/simplify-locals/validation-and-signoff.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `simplify-locals` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `simplify-locals` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals --out-dir .tmp/pass-fuzz-simplify-locals`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`simplify-locals` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass.

This does **not** close `[SL]004` or make the pass preset-ready. The Starshine pass remains explicit-only for the relevant no-DWARF optimize-path slot work; late-slot validation, artifact replay, runtime work, and remaining raw wasm/text-form drift are still tracked separately.
