# Optimize Instructions OI-D i32.wrap_i64 MaxBits Facts

Date: 2026-06-25

## Question

Does Binaryen `version_130` use `Bits::getMaxBits`-style facts through `i32.wrap_i64`, and should Starshine cover the narrow nonnegative subset?

## Oracle probe

Probe: `.tmp/oi-d-wrap-maxbits-probe.wat`

```wat
(module
  (func (param $x i64) (result i32)
    local.get $x
    i64.const 255
    i64.and
    i32.wrap_i64
    i32.const 256
    i32.lt_u)
  (func (param $x i64) (result i32)
    (local $n i32)
    local.get $x
    i64.const 255
    i64.and
    i32.wrap_i64
    local.set $n
    local.get $n
    i32.const 128
    i32.lt_s))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-wrap-maxbits-probe.wat -o -
```

Observed Binaryen output:

- The direct `i32.wrap_i64(i64.and(x, 255)) <_u 256` comparison folds to `i32.const 1`.
- The local-carried `i32.lt_s(local.get n, 128)` spelling rewrites to `i32.lt_u` after `n` is assigned from the wrapped masked i64 value.

## Starshine slice

Extended Starshine's narrow unsigned max fact helper in `src/passes/optimize_instructions.mbt` so an `i32.wrap_i64` expression inherits an i32 unsigned max fact when the wrapped i64 producer has a proven nonnegative max no larger than `i32::MAX`. This intentionally avoids claiming facts for wider i64 maxima where truncation can produce the full i32 unsigned range.

Added focused public-pipeline coverage in `src/passes/optimize_instructions_test.mbt` with `optimize-instructions folds i32.wrap_i64 unsigned maxBits compares`. The test failed before implementation because Starshine kept the direct unsigned compare and the local-carried signed spelling; it passed after the `i32.wrap_i64` fact producer was added.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-wrap-maxbits-probe.wat -o -` passed and showed the fold/spelling rewrite described above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i32.wrap_i64 unsigned maxBits*'` failed before implementation and passed `1/1` after implementation.

Full required slice validation is recorded in the commit that cites this note.

## Remaining work

This is not a full `i32.wrap_i64` range analysis. Remaining OI-D/maxBits gaps include wrap facts for exactly characterized wider i64 ranges, CFG/phi/select facts, dynamic/zero shifts, broader producer families, signed range facts beyond the existing nonnegative subset, and broader Binaryen `LocalScanner` behavior.
