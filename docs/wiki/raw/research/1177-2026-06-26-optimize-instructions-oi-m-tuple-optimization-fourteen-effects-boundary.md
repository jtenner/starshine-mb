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

# OptimizeInstructions OI-M tuple-optimization fourteen-effect public multivalue boundary

## Question

Does Binaryen `version_130` localize a public multivalue block with fourteen later non-selected effects when `--optimize-instructions` is followed by `--tuple-optimization`, and should Starshine count its public block/drop spelling as parity?

## Evidence

Probe: `.tmp/oi-m-tuple-optimization-fourteen-effects-probe.wat`

```wat
(module
  (func $side_a (result i64) i64.const 9)
  (func $side_b (result f32) f32.const 1)
  (func $side_c (result f64) f64.const 2)
  (func $side_d (result i32) i32.const 3)
  (func $side_e (result i64) i64.const 4)
  (func $side_f (result f32) f32.const 5)
  (func $side_g (result f64) f64.const 6)
  (func $side_h (result i32) i32.const 7)
  (func $side_i (result i64) i64.const 8)
  (func $side_j (result f32) f32.const 10)
  (func $side_k (result f64) f64.const 11)
  (func $side_l (result i32) i32.const 12)
  (func $side_m (result i64) i64.const 13)
  (func $side_n (result f32) f32.const 14)
  (func (param $x i32) (result i32)
    (block (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32)
      local.get $x
      call $side_a
      call $side_b
      call $side_c
      call $side_d
      call $side_e
      call $side_f
      call $side_g
      call $side_h
      call $side_i
      call $side_j
      call $side_k
      call $side_l
      call $side_m
      call $side_n)
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fourteen-effects-probe.wat -o -
```

Observed Binaryen output succeeds and reconstructs the block through tuple scratch plus scalar locals. It creates a tuple scratch local for the fifteen-result block, stores the selected first lane into a scalar temp, extracts/drops the fourteen later lanes through scalar temps, and returns the selected lane.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with fourteen later effects through tuple-optimization boundary`

The test asserts that the public Starshine pipeline keeps the block, drops, calls, and selected `local.get`, and does not introduce temp `local.set` traffic.

## Classification

Boundary/status slice, not parity implementation. Binaryen's tuple-scratch localization is an open OI-M / `tuple-optimization` neighbor gap. Starshine's retained public multivalue spelling must not be classified as parity until local tuple-scratch reconstruction/localization is implemented.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fourteen-effects-probe.wat -o -` passed and localized through tuple scratch plus scalar locals.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fourteen later effects through tuple-optimization*'` passed `1/1`.
