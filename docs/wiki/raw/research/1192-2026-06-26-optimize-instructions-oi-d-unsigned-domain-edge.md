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

# OptimizeInstructions OI-D unsigned domain-edge compare folding

## Question

Does Binaryen `version_130` fold unsigned integer comparisons whose constant endpoint is the minimum or maximum unsigned value, and can Starshine safely cover that narrow scalar parity gap while preserving operand effects?

## Evidence

Probe: `.tmp/oi-d-unsigned-domain-boundary-probe.wat`

```wat
(module
  (func $i32_gt_max (param i32) (result i32) local.get 0 i32.const -1 i32.gt_u)
  (func $i32_le_max (param i32) (result i32) local.get 0 i32.const -1 i32.le_u)
  (func $i32_lt_zero (param i32) (result i32) local.get 0 i32.const 0 i32.lt_u)
  (func $i32_ge_zero (param i32) (result i32) local.get 0 i32.const 0 i32.ge_u)
  (func $i64_gt_max (param i64) (result i32) local.get 0 i64.const -1 i64.gt_u)
  (func $i64_le_max (param i64) (result i32) local.get 0 i64.const -1 i64.le_u)
  (func $i64_lt_zero (param i64) (result i32) local.get 0 i64.const 0 i64.lt_u)
  (func $i64_ge_zero (param i64) (result i32) local.get 0 i64.const 0 i64.ge_u))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-unsigned-domain-boundary-probe.wat -o -
```

Observed Binaryen output folds `x >_u UINT_MAX` and `x <_u 0` to `i32.const 0`, and folds `x <=_u UINT_MAX` and `x >=_u 0` to `i32.const 1`, for both i32 and i64 operands.

A second effect probe, `.tmp/oi-d-unsigned-domain-effect-probe.wat`, shows Binaryen preserves effectful operands with `drop(call)` before the folded boolean constant.

## Starshine coverage

Added red-first coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds unsigned domain-edge compares`

The focused test failed before implementation because Starshine kept `i32.gt_u(local.get 0, i32.const -1)`. The implementation adds `optimize_instructions_try_fold_unsigned_domain_edge_compare`, which handles only unsigned relational comparisons against the exact unsigned-domain endpoints (`0` and all-ones) and preserves effectful/trapping left operands with `drop(lhs); i32.const result`.

## Classification

Parity implementation slice. This narrows OI-D scalar compare behavior for domain-edge unsigned comparisons without claiming broad constant relational folding or general range analysis beyond the proven endpoint cases.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-unsigned-domain-boundary-probe.wat -o -` passed and showed the unsigned endpoint folds.
- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-unsigned-domain-effect-probe.wat -o -` passed and showed operand-effect preservation via `drop`.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*unsigned domain-edge compares*'` failed before implementation, then passed `1/1` after implementation.
