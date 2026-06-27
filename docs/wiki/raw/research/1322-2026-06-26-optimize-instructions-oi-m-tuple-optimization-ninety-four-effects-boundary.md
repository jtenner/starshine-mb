# Optimize-instructions OI-M tuple-optimization ninety-four-effect boundary

## Slice

Boundary/status-only OI-M slice extending public `optimize-instructions` + `tuple-optimization` effect-count coverage from ninety-three to ninety-four later non-selected effects.

The fixture builds a public WAT multivalue block whose first result is selected and whose ninety-four later block results are dropped after the block. Binaryen localizes this shape through tuple scratch traffic; Starshine currently keeps the public multivalue block and drops because local tuple-scratch reconstruction/localization is still missing.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-ninety-four-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ninety-four-effects-probe.wat -o .tmp/oi-m-tuple-optimization-ninety-four-effects-probe.out.wat
```

Result: passed. Binaryen produced one `tuple.make 95` occurrence and `94` `local.set` occurrences, showing successful tuple-scratch localization for the probed ninety-four-effect shape.

## Starshine coverage

File:

- `src/passes/optimize_instructions_test.mbt`

Focused test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ninety-four later effects through tuple-optimization*'
```

Result: passed `1/1`.

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(94)` and asserts that Starshine keeps the public `block`, `drop`s, every later effect call, and `local.get`, while not introducing `local.set` traffic.

## Boundaries

This is not a parity implementation slice. It records a current mismatch family:

- Binaryen performs tuple-scratch reconstruction/localization for this public multivalue shape.
- Starshine keeps the block/drop spelling until tuple-scratch reconstruction/localization exists.

Do not count this as OI-M closure. It only extends the public effect-count boundary ladder through ninety-four later effects.
