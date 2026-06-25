# Optimize-instructions OI-D i64 sign-extension equality boundary

Date: 2026-06-25

## Summary

This OI-D boundary/status slice locks the observed `i64.extend*_s` equality behavior for direct `--optimize-instructions` parity work. Binaryen `version_130` keeps `i64.extend8_s`, `i64.extend16_s`, and `i64.extend32_s` equality/inequality comparisons even when the compared constant is outside the corresponding signed lane range. Starshine now has public-pipeline coverage proving it also keeps those i64 forms rather than generalizing the covered i32 sign-extension equality fold.

This is coverage/status evidence for existing behavior, not a red-first implementation slice.

## Binaryen oracle

Probe: `.tmp/oi-d-i64-signext-equality-probe.wat`

```wat
(module
  (func (export "e8eq") (param i64) (result i32)
    local.get 0
    i64.extend8_s
    i64.const 128
    i64.eq)
  (func (export "e8ne") (param i64) (result i32)
    local.get 0
    i64.extend8_s
    i64.const 128
    i64.ne)
  (func (export "e16eq") (param i64) (result i32)
    local.get 0
    i64.extend16_s
    i64.const 32768
    i64.eq)
  (func (export "e32eq") (param i64) (result i32)
    local.get 0
    i64.extend32_s
    i64.const 2147483648
    i64.eq))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-i64-signext-equality-probe.wat -o -
```

Observed Binaryen output kept all i64 sign-extension comparisons as written. No out-of-range equality/inequality fold analogous to Starshine's i32 subset was applied.

## Starshine coverage

Added public-pipeline test:

- `optimize-instructions keeps i64 sign-extension equality outside range`

The test asserts that Starshine keeps the `i64.eq` / `i64.ne` comparisons and the underlying `i64.extend8s`, `i64.extend16s`, and `i64.extend32s` operations with their out-of-range constants.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-i64-signext-equality-probe.wat -o -` passed and kept the i64 sign-extension comparisons.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i64 sign-extension equality*'` passed `1/1`.

## Remaining OI-D work

This slice narrows only the i64 sign-extension equality boundary. Remaining scalar/maxBits work still includes broader Binaryen width facts, local-scanner facts beyond the covered fallthrough subset, signed range proofs where Binaryen actually folds, and broader expression-identity coverage beyond direct local operands.
