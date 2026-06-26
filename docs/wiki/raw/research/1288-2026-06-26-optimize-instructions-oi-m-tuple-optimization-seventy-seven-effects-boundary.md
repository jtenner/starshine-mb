# OptimizeInstructions OI-M Tuple-Optimization Seventy-Seven-Effect Boundary

Date: 2026-06-26

## Summary

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` effect-count ladder to a multivalue block with seventy-seven later non-selected effect calls.

Binaryen `version_130` localizes the selected value through tuple-scratch reconstruction, emitting `tuple.make 78` plus scalar local traffic. Starshine still keeps the public multivalue `block` / `drop` / `call` / `local.get` spelling. This remains an open tuple-scratch reconstruction/localization gap, not parity closure.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-seventy-seven-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-seventy-seven-effects-probe.wat -o .tmp/oi-m-tuple-optimization-seventy-seven-effects-probe.out.wat
```

Observed Binaryen output contains one `tuple.make 78` and seventy-seven `local.set` occurrences, showing Binaryen localized the selected lane through tuple/scalar scratch locals rather than keeping the original block/drop stack spelling.

## Starshine coverage

- Reused `optimize_instructions_tuple_optimization_effect_boundary_fixture(77)` in `src/passes/optimize_instructions_test.mbt`.
- Added focused boundary/status coverage named `optimize-instructions intentionally keeps public multivalue block with seventy-seven later effects through tuple-optimization boundary`.
- The test asserts Starshine currently keeps `block`, `drop`, all seventy-seven effect calls, and `local.get`, and does not introduce `local.set` traffic.

## Boundary

This is intentionally boundary/status coverage. It preserves evidence for the mismatch while the local tuple-scratch reconstruction/localization implementation remains incomplete. Do not classify this as an accepted semantic win or OI-M closure. The next implementation work should reduce the tuple-scratch gap directly, shrink the direct-HOT/public fixture blocker, or add a source-backed positive localization slice.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 78` plus seventy-seven `local.set` occurrences.
- Focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*seventy-seven later effects through tuple-optimization*'` passed `1/1`.

Full slice validation is recorded in the commit that references this note.
