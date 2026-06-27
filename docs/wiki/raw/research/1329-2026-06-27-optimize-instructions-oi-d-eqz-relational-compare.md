# OptimizeInstructions OI-D eqz relational compare inversion

## Summary

Binaryen `version_130` `--optimize-instructions` rewrites `i32.eqz` around integer relational compare results by inverting the relational opcode while preserving the original operands.

Starshine now matches the covered i32/i64 integer-relational subset:

- `i32.eqz(i32.lt_s(a, b))` -> `i32.ge_s(a, b)`
- `i32.eqz(i64.le_u(a, b))` -> `i64.gt_u(a, b)`
- analogous i32/i64 signed and unsigned `lt`/`le`/`gt`/`ge` inversions.

## Oracle evidence

Probe: `.tmp/oi-compare-eqz-rel-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-compare-eqz-rel-probe.wat -o .tmp/oi-compare-eqz-rel-probe.out.wat
```

Result: passed. Binaryen inverted the local-backed i32 signed `<` shape to `i32.ge_s`, inverted the local-backed i64 unsigned `<=` shape to `i64.gt_u`, and also inverted a call-backed i32 signed `<` shape to `i32.ge_s` while preserving the call operand.

A companion float probe `.tmp/oi-float-compare-eqz-probe.wat` showed Binaryen keeps `i32.eqz(f32.lt(...))` but rewrites `i32.eqz(f64.eq(...))` to `f64.ne(...)`; this slice deliberately excludes NaN-sensitive float relational compares and does not claim float eq/ne cleanup.

## Starshine change

- Added `optimize_instructions_inverted_integer_compare(...)` in `src/passes/optimize_instructions.mbt` for i32/i64 signed and unsigned relational compare inversions.
- Wired the helper into `optimize_instructions_try_fold_eqz(...)` after the existing compare-to-zero eq/ne rewrites so Starshine keeps Binaryen's preferred `eqz(x)` spelling for zero compares.
- Added red-first HOT coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions rewrites eqz on integer compares into inverted compares`.

## Validation

- Binaryen oracle command above passed.
- Red-first focused command before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*integer compares into inverted compares*'` failed because Starshine kept `i32.eqz(i32.lt_s(...))`.
- After implementation: focused `*integer compares into inverted compares*` passed `1/1`.
- Existing focused zero-compare guard `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*zero compare into inverted compare*'` passed `1/1`, proving the new relational inversion did not overwrite the established zero-compare `eqz` spelling.

## Boundaries

This is a narrow OI-D integer-relational cleanup. It does not claim arbitrary boolean algebra, nonzero integer eq/ne inversion, float eq/ne inversion, NaN-sensitive float relational inversion, or compare operand canonicalization beyond preserving the original child order under an inverted opcode.
