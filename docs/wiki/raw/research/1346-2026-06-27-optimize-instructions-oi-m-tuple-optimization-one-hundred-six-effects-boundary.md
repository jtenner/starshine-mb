# Optimize-instructions OI-M tuple-optimization one-hundred-six-effect boundary

Date: 2026-06-27

## Scope

Boundary/status-only OI-M coverage for the public `optimize-instructions` plus `tuple-optimization` neighborhood with one selected multivalue block result followed by one hundred six non-selected effect results.

This is not a parity implementation. It extends the public effect-count ladder and keeps the tuple-scratch reconstruction/localization gap explicit.

## Fixture

The generated WAT fixture has:

- `106` side-effect-shaped result-producing helper calls (`$side_0` through `$side_105`).
- one public function returning the first value from a multivalue `block` with `107` results.
- `106` trailing `drop`s to discard every non-selected block result.

Probe path:

- `.tmp/oi-m-tuple-optimization-one-hundred-six-effects-probe.wat`

## Binaryen oracle

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-six-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-six-effects-probe.out.wat
```

Observed Binaryen `version_130` behavior:

- output contains `tuple.make 107` once.
- output contains `106` `local.set` occurrences.

Agent classification: Binaryen successfully localizes this public multivalue shape through tuple/scalar scratch locals. Starshine's retained public block/drop spelling is an open tuple-scratch reconstruction/localization parity gap, not an intentional Starshine win.

## Starshine coverage

Test added:

- `optimize-instructions intentionally keeps public multivalue block with one hundred six later effects through tuple-optimization boundary`

The test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(106)` and runs the public pipeline with `['optimize-instructions', 'tuple-optimization']`. It asserts Starshine still prints the block/drop/call/local.get spelling and does not introduce `local.set` traffic.

Because this is boundary/status coverage for intentionally unimplemented localization, the test passed before any implementation change. The test name and comments mark it as a boundary, not red-first parity implementation.

## Validation

Commands run:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-six-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-six-effects-probe.out.wat
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*one hundred six later effects through tuple-optimization*'
```

The focused boundary test passed before and after formatting. Broader `moon fmt`, `moon test src/passes`, and diff whitespace checks are recorded in the commit and handoff.

## Boundary

This slice only extends the public tuple-optimization effect-count boundary through one hundred six later effects. It does not implement multi-result selected/sibling tuple-scratch localization, full `simplify-locals` neighbor parity, or direct HOT replay of the known full-simplify `InvalidChildRef` blocker.
