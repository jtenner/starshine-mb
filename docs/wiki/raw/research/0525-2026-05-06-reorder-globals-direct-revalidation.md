---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/reorder-globals/index.md
  - ../../binaryen/passes/reorder-globals/starshine-strategy.md
  - ../../binaryen/passes/reorder-globals/implementation-structure-and-tests.md
  - ../../../../src/passes/reorder_globals.mbt
  - ../../../../src/passes/reorder_globals_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/reorder-globals/index.md
  - ../../binaryen/passes/reorder-globals/starshine-strategy.md
  - ../../binaryen/passes/reorder-globals/implementation-structure-and-tests.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `reorder-globals` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `reorder-globals` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass reorder-globals --out-dir .tmp/pass-fuzz-reorder-globals`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`reorder-globals` is re-proven for direct explicit-pass parity under the refreshed harness. Keep the pass documented as an active module pass with Starshine-specific numeric `GlobalIdx` remapping, and keep the `string-gathering -> reorder-globals -> directize` preset-tail proof as separate ordered-neighborhood work rather than an AUD002 direct-pass blocker.
