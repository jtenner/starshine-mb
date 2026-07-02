# OptimizeInstructions OI-M selected-ninth multi-result tuple boundary

Date: 2026-06-25

## Summary

This former boundary/status slice was superseded by the 2026-07-02 arity-9 implementation slice.

Binaryen `version_130` localizes the ninth scalar result selected from a multi-result tuple child through a tuple scratch local and a scalar temp. The 2026-07-02 follow-up refreshed the probe to `.tmp/oi-m-tuple-multiresult-selected-ninth-probe.binaryen.20260702.wat`, changed the direct-HOT test to a red-first positive expectation, and taught Starshine's direct one-use tuple.extract localizer to store nine selected-child scalar results in stack-pop order before reloading the selected ninth lane.

This note is retained as source/probe history. It no longer defines an active boundary for direct one-use arity-9 selected children; after the later arity-16 slice, arity 17+ remains the next selected-child tuple-scratch boundary.

## Evidence

- Binaryen oracle probe: `.tmp/oi-m-tuple-multiresult-selected-ninth-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-ninth-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-ninth-probe.binaryen.20260702.wat`
- Oracle result: Binaryen introduced a tuple scratch local for the imported `(result i32 i64 f32 f64 i32 i64 f32 f64 i32)` call and a scalar temp for the selected ninth `i32` lane before returning the temp.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, direct-HOT test `optimize-instructions localizes ninth lane from nine-result selected tuple child`
- Red-first validation: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*nine-result selected tuple child*'` failed `0/1` before implementation because the result stayed `TupleExtract`, then passed `1/1` after `src/passes/optimize_instructions.mbt` admitted selected-child arity 9.

## Status

- Superseded for direct one-use arity-9 selected-child localization by the 2026-07-02 implementation slice.
- Remaining OI-M work includes selected-child arities 17+, multi-result non-selected sibling tuple-scratch localization, multi-use tuple producers, public/binary tuple fixture coverage where representable, full `simplify-locals` replay/reduction for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, control/EH sibling localization, and broader tee/drop reconstruction.
