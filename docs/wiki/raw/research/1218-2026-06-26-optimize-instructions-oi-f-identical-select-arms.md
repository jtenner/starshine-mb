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

Probes: `.tmp/oi-select-same-arms-probe.wat`, `.tmp/oi-select-float-arms-probe.wat`, and `.tmp/oi-select-global-arms-probe.wat`.

Commands:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-same-arms-probe.wat -o .tmp/oi-select-same-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-float-arms-probe.wat -o .tmp/oi-select-float-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-global-arms-probe.wat -o .tmp/oi-select-global-arms-probe.out.wat
```

Result: Binaryen folds identical pure local, global, and constant arms to the selected value, but keeps the effectful-call-arm sibling spelling. The exact output used generated function names, but the behavioral point is that `(select (i32.const 7) (i32.const 7) cond)` becomes `i32.const 7`, `(select (local.get 1) (local.get 1) cond)` becomes `local.get 1`, `(select (global.get $g) (global.get $g) cond)` becomes `global.get $g`, and a follow-up float probe folds identical f32/f64 constants when the condition is also pure.

## Starshine change

Added red-first coverage for direct local-get, direct global-get, and direct float-constant shapes:

- `optimize-instructions folds select with identical pure local arms`
- `optimize-instructions folds select with identical pure global arms`
- `optimize-instructions folds select with identical pure float constant arms`
- `optimize-instructions keeps identical select arms when condition may trap`

The local-get test failed before the first implementation because Starshine kept the `select`. The float-constant test later failed before the narrower follow-up because Starshine only recognized local/i32/i64 identical arms. The global-get test later failed before the direct-global follow-up because the identity helper did not compare same-global arms. The implementation now folds only when:

- the true and false arms are side-effect-free;
- the true and false arms are the same direct `local.get`, same direct `global.get`, i32 constant, i64 constant, f32 constant, or f64 constant;
- the condition is side-effect-free, so dropping it cannot remove a trap or effect.

This intentionally avoids broader expression structural equality, NaN-payload equality claims, reference constants, global mutability/value-equivalence claims beyond same-index `global.get`, and effectful/trapping conditions until separately proven.

## Validation

- Red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*pure local arms*'` failed `0/1`.
- Float follow-up red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*float constant arms*'` failed `0/1`.
- Global follow-up red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*global arms*'` failed `0/1`.
- Oracle commands above passed, including `.tmp/oi-select-float-arms-probe.wat` and `.tmp/oi-select-global-arms-probe.wat`.
- Post-implementation focused local test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*identical*select*'` passed `1/1`.
- Post-implementation focused float test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*float constant arms*'` passed `1/1`.
- Post-implementation focused global test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*global arms*'` passed `1/1`.

## Remaining work

This is an OI-F boolean/select shell sub-slice. It does not close broader `optimizeTernary` parity, structural-expression equality, or effectful-arm select rewrites.
