---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/string-gathering/index.md
  - ../../binaryen/passes/string-gathering/starshine-strategy.md
  - ../../binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/string_gathering.mbt
  - ../../../../src/passes/string_gathering_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/string-gathering/index.md
  - ../../binaryen/passes/string-gathering/starshine-strategy.md
  - ../../binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `string-gathering` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `string-gathering` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass string-gathering --out-dir .tmp/pass-fuzz-string-gathering`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`string-gathering` is re-proven for direct explicit-pass parity under the refreshed harness. Keep the pass documented as an active direct module pass, and keep the `remove-unused-module-elements -> string-gathering -> reorder-globals -> directize` preset-tail proof as separate ordered-neighborhood work rather than an AUD002 direct-pass blocker.
