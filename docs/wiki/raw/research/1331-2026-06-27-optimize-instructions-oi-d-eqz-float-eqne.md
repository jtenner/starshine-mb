# OptimizeInstructions OI-D: `eqz` Float Equality/Inquality Inversion

Date: 2026-06-27

## Scope

This slice narrows the OI-D `i32.eqz(compare)` parity gap for floating-point equality and inequality compares only:

- `i32.eqz(f32.eq(a, b)) -> f32.ne(a, b)`
- `i32.eqz(f32.ne(a, b)) -> f32.eq(a, b)`
- `i32.eqz(f64.eq(a, b)) -> f64.ne(a, b)`
- `i32.eqz(f64.ne(a, b)) -> f64.eq(a, b)`

It deliberately does **not** invert NaN-sensitive float relational compares such as `f32.lt`: the earlier companion probe kept `i32.eqz(f32.lt(...))`, and this slice keeps that boundary.

## Binaryen evidence

Probe: `.tmp/oi-float-eqne-eqz-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions \
  .tmp/oi-float-eqne-eqz-probe.wat \
  -o .tmp/oi-float-eqne-eqz-probe.out.wat
```

Result: passed. The output rewrote direct and call-backed float equality/inequality under `i32.eqz` to the inverted float equality opcode while preserving the original operands:

- `f32.eq` became `f32.ne`
- `f32.ne` became `f32.eq`
- `f64.eq` became `f64.ne`
- `f64.ne` became `f64.eq`

## Starshine change

Added red-first HOT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions rewrites eqz on float eq-ne compares into inverted compares`

Before implementation it failed with the root still spelled `I32Eqz` instead of `F32Ne`. The implementation generalized the existing `eqz(compare)` inversion helper to include only float equality/inequality opcodes, then rewired the existing `optimize_instructions_try_fold_eqz(...)` compare case to use the renamed helper.

## Boundaries

- No float relational inversion.
- No broad boolean algebra.
- No NaN-insensitive equivalence claim beyond the exact Binaryen-observed equality/inequality opcode inversion.
- No operand canonicalization beyond preserving the existing compare children under the inverted opcode.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-float-eqne-eqz-probe.wat -o .tmp/oi-float-eqne-eqz-probe.out.wat` — passed.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*float eq-ne compares into inverted compares*'` — failed red-first before implementation, then passed after implementation.
