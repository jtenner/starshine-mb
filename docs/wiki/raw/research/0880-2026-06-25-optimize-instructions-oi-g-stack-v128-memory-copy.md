---
kind: research
status: supported
date: 2026-06-25
sources:
  - ../../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../wiki/binaryen/passes/optimize-instructions/index.md
  - ../../../../wiki/binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../wiki/binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md
  - ../../../../wiki/binaryen/passes/optimize-instructions/wat-shapes.md
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-G stack-carried v128 `memory.copy` coverage

## Question

Does Starshine's existing flat stack-carried bulk-memory raw-gate escape cover the size-16 `memory.copy` lane with effectful call operands, matching Binaryen's SIMD one-load/one-store lowering?

## Oracle

Probe: `.tmp/oi-g-stack-call-memory-copy-16-probe.wat`.

```wat
(module
  (memory 1)
  (func $dst (result i32) i32.const 0)
  (func $src (result i32) i32.const 16)
  (func (export "copy")
    call $dst
    call $src
    i32.const 16
    memory.copy))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-stack-call-memory-copy-16-probe.wat -o -
```

Result: Binaryen `version_130` rewrites the body to `v128.store align=1` whose address child is `call $dst` and whose value child is `v128.load align=1 (call $src)`. The destination call remains before the source call, and the bulk-memory opcode is gone.

## Starshine evidence

Added public-pipeline coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions expands stack-carried effectful v128 memory.copy`

The test proves:

- the raw pipeline does not report `stack-carried-effect-optimize-instructions-noop` for this exact flat size-16 copy;
- `memory.copy` is removed;
- the pretty output keeps `call (Func 0)`, `call (Func 1)`, `v128.load`, and `v128.store` in order.

This is coverage/status evidence for existing behavior after the earlier size-16 implementation. It is not a red-first implementation slice.

Focused validation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*effectful v128 memory.copy*'
```

passed `1/1`.

## Boundary

This slice only covers the exact flat stack-carried size-16 `memory.copy` shape whose destination/source operands are direct no-parameter one-result calls. It does not broaden tuple/localizing support, non-flat effect/control forms, zero-size cleanup, oversized copies, or dynamic-size bulk-memory.
