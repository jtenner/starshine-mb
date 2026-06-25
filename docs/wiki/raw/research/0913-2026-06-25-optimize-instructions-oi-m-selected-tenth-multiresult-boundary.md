# OptimizeInstructions OI-M selected-tenth multi-result tuple boundary

Date: 2026-06-25

## Summary

This boundary/status slice locks the next OI-M selected-child multi-result tuple boundary.

Binaryen `version_130` localizes the tenth scalar result selected from a multi-result tuple child through a tuple scratch local and a scalar temp. Starshine's current direct-HOT tuple.extract localizer only proves selected children that produce a single result, so Starshine intentionally keeps the direct `tuple.extract(tuple.make(...))` spelling for this multi-result selected-child shape.

This is boundary/status evidence, not a red-first implementation slice. It prevents accidentally generalizing the covered single-result selected-child localizer, and extends the previous selected-first through selected-ninth multi-result boundaries by one lane.

## Evidence

- Binaryen oracle probe: `.tmp/oi-m-tuple-multiresult-selected-tenth-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-tenth-probe.wat -o -`
- Oracle result: Binaryen introduced a tuple scratch local for the imported `(result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64)` call and a scalar temp for the selected tenth `i64` lane before returning the temp.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, direct-HOT test `optimize-instructions intentionally keeps tuple.extract with multi-result selected tenth lane boundary`
- Focused validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected tenth lane*'` passed `1/1`.

## Status

- Counted as the thirty-fourth OI-M tuple/multivalue sub-slice.
- Remaining OI-M work includes a real multi-result selected/sibling tuple-scratch localizer, public/binary tuple fixture coverage where representable, full `simplify-locals` replay/reduction for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction.
