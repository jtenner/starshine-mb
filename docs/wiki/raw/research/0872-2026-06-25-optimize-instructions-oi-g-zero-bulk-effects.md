---
kind: research
status: complete
date: 2026-06-25
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../src/passes/optimize_instructions_test.mbt
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/wat-shapes.md
---

# Optimize-instructions OI-G zero-size bulk-memory effect boundary

## Question

Does Binaryen `version_130` remove zero-size `memory.copy` / `memory.fill` when their address or value operands are effectful calls?

## Oracle

Probe: `.tmp/oi-g-zero-bulk-effect-probe.wat`.

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-zero-bulk-effect-probe.wat -o -
```

Binaryen keeps both bulk-memory operations. It prints `memory.copy(call $dst, call $src, i32.const 0)` and `memory.fill(call $dst, call $val, i32.const 0)` rather than dropping the calls or rewriting to empty code.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions keeps zero-size bulk-memory with effectful operands`

The public-pipeline fixture uses stack-carried calls for the destination/source/value operands and asserts that the optimized function still contains `memory.copy`, `memory.fill`, and the original call order. It also asserts that no tiny-copy/fill load/store lowering appeared.

This is a boundary/status slice, not a red-first implementation slice. Starshine already matched the source-backed keep-spelling behavior for this effectful zero-size subset.

## Status

OI-G now has explicit effectful zero-size bulk-memory coverage in addition to the earlier zero-size pure boundary. Remaining OI-G work still includes nonconstant-size fills/copies, nonconstant size-16 fill values, broader memory/load-store canonicalization, and broader raw-gate escapes.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-zero-bulk-effect-probe.wat -o -` passed and kept both zero-size bulk-memory operations.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*zero-size bulk-memory*'` passed `1/1`.
