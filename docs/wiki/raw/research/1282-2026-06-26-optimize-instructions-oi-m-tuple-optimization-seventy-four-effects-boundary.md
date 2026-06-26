# OptimizeInstructions OI-M Tuple-Optimization Seventy-Four-Effect Boundary

Date: 2026-06-26

## Summary

This boundary/status slice extends the public `optimize-instructions` plus `tuple-optimization` multivalue effect-count ladder to seventy-four later non-selected effects.

Binaryen `version_130` localizes the public multivalue block through tuple scratch (`tuple.make 75`) plus scalar locals. Starshine still keeps the public block/drop/call/local.get spelling and introduces no local.set traffic. This is intentionally recorded as the same open tuple-scratch reconstruction/localization gap, not OI-M parity closure.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-seventy-four-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-seventy-four-effects-probe.wat -o .tmp/oi-m-tuple-optimization-seventy-four-effects-probe.out.wat
```

Observed Binaryen output contained `tuple.make 75` once and `74` `local.set` occurrences.

## Starshine coverage

Added the public-pipeline boundary/status test `optimize-instructions intentionally keeps public multivalue block with seventy-four later effects through tuple-optimization boundary` in `src/passes/optimize_instructions_test.mbt`.

The test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(74)` under `pass_test_run_pipeline(..., ["optimize-instructions", "tuple-optimization"])` and asserts the retained Starshine spelling:

- contains `block`;
- contains `drop`;
- contains all `call (Func i)` effects for `0 <= i < 74`;
- contains `local.get`;
- does not contain `local.set`.

## Boundary status

This slice is coverage/status only. It does not implement Binaryen's tuple-scratch localization, selected-lane tuple reconstruction, sibling localization, multi-use tuple proof, or the direct-HOT full-simplify fixture blocked by `InvalidChildRef(3, 0, 0)`.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 75` plus `74` `local.set` occurrences.
- Focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*seventy-four later effects through tuple-optimization*'` passed `1/1`.

Full slice validation is recorded in the commit that references this note.
