# WebAssembly Resource Section Validation Source Refresh

- Capture date: 2026-05-20
- Source family: current WebAssembly Core Specification validation, type-validation, binary-section, and Starshine validator / invalid-fuzzer evidence for non-function module resources.
- Primary sources checked on 2026-05-20:
  - WebAssembly Core Specification, `Validation / Modules`: <https://webassembly.github.io/spec/core/valid/modules.html> (site version shown as 2026-05-14). This anchors global, memory, table, tag, data-segment, element-segment, import/export, and whole-module context-construction rules.
  - WebAssembly Core Specification, `Validation / Types`: <https://webassembly.github.io/spec/core/valid/types.html> (site version shown as 2026-05-14). This anchors generic limit-range validation, memory bounds by address width, table bounds plus reference-type validation, global type validation, and tag type validation.
  - WebAssembly Core Specification, `Binary Format / Modules`: <https://webassembly.github.io/spec/core/binary/modules.html> (site version shown as 2026-05-14). This anchors section ids for table, memory, global, element, data, data-count, and tag sections, and the note that numeric ids do not always match encoding order.
  - WebAssembly Core Specification, `Syntax / Modules`: <https://webassembly.github.io/spec/core/syntax/modules.html> (site version shown as 2026-05-14). This anchors the abstract module fields and segment/resource shapes that the validation rules classify.

## Durable takeaways

- Resource-section validation is not one flat "module field is present" check. It builds several imported-prefix index spaces: tables, memories, globals, tags, data segments, and element segments.
- Limits are a shared validation primitive: lower bound must be within the family maximum, and an optional upper bound must be between lower bound and the family maximum. Memory limits are capped by page count derived from address width; table limits are capped by addressable element count.
- Global and table initializers are constant expressions. Globals are validated incrementally, so a global initializer can see imports and earlier globals, but not later defined globals.
- Active data offsets use the selected memory address type; passive data has no parent memory or offset. Active element offsets use the selected table address type; passive and declarative element modes have no parent table or offset.
- Element payload expressions must be constant expressions of the element reference type, and active element segment types must match the target table element type.
- Tag types are type uses that expand to function types; Starshine additionally rejects non-empty tag result lists in the current implementation, matching the exception-tag contract elsewhere in the wiki.
- Data-count validation has two related but distinct concerns in Starshine: a present count must equal the number of data segments, and body uses of `memory.init` / `data.drop` require the data-count section to exist.

## Starshine implications

- `src/validate/validate.mbt` owns the live section validators: `ValidateMax for Limits`, `Validate for MemType`, `Validate for TableType`, `Validate for TagType`, `validate_tablesec`, `validate_memsec`, `validate_tagsec`, `validate_globalsec`, `validate_elemsec`, `validate_datasec`, and `validate_datacnt`.
- `validate_importsec(...)` appends imported resource types before local resource sections, so all section validators and instruction typecheckers see the imported-prefix index spaces.
- `validate_globalsec(...)`, `validate_tablesec(...)`, `validate_memsec(...)`, `validate_tagsec(...)`, `validate_elemsec(...)`, and `validate_datasec(...)` all extend their respective `Env` arrays as they validate accepted entries. This is most semantically visible for globals, whose initializer visibility is incremental.
- `validate_elem_mode(...)` and `Validate for DataMode` are the local anchors for active segment parent-index checks and address-width-aware offset constant expressions.
- `src/validate/invalid_fuzzer.mbt` has deterministic AST-invalid strategies for mutable `global.get` in global initializers, mutable `global.get` in table initializers, non-constant active data offsets, non-constant active element offsets, shared memory without maximum, shared memory64 without maximum, and invalid tag type index.

## Current local/spec caveats to keep visible

- Current Starshine validates shared memories as a local/proposal-facing `MemType(..., shared=true)` surface and rejects shared memories without maximum. The current core spec pages checked here describe memory/table address-width and limit rules but do not, by themselves, make Starshine's shared-memory flag a stable core-WebAssembly field.
- Starshine's WAST resource declarations still lower table and memory limits through `Limits::i32(...)`; use direct core, binary, or generator fixtures for memory64/table64 declaration evidence until the text surface is widened.
- Official module validation constructs one context from module components. Starshine's implementation phase order is operationally different but should remain semantically equivalent: some checks, such as data-count equality and `ref.func` declarations, are split into named local phases for diagnostics and tracing.
- Element declarative mode is supported by Starshine core/binary/generator/validator paths, while current high-level WAST lowering still has a declarative-mode preservation gap documented by the element authoring page.

## Follow-up questions

- Should Starshine split a focused invalid-fuzzer strategy for table or memory limit overflow versus relying on shared-memory-without-max and generator coverage of valid limit variants?
- If shared-memory proposal support is made public API rather than local internal surface, refresh this note against the relevant official threads/proposal source and update the resource validator page accordingly.
