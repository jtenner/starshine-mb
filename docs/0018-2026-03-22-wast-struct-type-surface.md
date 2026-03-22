# WAST Struct Type Surface

Status: landed parser/printer/lowerer slice for GC `struct` type definitions and descriptor metadata.

## Scope

Document the higher-level WAST type-definition surface now supported in `src/wast`, what remains out of scope, and the validation evidence for this slice.

## Current Behavior

- `wast_to_module` now parses `type` definitions with either a bare body or a `sub` wrapper.
- Supported type bodies in this slice are:
  - `func`
  - `struct`
- Supported subtype/header clauses in this slice are:
  - `sub`
  - `final`
  - zero or more named / numeric supertypes
  - `descriptor`
  - `describes`
- Supported `struct` field storage syntax in this slice is:
  - immutable value fields like `(field i32)` or `(field (ref $t))`
  - mutable value fields like `(field (mut i64))`
  - packed storage spellings `i8` / `i16`
- `module_to_wast` now prints those type definitions back in a normalized text form.
- `wast_to_binary_module` now lowers those type definitions into real `@lib.RecType` / `@lib.SubType` entries, including forward references through `descriptor` / `describes`.
- Descriptor-bearing module fixtures are now covered at module level, not only via direct instruction lowering tests.

## Deliberate Non-Scope

- `rec` group authoring is still not modeled in the higher-level WAST AST.
- This slice does not change the binary parser or spec-harness policy for the broader custom-descriptors corpus.

## Correctness Constraints

- Bare `(type ... (struct ...))` and wrapped `(type ... (sub ... (struct ...)))` must remain distinct in the AST because the latter is a non-final subtype surface.
- Forward metadata references must resolve against the full explicit type-definition index space before lowering function-local implicit type uses.
- Struct field lowering must preserve mutability and reference nullability exactly.
- Normalized printing must remain parseable by the same higher-level parser.

## Validation

- Added parser coverage for mixed bare and `sub`-wrapped `struct` type definitions with `descriptor` / `describes` metadata and ref-bearing fields.
- Added printer roundtrip coverage for normalized `struct` type-definition output.
- Added lowering coverage proving:
  - forward descriptor references resolve,
  - metadata reaches the lowered type section,
  - descriptor-bearing `struct.new_desc` fixtures can be authored end to end.
- Package gate for this slice: `moon test src/wast`.

## Performance Impact

- No expected runtime impact outside text parsing/printing/lowering.
- The new work is proportional to explicit `type` field count and field count, with no new whole-module analysis.

## Remaining Work

- Add `rec` group authoring if higher-level fixtures need recursive text modules instead of binary-only coverage.
- Expand spec-oriented descriptor fixtures once the remaining type-surface pieces land.

## Open Questions

- Whether custom-descriptor text fixtures should move into the spec harness incrementally or stay as focused internal `src/wast` coverage until `rec` groups are available.
