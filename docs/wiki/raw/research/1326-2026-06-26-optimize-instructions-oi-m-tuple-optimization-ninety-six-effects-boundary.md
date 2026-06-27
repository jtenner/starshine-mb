# Optimize Instructions OI-M Tuple-Optimization Ninety-Six-Effect Boundary

Date: 2026-06-26

## Scope

Boundary/status slice for the public `optimize-instructions` + `tuple-optimization` neighborhood. This extends the generated public multivalue effect-count ladder from ninety-five to ninety-six later non-selected effects.

This is not a parity implementation slice. It records a retained tuple-scratch reconstruction/localization gap.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-ninety-six-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ninety-six-effects-probe.wat -o .tmp/oi-m-tuple-optimization-ninety-six-effects-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- The probe validates.
- Binaryen localizes the public multivalue block through `tuple.make 97`.
- The output contains one `tuple.make 97` spelling and ninety-six `local.set` spellings.

## Starshine coverage

Added focused boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with ninety-six later effects through tuple-optimization boundary`

The test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(96)`, runs the public pass sequence `optimize-instructions` then `tuple-optimization`, and asserts that Starshine still preserves:

- the public `block` spelling;
- `drop` traffic for non-selected results;
- all ninety-six side-effect calls;
- `local.get` spelling;
- no introduced `local.set` traffic.

This passed immediately because it is a status/boundary slice for known retained behavior, not a red-first implementation gap.

## Retained boundary

Binaryen reconstructs/localizes the multivalue block via tuple scratch traffic; Starshine still keeps the public multivalue block/drop/call/local.get spelling. Treat this as an open OI-M tuple-scratch localization gap, not an accepted behavior-parity closeout.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 97` once plus ninety-six `local.set` occurrences.
- Focused Starshine boundary test passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ninety-six later effects through tuple-optimization*'`.

## Status

The public tuple-optimization effect-count boundary ladder now reaches ninety-six later non-selected effects. Overall OI-M and overall `optimize-instructions` parity remain incomplete.
