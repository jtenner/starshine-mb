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

# OptimizeInstructions OI-D unsigned constant relational compare folding

## Question

Does Binaryen `version_130` fold unsigned integer relational comparisons with two constant operands, and can Starshine cover that narrow scalar parity gap without claiming broader signed relational folding?

## Evidence

Probe: `.tmp/oi-d-int-const-rel-probe.wat`

```wat
(module
  (func (export "i32") (result i32 i32 i32 i32 i32 i32 i32 i32)
    (i32.lt_s (i32.const -1) (i32.const 0))
    (i32.lt_u (i32.const -1) (i32.const 0))
    (i32.gt_s (i32.const 7) (i32.const -3))
    (i32.gt_u (i32.const 7) (i32.const -3))
    (i32.le_s (i32.const -5) (i32.const -5))
    (i32.le_u (i32.const -5) (i32.const -5))
    (i32.ge_s (i32.const -6) (i32.const 1))
    (i32.ge_u (i32.const -6) (i32.const 1)))
  (func (export "i64") (result i32 i32 i32 i32 i32 i32 i32 i32)
    (i64.lt_s (i64.const -1) (i64.const 0))
    (i64.lt_u (i64.const -1) (i64.const 0))
    (i64.gt_s (i64.const 7) (i64.const -3))
    (i64.gt_u (i64.const 7) (i64.const -3))
    (i64.le_s (i64.const -5) (i64.const -5))
    (i64.le_u (i64.const -5) (i64.const -5))
    (i64.ge_s (i64.const -6) (i64.const 1))
    (i64.ge_u (i64.const -6) (i64.const 1))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-int-const-rel-probe.wat -o -
```

Observed Binaryen output folds the unsigned relational constant pairs to `i32.const` booleans for both i32 and i64. The same probe shows signed relational constant pairs are mixed: some fold, while others are kept or canonicalized (for example through zero-comparison spellings). This slice therefore covers only unsigned relational constant comparisons.

## Starshine coverage

Added red-first coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds unsigned constant relational compares`

The focused test failed before implementation because Starshine kept an i64 unsigned relational constant compare. The implementation extends the existing constant integer compare helper to fold i32/i64 `lt_u`, `le_u`, `gt_u`, and `ge_u` only when both operands are constants, using unsigned reinterpretation for the comparison and producing the corresponding `i32.const` boolean.

## Classification

Parity implementation slice. This narrows OI-D scalar compare behavior for unsigned relational constant pairs. It does not claim general signed relational constant folding, because the observed Binaryen direct-pass behavior for signed relational constants is not uniform.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-int-const-rel-probe.wat -o -` passed and showed unsigned relational constant folds.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*unsigned constant relational compares*'` failed before implementation, then passed `1/1` after implementation.
