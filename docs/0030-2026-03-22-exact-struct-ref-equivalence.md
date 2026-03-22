# Exact Struct Ref Equivalence

## Scope
- Land the next `tests/spec/proposals/custom-descriptors/exact.wast` validator slice after passive typed empty `elem` support.
- Accept exact references to distinct but structurally equivalent defined struct types.
- Keep the slice narrow enough that exact function-type equivalence remains separate follow-up work.

## Current Behavior
- Exact reference matching currently treats `(ref (exact x))` and `(ref (exact y))` as compatible only when their lowered heap types are literally identical.
- That rejects modules where two top-level struct types expand to the same closure but are named by different type indices.
- The first remaining failure in `exact.wast` is the exact-struct case with:
  - `(type (struct (field (ref 0))))`
  - `(type (struct (field (ref 1))))`

## Correctness Constraints
- Exact matching must still reject subtype-vs-supertype cases such as `(exact sub) </: (exact super)`.
- Structural equivalence must compare the full defined type closure, not just the outer constructor.
- Recursive references need a cycle guard so equivalent recursive shapes can be compared without infinite descent.
- This slice should not change exact function matching yet.

## Validation Plan
- Add an end-to-end WAST regression that lowers and validates the exact-struct fixture directly.
- Re-run that focused regression after the matcher change.
- Leave the broader `exact.wast` fixture for the next slice, where the remaining failure boundary is exact function equivalence.

## Performance Impact
- Exact heap-type equivalence adds recursive work only on exact-to-exact comparison paths.
- The implementation uses the existing type-count-sized fuel budget plus a visited-pair guard, so worst-case work remains bounded by module type graph size.

## Open Questions
- Exact function-type equivalence still needs the same closure-comparison treatment for params and results.
- If later descriptor-bearing exact types use distinct but equivalent descriptor graphs, metadata equality may need the same structural treatment instead of raw index equality.
