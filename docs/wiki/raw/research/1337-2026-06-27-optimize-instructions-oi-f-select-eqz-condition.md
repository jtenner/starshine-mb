# OptimizeInstructions OI-F select eqz-condition cleanup

Date: 2026-06-27

## Scope

This slice narrows one Binaryen `OptimizeInstructions` boolean/select parity gap: direct `i32.eqz` select conditions.

Binaryen `version_130` was probed with:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-select-eqz-condition-probe.wat -o .tmp/oi-f-select-eqz-condition-probe.out.wat
```

The oracle rewrote:

- `(select A B (i32.eqz cond))` to `(select B A cond)` for arbitrary i32 values.
- `(select (i32.const 1) (i32.const 0) (i32.eqz cond))` to `i32.eqz(cond)` through the boolean-constant select cleanup.
- The arbitrary-value shape with an effectful call condition to `(select B A (call ...))`, preserving the condition effect.

## Starshine change

`src/passes/optimize_instructions.mbt` now recognizes a direct `i32.eqz` condition in `optimize_instructions_try_fold_const_select(...)` before the existing boolean-constant arm and constant-condition cases:

- exact `1/0` arms compose directly to `i32.eqz(inner_condition)`,
- exact `0/1` arms compose directly to `i32.ne(inner_condition, 0)`,
- otherwise the pass rebuilds the select with the two value arms swapped and the inner condition as the select condition.

The rewrite preserves the inner condition operand, including effectful call operands, and does not move either value arm across the condition; it only removes the direct condition negation by swapping the already-selected arms.

## Test evidence

Added red-first HOT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions removes eqz from select conditions by swapping arms`

Before implementation, the focused test failed because Starshine kept the original `42/13` arm order under a root `Select`; after implementation it passed and the boolean-constant case folded to `i32.eqz(local.get)`.

## Boundaries

This is deliberately narrow. It does not claim:

- broader condition normalization beyond a direct `i32.eqz` select condition,
- branch-condition rewrites,
- arbitrary boolean algebra,
- non-select ternary rewrites,
- or any new movement of trapping/effectful value arms across the condition.

OI-F remains open for broader Binaryen boolean/select/ternary behavior.
