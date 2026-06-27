# Optimize-instructions OI-M tuple-optimization one-hundred-eight-effect boundary

Date: 2026-06-27

## Scope

Boundary/status slice for the public `optimize-instructions` + `tuple-optimization` neighbor. It extends the public multivalue effect-count ladder to one hundred eight later non-selected effects.

This is not a parity implementation slice. It records that Binaryen can still localize the selected value through tuple scratch traffic for this generated shape, while Starshine intentionally keeps the public multivalue block/drop spelling until tuple-scratch reconstruction/localization exists.

## Binaryen oracle

Probe file: `.tmp/oi-m-tuple-optimization-one-hundred-eight-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-eight-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-eight-effects-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- Output contains `tuple.make 109` once.
- Output contains `108` `local.set` occurrences.
- The successful oracle run proves this generated fixture remains a valid Binaryen tuple-scratch localization case at one hundred eight later effects, not a Binaryen/tool validation boundary.

## Starshine status

File:

- `src/passes/optimize_instructions_test.mbt`

Test:

- `optimize-instructions intentionally keeps public multivalue block with one hundred eight later effects through tuple-optimization boundary`

The test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(108)` and asserts current Starshine output keeps:

- the multivalue `block`,
- the dropped non-selected effect results,
- all `108` side-effecting calls,
- a `local.get` selected result,
- no `local.set` traffic.

Because this is a boundary/status test for an intentionally retained mismatch, it passes before implementation and after formatting. It is explicitly not a green parity test.

## Validation

Commands run during the slice:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-eight-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-eight-effects-probe.out.wat
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*one hundred eight later effects through tuple-optimization*'
```

Broader `moon fmt`, focused OI test, `moon test src/passes`, and diff whitespace checks are recorded in the commit and handoff for this slice.

## Boundary

This slice only extends the public generated boundary ladder. It does not reduce the tuple-scratch reconstruction/localization gap, does not claim multi-result selected or sibling tuple parity, does not exercise the full-simplify `InvalidChildRef` blocker, and does not close OI-M.
