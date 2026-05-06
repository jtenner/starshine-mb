---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/code-folding/index.md
  - ../../binaryen/passes/code-folding/starshine-strategy.md
  - ../../binaryen/passes/code-folding/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/code_folding.mbt
  - ../../../../src/passes/code_folding_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/code-folding/index.md
  - ../../binaryen/passes/code-folding/starshine-strategy.md
  - ../../binaryen/passes/code-folding/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `code-folding` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `code-folding` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-folding --out-dir .tmp/pass-fuzz-code-folding`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`code-folding` is re-proven for direct default-pass parity under the refreshed harness. Keep the active HOT pass direct-evidence-current, but leave broader `[CF]002` late-slot and artifact validation work open: the local implementation is still a narrow void-tail / cleanup subset and the exact late-pipeline `code-folding -> merge-blocks -> remove-unused-brs` neighborhood remains to be replayed before public preset scheduling expands.
