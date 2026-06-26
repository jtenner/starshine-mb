# OptimizeInstructions OI-M Tuple Optimization Seventy-Three-Effect Boundary

Date: 2026-06-26

## Summary

This boundary/status slice extends the public `optimize-instructions` plus `tuple-optimization` effect-count ladder to seventy-three later non-selected effects.

Binaryen `version_130` localizes the probed public multivalue block through `tuple.make 74` plus tuple/scalar scratch locals. Starshine still keeps the public block/drop/call/local.get spelling and does not introduce `local.set` traffic. This remains an open tuple-scratch reconstruction/localization gap, not OI-M parity closure.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-seventy-three-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-seventy-three-effects-probe.wat -o .tmp/oi-m-tuple-optimization-seventy-three-effects-probe.out.wat
```

Observed Binaryen output contained `tuple.make 74` and `73` `local.set` occurrences.

## Starshine coverage

Added focused boundary/status coverage in `src/passes/optimize_instructions_test.mbt` using `optimize_instructions_tuple_optimization_effect_boundary_fixture(73)`. The test asserts that Starshine keeps block/drop/call/local.get spelling and does not synthesize local scratch traffic.

This test is intentionally boundary/status coverage, not red-first implementation coverage. It documents a retained mismatch until tuple-scratch reconstruction/localization is implemented.

## Validation

- Binaryen oracle command above passed.
- Focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*seventy-three later effects through tuple-optimization*'` passed `1/1`.

Full slice validation is recorded in the commit that references this note.
