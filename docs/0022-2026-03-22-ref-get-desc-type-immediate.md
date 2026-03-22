# Ref Get Desc Type Immediate

Status: landed end-to-end `ref.get_desc` type-immediate support across WAST, lib, binary, and validation.

## Scope

Document the `ref.get_desc` follow-up surfaced by lifting `tests/spec/proposals/custom-descriptors/ref_get_desc.wast`: the instruction needed to carry its inspected type immediate through every text, IR, binary, and typecheck layer instead of being modeled as an operand-only GC opcode.

## Current Behavior

- Higher-level WAST now parses and prints `ref.get_desc <typeidx>` instead of an immediate-free form.
- `wast_to_binary_module` resolves named or numeric type indices on `ref.get_desc` and lowers them into `@lib.Instruction::ref_get_desc(TypeIdx)`.
- The lib instruction and typed-instruction surfaces now model the inspected `TypeIdx` explicitly.
- Binary encode/decode for GC subopcode `34` now writes and reads the type immediate after the opcode.
- Descriptor typechecking now:
  - resolves the descriptor-bearing struct type referenced by the inspected `TypeIdx`,
  - rejects descriptor-less targets,
  - rejects operands whose heap types do not match the inspected target,
  - computes a non-null descriptor reference result type from the target metadata,
  - preserves exactness only when the operand is bottom or already exact for the inspected type.

## Why This Slice Matters

Before this slice, the parser and IR treated `ref.get_desc` as if it had no immediate, which made higher-level text roundtrips diverge from the custom-descriptor proposal and prevented the validator from checking that the operand and inspected target type actually matched.

That was enough for lower-level instruction smoke coverage, but it blocked clean migration of the spec's `ref_get_desc.wast` fixture and left the public lib API with the wrong instruction shape.

## Correctness Constraints

- `ref.get_desc` must preserve the inspected type immediate through parse, print, lowering, binary roundtrip, and typed instruction conversion.
- Validation must reject unknown or descriptor-less inspected types instead of silently returning a placeholder result type.
- The result must always be a non-null reference to the descriptor type declared on the inspected struct type.
- Exact descriptor results are only valid when the operand is bottom or exactly the inspected type; wider operand types must produce an inexact descriptor reference result.

## Validation

- Updated parser, printer, lowering, binary, transformer, and typecheck tests to use `ref.get_desc` with an explicit type immediate.
- Added descriptor-result environment coverage proving the result type now comes from descriptor metadata rather than a fixed scalar fallback.
- Added negative typecheck coverage for descriptor-less targets and kept non-reference operand rejection on the new instruction shape.

## Performance Impact

- No meaningful runtime impact.
- The added validation work is a single descriptor-type lookup and heap-type compatibility check per `ref.get_desc`.

## Remaining Work

- The next fixture-lift blocker is legacy GC reference-type aliases such as `anyref` in `tests/spec/proposals/custom-descriptors/ref_get_desc.wast`.
- Once those aliases parse cleanly, the dedicated native harness coverage for `ref_get_desc.wast` can land as a separate slice.

## Open Questions

- Whether the next alias-parsing slice should cover only the legacy aliases needed by `ref_get_desc.wast` or proactively cover the broader custom-descriptor fixture set that still uses `anyref`, `eqref`, `structref`, and `arrayref`.
