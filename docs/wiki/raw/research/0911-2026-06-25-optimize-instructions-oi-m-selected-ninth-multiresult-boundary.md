# OptimizeInstructions OI-M selected-ninth multi-result tuple boundary

Date: 2026-06-25

## Summary

This boundary/status slice locks the next OI-M selected-child multi-result tuple boundary.

Binaryen `version_130` localizes the ninth scalar result selected from a multi-result tuple child through a tuple scratch local and a scalar temp. After the 2026-07-02 arity-8 follow-up, Starshine's current direct-HOT tuple.extract localizer proves direct one-use selected children with one through eight scalar results, so Starshine intentionally keeps the direct `tuple.extract(tuple.make(...))` spelling for this ninth-result selected-child shape.

This remains boundary/status evidence, not a red-first implementation slice. It prevents accidentally generalizing the covered selected-child localizer beyond its source-backed arity-8 cap, and extends the previous selected-first through selected-eighth implementation boundary by one lane.

## Evidence

- Binaryen oracle probe: `.tmp/oi-m-tuple-multiresult-selected-ninth-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-ninth-probe.wat -o -`
- Oracle result: Binaryen introduced a tuple scratch local for the imported `(result i32 i64 f32 f64 i32 i64 f32 f64 i32)` call and a scalar temp for the selected ninth `i32` lane before returning the temp.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, direct-HOT test `optimize-instructions intentionally keeps tuple.extract with multi-result selected ninth lane boundary`
- Last focused validation for this boundary: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected ninth lane*'` passed `1/1`. The boundary should be refreshed with a red-first positive test before implementing arity 9.

## Status

- Supersedes the eighth-lane boundary as the next selected-child arity boundary after the 2026-07-02 arity-8 implementation slice.
- Remaining OI-M work includes selected-child arities 9+, multi-result non-selected sibling tuple-scratch localization, multi-use tuple producers, public/binary tuple fixture coverage where representable, full `simplify-locals` replay/reduction for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, control/EH sibling localization, and broader tee/drop reconstruction.
