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

# OptimizeInstructions OI-M tuple-optimization five-effect boundary

## Question

How does Binaryen handle a public multivalue block whose selected first result is followed by five non-selected effectful siblings when `--optimize-instructions` is followed by `--tuple-optimization`, and should Starshine claim parity for its retained public block/drop spelling?

## Evidence

Probe: `.tmp/oi-m-tuple-optimization-five-effects-probe.wat`

```wat
(module
  (func $side_a (result i64) (i64.const 9))
  (func $side_b (result f32) (f32.const 1))
  (func $side_c (result f64) (f64.const 2))
  (func $side_d (result i32) (i32.const 3))
  (func $side_e (result i64) (i64.const 4))
  (func (param $x i32) (result i32)
    (block (result i32 i64 f32 f64 i32 i64)
      local.get $x
      call $side_a
      call $side_b
      call $side_c
      call $side_d
      call $side_e)
    drop
    drop
    drop
    drop
    drop))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-five-effects-probe.wat -o -
```

Observed Binaryen output localizes the public multivalue block through a tuple scratch local, scalar scratch locals for the selected and non-selected lanes, and nested block/drop reconstruction. The five later effectful siblings remain evaluated before being dropped.

## Starshine coverage

Added public-pipeline boundary coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with five later effects through tuple-optimization boundary`

The test asserts that Starshine keeps the public multivalue block/drop/call/local.get spelling and does not introduce temp `local.set` traffic.

## Classification

Boundary/status slice, not parity. This extends the existing one-, two-, three-, and four-effect tuple-optimization neighbor boundaries. The retained Starshine spelling is still an open tuple-scratch reconstruction/localization parity gap, not a Starshine win.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-five-effects-probe.wat -o -` passed and showed Binaryen tuple scratch plus scalar-local reconstruction.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*five later effects through tuple-optimization*'` passed `1/1`.
