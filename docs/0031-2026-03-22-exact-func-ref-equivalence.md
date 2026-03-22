# Exact Func Ref Equivalence

## Scope
- Finish the validator follow-up exposed by the later function-typed assertions in `tests/spec/proposals/custom-descriptors/exact.wast`.
- Accept exact references to distinct but structurally equivalent defined function types.
- Leave fixture-level native harness coverage as the next separate slice.

## Current Behavior
- After landing exact struct closure equivalence, the next `exact.wast` failure is the function case where two equivalent signatures reference distinct but equivalent struct indices.
- The old exact matcher still rejected those function refs because exact closure comparison stopped before params and results.

## Correctness Constraints
- Exact function matching must compare params and results structurally, not with the normal subtype relation.
- This must preserve the existing invalid cases where exact subtype identities are different, such as `(exact sub) </: (exact super)`.
- The change should reuse the same bounded recursive type-pair traversal as the struct slice.

## Validation Plan
- Add a dedicated end-to-end WAST regression for the exact-function fixture.
- Re-run the focused regression after extending exact closure comparison to function params/results.
- Probe the broader static path with `moon run src/cmd -- spec tests/spec/proposals/custom-descriptors/exact.wast`.

## Performance Impact
- The work stays on exact-to-exact comparison paths only.
- The additional cost is a bounded walk over param/result value types reusing the existing fuel and visited-pair guard from the struct slice.

## Open Questions
- The next remaining work is fixture-level native spec-harness coverage so `exact.wast` stays pinned on the static path in CI-style tests.
- If later exact metadata graphs need cross-index equivalence, `TypeMetadata` comparison may need the same structural treatment.
