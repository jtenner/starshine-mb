---
kind: research
status: supported
created: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../wiki/binaryen/passes/optimize-instructions/index.md
  - ../../../../src/passes/optimize_instructions.mbt
  - ../../../../src/passes/optimize_instructions_test.mbt
---

# OI-F identical numeric select arms

## Summary

Binaryen `version_130` direct `--optimize-instructions` folds identical pure numeric expression arms of a `select` when the condition is side-effect-free. This slice adds the same narrow Starshine behavior for same-order local/constant integer binary shells, covering direct numeric `i32` and `i64` arms rather than only `ref.i31` payloads.

## Oracle

Probe: `.tmp/oi-select-identical-binary-arms-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-binary-arms-probe.wat -o .tmp/oi-select-identical-binary-arms-probe.out.wat
```

Result: passed. Binaryen removed the `select` for identical `i32.add(local.get, i32.const)`, `i64.add(local.get, i64.const)`, and `i32.eqz(local.get)` arms, leaving the shared expression shell.

## Starshine change

`src/passes/optimize_instructions.mbt` now lets `optimize_instructions_select_arms_are_identical_pure` recognize direct identical numeric expression arms before constant-arm fallback:

- existing narrow same-order `i32.<binop>(local.get, i32.const)` helper is reused for direct `i32` select arms;
- a sibling narrow same-order `i64.<binop>(local.get, i64.const)` helper covers direct `i64` select arms;
- existing direct `i32` unary local-payload equality also applies to direct `i32` select arms.

The binary shell set stays intentionally narrow: add/sub/mul/and/or/xor/shift/rotate/div/rem, same instruction, same left local id, same right constant, and same operand order.

## Tests and evidence

Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions folds select with identical pure numeric expression arms`.

Red-first result before implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*numeric expression arms*'
# failed 0/1 on the i32.add payload case
```

Post-implementation focused result:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*numeric expression arms*'
# passed 1/1
```

## Boundaries

This is not arbitrary structural equality. It does not claim commuted operands, globals as equivalent to locals, common subexpression reasoning, NaN-payload equality, broad reference equality, or effectful/trapping condition folding. It is a direct same-shell parity slice for identical pure arms with a side-effect-free condition.
