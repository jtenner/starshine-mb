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

# OI-D sign-extension unsigned-top compare rewrite

## Summary

Binaryen `version_130` rewrites the narrow unsigned-top compare subset where an `i32.extend8_s` or `i32.extend16_s` result is compared against `u32::MAX` with `lt_u` or `ge_u`.

Observed direct `--optimize-instructions` shapes:

- `i32.lt_u(i32.extend8_s(x), -1)` becomes `i32.ne(i32.and(x, 255), 255)`.
- `i32.ge_u(i32.extend8_s(x), -1)` becomes `i32.eq(i32.and(x, 255), 255)`.
- The `extend16_s` sibling uses mask/constant `65535`.
- Effectful operands remain evaluated once as the input to the `and`, e.g. `i32.and(call $effect, 255)`.

Starshine now implements this narrow source-backed rewrite for i32 sign-extension inputs. This complements, but does not broaden, the earlier equality-only sign-extension range fold and the signed-relational keep-spelling boundary.

## Evidence

Oracle probes:

```sh
wasm-opt --all-features -S --optimize-instructions \
  .tmp/oi-d-signext-unsigned-rel-probe2.wat -o -
wasm-opt --all-features -S --optimize-instructions \
  .tmp/oi-d-signext-unsigned-rel-effect-probe.wat -o -
```

Red-first test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt \
  --filter '*sign-extension unsigned top*'
```

Before implementation the focused test failed because Starshine kept `I32LtU` over `i32.extend8_s`. After implementation it passed `1/1`.

## Retained boundaries

This slice intentionally does not claim broad sign-extension relational parity. Binaryen still keeps the probed signed-relational out-of-range forms recorded in `0889`, and the observed unsigned rewrite here is limited to `lt_u` / `ge_u` against `u32::MAX` for `i32.extend8_s` / `i32.extend16_s`.
