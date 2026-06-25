# OptimizeInstructions OI-D maxBits signed relational folds

## Summary

Starshine now extends the narrow direct `maxBits` compare folder from equality/unsigned-relational out-of-range tests to signed relational tests when the proven value range is nonnegative and bounded.

The covered subset includes direct i32/i64 `and` masks, recursive direct `shr_u` facts, and direct unsigned load width facts already recognized by `optimize_instructions_i32_unsigned_max(...)` / `optimize_instructions_i64_unsigned_max(...)`. Effectful or trapping operands are preserved as `drop(lhs); i32.const result` before replacing the compare.

## Binaryen oracle

Probe: `.tmp/oi-d-maxbits-signed-rel-probe.wat`.

Observed with:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-maxbits-signed-rel-probe.wat -o -
```

Findings:

- `i32.gt_s((x & 255), 300)` folds to `i32.const 0`.
- `i32.le_s(i32.load8_u(ptr), 300)` folds to `drop(i32.load8_u(ptr)); i32.const 1`, preserving the trapping load.
- Binaryen rewrites some non-folding signed forms such as `lt_s(..., 0)` / `ge_s(..., 0)` to unsigned spelling instead of immediately replacing them with constants. This Starshine slice only claims the out-of-range constant-result subset.

## Starshine changes

- Added red-first focused test `optimize-instructions folds unsigned maxBits signed compares` in `src/passes/optimize_instructions_test.mbt`.
- Extended `optimize_instructions_i32_masked_unsigned_compare_result(...)` and `optimize_instructions_i64_masked_unsigned_compare_result(...)` to return constants for signed relational comparisons whose RHS is outside the proven nonnegative bounded range.
- Reused the existing drop-then-const replacement path, so trapping loads and effectful bounded expressions remain evaluated before the folded result.

## Validation

- Red-first focused test failed before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*unsigned maxBits signed compares*'`.
- The same focused test passed after implementation (`1/1`).

## Remaining work

This is still narrower than Binaryen's full `LocalScanner` behavior. Open OI-D work includes CFG/phi/select width facts, local-carried `maxBits`, signed range facts beyond this nonnegative direct subset, and signed-to-unsigned compare spelling canonicalization for non-folding boundary cases.
