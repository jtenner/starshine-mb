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

# OI-M tuple-optimization four-effect public multivalue boundary

## Summary

This boundary/status slice extends the public `optimize-instructions -> tuple-optimization` neighbor evidence from two and three later non-selected effects to four.

The probed module returns a public multivalue block `(result i32 i64 f32 f64 i32)`, keeps the first `i32` lane, and drops the four later lanes. Binaryen `version_130` localizes the block through a tuple scratch local plus scalar scratch locals for the non-selected siblings. Starshine's public pipeline still keeps the original multivalue block and four `drop`s without introducing temp locals.

This is evidence for the open tuple-scratch reconstruction/localization gap, not parity.

## Evidence

Oracle probe:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization \
  .tmp/oi-m-tuple-optimization-four-effects-probe.wat -o -
```

Focused public-pipeline boundary test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt \
  --filter '*four later effects through tuple-optimization*'
```

The focused test passed `1/1`, asserting Starshine keeps the block/drop/call/local.get spelling and does not synthesize `local.set` traffic.

## Retained boundary

Tuple-optimization neighbor parity remains open for public multivalue selected-child shapes with non-selected siblings. The direct HOT tuple extraction subset is still limited to one-use `tuple.extract(tuple.make(...))` forwarding and selected-lane localization for single-result effectful/trapping siblings; broader Binaryen-style tuple scratch localization is not implemented here.
