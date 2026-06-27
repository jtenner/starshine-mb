# Optimize-instructions OI-M tuple-optimization one-hundred-nine-effect boundary

Date: 2026-06-27

## Scope

This is boundary/status coverage for the public `optimize-instructions` plus `tuple-optimization` neighbor on a multivalue block with one selected value followed by one hundred nine later non-selected effect calls.

It does not implement tuple-scratch reconstruction. The retained mismatch remains the known OI-M tuple/multivalue localization gap: Binaryen can materialize tuple scratch plus scalar locals for this public pipeline shape, while Starshine currently keeps the multivalue `block` / `drop` spelling.

## Binaryen oracle

Probe file: `.tmp/oi-m-tuple-optimization-one-hundred-nine-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-nine-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-nine-effects-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- The command succeeds on the generated public WAT fixture.
- The output contains `tuple.make 110` once.
- The output contains `109` `local.set` occurrences.

This is evidence that Binaryen successfully localizes the probed tuple/multivalue shape at this effect count. It is not evidence that Starshine has closed the tuple-scratch reconstruction gap.

## Starshine coverage

File:

- `src/passes/optimize_instructions_test.mbt`

Test:

- `optimize-instructions intentionally keeps public multivalue block with one hundred nine later effects through tuple-optimization boundary`

The test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(109)` and runs the public pipeline `['optimize-instructions', 'tuple-optimization']`.

Assertions intentionally lock current Starshine boundary behavior:

- the pretty-printed output still contains `block`;
- the output still contains `drop`;
- every effect call `Func 0` through `Func 108` remains present;
- the output still contains `local.get`;
- the output does not introduce `local.set` traffic.

## Validation

Commands run during the slice:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-nine-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-nine-effects-probe.out.wat
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*one hundred nine later effects through tuple-optimization*'
```

The focused boundary/status test passed before implementation because this slice records current supported boundary behavior rather than changing tuple localization. Broader `moon fmt`, focused OI test, `moon test src/passes`, and diff whitespace checks are recorded in the commit and handoff for this slice.

## Boundary

The test is not a parity implementation and should not be treated as OI-M closure. The open implementation work is still safe tuple-scratch reconstruction/localization for selected/sibling multivalue shapes across `optimize-instructions`, `tuple-optimization`, and related `simplify-locals` neighbor pipelines.
