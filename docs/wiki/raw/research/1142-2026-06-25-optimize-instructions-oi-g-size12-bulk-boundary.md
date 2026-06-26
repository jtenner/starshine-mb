# Optimize-instructions OI-G size-12 bulk-memory boundary

## Question

Does Binaryen `version_130` `--optimize-instructions` lower constant-size-12 `memory.copy` / `memory.fill` to mixed scalar load/store operations, or is size 12 outside the exact tiny bulk-memory lowering boundary?

## Probe

Input saved locally as `.tmp/oi-g-memory-copy-size12-probe.wat`:

```wat
(module
  (memory 1)
  (func (param $dst i32) (param $src i32) (param $value i32)
    local.get $dst
    local.get $src
    i32.const 12
    memory.copy
    local.get $dst
    local.get $value
    i32.const 12
    memory.fill))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size12-probe.wat -o -
```

## Finding

Binaryen keeps both operations as bulk-memory instructions:

- `memory.copy(local.get $dst, local.get $src, i32.const 12)` remains `memory.copy`.
- `memory.fill(local.get $dst, local.get $value, i32.const 12)` remains `memory.fill`.

It does not synthesize mixed 8+4 load/store sequences for this shape.

## Starshine coverage

`src/passes/optimize_instructions_test.mbt` now has public-pipeline boundary coverage named `optimize-instructions keeps size-12 bulk-memory outside exact lowering boundary`.

The test asserts that Starshine preserves `memory.copy` and `memory.fill` and does not introduce scalar/SIMD lowering instructions (`i32.load8u`, `i32.store8`, `i32.load16u`, `i32.store16`, broad `i32.load`/`i32.store`, `i64.load`/`i64.store`, or `v128.load`/`v128.store`).

## Classification

Boundary/status evidence, not red-first implementation work. The source-backed exact bulk-memory lowering lanes remain the existing 1/2/4/8/16-size cases; size 12 is a keep-spelling boundary under the probed Binaryen `version_130` behavior.

## Follow-ups

OI-G remains incomplete. Remaining work includes broader `optimizeStoredValue` shapes, non-flat effect/control `memory.copy` localization, further raw-gate escapes, broader load/store canonicalization, and zero-size bulk cleanup pending trap-relaxed/TNH/IIT support.
