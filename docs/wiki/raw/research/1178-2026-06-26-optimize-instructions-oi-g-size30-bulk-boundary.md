---
kind: research
status: supported
date: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-G size-30 bulk-memory boundary

## Question

Does Binaryen `version_130` lower constant-size-30 `memory.copy` / `memory.fill` by combining SIMD, eight-byte, four-byte, two-byte, or other scalar lanes, and should Starshine widen its exact tiny bulk-memory lowering to match?

## Evidence

Probe: `.tmp/oi-g-memory-copy-size30-probe.wat`

```wat
(module
  (memory 1)
  (func (param $dst i32) (param $src i32) (param $value i32)
    local.get $dst
    local.get $src
    i32.const 30
    memory.copy
    local.get $dst
    local.get $value
    i32.const 30
    memory.fill))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size30-probe.wat -o -
```

Observed Binaryen output keeps both bulk-memory operations with `i32.const 30`. It does not split the copy/fill into a 16-byte SIMD lane, an 8-byte lane, a 4-byte lane, a 2-byte lane, or any other scalar/SIMD lowering.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions keeps size-30 bulk-memory outside exact lowering boundary`

The test asserts that Starshine keeps both `memory.copy` and `memory.fill`, and does not introduce scalar or SIMD load/store operations.

## Classification

Boundary/status slice, not parity implementation. This narrows OI-G by documenting that size 30 is outside Binaryen's observed direct `--optimize-instructions` lowering surface, matching the existing non-exact-size boundaries through size 29.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size30-probe.wat -o -` passed and kept the bulk-memory operations.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*size-30 bulk-memory*'` passed `1/1`.
