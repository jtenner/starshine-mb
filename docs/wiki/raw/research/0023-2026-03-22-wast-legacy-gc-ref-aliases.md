# WAST Legacy GC Ref Aliases

Status: landed legacy GC reference-type alias parsing and lowering in the higher-level WAST surface.

## Scope

Document the compatibility follow-up needed by mixed-runtime custom-descriptor fixtures: the higher-level WAST parser now accepts older GC reference aliases and lowers them onto the existing typed-ref model instead of rejecting them as unknown value types.

## Current Behavior

- Higher-level WAST now accepts legacy aliases:
  - `anyref`
  - `eqref`
  - `i31ref`
  - `structref`
  - `arrayref`
  - `nullref`
- The parser also now recognizes abstract heap keywords `struct` and `array` inside:
  - `(ref struct)`
  - `(ref null struct)`
  - `(ref array)`
  - `(ref null array)`
  - `ref.null struct`
  - `ref.null array`
- These spellings normalize onto the existing `TypedFuncRef(...)` / `NonNullTypedFuncRef(...)` AST forms rather than introducing a second parallel representation.
- Lowering now maps the new abstract heap refs onto the corresponding lib abstract heap types:
  - `any`
  - `eq`
  - `i31`
  - `struct`
  - `array`
  - `none`

## Why This Slice Matters

After the `ref.get_desc` immediate fix, `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` advanced far enough to expose a simpler front-end compatibility gap: the fixture still uses legacy aliases like `anyref`, which the higher-level parser rejected even though the lower layers already model the equivalent abstract heap types.

Landing this compatibility layer keeps the normalized text surface modern while letting higher-level fixture migration continue.

## Correctness Constraints

- Legacy aliases must lower to the same abstract heap types as their explicit `(ref null ...)` spellings.
- `struct` and `array` heap keywords must be valid only in heap-type positions, not as standalone numeric or structural value types.
- Printing may normalize aliases back to the canonical explicit ref spellings; source compatibility matters here, not textual preservation of the alias token.

## Validation

- Added parser coverage for the legacy aliases plus `ref.null struct` / `ref.null array`.
- Added lowering coverage proving the aliases map to the expected lib abstract heap types in tables and function signatures.
- Package gate for this slice: `moon test src/wast`.

## Performance Impact

- No meaningful runtime impact.
- The parser cost is a small reserved-keyword lookup in value-type positions.

## Remaining Work

- `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` now parses past the alias layer and fails later on missing higher-level GC accessor instruction coverage, starting with folded `struct.get`.
- The next slice should add those missing instruction forms and then lift the fixture into the native harness.

## Open Questions

- Whether the next instruction-surface slice should target only the accessor forms needed by `ref_get_desc.wast` or sweep in the rest of the still-missing higher-level GC instruction family while the AST surface is already open.
