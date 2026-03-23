# `string.const` Surface and Binary Section

Status: landed.

## Scope
- add `string.const` to the local public lib instruction surface
- parse, print, and lower `string.const "..."` through higher-level WAST
- validate `string.const` as a `stringref`-producing instruction
- allow `string.const` in constant-expression contexts like immutable globals
- encode and decode `string.const` through a real module string-literal section
- carry typed `string.const` through SSA conversion, destruction, and type tracking

## Current Behavior
- Raw IR now models `string.const` as `Instruction::StringConst(Bytes)`.
- Typed IR now models `string.const` as `TInstrKind::TStringConst(Bytes)`.
- Higher-level WAST accepts and prints `string.const "..."` using the existing byte-quote helpers.
- Module binary encode now emits a section `14` string table before the globals section and encodes `string.const` as `0xFB 0x82 <idx>`.
- Module binary decode resolves those indices back to literal bytes before validation and later passes see the module.
- Validator constant-expression checks now accept `string.const`, so immutable `stringref` globals can be initialized directly from literals.
- SSA now treats `string.const` as a pure nullary value producer with `stringref` result type.

## Correctness Constraints
- Binary module encode must preserve explicit string-literal section order and append newly referenced literals deterministically.
- String-literal decoding must happen before decoding globals and code, since both can contain `string.const`.
- Constant-expression checks must accept the instruction without widening other non-constant string operations.
- Typed lowering must preserve literal bytes exactly; string passes need literal identity, not only section indices.

## Validation
- WAST lowering coverage for a global and function body containing `string.const`
- Typechecker coverage for raw `string.const`
- Binary module roundtrip coverage for `string.const` plus the string-literal section
- SSA local collection, SSA destruction, and type-tracking coverage for typed `string.const`

## Performance Impact
- Module encode now scans globals and code once to collect unique string literals.
- The scan is linear in instruction count and string literal count, which is acceptable for the current compatibility slice.

## Open Questions
- The repo's existing non-null typed-ref binary prefix uses `0x64`, which collides with the proposal's abstract `stringref` byte. This slice keeps local module roundtrip working by encoding abstract `stringref` through the existing nullable-ref path and canonicalizing it back on decode.
- Before broader external stringref interop claims, reconcile that local workaround with canonical proposal byte encoding.
- The next meaningful follow-up is `StringGathering`, not more literal plumbing.
