# WebAssembly GC Type And Custom-Descriptor Source Snapshot

- Capture date: 2026-05-13
- Sources:
  - WebAssembly Core Specification, `Types — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/syntax/types.html>
  - WebAssembly Core Specification, `Text Types — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/text/types.html>
  - WebAssembly custom-descriptors proposal overview, `WebAssembly/custom-descriptors` main branch: <https://github.com/WebAssembly/custom-descriptors/blob/main/proposals/custom-descriptors/Overview.md>

## Durable Takeaways

- The current core spec treats `func`, `struct`, and `array` as the three composite type forms. Structs are heterogeneous indexed aggregates; arrays are homogeneous dynamic-index aggregates; functions classify parameter/result signatures.
- Recursive types group mutually recursive composite types. Each subtype can declare supertypes and `final`; every member of a recursive group receives its own module type index.
- The text format keeps `(rec ...)` as the explicit grouped form, while a single type may omit the outer `rec` abbreviation. This is the source-level reason Starshine must preserve rec grouping in the WAST AST while resolving type uses through flat type indices at lowering time.
- The custom-descriptors proposal adds `describes` and `descriptor` metadata to type definitions and defines additional subtype consistency rules for described/descriptor pairs. The proposal currently states that those clauses are restricted to struct type definitions, with a note that this may be relaxed later.
- The same proposal introduces descriptor-specific allocation operators (`struct.new_desc`, `struct.new_default_desc`) and exact heap types to prevent allocating a base type with a descriptor for an incompatible subtype.

## Starshine Reconciliation Notes

- Starshine's WAST front end already supports `func`, `struct`, `array`, `sub`, `final`, explicit `(rec ...)`, type identifiers, and numeric type indices in the higher-level text path.
- Starshine stores custom descriptor metadata generically on `TypeDef`, and the current WAST lowering tests include array metadata fixtures. That is broader than the current proposal's struct-only restriction. Treat array metadata support as a local/proposal-tracking compatibility surface, not as evidence that the proposal accepts descriptors on arrays.
- Starshine's lowering invariant should remain: preserve `RecField` grouping in `src/wast/parser.mbt` / `src/wast/module_wast.mbt`, but compute function type-use indices from the flattened type space in `src/wast/lower_to_lib.mbt`.

## Follow-up Questions

- If the upstream custom-descriptors proposal keeps the struct-only restriction, decide whether Starshine should reject descriptor metadata on non-struct WAST type definitions or keep the broader parser/lowering surface only for internal fixtures.
- If the proposal relaxes that restriction, refresh this source snapshot and the WAST GC authoring page with the exact accepted body forms.
