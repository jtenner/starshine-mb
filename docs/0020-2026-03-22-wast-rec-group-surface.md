# WAST Rec Group Surface

Status: landed parser/printer/lowerer slice for higher-level WAST `rec` group authoring.

## Scope

Document the higher-level WAST `rec` group surface now supported in `src/wast`, how it closes the last missing GC type-authoring text gap from `0018` and `0019`, and what remains after the grouped surface lands.

## Current Behavior

- `wast_to_module` now models `(rec ...)` as a first-class higher-level module field instead of flattening grouped type definitions away.
- Supported grouped members in this slice are the same higher-level `type` bodies already supported outside groups:
  - `func`
  - `struct`
  - `array`
- Grouped type definitions keep the same header support as standalone type defs:
  - bare bodies,
  - `sub`,
  - `final`,
  - supertypes,
  - `descriptor`,
  - `describes`.
- Within a single grouped or standalone type header, `describes` must appear before `descriptor`; the parser now rejects the reversed order instead of silently normalizing it.
- Empty and singleton groups are preserved textually as `(rec)` and `(rec (type ...))`.
- `module_to_wast` now prints grouped type defs back as normalized `rec` blocks.
- `wast_to_binary_module` now lowers grouped type defs into real `@lib.RecType::group(...)` entries while preserving the same flat type index space used by later type uses and descriptor metadata.

## Why This Slice Matters

After `0018` and `0019`, the higher-level WAST surface could author individual GC type definitions but still could not express the grouped `(rec ...)` modules used by `type-rec` and custom-descriptor spec material. That left the final GC type-authoring gap in the higher-level text layer.

This slice closes that gap.

## Correctness Constraints

- `rec` groups must remain distinct in the AST from a flat list of standalone `type` fields because validation and authoring semantics depend on group boundaries.
- Type ids declared inside grouped defs must still pre-register into the flat explicit type index space before lowering type uses, supertypes, or descriptor metadata.
- Descriptor metadata clause order must stay source-stable enough to reject `descriptor`-before-`describes` spellings that the spec treats as malformed.
- Lowering a grouped field must produce one grouped `@lib.RecType` entry rather than multiple single entries.
- Printed `rec` blocks must roundtrip through the same higher-level parser without losing grouping structure.

## Validation

- Added parser coverage for populated and empty `rec` groups.
- Added malformed-text coverage for reversed `descriptor` / `describes` clause ordering in grouped type headers.
- Added printer roundtrip coverage proving grouped type definitions stay grouped after `module_to_wast`.
- Added lowering coverage proving grouped defs become `@lib.GroupRecType(...)` entries and that later function type uses can still reference grouped function signatures.
- Package gate for this slice: `moon test src/wast`.

## Performance Impact

- No expected runtime impact outside text parsing/printing/lowering.
- The new work is linear in grouped type-definition count and reuses the existing flat type-index registration pass.

## Remaining Work

- Move more focused custom-descriptor fixtures from binary-only coverage into higher-level text coverage now that `rec` groups are authorable.
- Decide whether the next follow-up should stay in `src/wast` fixture coverage or start lifting selected spec-harness cases directly.

## Open Questions

- Whether higher-level fixture migration should prioritize descriptor-validation negatives from `tests/spec/proposals/custom-descriptors/descriptors.wast` or first target executable positive fixtures that exercise more end-to-end runtime behavior.
