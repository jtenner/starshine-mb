# OptimizeInstructions OI-M tuple-optimization eighty-four-effect boundary

Date: 2026-06-26

## Slice

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` multivalue neighbor ladder from eighty-three to eighty-four later non-selected effects.

It is not a parity implementation. The retained mismatch remains Starshine's missing tuple-scratch reconstruction/localization for public multivalue blocks.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-eighty-four-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-eighty-four-effects-probe.wat -o .tmp/oi-m-tuple-optimization-eighty-four-effects-probe.out.wat
```

Observed Binaryen `version_130` output:

- `tuple.make 85` count: `1`
- `local.set` count: `84`

This shows Binaryen can localize the selected first block result across eighty-four later effect calls by materializing tuple/scalar scratch traffic.

## Starshine coverage

Added focused boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with eighty-four later effects through tuple-optimization boundary`

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(84)` and asserts that current Starshine public pipeline output still contains the multivalue `block`, `drop` instructions, every effect call, and `local.get`, while not introducing `local.set` traffic.

This passing test documents current behavior and keeps the open tuple-scratch localization gap visible; it must not be read as Binaryen parity closure.

## Validation

- Binaryen oracle probe passed and produced `tuple.make 85` plus `84` `local.set` occurrences.
- Focused Starshine boundary test passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*eighty-four later effects through tuple-optimization*'` reported `1/1`.

## Retained boundaries

Starshine still lacks public tuple-scratch reconstruction/localization for this family. Broader multi-result selected/sibling localization, dedicated `tuple-optimization` neighbor parity, and full `simplify-locals` tuple traffic remain open.
