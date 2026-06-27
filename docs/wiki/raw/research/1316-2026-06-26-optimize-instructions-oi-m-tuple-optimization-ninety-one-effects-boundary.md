# Optimize-instructions OI-M tuple-optimization ninety-one-effect boundary

## Slice

This OI-M boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` neighbor ladder to a multivalue block with ninety-one later non-selected effects.

This is not parity implementation. It records another successful Binaryen tuple-scratch localization point while Starshine intentionally keeps the public multivalue block/drop spelling until tuple-scratch reconstruction/localization exists.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-ninety-one-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ninety-one-effects-probe.wat -o .tmp/oi-m-tuple-optimization-ninety-one-effects-probe.out.wat
```

Result: passed. Binaryen `version_130` localized the public multivalue block through `tuple.make 92` and introduced `91` `local.set` occurrences for tuple/scalar scratch traffic.

## Starshine coverage

Files:

- `src/passes/optimize_instructions_test.mbt`

Focused test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ninety-one later effects through tuple-optimization*'
```

Result: passed `1/1`.

The test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(91)` and asserts that Starshine still prints `block`, `drop`, all ninety-one side-effecting calls, and `local.get`, while not introducing `local.set` traffic.

## Status

- Counted as the one hundred thirty-third OI-M tuple/multivalue sub-slice.
- Public tuple-optimization effect-count boundary coverage now extends through ninety-one later effects.
- The retained mismatch remains a tuple-scratch reconstruction/localization gap, not OI-M closure.

## Boundaries

This slice does not implement tuple-scratch localization, selected-lane/sibling reconstruction, `simplify-locals` neighbor behavior, or direct-HOT tuple replay. It only extends the successful public boundary ladder by one effect count and keeps the open parity gap explicit.
