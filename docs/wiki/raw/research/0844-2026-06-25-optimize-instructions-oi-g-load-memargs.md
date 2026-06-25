---
kind: research
status: supported
created: 2026-06-25
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md
  - ../../../binaryen/passes/optimize-instructions/wat-shapes.md
  - ../../../../src/passes/optimize_instructions.mbt
  - ../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-G load-result memarg preservation

## Summary

This slice locks a source-backed detail of the OI-G load-result rewrites: when `optimize-instructions` rewrites a load result through a reinterpret or `i64.extend_i32_*`, the replacement representation load must preserve the original memory access metadata.

The covered shapes are:

- `f32.reinterpret_i32(i32.load offset=4 align=1 p) -> f32.load offset=4 align=1 p`;
- `i64.extend_i32_u(i32.load offset=8 align=2 p) -> i64.load32_u offset=8 align=2 p`;
- `i64.extend_i32_s(i32.load16_s offset=12 align=1 p) -> i64.load16_s offset=12 align=1 p`.

No pass implementation change was needed; the current `optimize_instructions_try_rewrite_load_result(...)` path already copies the source memarg while replacing the load opcode.

## Binaryen oracle

`wasm-opt version_130` preserves offsets and alignments while changing only the load representation:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-load-memarg-probe.wat -o -
```

Observed output included `f32.load offset=4 align=1`, `i64.load32_u offset=8 align=2`, and `i64.load16_s offset=12 align=1`.

## Starshine coverage

Added focused coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves memargs when rewriting representation loads`

The test verifies that the reinterpret / extend opcodes are removed and that the replacement loads retain the source memarg offset and alignment in Starshine's pretty-printed core output.

## Validation

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memargs*'` passed `1/1`.

Broader OI-G validation is recorded in the committing slice.

## Remaining OI-G work

This closes only memarg-preservation coverage for already implemented load-result rewrites. Broader shared-load canonicalization, additional `optimizeStoredValue` shapes, zero-size trap-relaxed bulk-memory cleanup, and broader raw-gate escapes remain open under `[O4Z-AUDIT-OI-G]`.
