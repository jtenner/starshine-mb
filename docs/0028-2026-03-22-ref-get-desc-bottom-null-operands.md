Status: landed `ref.get_desc` compatibility for bottom-null operands and cleared the mixed-runtime `ref_get_desc.wast` static fixture.

## Scope

Document the follow-up after exact `ref.null` preservation: `ref.get_desc` and general validation still rejected bottom refs like `ref.null none` when a module expected a nullable defined struct or array type. This slice aligns bottom-ref matching with the custom-descriptor spec cases and lifts the native static harness over `tests/spec/proposals/custom-descriptors/ref_get_desc.wast`.

## Current Behavior

Before this slice:

- `Env::descriptor_result_type(...)` compared operand compatibility too narrowly.
- `Match::matches(HeapType::abs(none), HeapType::new($t), env)` returned false for defined struct and array targets.
- As a result, valid forms like `(ref.get_desc $a (ref.null none))` failed.
- The same gap also broke const-expression validation for globals and function bodies returning `ref.null none` against nullable defined refs.

After this slice:

- `descriptor_result_type(...)` accepts operands that match either the inspected nullable ref or the exact inspected nullable ref, while still producing exact descriptor results only for exact-compatible operands.
- Heap-type matching now treats `none` as a subtype of defined struct and array types, and `nofunc` as a subtype of defined function types.
- The mixed-runtime custom-descriptor harness now passes `ref_get_desc.wast` on the native static path.

## Correctness Constraints

- `none` must match defined struct and array references, but not defined function references.
- `nofunc` must match defined function references, but not defined struct or array references.
- Exact descriptor results must still be reserved for exact-compatible operands, including `none <: (exact t)` where the spec permits it.

## Validation Plan

- `moon test src/validate/env_tests.mbt -F '*projects DefType*'`
- `moon test src/validate/match.mbt -F '*bottom refs against compatible defined types*'`
- `moon test src/wast -F '*ref.null none through ref.get_desc*'`
- `moon test src/wast/spec_harness.mbt --target native -F '*mixed-runtime custom descriptor fixtures*'`

## Performance Impact

- No meaningful runtime impact expected.
- The change adds a small amount of subtype-shape logic when the left-hand heap type is one of the bottom abstract refs and the right-hand side is a defined type index.

## Open Questions

- The mixed-runtime `ref_get_desc.wast` fixture is now green; the next custom-descriptor fixture lift still needs to be chosen from the remaining runtime-mixed proposals.
