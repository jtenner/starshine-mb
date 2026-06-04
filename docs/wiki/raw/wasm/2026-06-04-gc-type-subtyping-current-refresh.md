# WebAssembly GC Type-Use, Recursive-Type, And Subtyping Current Refresh

- Capture date: 2026-06-04
- Source family: current WebAssembly Core 3.0 type/text/binary/validation pages plus Starshine WAST lowering and validator evidence
- Primary sources checked on 2026-06-04:
  - WebAssembly Core Specification, `Syntax / Types` — WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/syntax/types.html>
  - WebAssembly Core Specification, `Text Format / Types` — WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/text/types.html>
  - WebAssembly Core Specification, `Text Format / Modules` — WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/text/modules.html>
  - WebAssembly Core Specification, `Binary Format / Types` — WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/binary/types.html>
  - WebAssembly Core Specification, `Validation / Types` — WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/types.html>
  - WebAssembly Core Specification, `Validation / Modules` — WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly proposals tracker, current on 2026-06-04: <https://github.com/WebAssembly/proposals>
  - WebAssembly custom-descriptors overview, current `main` on 2026-06-04: <https://raw.githubusercontent.com/WebAssembly/custom-descriptors/main/proposals/custom-descriptors/Overview.md>

## Current official takeaways

- Current Core 3.0 still treats `func`, `struct`, and `array` as the composite type families; recursive groups are grouping constructs, but each member receives a flat module type index.
- The binary type grammar still has explicit rec/sub/final encodings: `0x4e` for recursive type groups, `0x4f` for final subtypes, `0x50` for non-final subtypes, and the abbreviation where a bare composite type is a final subtype with no supertypes.
- Type-use text remains two-layered: a use can name an existing `(type ...)` and may also carry inline `(param ...)` / `(result ...)` clauses. The official text rule treats the inline clauses as an abbreviation/check against the referenced function type, not as a second independent signature.
- Current validation still separates composite-type validation from subtype validation. Supertypes must resolve as type indices, the child composite type must match the supertype composite type, and finality is part of the subtype surface that controls later extension.
- The official rules remain stricter than Starshine's WAST parsing. A parsed `(rec ...)`, `(sub ...)`, `final`, `describes`, `descriptor`, or type-use abbreviation is not semantic evidence until the lowered module is validated.

## Starshine current-code evidence

- `src/wast/parser.mbt` parses `TypeField`, `RecField`, `(sub final? super* ...)`, and descriptor metadata clauses. `parse_type_metadata_clauses(...)` deliberately rejects `describes` after `descriptor` and duplicate metadata clauses.
- `src/wast/lower_to_lib.mbt` lowers grouped WAST type definitions to `@lib.RecType`, counts every subtype member in `wt_flat_type_count(...)`, and uses `wt_resolve_type_use(...)` for function/import/tag/block/call-indirect/tail-call-reference type uses.
- `wt_resolve_type_use(...)` still has a known text-lowering caveat: when a `(type ...)` index is present, it returns the referenced type index and does not check inline `(param ...)` / `(result ...)` consistency against the referenced function type. Validator signoff remains required for any fixture that depends on explicit type-use plus inline-signature equality.
- `wt_resolve_named_or_num_index(...)` still ignores its `upper_bound` argument for numeric indices. Numeric out-of-range type-use fixtures should be treated as validator evidence, not lowering-only evidence.
- `src/validate/validate.mbt` owns `validate_typesec(...)`, `validate_rectype_and_extend(...)`, `normalize_rectype_for_global_env(...)`, `Validate for SubType`, `validate_rectype_has_super_cycle(...)`, and `validate_descriptor_metadata_group(...)`.
- The validator now has focused local coverage beyond the older May note: `InvalidSubtypeFinalSuper` and `InvalidSubtypeSuperCycle` are stable invalid-AST families, with focused tests in `src/validate/invalid_fuzzer.mbt` / `src/validate/gen_invalid_tests.mbt`.
- Local subtype caveats remain: `Validate for SubType` iterates all declared supers, so this refresh should not be read as proof that Starshine enforces a single-supertype limit. The recursive validation context exposes the current group while validating each subtype; cycle rejection is explicit, but forward or multi-super edge policy needs focused tests before being documented as fully aligned with current Core 3.0.
- Starshine descriptor metadata remains proposal/local. The current proposals tracker still keeps custom descriptors outside stable Core, and the custom-descriptors overview still frames descriptor/describes metadata as a WasmGC struct feature. Starshine WAST still accepts descriptor metadata on array type definitions in local tests, while validator-side `validate_descriptor_metadata_group(...)` rejects metadata on non-struct types.

## Documentation consequences

- Refresh `docs/wiki/wast/gc-type-authoring.md` so type-use examples warn that explicit `(type ...)` plus inline params/results is a portability and validation boundary, not only a lowering convenience.
- Refresh `docs/wiki/validate/type-section-and-subtyping.md` so the old broad caveat about final-supertype coverage is superseded by the current `InvalidSubtypeFinalSuper` / `InvalidSubtypeSuperCycle` evidence, while single-supertype and forward-supertype coverage remain intentionally unclaimed.
- Refresh binary/resource section routing to cite this current source bridge when explaining binary `RecType` / `SubType` section shape and pass rewrite obligations.
- Keep custom-descriptor claims split: core GC type syntax is current Core 3.0; descriptor metadata and exact descriptor behavior remain proposal/local and should keep routing through `docs/wiki/custom-descriptors/` plus the focused descriptor raw sources.

## Supersession

This note supersedes the source-freshness layer of `2026-05-20-wast-gc-typeuse-and-subtype-sources.md` and `2026-05-20-type-section-validation-and-subtyping-refresh.md` where they describe the current official page date or say final-supertype enforcement is not yet documented by local evidence. Those older manifests remain useful provenance for the original WAST type-use page split, recursive-group flat-index bug class, and initial subtype validation audit.
