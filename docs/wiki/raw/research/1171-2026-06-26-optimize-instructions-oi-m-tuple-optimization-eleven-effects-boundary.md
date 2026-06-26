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

# OptimizeInstructions OI-M tuple-optimization eleven-effect boundary

## Question

Does Binaryen `version_130` localize a public multivalue block with eleven later non-selected effects through tuple scratch under `--optimize-instructions --tuple-optimization`, extending the earlier two- through ten-effect probes?

## Evidence

Probe: `.tmp/oi-m-tuple-optimization-eleven-effects-probe.wat`

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
  (func (param $x i32) (result i32)
    (block (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64)
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
      call $side_k)
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
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eleven-effects-probe.wat -o -
```

Observed Binaryen behavior: the command fails validation after constructing a tuple-scratch/localization shape. The validator reports that a non-final block element returning a value must be dropped and that the block result does not match the last value. This is classified as a Binaryen/oracle boundary for this exact eleven-effect probe, not as a Starshine parity target.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with eleven later effects through tuple-optimization boundary`

The test asserts that Starshine's public `optimize-instructions` plus `tuple-optimization` pipeline keeps the multivalue block/drop spelling, preserves all eleven side-effecting calls, and does not introduce tuple scratch locals.

## Classification

Boundary/status slice, not parity implementation. The two- through ten-effect public tuple-optimization probes remain valid Binaryen tuple-scratch localization boundaries. This eleven-effect shape is a separate Binaryen/oracle boundary and should not be used to claim a missing Starshine behavior target unless a later Binaryen version produces valid output for the reduced probe.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eleven-effects-probe.wat -o -` failed validation in Binaryen after tuple-scratch localization; classified as a Binaryen/oracle boundary for this probe.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eleven later effects through tuple-optimization*'` passed `1/1`.
