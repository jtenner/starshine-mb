# OptimizeInstructions OI-F Identical Integer Compare Select Arms With Effectful Conditions

Date: 2026-06-26

## Summary

Binaryen `version_130` `--optimize-instructions` folds identical ordered-local integer compare select arms even when the condition is effectful, preserving that condition as a dropped prefix before the surviving compare expression.

This slice extends Starshine's narrow nontrapping effectful-condition select fold to sibling i32/i64 integer compare shells over the same ordered locals. It intentionally does not generalize to trapping conversions, float compare equivalence, broad NaN equality, commuted operands, arbitrary structural equality, SIMD equality, or expression arms that may observe/reorder effects.

## Oracle evidence

Probe: `.tmp/oi-select-identical-int-compare-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-int-compare-effectful-condition-probe.wat -o .tmp/oi-select-identical-int-compare-effectful-condition-probe.out.wat
```

Observed Binaryen output removed both `select` instructions, preserved each effectful call as a dropped prefix, then emitted one `i32.lt_s(local.get, local.get)` and one `i64.ge_u(local.get, local.get)` for the two probes.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt` for identical ordered-local `i32.lt_s` and `i64.ge_u` select arms with an effectful call condition. The test failed before implementation (`0/1`) because Starshine kept the first `select`, then passed after implementation (`1/1`).
- Extended `optimize_instructions_select_arms_are_identical_nontrapping_reorderable(...)` in `src/passes/optimize_instructions.mbt` to accept identical ordered-local i32/i64 compare arms for the existing effectful-condition preservation path.

## Soundness boundary

The rewrite changes evaluation order from `arm, arm, condition, select` to `condition, arm`. That is only sound for an arm shell that is pure, nontrapping, and cannot observe the condition's effects. The implemented shells read only locals and perform integer compares, which cannot trap and cannot observe calls, globals, or memory changed by the condition. Trapping conversions and broader expression equality remain open until each candidate has an equivalent proof and fresh oracle tests.

## Validation

- Binaryen oracle command above passed and showed `selects: 0`, `i32.lt_s: 1`, and `i64.ge_u: 1`.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*integer compare select arms*'` failed before implementation and passed after implementation.

Full slice validation is recorded in the commit that references this note.
