# OptimizeInstructions OI-F Identical I64 Add Select Arms With Effectful Conditions

Date: 2026-06-26

## Summary

Binaryen `version_130` `--optimize-instructions` folds identical ordered-local `i64.add` select arms even when the condition is effectful, preserving that condition as a dropped prefix before the selected arithmetic expression.

This slice extends Starshine's narrow nontrapping effectful-condition select fold from identical `i32.add(local.get, local.get)` arms to the sibling `i64.add(local.get, local.get)` shell with the same ordered locals. It intentionally does not generalize to trapping integer div/rem, commuted operands, arbitrary expression equality, float algebraic equality, SIMD equality, or expression arms that may observe/reorder effects.

## Oracle evidence

Probe: `.tmp/oi-select-identical-i64-add-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-i64-add-effectful-condition-probe.wat -o .tmp/oi-select-identical-i64-add-effectful-condition-probe.out.wat
```

Observed Binaryen output removed the `select`, preserved one `call $effect` as a dropped prefix, then emitted the single `i64.add(local.get, local.get)`. Follow-up counts showed `select count: 0`, `call $effect count: 1`, and `i64.add count: 1`.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt` for identical ordered-local `i64.add` select arms with an effectful call condition. The test failed before implementation (`0/1`) because Starshine kept the `select`, then passed after implementation (`1/1`).
- Extended `optimize_instructions_select_arms_are_identical_nontrapping_reorderable(...)` in `src/passes/optimize_instructions.mbt` to accept identical ordered-local `i64.add` arms for the existing effectful/trapping-condition preservation path.

## Soundness boundary

The rewrite changes evaluation order from `arm, arm, condition, select` to `condition, arm`. That is only sound for an arm shell that is pure, nontrapping, and cannot observe the condition's effects. The implemented shell reads only locals and performs `i64.add`, so calls/global/memory changes in the condition cannot alter the result. Integer div/rem remain intentionally unimplemented because they can trap; broader structural equality remains open until each candidate has an equivalent proof and fresh oracle tests.

## Validation

- Binaryen oracle command above passed.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*identical i64.add select arms*'` failed before implementation and passed after implementation.

Full slice validation is recorded in the commit that references this note.
