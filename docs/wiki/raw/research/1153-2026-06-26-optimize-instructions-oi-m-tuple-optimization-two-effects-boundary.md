# Optimize Instructions OI-M tuple-optimization two-effect boundary

Date: 2026-06-26

## Summary

Boundary/status slice for `[O4Z-AUDIT-OI-M]`.

Binaryen `version_130` direct `--optimize-instructions --tuple-optimization` localizes a public multivalue block with two later non-selected effect results through tuple scratch and scalar locals. Starshine's public WAT pipeline currently keeps the multivalue block plus two `drop`s when the same neighbor pass sequence runs.

This is not claimed as parity. It is a narrowly documented boundary for the tuple-scratch reconstruction/localization gap, extending the existing one-later-effect `tuple-optimization` neighbor boundary to a two-later-effect shape that is representable in public WAT.

## Binaryen oracle

Probe file: `.tmp/oi-m-tuple-optimization-two-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-two-effects-probe.wat -o -
```

Observed output:

- introduces a tuple scratch local for the `(i32, i64, f32)` block result,
- stores the selected `i32` lane in a scalar local,
- drops/reconstructs the non-selected `i64` and `f32` lanes through tuple extracts,
- returns the selected scalar local.

This confirms that Binaryen performs tuple-scratch localization for this neighbor shape.

## Starshine coverage

Added focused public-pipeline test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with two later effects through tuple-optimization boundary`

The test runs `optimize-instructions` followed by `tuple-optimization`, then asserts Starshine keeps the public multivalue `block`, both call effects, and `drop` spelling, without synthesizing local scratch traffic. The test is boundary/status evidence only.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-two-effects-probe.wat -o -` — passed; Binaryen localized via tuple scratch and scalar locals.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*two later effects through tuple-optimization*'` — passed `1/1`.

## Backlog impact

This increments OI-M tuple/multivalue boundary/status coverage beyond the first forty-three sub-slices. It does not close the tuple-scratch gap. Remaining OI-M work still includes implementing or reducing tuple-scratch localization for multi-result selected children and non-selected siblings, broader tee/drop reconstruction, direct-HOT verifier reduction for the full `simplify-locals` `InvalidChildRef` boundary, and more neighbor replay evidence for `tuple-optimization` and `simplify-locals`.
