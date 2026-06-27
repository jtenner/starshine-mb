# OptimizeInstructions OI-F Identical Float Compare Select Arms With Effectful Conditions

Date: 2026-06-26

## Summary

Binaryen `version_130` `--optimize-instructions` folds identical ordered-local float compare select arms even when the condition is effectful, preserving that condition as a dropped prefix before the surviving compare expression.

This slice extends Starshine's narrow nontrapping effectful-condition select fold to sibling f32/f64 compare shells over the same ordered locals. It intentionally does not generalize to broad NaN/algebraic equality, commuted operands, value-equivalent constants, arbitrary structural equality, or any expression arm that may trap or observe reordered effects.

## Oracle evidence

Probe: `.tmp/oi-select-identical-float-compare-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-float-compare-effectful-condition-probe.wat -o .tmp/oi-select-identical-float-compare-effectful-condition-probe.out.wat
```

Observed Binaryen output removed both `select` instructions, preserved each effectful call as a dropped prefix, then emitted one `f32.lt(local.get, local.get)` and one `f64.ge(local.get, local.get)` for the two probes.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt` for identical ordered-local `f32.lt` and `f64.ge` select arms with an effectful call condition. The test failed before implementation (`0/1`) because Starshine kept the first `select`, then passed after implementation (`1/1`).
- Extended `optimize_instructions_select_arms_are_identical_nontrapping_reorderable(...)` in `src/passes/optimize_instructions.mbt` to accept identical ordered-local f32/f64 compare arms for the existing effectful-condition preservation path.

## Soundness boundary

The rewrite changes evaluation order from `arm, arm, condition, select` to `condition, arm`. That is only sound for an arm shell that is pure, nontrapping, and cannot observe the condition's effects. The implemented float compare shells read only locals and perform float comparisons, which cannot trap and cannot observe calls, globals, or memory changed by the condition. This is not a broad NaN-equivalence proof: only same-instruction, same-ordered local/local compare shells are accepted.

## Validation

- Binaryen oracle command above passed and showed `selects: 0`, `f32.lt: 1`, and `f64.ge: 1`.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*float compare select arms*'` failed before implementation and passed after implementation.

Full slice validation is recorded in the commit that references this note.
