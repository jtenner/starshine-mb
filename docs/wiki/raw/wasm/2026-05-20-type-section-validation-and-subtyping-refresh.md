# WebAssembly Type-Section Validation And Subtyping Source Refresh

- Capture date: 2026-05-20
- Source family: current WebAssembly Core Specification type syntax, binary type encoding, validation, matching, and module-validation pages plus Starshine validator and proof-helper evidence.
- Primary sources checked on 2026-05-20:
  - WebAssembly Core Specification, `Syntax / Types`: <https://webassembly.github.io/spec/core/syntax/types.html> (site version shown as 2026-05-14). This anchors function/struct/array composite types, field/storage types, recursive type groups, and the rule that every recursive-group member receives a separate module type index.
  - WebAssembly Core Specification, `Binary Format / Types`: <https://webassembly.github.io/spec/core/binary/types.html> (site version shown as 2026-05-14). This anchors `rectype` opcode `0x4E`, final subtype opcode `0x4F`, non-final subtype opcode `0x50`, and the abbreviation where a bare composite type decodes as a final subtype with no supertypes.
  - WebAssembly Core Specification, `Validation / Types`: <https://webassembly.github.io/spec/core/valid/types.html> (site version shown as 2026-05-14). This anchors type-use existence, composite-type validation, recursive-type validation by first type index, and subtype validation through earlier supertypes plus composite-type matching.
  - WebAssembly Core Specification, `Validation / Matching`: <https://webassembly.github.io/spec/core/valid/matching.html> (site version shown as 2026-05-14). This anchors the subtyping/matching relation for heap, reference, result, composite, field, and storage types.
  - WebAssembly Core Specification, `Validation / Modules`: <https://webassembly.github.io/spec/core/valid/modules.html> (site version shown as 2026-05-14). This anchors the way functions and other module fields consume type indices after the type context is built.

## Durable takeaways

- The type section is the root of the module type context. Later function, table, global, tag, element, instruction, and custom-descriptor checks rely on type indices resolved from this context.
- Recursive groups are source and binary grouping constructs, but every member contributes its own flat module type index. A validator therefore needs both a group-local view for `rec` references and a normalized module-global view for later users.
- Official subtype validation is stricter than "the referenced index exists": supertypes are bounded to at most one in the current core rules, must refer to earlier type indices, must expand to subtypes, and the child composite type must match the supertype composite type.
- The matching relation is shape-sensitive: function types are contravariant in parameters and covariant in results; struct subtypes can have a compatible field prefix plus trailing fields; mutable fields are invariant; arrays compare their single field type.
- Exact references and bottom/null heap families are part of the matching story, but proposal-local custom-descriptor exactness details remain covered by the custom-descriptor source refreshes.

## Starshine implications

- `src/validate/validate.mbt` owns `validate_typesec(...)`, `validate_rectype_and_extend(...)`, `Validate for RecType`, `Validate for SubType`, descriptor metadata group checks, and exact-reference validation requiring a defined heap type.
- `validate_rectype_and_extend(...)` validates a `RecType` in a temporary recursive context, then normalizes any `RecIdx` occurrences in supertypes and descriptor metadata to absolute `TypeIdx` values before appending to `Env.global_types`.
- `src/validate/env.mbt` owns `Env.global_types`, `Env.rec_stack`, `resolve_subtype(...)`, `resolve_typeidx_subtype(...)`, `resolve_functype(...)`, and `append_rectype_types(...)`.
- `src/validate/match.mbt` owns Starshine's executable matching relation for composite, field, storage, heap, reference, external, and exact reference types. Its recursion fuel and visited-pair guards are the local safety boundary for recursive type matching.
- `src/validate_proof/rectype_index.mbt` provides proved helpers for suffix and group-relative index arithmetic. `src/validate/imports.mbt` currently imports `group_member_relative_index`, `group_relative_absolute_index`, and `suffix_start_index` for live validator use.
- `src/validate/invalid_fuzzer.mbt` has TypeSection-family strategies for out-of-range subtype supertypes, incompatible supertype shapes, and descriptor metadata on non-struct types. These are useful regression anchors for future type-section tightening.

## Current local/spec caveats to keep visible

- The inspected Starshine validator enforces supertype existence and composite-shape matching, but this refresh should not be read as proof that every official subtype well-formedness side condition is currently covered by focused tests. In particular, future parity work should add explicit tests before claiming full enforcement of the official earlier-index / single-supertype / final-supertype boundary.
- Starshine's custom-descriptor metadata validation intentionally goes beyond core WebAssembly 3.0 and must remain routed through the descriptor proposal pages. Keep the core type-section contract separate from proposal-local exact-reference and descriptor-pair behavior.
- WAST parsing/lowering can preserve and lower shapes that still require module validation. Do not treat successful text parsing of `(sub ...)`, `final`, `describes`, `descriptor`, or `rec` as semantic validation evidence.

## Follow-up questions

- Should `validate_typesec(...)` grow explicit focused regressions for the official `|supers| <= 1`, earlier-supertype, and final-supertype restrictions, or should Starshine intentionally accept a broader internal type graph? Record the choice in the focused validator page if behavior changes.
- If future custom-descriptor proposal text changes descriptor metadata placement or exact-reference rules, update this source note only for the core type-section overlap and keep proposal details in the custom-descriptor source manifests.
