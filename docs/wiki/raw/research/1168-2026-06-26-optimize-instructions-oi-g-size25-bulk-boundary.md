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

# OptimizeInstructions OI-G size-25 bulk-memory boundary

## Question

Does Binaryen `version_130` lower constant-size-25 `memory.copy` / `memory.fill` by combining a SIMD-width lane, an eight-byte lane, and a one-byte tail, and should Starshine widen its exact tiny bulk-memory lowering to match?

## Evidence

Probe: `.tmp/oi-g-memory-copy-size25-probe.wat`

```wat
(module
  (memory 1)
  (func (param $dst i32) (param $src i32) (param $value i32)
    local.get $dst
    local.get $src
    i32.const 25
    memory.copy
    local.get $dst
    local.get $value
    i32.const 25
    memory.fill))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size25-probe.wat -o -
```

Observed Binaryen output keeps both bulk-memory operations with `i32.const 25`. It does not split the copy/fill into a 16-byte SIMD lane plus an 8-byte lane and 1-byte tail, or any other scalar/SIMD lowering.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions keeps size-25 bulk-memory outside exact lowering boundary`

The test asserts that Starshine keeps both `memory.copy` and `memory.fill`, and does not introduce scalar or SIMD load/store operations.

## Classification

Boundary/status slice, not parity implementation. This narrows OI-G by documenting that size 25 is outside Binaryen's observed direct `--optimize-instructions` lowering surface, matching the existing size-17/18/19/20/21/22/23/24 boundaries.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size25-probe.wat -o -` passed and kept the bulk-memory operations.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*size-25 bulk-memory*'` passed `1/1`.
