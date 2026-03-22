# WAST Rec Group Flat Type Indices

Status: landed flattened implicit functype indexing after grouped `rec` entries.

## Scope

Document the lowering fix needed after the imported-global parser slice: when higher-level WAST appends implicit function types after grouped `(rec ...)` fields, the appended type index must use the flattened subtype count, not the raw number of rec entries.

## Current Behavior

- Implicit functypes synthesized from inline function signatures now append after the full flattened type space.
- Grouped rec entries no longer collapse later function-section type indices.
- For a module like:
  - `(rec (type $a ...) (type $b ...))`
  - followed by an inline-signature function
  the appended functype now lands at flat type index `2`, not rec-entry index `1`.
- Validation now sees those later function-section entries as actual function types instead of non-function grouped subtype members.

## Why This Slice Matters

After imported globals started parsing cleanly, `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` advanced into validation and failed immediately because the first module’s inline-signature functions pointed at the wrong type indices once a grouped `rec` preceded them.

The issue was not descriptor-specific logic; it was the shared lowering helper using `ctx.type_recs.length()` instead of the flattened subtype count when appending implicit function types.

## Correctness Constraints

- Appended function types must use the same flat index space as explicit type references.
- Grouped `rec` fields count by contained subtypes, not by rec-entry containers.
- Existing matching/dedup logic for previously appended function types must keep working against the same flat numbering.

## Validation

- Added focused coverage in `src/wast/rec_group_typeuse_test.mbt`.
- Targeted red-to-green gate during landing:
  - `moon test src/wast -F '*implicit functypes after rec groups*'`
- Follow-up confirmation after the slice:
  - `moon test src/wast/spec_harness.mbt --target native -F '*mixed-runtime custom descriptor fixtures*'`
  - the fixture advanced past the `funcsec` type-index failure and exposed the remaining `ref.get_desc` operand/result semantics.

## Performance Impact

- No meaningful runtime impact.
- The new flattened-count helper is a short scan over existing rec entries during implicit functype append paths.

## Remaining Work

- `ref_get_desc.wast` now fails on the remaining null/exact descriptor-result cases.
- Finishing that path likely requires carrying exactness for `ref.null (exact ...)` through the lowered instruction surface, not just parser/lowering fixes.

## Open Questions

- Whether the exact-`ref.null` follow-up should be modeled as a focused WAST-only workaround or as the broader lib-instruction/API change that would preserve exact ref-null result types end to end.
