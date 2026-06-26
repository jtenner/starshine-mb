# Optimize-instructions OI-F identical conversion select arms

## Slice

This OI-F implementation slice extends Starshine's identical-pure `select` arm fold to a narrow direct f32/f64 conversion sibling.

## Binaryen oracle

Probe: `.tmp/oi-select-identical-conversion-arms-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-conversion-arms-probe.wat -o .tmp/oi-select-identical-conversion-arms-probe.out.wat
```

Result: passed. Binaryen `version_130` removed `select` around identical direct conversion arms for:

- `f32.convert_i32_s(local.get)`
- `f64.convert_i64_u(local.get)`
- `f64.promote_f32(local.get)`
- `f32.demote_f64(local.get)`

The condition was a side-effect-free local.

## Starshine change

Files:

- `src/passes/optimize_instructions.mbt`
- `src/passes/optimize_instructions_test.mbt`

Starshine now recognizes matching direct f32/f64 unary conversion local shells as identical pure select arms:

- f32 conversions from i32/i64 local payloads, `f32.demote_f64`, and `f32.reinterpret_i32`
- f64 conversions from i32/i64 local payloads, `f64.promote_f32`, and `f64.reinterpret_i64`

The implementation reuses the existing exact-instruction/same-local unary shell matcher and only adds these direct instruction families to the f32/f64 identical-arm predicates.

## Red-first evidence

Focused test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*numeric expression arms*'
```

Before implementation, the test failed `0/1` on the new `f32.convert_i32_s` case:

```text
expected identical pure f32.convert_i32_s select arms to fold
```

After implementation, the same focused test passed `1/1`.

## Boundaries

This is not broad structural expression equality. It deliberately does not claim:

- commuted operands
- value-equivalent constants
- broad NaN payload equality
- float algebraic equality
- arbitrary nested conversion trees
- effectful or trapping condition folding
- broad trapping-conversion cleanup beyond the direct shells covered here

The fold still requires both select arms and the condition to satisfy Starshine's local side-effect-free checks.
