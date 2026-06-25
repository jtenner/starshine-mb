# OptimizeInstructions OI-D i64 dynamic shift maxBits boundary

Date: 2026-06-25

## Summary

This boundary slice extends the existing dynamic-shift `maxBits` keep-spelling coverage from i32 to i64. Binaryen `version_130` keeps an unsigned comparison over a masked value shifted by a dynamic i64 amount, while folding the otherwise identical constant-zero shift sibling.

Starshine now has focused HOT coverage proving it also keeps the dynamic i64 shift shape. This is not red-first implementation work; it is source-backed status coverage that prevents accidental overgeneralization of the current constant-shift `maxBits` proof.

## Binaryen oracle

Probe: `.tmp/oi-d-i64-dynamic-shr-maxbits-boundary-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-i64-dynamic-shr-maxbits-boundary-probe.wat -o -
```

Observed Binaryen behavior:

- `$dynamic` keeps `i64.lt_u(i64.shr_u(i64.and(local.get $x, 255), local.get $s), 256)`.
- `$zero` folds the constant-zero shift variant to `i32.const 1`.

## Starshine coverage

Added `optimize-instructions keeps i64 dynamic unsigned-shift masked maxBits boundary` in `src/passes/optimize_instructions_test.mbt`.

The test constructs the direct HOT shape and asserts that the root remains a compare with exact instruction `i64.lt_u`, and that the left child remains an exact `i64.shr_u`.

## Classification

Boundary/status slice, not an implementation slice.

The existing Starshine `maxBits` fold is deliberately limited to source-backed constant shifts and other covered producers. Dynamic shift amounts may be provable in some masked cases, but this Binaryen `version_130` probe keeps the i64 dynamic form, so Starshine should not widen this behavior without a separate source-backed proof and Starshine-win justification.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-i64-dynamic-shr-maxbits-boundary-probe.wat -o -` passed and produced the observed keep/fold split.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i64 dynamic unsigned-shift masked maxBits boundary*'` passed `1/1`.

## Remaining work

Full Binaryen LocalScanner behavior remains open, including CFG/phi/select facts, broader recursive producers, exact wrap ranges beyond the first subset, and any dynamic-shift range reasoning that is explicitly accepted as a deliberate Starshine win.
