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

# Optimize-instructions OI-G nonconstant bulk-memory effect boundary

## Question

Does Binaryen `version_130` lower `memory.copy` / `memory.fill` when the size operand is a dynamic call result and the other operands are effectful calls?

## Oracle

Probe: `.tmp/oi-g-nonconstant-bulk-effects-probe.wat`.

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-nonconstant-bulk-effects-probe.wat -o -
```

Binaryen keeps both bulk-memory operations. It prints `memory.copy(call $dst, call $src, call $size)` and `memory.fill(call $dst, call $val, call $size)` rather than guessing a tiny lowering or dropping any call operand.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions keeps nonconstant bulk-memory with effectful size`

The public-pipeline fixture uses call-backed destination, source/value, and size operands. It asserts that the optimized function still contains `memory.copy` and `memory.fill`, preserves the call order, and does not emit any tiny load/store lowering.

This is a boundary/status slice, not a red-first implementation slice. Starshine already matched the source-backed keep-spelling behavior for this dynamic-size effectful subset.

## Status

OI-G now has explicit effectful dynamic-size bulk-memory coverage in addition to zero-size and pure nonconstant-size boundaries. Remaining OI-G work still includes broader load/store canonicalization, broader raw-gate escapes, and trap-relaxed zero-size cleanup only if/when Starshine supports the required modes.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-nonconstant-bulk-effects-probe.wat -o -` passed and kept both dynamic-size bulk-memory operations.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nonconstant bulk-memory*'` passed `1/1`.
