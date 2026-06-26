# OptimizeInstructions OI-D signed constant relational boundary

Date: 2026-06-26

## Slice

Boundary/status-only OI-D coverage for signed relational constant pairs in `optimize-instructions`.

## Binaryen oracle

Fresh local probe: `.tmp/oi-d-signed-rel-next-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-signed-rel-next-probe.wat -o -
```

Observed `version_130` behavior is mixed, not a uniform constant fold:

- `i32.lt_s (i32.const -2) (i32.const 1)` canonicalizes to `i32.le_s ... (i32.const 0)`.
- `i64.lt_s (i64.const -2) (i64.const 1)` canonicalizes to `i64.le_s ... (i64.const 0)`.
- Some sign-disjoint false/true cases fold directly to `i32.const 0/1`, such as `2 < -1`, `7 <= -3`, `3 > -4`, and `-5 >= -5`.
- Other signed false cases remain signed compares, such as `-5 > 5` and `-6 >= 0`.

This supports keeping the previous unsigned-relational implementation narrow. Do not generalize signed relational constant folding without a source-backed rule for Binaryen's mixed canonicalize/fold/keep behavior.

## Starshine coverage

Added `optimize-instructions keeps signed constant relational mixed boundary` in `src/passes/optimize_instructions_test.mbt`.

The test is intentionally status/boundary coverage, not red-first implementation work:

- locks the existing `i32.lt_s -2 1` canonicalization to `i32.le_s -2 0`, matching the Binaryen zero-compare spelling;
- locks an `i64.gt_s -5 5` keep-spelling boundary, preventing accidental broad signed-constant folding while the exact Binaryen rule remains open.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-signed-rel-next-probe.wat -o -` passed and produced the mixed behavior summarized above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*signed constant relational mixed boundary*'` passed `1/1`.

## Status

This slice narrows and documents the signed-relational constant boundary after the unsigned constant relational fold. It is not parity for all signed relational constant pairs. Remaining work: source-backed classification or implementation for the Binaryen-folded signed constant subfamily, without over-folding the canonicalized/kept subfamilies.
