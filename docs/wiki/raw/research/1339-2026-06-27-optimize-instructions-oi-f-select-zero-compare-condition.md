# OptimizeInstructions OI-F select zero-compare condition cleanup

Date: 2026-06-27

## Scope

This slice narrows one Binaryen `OptimizeInstructions` boolean/select parity gap: direct `i32.eq` / `i32.ne` zero comparisons used as `select` conditions.

Binaryen `version_130` was probed with:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-zero-compare-probe.wat -o .tmp/oi-select-zero-compare-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-zero-compare-effect-probe.wat -o .tmp/oi-select-zero-compare-effect-probe.out.wat
```

The oracle rewrote:

- `(select A B (i32.eq cond 0))` to `(select B A cond)` for arbitrary i32 values.
- `(select A B (i32.ne cond 0))` to `(select A B cond)` for arbitrary i32 values.
- Exact boolean `1/0` arms with an `eq zero` condition to `i32.eqz(cond)`.
- Effectful call-backed `eq zero` / `ne zero` conditions by preserving the call as the new select condition after dropping the redundant zero comparison.

## Starshine change

`src/passes/optimize_instructions.mbt` now recognizes direct `i32.eq` / `i32.ne` zero condition shells in `optimize_instructions_try_fold_const_select(...)`:

- `i32.eq(inner, 0)` and `i32.eq(0, inner)` invert the condition by swapping select arms, matching the existing direct `i32.eqz` condition semantics.
- `i32.ne(inner, 0)` and `i32.ne(0, inner)` keep the original select arms and replace the condition with `inner`.
- Exact `1/0` and `0/1` boolean arms compose directly to `i32.eqz(inner)` or `i32.ne(inner, 0)` as appropriate.

The rewrite preserves the inner condition operand, including effectful call operands, and does not move value arms across the condition.

## Test evidence

Added red-first HOT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions removes zero compares from select conditions`

Before implementation, the focused test failed on the `i32.ne(local.get, 0)` condition because Starshine kept the compare as the select condition. After implementation, the focused test passed for value-arm `eq zero`, value-arm `ne zero`, boolean-arm composition, and effectful call-backed `ne zero` conditions.

## Boundaries

This is deliberately narrow. It does not claim:

- arbitrary compare constants beyond literal zero,
- non-i32 condition compares,
- broader condition normalization,
- branch-condition rewrites,
- arbitrary boolean algebra,
- non-select ternary rewrites,
- or any new movement of trapping/effectful value arms across the condition.

OI-F remains open for broader Binaryen boolean/select/ternary behavior.
