# Optimize-instructions OI-M selected trapping tuple lane coverage

Date: 2026-06-25

## Scope

This OI-M slice adds focused coverage for the selected child of one-use `tuple.extract(tuple.make(...))` when that selected lane may trap. Earlier OI-M trapping coverage covered non-selected trapping siblings; this slice proves the selected trapping lane itself is preserved rather than treated as removable tuple debris.

This is coverage/status evidence for the existing direct-HOT localizer, not a new tuple-scratch implementation.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-selected-trapping-probe.wat`

`wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-probe.wat -o -` preserves the selected `i32.load` through tuple scratch:

- `local.tee` stores the selected load result;
- `drop` preserves the selected lane evaluation in the tuple-scratch spelling;
- `local.get` returns the selected value.

Starshine does not need to match that tuple-scratch output shape for direct-HOT semantic coverage; it may forward to the selected `i32.load` as long as the trapping load remains evaluated exactly as the returned value.

## Starshine coverage

`src/passes/optimize_instructions_test.mbt` adds:

- `optimize-instructions preserves selected trapping tuple.extract lane`

The direct-HOT fixture selects lane `0` from a one-use tuple whose selected child is an exact `i32.load` and whose remaining siblings are pure constants. After `optimize-instructions`, Starshine must leave an exact `i32.load` as the root result.

The focused test passed immediately after expectation calibration, so no implementation change was needed. This is coverage/status evidence for an already implemented selected-lane forwarding path.

## Validation

- Binaryen oracle probe above passed.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected trapping tuple.extract lane*'` passed `1/1`.

## Remaining boundaries

This does not close OI-M. Public tuple text/binary fixture coverage, tuple-scratch localization for multi-result selected children and siblings, broader multivalue block reconstruction, multi-use tuple extraction, full `simplify-locals` and `tuple-optimization` public parity, and the recorded direct-HOT full-neighbor verifier failure (`InvalidChildRef(3, 0, 0)`) remain open.
