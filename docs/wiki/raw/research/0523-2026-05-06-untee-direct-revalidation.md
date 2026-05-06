---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/untee/index.md
  - ../../binaryen/passes/untee/starshine-strategy.md
  - ../../../../src/passes/untee.mbt
  - ../../../../src/passes/untee_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/untee/index.md
  - ../../binaryen/passes/untee/starshine-strategy.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `untee` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `untee` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass untee --out-dir .tmp/pass-fuzz-untee`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`untee` is re-proven for direct default-pass parity under the refreshed harness. Keep the pass as an explicit direct module pass and keep it outside the no-DWARF `optimize` / `shrink` preset unless a later source-backed preset-order proof needs it.
