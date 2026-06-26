---
kind: research
status: supported
date: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-D i64.extend_i32_u narrowed maxBits propagation

## Question

Does Binaryen propagate a narrower unsigned `maxBits` fact through `i64.extend_i32_u` when the i32 operand is already proven small?

## Evidence

Probe: `.tmp/oi-d-i64-extend-i32-u-masked-narrow-probe.wat`

```wat
(module
  (func (param $x i32) (result i32)
    local.get $x
    i32.const 255
    i32.and
    i64.extend_i32_u
    i64.const 300
    i64.gt_s)
  (func (param $x i32) (result i32)
    local.get $x
    i32.const 255
    i32.and
    i64.extend_i32_u
    i64.const 128
    i64.lt_s))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-i64-extend-i32-u-masked-narrow-probe.wat -o -
```

Binaryen `version_130` folds the out-of-range `gt_s 300` compare to `i32.const 0` and rewrites the in-range signed comparison to unsigned spelling. That shows `i64.extend_i32_u` is not only a conservative `u32::MAX` producer; it can also preserve a narrower child range fact when the operand already has one.

## Starshine coverage

Extended the red-first public-pipeline test:

- `optimize-instructions folds i64.extend_i32_u unsigned maxBits compares`

The new masked-extension case failed before implementation because Starshine rewrote the comparison to `i64.gt_u` but did not fold it. The implementation now asks the i32 unsigned maxBits helper for the `i64.extend_i32_u` operand first and falls back to `u32::MAX` only when no narrower fact is available.

## Classification

Parity implementation slice. This narrows OI-D `maxBits` producer coverage without changing dynamic-shift boundaries, mixed signed relational constant behavior, or broader CFG/select/phi range scanning.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-i64-extend-i32-u-masked-narrow-probe.wat -o -` passed and folded the masked `i64.extend_i32_u` out-of-range signed comparison to `i32.const 0`.
- Red-first `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i64.extend_i32_u unsigned maxBits*'` failed before implementation, then passed `1/1` after implementation.
