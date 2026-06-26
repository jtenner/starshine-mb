# OptimizeInstructions OI-F Identical Integer Bitwise Select Arms With Effectful Conditions

Date: 2026-06-26

## Summary

Binaryen `version_130` `--optimize-instructions` folds identical ordered-local integer bitwise select arms even when the condition is effectful, preserving that condition as a dropped prefix before the surviving bitwise expression.

This slice extends Starshine's narrow nontrapping effectful-condition select fold from identical ordered-local integer `add` / `mul` arms to sibling `i32.and` / `i32.or` / `i32.xor` and `i64.and` / `i64.or` / `i64.xor` shells with the same ordered locals. It intentionally does not generalize to shifts/rotates, trapping div/rem, commuted operands, arbitrary expression equality, float algebraic equality, SIMD equality, or expression arms that may observe/reorder effects.

## Oracle evidence

Probe: `.tmp/oi-select-identical-int-bitwise-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-int-bitwise-effectful-condition-probe.wat -o .tmp/oi-select-identical-int-bitwise-effectful-condition-probe.out.wat
```

Observed Binaryen output removed both `select` instructions, preserved each `call $effect` as a dropped prefix, then emitted one `i32.and(local.get, local.get)` and one `i64.xor(local.get, local.get)` for the two exported probes.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt` for identical ordered-local `i32.and` and `i64.xor` select arms with an effectful call condition. The test failed before implementation (`0/1`) because Starshine kept the first `select`, then passed after implementation (`1/1`).
- Extended `optimize_instructions_select_arms_are_identical_nontrapping_reorderable(...)` in `src/passes/optimize_instructions.mbt` to accept identical ordered-local i32/i64 bitwise arms for the existing effectful/trapping-condition preservation path.

## Soundness boundary

The rewrite changes evaluation order from `arm, arm, condition, select` to `condition, arm`. That is only sound for an arm shell that is pure, nontrapping, and cannot observe the condition's effects. The implemented shells read only locals and perform integer bitwise operations, so calls/global/memory changes in the condition cannot alter the result. Shift/rotate shells are left for separate proof because their shift-count masking and local representation should be audited independently; trapping integer div/rem remain intentionally unimplemented because they can trap; broader structural equality remains open until each candidate has an equivalent proof and fresh oracle tests.

## Validation

- Binaryen oracle command above passed.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*integer bitwise select arms*'` failed before implementation and passed after implementation.

Full slice validation is recorded in the commit that references this note.
