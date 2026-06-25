# OptimizeInstructions OI-M selected trapping tuple lane with two earlier and seven later siblings

Date: 2026-06-25

## Summary

This coverage/status slice extends the OI-M selected trapping tuple-localization matrix to a one-use tuple where the selected lane is an `i32.load`, two earlier siblings are effectful `i64` calls, and seven later siblings are effectful `i32` calls.

Binaryen `version_130` preserves the selected trapping lane through tuple scratch while preserving sibling effect order:

1. drop the first earlier call;
2. drop the second earlier call;
3. store/drop the selected `i32.load` through a temp;
4. drop all seven later calls;
5. reload the selected temp.

Starshine's existing direct-HOT localizer already produces the same behavior-preserving order for this shape.

This is coverage/status evidence, not a red-first implementation slice. It expands the sibling-count matrix around the selected-lane localizer without claiming full tuple text/parser support, multi-result selected/sibling localization, or dedicated `tuple-optimization` neighbor parity.

## Evidence

- Binaryen oracle probe: `.tmp/oi-m-tuple-selected-trapping-two-earlier-seven-later-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-two-earlier-seven-later-probe.wat -o -`
- Oracle result: Binaryen emitted two earlier `drop(call)`, `drop(local.tee (i32.load ...))`, seven later `drop(call)`, and final `local.get`.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, direct-HOT test `optimize-instructions preserves selected trapping tuple.extract lane with two earlier and seven later siblings`
- Focused validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*two earlier and seven later siblings*'` passed `1/1`.

## Status

- Counted as the twenty-fourth OI-M tuple/multivalue sub-slice.
- Remaining OI-M work includes public/binary tuple fixture coverage where representable, multi-result selected/sibling tuple-scratch localization, full `simplify-locals` replay for the `InvalidChildRef` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction.
