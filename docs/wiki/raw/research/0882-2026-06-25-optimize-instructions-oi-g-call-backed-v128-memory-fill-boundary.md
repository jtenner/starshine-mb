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
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-G call-backed size-16 `memory.fill` boundary

## Question

Should Starshine generalize the constant size-16 `memory.fill` SIMD lowering to a fill value produced by a call?

## Oracle

Probe: `.tmp/oi-g-stack-call-memory-fill-16-probe.wat`.

```wat
(module
  (memory 1)
  (func $dst (result i32) (i32.const 8))
  (func $val (result i32) (i32.const 171))
  (func (export "run")
    call $dst
    call $val
    i32.const 16
    memory.fill))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-stack-call-memory-fill-16-probe.wat -o -
```

Result: Binaryen `version_130` keeps the `memory.fill` with `call $dst`, `call $val`, and `i32.const 16`. It does not materialize a `v128.const` / `v128.store` for this call-backed value.

## Starshine evidence

Updated public-pipeline coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps non-local wider memory.fill values`

The test now proves the existing non-local wider-fill boundary includes the call-backed SIMD-width size-16 shape:

- the optimized function still contains `memory.fill`;
- the value call is preserved;
- `v128.store` is not introduced.

This is boundary/status evidence, not a red-first implementation slice. It prevents an invalid generalization from the constant-value size-16 SIMD lowering to call-backed fill values.

Focused validation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-local wider memory.fill values*'
```

passed `1/1`.

## Boundary

This slice only covers a flat no-parameter direct-call fill value for constant size `16`. Constant fill values still lower to repeated-byte `v128.const` plus `v128.store`; size-1 local/global/direct-call values remain the covered byte-fill exception. Broader source-backed materialization for non-local wider `memory.fill` values remains open only if a future Binaryen source or oracle probe demonstrates it.
