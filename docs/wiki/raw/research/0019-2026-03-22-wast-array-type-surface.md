# WAST Array Type Surface

Status: landed parser/printer/lowerer slice for higher-level GC `array` type definitions.

## Scope

Document the higher-level WAST `array` type-definition surface now supported in `src/wast`, its interaction with the earlier `struct` type slice, and the remaining text-surface gap after this change.

## Current Behavior

- `wast_to_module` now models higher-level `array` type bodies alongside `func` and `struct`.
- Supported `array` spellings in this slice are:
  - `(array i8)`
  - `(array i16)`
  - `(array (ref ...))`
  - `(array (mut ...))`
- The same higher-level type-definition header support now applies across both `struct` and `array` bodies:
  - bare `type` bodies,
  - `sub`,
  - `final`,
  - supertypes,
  - `descriptor`,
  - `describes`.
- `module_to_wast` prints normalized `array` type definitions back to parseable text.
- `wast_to_binary_module` lowers those `array` definitions into real `@lib.CompType::array(...)` entries with the expected field mutability and packed/reference storage.

## Why This Slice Matters

After `0018`, the higher-level WAST surface could author descriptor-bearing `struct` fixtures but still could not express the `array` type definitions that appear throughout GC and custom-descriptor spec material. That left the type surface asymmetrical and kept part of the descriptor corpus text-inexpressible at the higher level.

This slice closes that asymmetry.

## Correctness Constraints

- `array` element storage must preserve packed-vs-value encoding exactly.
- `sub`-wrapped array types must remain distinct from bare array type defs because they lower to different subtype forms.
- Metadata resolution still has to happen against the explicit type-definition index space before later implicit function-type synthesis.
- Printed `array` type definitions must roundtrip through the same parser without changing mutability or packed storage.

## Validation

- Added parser coverage for bare and `sub`-wrapped `array` type definitions with descriptor metadata.
- Added printer roundtrip coverage for normalized `array` type-definition output.
- Added lowering coverage proving `array` type defs lower into the expected `CompType::array(...)` entries with descriptor/describes metadata.
- Package gate for this slice: `moon test src/wast`.

## Remaining Work

- Lift more custom-descriptor fixtures into higher-level text coverage now that `rec` groups are also modeled.

## Open Questions

- Whether the next slice should directly add higher-level `rec` group syntax, or first target a smaller fixture-driven subset if the full group surface is broader than currently needed.
