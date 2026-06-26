---
kind: research
status: supported
date: 2026-06-26
pass: optimize-instructions
slice: O4Z-AUDIT-OI-M
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-M tuple-optimization three-effect public multivalue boundary

## Summary

This is boundary/status evidence for the public `optimize-instructions -> tuple-optimization` neighbor, not a parity implementation.

Binaryen `version_130` localizes a public multivalue block with one selected `i32` result and three later non-selected effect results through a tuple scratch local and scalar locals. Starshine's public WAT pipeline keeps the original multivalue `block` plus three `drop`s and does not synthesize tuple scratch traffic.

The retained Starshine spelling is a documented tuple-scratch reconstruction/localization gap for OI-M. It extends the earlier one-effect and two-effect public neighbor probes but does not close tuple-optimization parity.

## Probe

```wat
(module
  (func $side_a (result i64) (i64.const 9))
  (func $side_b (result f32) (f32.const 1))
  (func $side_c (result f64) (f64.const 2))
  (func (param $x i32) (result i32)
    (block (result i32 i64 f32 f64)
      local.get $x
      call $side_a
      call $side_b
      call $side_c)
    drop
    drop
    drop))
```

Binaryen command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization \
  .tmp/oi-m-tuple-optimization-three-effects-probe.wat -o -
```

Observed Binaryen shape: tuple scratch plus scalar-local traffic around the three non-selected results.

Starshine coverage:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt \
  --filter '*three later effects through tuple-optimization*'
```

The focused boundary test passed `1/1`, asserting the public output still contains the `block`, three `drop` spellings, calls to all three side-effecting helpers, and no introduced `local.set`.

## Retained gap

Remaining OI-M work still includes tuple-scratch localization for public multivalue blocks, multi-result selected children and siblings, broader tee/drop reconstruction, and the full `simplify-locals` direct-HOT verifier reduction currently blocked by `InvalidChildRef` evidence from earlier slices.
