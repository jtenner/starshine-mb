---
kind: research
status: supported
date: 2026-06-26
pass: optimize-instructions
slice: O4Z-AUDIT-OI-D
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-D i64 sign-extension unsigned-top compare rewrite

## Summary

Binaryen `version_130` also rewrites the i64 sign-extension unsigned-top compare subset, but unlike the i32 lane it does not mask back to the lane width. Observed direct `--optimize-instructions` shapes:

- `i64.lt_u(i64.extend8_s(x), -1)` becomes `i64.ne(i64.extend8_s(x), -1)`.
- `i64.ge_u(i64.extend8_s(x), -1)` becomes `i64.eq(i64.extend8_s(x), -1)`.
- The same spelling applies to `i64.extend16_s` and `i64.extend32_s`.
- Effectful operands remain evaluated once as the child of the retained sign-extension.

Starshine now implements this narrow source-backed rewrite for i64 sign-extension inputs. This complements the previous i32 mask rewrite and does not generalize the documented i64 sign-extension equality boundary: Binaryen still keeps out-of-range equality/inequality compares such as `i64.eq(i64.extend8_s(x), 128)`.

## Evidence

Oracle probes:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-probe.wat -o -
wasm-opt --all-features -S --optimize-instructions .tmp/oi-probe-effect.wat -o -
```

Red-first test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt \
  --filter '*i64 sign-extension unsigned top*'
```

Before implementation the focused test failed because Starshine kept `I64LtU` over `i64.extend8_s`. After implementation it passed `1/1`.

## Retained boundaries

This slice is limited to `i64.lt_u` / `i64.ge_u` against `u64::MAX` with a direct `i64.extend8_s`, `i64.extend16_s`, or `i64.extend32_s` left operand. It does not broaden signed-relational sign-extension rewrites, i64 out-of-range equality folds, or non-top unsigned compare reasoning.
