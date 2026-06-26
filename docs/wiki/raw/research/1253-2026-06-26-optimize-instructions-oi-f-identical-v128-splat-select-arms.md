# Optimize Instructions OI-F identical v128 splat select arms

Date: 2026-06-26

## Scope

This bounded OI-F slice extends the identical-pure select-arm matcher from direct byte-identical `v128.const` leaves to a narrow direct SIMD splat/local shell: matching `i8x16.splat`, `i16x8.splat`, `i32x4.splat`, `i64x2.splat`, `f32x4.splat`, or `f64x2.splat` arms whose sole child is the same `local.get`, with a side-effect-free select condition.

This is not a claim for SIMD algebraic equality, lane-equivalent spelling equality, arbitrary structural expression equality, commuted operands, splat-of-equivalent-expression matching, or effectful/trapping condition folding.

## Binaryen oracle

Probe: `.tmp/oi-select-identical-v128-splat-arms-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-v128-splat-arms-probe.wat -o .tmp/oi-select-identical-v128-splat-arms-probe.out.wat
```

Result: passed. Binaryen rewrote the probed

```wat
(select
  (i8x16.splat (local.get 0))
  (i8x16.splat (local.get 0))
  (local.get 1))
```

to the single `i8x16.splat(local.get 0)` arm, dropping the side-effect-free condition.

## Starshine change

- `src/passes/optimize_instructions_test.mbt` adds red-first focused coverage: `optimize-instructions folds select with identical pure v128 splat arms`.
- Before implementation, the focused test failed because Starshine kept the `select`.
- `src/passes/optimize_instructions.mbt` now treats direct SIMD splat nodes with a side-effect-free child as side-effect-free for the local expression matcher and recognizes same-instruction/same-local splat arm pairs as identical pure arms.

## Validation

- Red-first focused test before implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*v128 splat arms*'
```

failed `0/1` with `expected identical pure v128 splat select arms to fold`.

- After implementation, the same focused command passed `1/1`.

Broader commit validation is recorded in the commit body for this slice.

## Boundaries

Retained open boundaries:

- no SIMD algebraic equality
- no lane-equivalent spelling equality
- no arbitrary structural expression equality
- no commuted operand matching
- no splat payload expression equality beyond the same direct `local.get`
- no effectful or trapping select-condition folding
