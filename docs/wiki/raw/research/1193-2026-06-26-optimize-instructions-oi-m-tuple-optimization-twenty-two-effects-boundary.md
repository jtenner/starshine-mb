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

# OptimizeInstructions OI-M tuple-optimization twenty-two-effect boundary

## Question

How does Binaryen `version_130` handle a public multivalue block whose first result is selected while twenty-two later non-selected effectful results are dropped when `--optimize-instructions` runs next to `--tuple-optimization`, and should Starshine claim parity for that neighbor shape?

## Evidence

Probe: `.tmp/oi-m-tuple-optimization-twenty-two-effects-probe.wat`

The probe defines twenty-two side-effect-shaped calls with single results after the selected `local.get $x` inside a public multivalue block:

```wat
(func (param $x i32) (result i32)
  (block (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32)
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
    call $side_n
    call $side_o
    call $side_p
    call $side_q
    call $side_r
    call $side_s
    call $side_t
    call $side_u
    call $side_v)
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
  drop
  drop
  drop
  drop
  drop
  drop
  drop
  drop
  drop)
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-two-effects-probe.wat -o -
```

Observed Binaryen output succeeds. It introduces a tuple scratch local and scalar scratch locals, stores the selected lane, extracts and drops the later effectful lanes in order, then returns the selected scalar value.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with twenty-two later effects through tuple-optimization boundary`

The test asserts that the Starshine public pipeline still keeps the block/drop/call/local.get spelling and does not introduce local-set scratch traffic.

## Classification

Boundary/status slice, not parity implementation. This extends the public `tuple-optimization` neighbor ladder to twenty-two later effects and keeps the tuple-scratch reconstruction/localization gap explicit rather than classifying the retained block/drop spelling as parity.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-two-effects-probe.wat -o -` passed and localized through tuple scratch plus scalar locals.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*twenty-two later effects through tuple-optimization*'` passed `1/1`.
