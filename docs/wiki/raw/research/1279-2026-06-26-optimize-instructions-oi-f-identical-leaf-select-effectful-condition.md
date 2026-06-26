# OptimizeInstructions OI-F Identical Leaf Select Arms With Effectful Conditions

Date: 2026-06-26

## Summary

Binaryen `version_130` `--optimize-instructions` folds `select(x, x, condition)` for direct identical nontrapping leaf arms even when the condition has effects or can trap, preserving the condition as a dropped prefix before the selected value.

This slice adds the same narrow Starshine behavior for identical direct leaf arms (`local.get`, `global.get`, constants, `ref.null`, and `ref.func`) only. It intentionally does not generalize to trapping expression arms, arbitrary structural equality, commuted/algebraic equality, or broader expression-arm reordering across effectful conditions.

## Oracle evidence

Probes: `.tmp/oi-select-identical-arms-effectful-condition-probe.wat` and `.tmp/oi-select-identical-leaf-trapping-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-arms-effectful-condition-probe.wat -o .tmp/oi-select-identical-arms-effectful-condition-probe.out.wat
```

Observed Binaryen output removed all `select` occurrences for local, global, and `i32.add(local.get, local.get)` identical-arm cases while preserving each condition call as `drop(call $effect)`. Follow-up counts showed `select count: 0` and `call $effect count: 3`. A separate trapping-condition probe with an `i32.load` condition also lowered to `drop(i32.load(...)); local.get`.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt` for identical local leaf arms with an effectful call condition. The fixed test failed before implementation (`0/1`) because Starshine kept the `select`, then passed after implementation (`1/1`).
- Updated `src/passes/optimize_instructions.mbt` so the existing identical-arm select cleanup preserves an effectful or trapping condition as `drop(condition); arm` when both arms are identical direct nontrapping leaf nodes and both condition/arm are single-result.

## Boundaries

This is deliberately narrower than Binaryen's observed expression-arm output. It does not fold identical binary/unary expression arms across effectful conditions yet, because expression arms can include trapping operations and reordering the dropped condition before them would be unsound without a stronger nontrapping proof and fresh tests. The existing trapping-condition boundary remains relevant for non-leaf expression arms.

## Validation

- Binaryen oracle command above passed.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*effectful condition*'` failed before implementation and passed after implementation; full pass tests also required updating the old trapping-condition boundary to the Binaryen-shaped `drop(condition); arm` leaf behavior.

Full slice validation is recorded in the commit that references this note.
