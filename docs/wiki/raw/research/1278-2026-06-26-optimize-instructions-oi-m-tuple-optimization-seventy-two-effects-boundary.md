# OptimizeInstructions OI-M tuple-optimization seventy-two-effect boundary

Date: 2026-06-26

## Summary

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` multivalue effect-count ladder to seventy-two later non-selected effects.

Binaryen `version_130` localizes the probed public multivalue block through tuple/scalar scratch locals and a `tuple.make 73`. Starshine still keeps the public block/drop/call/local.get spelling and does not introduce scratch `local.set` traffic. This remains an open tuple-scratch reconstruction/localization parity gap, not OI-M closure.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-seventy-two-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-seventy-two-effects-probe.wat -o .tmp/oi-m-tuple-optimization-seventy-two-effects-probe.out.wat
```

The probe passed. Follow-up counts found `tuple.make 73` once and `72` `local.set` occurrences in Binaryen's output.

## Starshine coverage

Changed file:

- `src/passes/optimize_instructions_test.mbt`: reused `optimize_instructions_tuple_optimization_effect_boundary_fixture(72)` to add focused boundary/status coverage for a public multivalue block with seventy-two later non-selected effects under `optimize-instructions` + `tuple-optimization`.

The test asserts that Starshine keeps the current public boundary spelling:

- `block` remains present;
- `drop` remains present;
- every later `call` remains present;
- `local.get` remains present;
- no scratch `local.set` traffic is introduced.

## Boundaries

This is a passing boundary/status test, not a red-first implementation slice. It documents the retained mismatch until Starshine gains local tuple-scratch reconstruction/localization for this public multivalue-block family.

It does not claim:

- tuple-scratch parity with Binaryen;
- dedicated `tuple-optimization` closure;
- full `simplify-locals` neighbor closure;
- multi-result selected/sibling localization beyond the existing documented slices;
- direct-HOT replay of the full-simplify shape, which remains separately blocked by the known `InvalidChildRef` issue.

## Validation

- Binaryen oracle command above passed and produced the expected `tuple.make 73` / `72` `local.set` shape.
- Focused Starshine boundary test passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*seventy-two later effects through tuple-optimization*'
```

- Final slice validation is recorded in the commit that cites this note.
