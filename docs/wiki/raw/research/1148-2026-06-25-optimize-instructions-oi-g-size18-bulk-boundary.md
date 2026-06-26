---
kind: research
status: supported
created: 2026-06-25
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../wiki/binaryen/passes/optimize-instructions/index.md
  - ../../../wiki/binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-G size-18 bulk-memory boundary

## Question

Does Binaryen `version_130` split a constant-size `18` `memory.copy` or `memory.fill` into an exact 16-byte SIMD lane plus trailing scalar lowering during direct `--optimize-instructions`?

## Evidence

Probe: `.tmp/oi-g-memory-copy-size18-probe.wat`:

```wat
(module
  (memory 1)
  (func (param $dst i32) (param $src i32) (param $value i32)
    local.get $dst
    local.get $src
    i32.const 18
    memory.copy
    local.get $dst
    local.get $value
    i32.const 18
    memory.fill))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size18-probe.wat -o -
```

Binaryen kept both `memory.copy(..., i32.const 18)` and `memory.fill(..., i32.const 18)` unchanged. It did not synthesize `v128.load` / `v128.store` plus trailing scalar load/store operations.

## Starshine coverage

Added public-pipeline boundary/status test `optimize-instructions keeps size-18 bulk-memory outside exact lowering boundary` in `src/passes/optimize_instructions_test.mbt`.

The test asserts Starshine keeps both bulk-memory operations and does not introduce scalar or SIMD load/store lowering. This is boundary/status evidence, not red-first implementation work: it locks the current source-backed exact-size lowering boundary at `1` / `2` / `4` / `8` / `16` rather than treating size `18` as a hidden mixed-lane parity gap.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size18-probe.wat -o -` — passed; Binaryen kept both size-18 bulk-memory operations.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*size-18 bulk-memory*'` — passed `1/1`.

## Follow-up

Broader OI-G work remains open: `optimizeStoredValue` shapes, non-flat effect/control `memory.copy` localization, further raw-gate escapes, broader load/store canonicalization, and zero-size bulk cleanup pending trap-relaxed/TNH/IIT support.
