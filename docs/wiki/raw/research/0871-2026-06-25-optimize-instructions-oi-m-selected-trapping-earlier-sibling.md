# Optimize-instructions OI-M selected trapping lane with earlier sibling

Date: 2026-06-25

## Scope

This OI-M slice adds status coverage for a one-use `tuple.extract(tuple.make(...))` shape where an earlier non-selected sibling has effects and the selected lane is a trapping `i32.load`.

This is coverage/status evidence for Starshine's existing direct-HOT localizer, not a behavior implementation slice. It does not claim broader tuple-scratch parity for multi-result selected lanes, public tuple WAT parsing, full `simplify-locals` neighbor replay, or `tuple-optimization` neighbor replay.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-earlier-sibling-selected-trapping-probe.wat`

`wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-earlier-sibling-selected-trapping-probe.wat -o -` preserves the earlier call before the selected trapping load. Binaryen materializes tuple scratch as:

- `drop(call $effect)` for the earlier non-selected sibling;
- `drop(local.tee temp (i32.load ...))` for the selected trapping lane;
- `local.get temp` as the final selected value.

The key behavioral requirement is ordering: the earlier effect remains before the selected load, and the selected load is not treated as removable tuple debris.

## Starshine coverage

`src/passes/optimize_instructions_test.mbt` adds direct-HOT coverage:

- `optimize-instructions preserves selected trapping tuple.extract lane with earlier effectful sibling`

The fixture builds a one-use tuple with an earlier `i64` call sibling, a selected exact `i32.load`, and a pure trailing constant. After OI, Starshine produces a smaller but behavior-equivalent direct-HOT block with `drop(Call)` followed by the exact selected `i32.load`. That keeps the required effect-before-trap order without needing Binaryen's local.tee/drop scratch spelling because there is no later effect after the selected lane.

The first overly strict draft expected Binaryen's three-root scratch shape and failed with Starshine's two-root block. The landed test intentionally records Starshine's smaller direct-HOT shape as status coverage for existing behavior, not red-first implementation evidence.

## Validation

- Binaryen oracle probe above passed.
- Focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected trapping tuple.extract lane with earlier effectful sibling*'` passed `1/1` after the coverage expectation was narrowed to the intended Starshine shape.

## Remaining boundaries

This does not close OI-M. Public tuple text/parser coverage remains limited, multi-result selected/sibling tuple-scratch localization remains a direct-HOT boundary, full `simplify-locals` replay of the localized tuple block still has the documented `InvalidChildRef` verifier blocker, and dedicated `tuple-optimization` neighbor parity remains separate.
