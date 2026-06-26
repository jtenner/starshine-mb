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

# OptimizeInstructions OI-D constant integer eq/ne compare folding

## Question

Does Binaryen `version_130` fold integer equality and inequality compares with two constant operands under direct `--optimize-instructions`, and can Starshine safely cover that narrow scalar parity gap?

## Evidence

Probe: `.tmp/oi-d-int-const-compare-probe.wat`

```wat
(module
  (func (export "f") (result i32 i32 i32 i32 i32 i32 i32 i32)
    i32.const 7 i32.const 7 i32.eq
    i32.const 7 i32.const 8 i32.ne
    i32.const -1 i32.const 0 i32.lt_s
    i32.const -1 i32.const 0 i32.gt_u
    i64.const 7 i64.const 7 i64.eq
    i64.const 7 i64.const 8 i64.ne
    i64.const -1 i64.const 0 i64.lt_s
    i64.const -1 i64.const 0 i64.gt_u))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-int-const-compare-probe.wat -o -
```

Observed Binaryen output folds the `i32.eq`, `i32.ne`, `i64.eq`, and `i64.ne` constant pairs to `i32.const 0/1`. The signed relational pairs are kept, and the unsigned-top greater-than pairs are canonicalized to `ne` rather than folded directly to constants in the observed output.

## Starshine coverage

Added red-first coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds integer eq/ne constant compares`

The focused test failed before implementation because Starshine kept the first constant `i32.eq` compare. The implementation adds `optimize_instructions_try_fold_integer_const_eq_ne_compare`, which folds only integer `eq` / `ne` with two same-width constant operands and returns an `i32.const` boolean result. It intentionally does not generalize to signed or unsigned relational constant compares in this slice because the observed Binaryen probe does not directly fold those spellings.

## Classification

Parity implementation slice. This narrows OI-D default scalar compare parity for a direct, side-effect-free, fully constant integer surface without claiming broader relational-constant folding.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-int-const-compare-probe.wat -o -` passed and showed the eq/ne folds plus relational keep/canonicalization boundary.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*integer eq/ne constant compares*'` failed before implementation, then passed `1/1` after implementation.
