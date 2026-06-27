# OptimizeInstructions OI-F identical float-unary select arms with effectful conditions

Date: 2026-06-26

## Slice

This slice extends Starshine `optimize-instructions` identical-arm `select` folding for effectful conditions from same-ordered local/local float binary shells to direct-local f32/f64 unary shells.

Binaryen `version_130` direct `--optimize-instructions` folds:

- `select(f32.abs(local.get x), f32.abs(local.get x), call $effect)`
- `select(f64.sqrt(local.get x), f64.sqrt(local.get x), call $effect)`

into `drop(call $effect)` followed by the single surviving float unary expression.

## Oracle evidence

Probe: `.tmp/oi-select-identical-float-unary-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-float-unary-effectful-condition-probe.wat -o .tmp/oi-select-identical-float-unary-effectful-condition-probe.out.wat
```

Observed output removed both `select` instructions and kept exactly one `f32.abs` and one `f64.sqrt`, each preceded by a dropped `call $effect`.

## Starshine change

Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful condition when folding identical float unary select arms`

Before implementation, the focused test failed because Starshine kept the first `select` instead of preserving the condition as a dropped prefix and folding to the single float unary arm.

Implementation extends `optimize_instructions_select_arms_are_identical_nontrapping_reorderable(...)` in `src/passes/optimize_instructions.mbt` to accept the existing direct-local `f32` and `f64` unary identical-arm predicates.

## Safety argument

The effectful-condition path moves the surviving identical arm after the dropped condition. This slice is intentionally limited to float unary shells over direct `local.get` children. The surviving expression cannot trap and cannot observe the condition's call/global side effects, so preserving `drop(condition)` before the surviving arm matches Binaryen's behavior for the probed shape.

## Validation

- Binaryen oracle probe passed; output had `selects: 0`, `f32.abs: 1`, and `f64.sqrt: 1`.
- Red-first focused Moon test failed before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*float unary select arms*'` reported `0/1`.
- After implementation, the same focused test passed `1/1`.

## Retained boundaries

This is not a broad arbitrary-expression equality proof and does not cover commuted operands, value-equivalent constants, SIMD algebraic equality, lane-equivalent vector spelling, trapping integer div/rem, trapping conversions, or broad expression-arm reordering across effectful conditions.
