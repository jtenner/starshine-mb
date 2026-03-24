Status: landed exact `ref.null` immediates end to end through the lowered lib model, validation, and binary roundtrip.

## Scope

Record the first `ref_get_desc.wast` follow-up after grouped `rec` indices: preserve exact nullable reference immediates on `ref.null`, so higher-level WAST can lower and validate `(ref.null (exact $t))` without silently degrading it to an inexact nullable ref.

## Current Behavior

Before this slice:

- Higher-level WAST already parsed exact nullable refs in value types and instruction immediates.
- Lowering converted `ref.null` immediates into `@lib.Instruction::RefNull(HeapType)`, which discarded exactness.
- Typechecking therefore pushed an inexact nullable ref even when the source text spelled `(ref.null (exact $t))`.
- `ref.get_desc` on an exact nullable operand produced an inexact descriptor result and failed exact-result fixtures.

After this slice:

- `@lib.Instruction::RefNull` and the lifted validation/lowering path both carry a full `@lib.RefType`.
- WAST lowering preserves exact nullable ref-null immediates.
- Validation now validates the `RefType` immediate itself.
- Binary encode/decode for opcode `0xD0` preserves exact nullable ref-null immediates through roundtrip.

## Correctness Constraints

- `ref.null` must always remain nullable, even if a caller constructs it from a non-null `RefType`.
- Existing inexact heap-type callers should keep working through the convenience `ref_null(HeapType)` constructors.
- Exact nullable refs must survive text lowering, tree conversion, typechecking, and binary roundtrip without degrading to inexact refs.

## Validation Plan

- `moon test src/wast -F '*exact ref.null*'`
- Follow-up fixture gate:
  - `moon test src/wast/spec_harness.mbt --target native -F '*mixed-runtime custom descriptor fixtures*'`

## Performance Impact

- No meaningful runtime impact expected.
- The change only widens the in-memory instruction immediate for `ref.null` and threads that richer type through existing validation/transform passes.

## Open Questions

- `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` still fails on the remaining descriptor-compatibility rule for bottom null operands like `ref.null none`.
- The next slice should likely tighten `Env::descriptor_result_type(...)` to compare operand and inspected types at the `RefType` level instead of only comparing raw heap types.
