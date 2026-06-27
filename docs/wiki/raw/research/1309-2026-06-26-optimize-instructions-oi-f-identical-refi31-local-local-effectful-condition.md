# OptimizeInstructions OI-F identical ref.i31 local-local payloads with effectful conditions

## Summary

Starshine now folds the next narrow OI-F `ref.i31` identical-arm family where both `select` arms are the same nontrapping `ref.i31` shell whose i32 payload is a same-ordered local/local integer operation and the condition is effectful. Binaryen `version_130` drops the condition for effects, removes the `select`, and keeps one copy of the `ref.i31(i32.add(local.get, local.get))` expression.

Covered payload shells are the existing same-ordered nontrapping i32 local/local helpers: add/sub/mul, bitwise and/or/xor, shift/rotate, and integer compare. This extends both the side-effect-free identical-arm predicate for `ref.i31` payloads and the effectful-condition reorderable subset needed to move the surviving arm after the dropped condition.

## Oracle evidence

Probe: `.tmp/oi-select-identical-refi31-local-local-effectful-condition-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-refi31-local-local-effectful-condition-probe.wat -o .tmp/oi-select-identical-refi31-local-local-effectful-condition-probe.out.wat
```

Result: passed. The Binaryen output contains no `select`, preserves `(drop (call $effect))`, and keeps one `ref.i31` wrapping the local/local `i32.add` payload.

## Starshine change

- Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt` under `optimize-instructions preserves effectful condition when folding identical ref.i31 select arms` for `ref.i31(i32.add(local.get 0, local.get 1))` arms.
- The focused test failed before implementation (`0/1`) because Starshine kept the `select`.
- Extended `src/passes/optimize_instructions.mbt` so `ref.i31` identical-arm matching admits same-ordered nontrapping i32 local/local payload shells in both the pure identical-arm predicate and the effectful-condition reorderable predicate.

## Boundaries

This remains a same-instruction, same-ordered-local proof. It does not claim commuted operands, algebraically equivalent payloads, trapping integer div/rem payloads, arbitrary reference expression equality, SIMD lane-equivalent spellings, or broader expression reordering across effectful conditions.

## Validation

- Binaryen oracle command above passed.
- Red-first focused test failed before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 select arms*'` (`0/1`).
- Focused test passed after implementation: same command (`1/1`).
