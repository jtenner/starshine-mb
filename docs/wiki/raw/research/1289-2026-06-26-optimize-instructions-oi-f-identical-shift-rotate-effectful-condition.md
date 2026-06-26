# OptimizeInstructions OI-F Identical Shift/Rotate Select Arms With Effectful Conditions

Date: 2026-06-26

## Summary

Binaryen `version_130` `--optimize-instructions` folds identical ordered-local integer shift/rotate select arms even when the condition is effectful, preserving that condition as a dropped prefix before the surviving shift/rotate expression.

This slice extends Starshine's narrow nontrapping effectful-condition select fold from identical ordered-local integer add/mul/bitwise arms to sibling `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr` and `i64.shl` / `i64.shr_s` / `i64.shr_u` / `i64.rotl` / `i64.rotr` shells with the same ordered locals. It intentionally does not generalize to trapping div/rem, commuted operands, arbitrary expression equality, float algebraic equality, SIMD equality, or expression arms that may observe/reorder effects.

## Oracle evidence

Probe: `.tmp/oi-select-identical-shift-rotate-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-shift-rotate-effectful-condition-probe.wat -o .tmp/oi-select-identical-shift-rotate-effectful-condition-probe.out.wat
```

Observed Binaryen output removed both `select` instructions, preserved each `call $effect` as a dropped prefix, then emitted one `i32.shl(local.get, local.get)` and one `i64.rotr(local.get, local.get)` for the two exported probes.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt` for identical ordered-local `i32.shl` and `i64.rotr` select arms with an effectful call condition. The test failed before implementation (`0/1`) because Starshine kept the first `select`, then passed after implementation (`1/1`).
- Extended `optimize_instructions_select_arms_are_identical_nontrapping_reorderable(...)` in `src/passes/optimize_instructions.mbt` to accept identical ordered-local i32/i64 shift/rotate arms for the existing effectful/trapping-condition preservation path.

## Soundness boundary

The rewrite changes evaluation order from `arm, arm, condition, select` to `condition, arm`. That is only sound for an arm shell that is pure, nontrapping, and cannot observe the condition's effects. The implemented shells read only locals and perform integer shifts/rotates. WebAssembly masks shift/rotate counts, so these shells do not trap on large counts, and calls/global/memory changes in the condition cannot alter their local operands. Trapping integer div/rem remain intentionally unimplemented because they can trap; broader structural equality remains open until each candidate has an equivalent proof and fresh oracle tests.

## Validation

- Binaryen oracle command above passed.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*shift and rotate select arms*'` failed before implementation and passed after implementation.

Full slice validation is recorded in the commit that references this note.
