# OptimizeInstructions OI-F identical ref.i31 select arms with effectful conditions

## Summary

Starshine now folds a narrow source-backed OI-F family where both `select` arms are the same nontrapping `ref.i31` shell and the condition is effectful. Binaryen `version_130` drops the condition for effects, removes the `select`, and keeps one copy of the `ref.i31` expression.

Covered shells are direct `ref.i31(local.get)`, `ref.i31(i32.const)`, and the already-covered nontrapping i32 local/constant and unary payload spellings admitted by Starshine's side-effect-free identical-arm predicate.

## Oracle evidence

Probe: `.tmp/oi-select-identical-refi31-effectful-condition-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-refi31-effectful-condition-probe.wat -o .tmp/oi-select-identical-refi31-effectful-condition-probe.out.wat
```

Result: passed. The Binaryen output contains no `select` instructions and preserves each `(drop (call $effect))` before the surviving `ref.i31` expression.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions preserves effectful condition when folding identical ref.i31 select arms`.
- The focused test failed before implementation (`0/1`) because Starshine kept the `select`.
- Extended the effectful-condition identical-arm predicate in `src/passes/optimize_instructions.mbt` to admit nontrapping `ref.i31` shells whose payloads are local, constant, nontrapping local/constant i32 binary, or direct i32 unary local forms.

## Boundaries

This is not arbitrary reference expression equality. It intentionally excludes trapping payloads, commuted or algebraically equivalent payloads beyond the named same-order local/constant helpers, broader structural expression equality, and any reference/GC operation whose evaluation could trap or observe side effects.

## Validation

- Binaryen oracle command above passed.
- Red-first focused test failed before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 select arms*'` (`0/1`).
- Focused test passed after implementation: same command (`1/1`).
