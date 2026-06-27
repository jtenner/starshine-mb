# OptimizeInstructions OI-F identical float local-const select arms with effectful conditions

Date: 2026-06-26

## Slice

This slice extends Starshine `optimize-instructions` identical-arm `select` folding for effectful conditions from direct-local float unary and same-ordered local/local float binary shells to same-ordered local/constant f32/f64 binary shells.

Binaryen `version_130` direct `--optimize-instructions` folds:

- `select(f32.add(local.get x, f32.const 2.5), f32.add(local.get x, f32.const 2.5), call $effect)`
- `select(f64.min(local.get x, f64.const 3.5), f64.min(local.get x, f64.const 3.5), call $effect)`

into `drop(call $effect)` followed by the single surviving float binary expression.

## Oracle evidence

Probe: `.tmp/oi-select-identical-float-localconst-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-float-localconst-effectful-condition-probe.wat -o .tmp/oi-select-identical-float-localconst-effectful-condition-probe.out.wat
```

Observed output removed both `select` instructions and kept the surviving `f32.add` and `f64.min` expressions, each preceded by a dropped `call $effect`.

## Starshine change

Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful condition when folding identical float local-const select arms`

Before implementation, the focused test failed because Starshine kept the first `select` instead of preserving the condition as a dropped prefix and folding to the single float local/constant arm.

Implementation extends `optimize_instructions_select_arms_are_identical_nontrapping_reorderable(...)` in `src/passes/optimize_instructions.mbt` to accept the existing direct `f32` and `f64` local/constant binary identical-arm predicates.

## Safety argument

The effectful-condition path moves the surviving identical arm after the dropped condition. This slice is intentionally limited to same-instruction, same-ordered float binary shells whose operands are direct `local.get` and literal constants. The surviving expression cannot trap and cannot observe the condition's call/global side effects, so preserving `drop(condition)` before the surviving arm matches Binaryen's behavior for the probed shape.

## Validation

- Binaryen oracle probe passed; output had `selects: 0`, and the folded bodies contained one surviving `f32.add` and one surviving `f64.min` expression.
- Red-first focused Moon test failed before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*float local-const select arms*'` reported `0/1`.
- After implementation, the same focused test passed `1/1`.

## Retained boundaries

This is not a broad arbitrary-expression equality proof and does not cover commuted operands, value-equivalent float constants, NaN/algebraic reasoning, SIMD algebraic equality, lane-equivalent vector spelling, trapping integer div/rem, trapping conversions, or broad expression-arm reordering across effectful conditions.
