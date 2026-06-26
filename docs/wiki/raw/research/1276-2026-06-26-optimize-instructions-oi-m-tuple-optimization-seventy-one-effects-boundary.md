# OptimizeInstructions OI-M tuple-optimization seventy-one-effect boundary

Date: 2026-06-26

## Summary

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` multivalue effect-count ladder to a block with seventy-one later non-selected effects.

Binaryen `version_130` localizes the public multivalue block through tuple scratch plus scalar locals. Starshine still keeps the public `block` / `drop` / `call` / `local.get` spelling because local tuple-scratch reconstruction/localization is not implemented. This is intentionally recorded as an open OI-M parity gap, not closure.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-seventy-one-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-seventy-one-effects-probe.wat -o .tmp/oi-m-tuple-optimization-seventy-one-effects-probe.out.wat
```

The Binaryen output contains `tuple.make 72` and `71` scalar `local.set` occurrences, proving Binaryen can localize through seventy-one later non-selected side-effecting siblings in this public tuple-optimization neighbor.

## Starshine coverage

Changed file:

- `src/passes/optimize_instructions_test.mbt`: added boundary/status test `optimize-instructions intentionally keeps public multivalue block with seventy-one later effects through tuple-optimization boundary`, using `optimize_instructions_tuple_optimization_effect_boundary_fixture(71)` and asserting Starshine keeps the public block/drop/call/local.get spelling without introducing `local.set` traffic.

This test is boundary/status coverage. It passed immediately because it locks Starshine's current no-localization behavior while documenting Binaryen's stronger tuple-scratch localization.

## Boundary classification

Agent classification: parity gap / implementation boundary. Both tools produce valid modules, but Starshine is missing Binaryen's tuple-scratch reconstruction/localization for this public multivalue neighbor. Do not classify this as a Starshine win or semantic-safe closure.

Still open:

- tuple-scratch reconstruction/localization for public multivalue block neighbors;
- multi-result selected/sibling localization;
- `simplify-locals` and dedicated `tuple-optimization` neighbor parity beyond boundary enumeration;
- the direct-HOT full-simplify `InvalidChildRef(3, 0, 0)` blocker noted by earlier OI-M research.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 72` with `71` `local.set` occurrences.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*seventy-one later effects through tuple-optimization*'` passed (`1/1`).
- Final slice validation is recorded in the commit that cites this note.
