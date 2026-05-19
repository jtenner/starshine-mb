# WAST Identifier, Name Section, And Annotation Source Snapshot

- Capture date: 2026-05-19
- Source family: WebAssembly Core Specification 3.0 draft plus local Starshine source map
- Primary sources:
  - WebAssembly Core Specification, `Text Format / Lexical Format — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/text/lexical.html>
  - WebAssembly Core Specification, `Text Format / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/text/modules.html>
  - WebAssembly Core Specification, `Text Format / Values — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/text/values.html>
  - WebAssembly Core Specification, `Custom Sections and Annotations — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/appendix/custom>

## Durable takeaways

- Text-format identifiers are symbolic authoring labels beginning with `$`; the text grammar uses them to name module fields, locals, labels, and references to those entities.
- The core binary format does not preserve text identifiers as semantic fields. Human-readable names belong in custom metadata, especially the standardized custom section named `name`.
- The WebAssembly name section records debug names in ordered subsection maps. It is metadata, not the source of validation semantics, but tools can use it for diagnostics and presentation.
- The custom-section appendix also defines annotation-style custom text syntax with placement metadata, but Starshine should not treat that official annotation surface as implemented unless the local WAST parser/lowerer has explicit coverage for the same placement and payload rules.

## Starshine implications

- Starshine's WAST AST keeps identifiers on many source entities so text fixtures can use `$` references while parsing, printing, and lowering.
- Starshine's WAST lowerer resolves type/function/table/memory/global/tag/element/data identifiers through maps into numeric core indices.
- Current WAST lowering only turns function and imported-function identifiers into structured function-name entries in `Module.name_sec`; it strips the leading `$` before storing the name.
- Current WAST lowering uses parameter and local identifiers to resolve instructions, but it does not create structured local-name maps from those identifiers.
- Current WAST lowering carries function annotations into `func_annotation_sec` only for defined functions and function imports. That is a Starshine/Binaryen-policy metadata path, not the full official `@custom` text custom-section placement model.

## Follow-up questions

- If Starshine wants type/table/memory/global/tag/element/data identifiers from WAST to roundtrip through binary metadata, add explicit lowering into the corresponding name-section maps plus validation and pass-remap tests.
- If Starshine wants local/label identifiers from WAST to survive through binary metadata, add function-index-scoped local/label name maps and keep mutating passes from leaving stale entries.
- If Starshine wants official text `@custom` placement support, implement it as a placement-bearing custom-section model rather than overloading the current function-annotation path.
