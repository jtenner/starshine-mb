# Optimize-instructions OI-F identical float conversion effectful condition select arms

## Slice

This OI-F coverage/status slice makes the effectful-condition identical select-arm behavior explicit for nontrapping float conversion unary shells.

The implementation was already covered by the existing f32/f64 unary local-shell identical-arm helpers and the effectful-condition nontrapping reorderable subset. This slice adds direct Binaryen oracle evidence and focused Starshine coverage so future work does not confuse these nontrapping conversion/promote/demote/reinterpret shells with trapping truncation cleanup or arbitrary conversion-tree equality.

## Binaryen oracle

Probe: `.tmp/oi-select-identical-float-conversion-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-float-conversion-effectful-condition-probe.wat -o .tmp/oi-select-identical-float-conversion-effectful-condition-probe.out.wat
```

Result: passed. Binaryen `version_130` removed both `select` instructions for identical `f32.convert_i32_s(local.get)` and `f64.promote_f32(local.get)` arms, preserved each effectful condition as `(drop (call $effect))`, and emitted the surviving conversion arm after the dropped condition.

## Starshine coverage

Files:

- `src/passes/optimize_instructions_test.mbt`

Focused test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*float conversion select arms*'
```

Result: passed `1/1`.

The test covers `f32.convert_i32_s(local.get)` and `f64.promote_f32(local.get)` under an effectful call condition and expects Starshine to build a block that drops the condition before the surviving conversion arm.

## Boundaries

This is coverage/status evidence, not a new implementation slice. The covered behavior is limited to identical, same-instruction, direct-local, nontrapping f32/f64 unary conversion shells already admitted by Starshine's nontrapping reorderable identical-arm predicate.

This does not claim:

- trapping `i32.trunc_f32_*`, `i32.trunc_f64_*`, `i64.trunc_f32_*`, or `i64.trunc_f64_*` cleanup;
- commuted operands or arbitrary structural expression equality;
- nested conversion-tree equality;
- value-equivalent float constants, NaN payload equivalence, or float algebraic equality;
- SIMD conversion or lane-equivalent vector spellings.
