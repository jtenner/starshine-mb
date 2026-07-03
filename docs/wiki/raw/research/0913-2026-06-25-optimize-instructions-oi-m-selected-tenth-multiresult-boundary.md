# OptimizeInstructions OI-M selected-tenth multi-result tuple boundary

Date: 2026-06-25

## Summary

This boundary/status slice originally locked the next OI-M selected-child multi-result tuple boundary. It is now superseded for the direct one-use arity-10 selected-child shape by the 2026-07-02 arity-10 implementation slice.

Binaryen `version_130` localizes the tenth scalar result selected from a multi-result tuple child through a tuple scratch local and a scalar temp. After the 2026-07-02 arity-10 follow-up, Starshine's current direct-HOT tuple.extract localizer proves direct one-use selected children with one through ten scalar results, so this note is no longer an active boundary for direct one-use arity 10.

It remains useful as source-backed history and as a reminder that arity 19+ and generalized tuple-scratch reconstruction are still outside the implemented subset after the later arity-18 slice.

## Evidence

- Binaryen oracle probe: `.tmp/oi-m-tuple-multiresult-selected-tenth-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-tenth-probe.wat -o -`
- Oracle result: Binaryen introduced a tuple scratch local for the imported `(result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64)` call and a scalar temp for the selected tenth `i64` lane before returning the temp.
- Starshine implementation test: `src/passes/optimize_instructions_test.mbt`, direct-HOT test `optimize-instructions localizes tenth lane from ten-result selected tuple child`
- Red-first focused validation before the arity-10 implementation: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*ten-result selected tuple child*'` failed `0/1` because the shape stayed `TupleExtract`.
- Post-implementation focused validation: the same focused command passed `1/1`; `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*selected eleventh lane*'` passed as a boundary before the later arity-11 implementation slice superseded that boundary.

## Status

- Superseded for direct one-use arity 10 by the 2026-07-02 arity-10 implementation slice.
- Remaining OI-M work includes selected-child arities 25+, multi-result non-selected sibling tuple-scratch localization, multi-use tuple producers, public/binary tuple fixture coverage where representable, full `simplify-locals` replay/reduction for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, control/EH sibling localization, and broader tee/drop reconstruction.
