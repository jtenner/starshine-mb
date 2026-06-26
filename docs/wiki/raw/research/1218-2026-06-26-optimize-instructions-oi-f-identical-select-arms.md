---
kind: research
status: supported
last_reviewed: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-F identical pure `select` arms

## Question

Does Binaryen `version_130` `--optimize-instructions` fold `select` when both value arms are the same pure expression, and can Starshine safely cover a narrow HOT subset?

## Oracle

Probe: `.tmp/oi-select-same-arms-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-same-arms-probe.wat -o .tmp/oi-select-same-arms-probe.out.wat
```

Result: Binaryen folds identical pure local and constant arms to the selected value, but keeps the effectful-call-arm sibling spelling. The exact output used generated function names, but the behavioral point is that `(select (i32.const 7) (i32.const 7) cond)` becomes `i32.const 7`, and `(select (local.get 1) (local.get 1) cond)` becomes `local.get 1` when the condition is also pure.

## Starshine change

Added red-first coverage for a direct local-get shape:

- `optimize-instructions folds select with identical pure local arms`
- `optimize-instructions keeps identical select arms when condition may trap`

The first test failed before implementation because Starshine kept the `select`. The implementation now folds only when:

- the true and false arms are side-effect-free;
- the true and false arms are the same direct `local.get`, i32 constant, or i64 constant;
- the condition is side-effect-free, so dropping it cannot remove a trap or effect.

This intentionally avoids broader expression structural equality, reference/float constants, and effectful/trapping conditions until separately proven.

## Validation

- Red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*pure local arms*'` failed `0/1`.
- Oracle command above passed.
- Post-implementation focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*identical*select*'` passed `1/1`.

## Remaining work

This is an OI-F boolean/select shell sub-slice. It does not close broader `optimizeTernary` parity, structural-expression equality, or effectful-arm select rewrites.
