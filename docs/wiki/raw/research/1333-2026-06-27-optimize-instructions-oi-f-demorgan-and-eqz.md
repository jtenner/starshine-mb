---
kind: research
status: supported
created: 2026-06-27
sources:
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../src/passes/optimize_instructions.mbt
  - ../../../../src/passes/optimize_instructions_test.mbt
---

# Optimize-instructions OI-F De Morgan `and(eqz, eqz)`

## Scope

This slice covers one narrow `optimizeBoolean` / boolean peephole parity gap: direct `i32.and` whose two children are direct `i32.eqz` unary nodes.

Implemented Starshine rewrite:

```wat
(i32.and (i32.eqz X) (i32.eqz Y))
```

becomes:

```wat
(i32.eqz (i32.or X Y))
```

The rewrite preserves the original left-to-right operand order (`X`, then `Y`) and does not drop operands.

## Binaryen evidence

Probe: `.tmp/oi-f-demorgan-and-eqz-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-f-demorgan-and-eqz-probe.wat -o .tmp/oi-f-demorgan-and-eqz-probe.out.wat
```

Result: passed. Binaryen `version_130` rewrote both the direct local-backed and call-backed probes to `i32.eqz(i32.or(...))`, preserving operand order and the effectful call operand inside the new `or`.

## Starshine change

- Added red-first test `optimize-instructions applies De Morgan to and of eqz operands` in `src/passes/optimize_instructions_test.mbt`.
  - Before implementation, the focused test failed because the HOT root stayed `I32And` instead of becoming `I32Eqz`.
  - After implementation, the focused test passes and checks the `i32.eqz` root, nested `i32.or`, and operand preservation for both local-backed and side-effecting call-backed shapes.
- Added `optimize_instructions_try_apply_demorgan_and_eqz(...)` in `src/passes/optimize_instructions.mbt` and wired it into the binary-node rewrite pass before identity/absorbing/canonicalization cleanup.

## Boundaries

This is deliberately narrow:

- only direct `i32.and` with two direct `i32.eqz` children;
- no general De Morgan expansion for `or(eqz, eqz)` or branch conditions;
- no arbitrary boolean algebra, non-eqz children, value-equivalent conditions, or commuted nested shells beyond the exact direct node shape;
- no claim about short-circuiting, since WebAssembly `i32.and` and `i32.or` evaluate both operands and the replacement preserves operand order.

## Validation

- Binaryen oracle probe passed.
- Focused Moon test failed red-first, then passed after implementation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*De Morgan to and of eqz operands*'`

Full slice validation is recorded in the commit message.
