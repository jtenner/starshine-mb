# Exact Custom Descriptor Static Harness

## Scope
- Pin `tests/spec/proposals/custom-descriptors/exact.wast` on the native static spec-harness path.
- Close the remaining custom-descriptor exactness follow-up after the exact struct/function validator slices.

## Current Behavior
- The static validator path for `exact.wast` now passes after the exact struct and exact func closure-equivalence fixes.
- Before this slice, that broader fixture was only probed ad hoc through the CLI spec command, not covered by a committed native harness test.

## Correctness Constraints
- The harness must treat `exact.wast` as a static fixture, not skip it as runtime-only.
- The test should assert both success and a non-zero checked-command count, matching the existing fixture-harness conventions.
- Existing mixed-runtime coverage for `ref_get_desc.wast` should remain separate.

## Validation Plan
- Add a dedicated native `src/wast/spec_harness.mbt` test for `tests/spec/proposals/custom-descriptors/exact.wast`.
- Run `moon test src/wast/spec_harness.mbt --target native -F '*exact custom descriptor static fixture*'`.

## Performance Impact
- None beyond one more native test over an already-supported fixture.

## Open Questions
- None for the exact-reference custom-descriptor path in the higher-level WAST/static validator stack.
