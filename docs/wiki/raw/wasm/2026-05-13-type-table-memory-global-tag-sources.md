# WebAssembly Type, Table, Memory, Global, Tag, And Stringrefs Source Snapshot

- Capture date: 2026-05-13
- Source family: WebAssembly Core Specification 3.0 draft plus Starshine-local stringrefs evidence
- Primary sources:
  - WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification + js-string-builtins draft, `Binary Format / Modules — WebAssembly 3.0 + js-string-builtins (Draft 2025-06-25)`: <https://webassembly.github.io/js-string-builtins/core/binary/modules.html>

## Durable takeaways

- Core WebAssembly modules define separate type, table, memory, global, and tag index spaces. Function, table, memory, global, and tag imports share the same respective index spaces as same-kind definitions and precede definitions.
- The type section has section id `1` and contains recursive type definitions. In the 3.0 draft, every function, struct, and array type used by a module is defined through this type-section surface.
- The table section has section id `4`, the memory section has section id `5`, the global section has section id `6`, and the tag section has section id `13`. These sections contain module-defined entries only; imports of the same kind are represented in the import section and extend the same index spaces before definitions.
- Table definitions have a default-initializer binary form and an explicit-initializer form prefixed by `0x40 0x00`; validation requires a valid table type and a constant initializer expression of the element reference type.
- Memory definitions validate their memory type. Shared memories require a maximum in Starshine's local validator, matching the common threads-style constraint even though this page is not a full threads proposal guide.
- Global definitions contain a global type plus a constant initializer expression of that value type. Global validation is incremental: each global initializer can see only the imported and earlier-defined globals already present in the context.
- Tag definitions wrap a type index. Validation requires that the index resolve to a function type with an empty result list.
- The official core WebAssembly 3.0 binary module source lists section ids only through the tag section (`13`). The reviewed js-string-builtins draft module page likewise did not define a core `stringrefs` section id. Starshine's `StringRefsSec` encoded as section id `14` is therefore documented as a local/proposal-facing implementation surface, not as a stable core-spec section.

## Starshine implications

- Starshine's `Module` keeps `type_sec`, `table_sec`, `mem_sec`, `tag_sec`, `stringrefs_sec`, and `global_sec` as separate optional fields. Imports live in `import_sec` and extend the same table/memory/global/tag environments before the corresponding local definition sections are validated.
- Starshine binary decode/encode uses ids `1`, `4`, `5`, `6`, and `13` for core type/table/memory/global/tag sections. The whole-module encoder emits them in canonical order, with the local `stringrefs_sec` slot between tag and global sections.
- Starshine validation mirrors the incremental environment model: type definitions are normalized into the global type environment; imports append index-space entries; table, memory, tag, and global sections append definitions after validation; global initializers are validated against previously available globals.
- Passes that rewrite type order, table order, memory order, global order, tag order, or string literal pools must repair all index carriers, exports, names, imports, initializer expressions, instruction immediates, and proposal/local metadata that depend on those spaces.

## Follow-up questions

- If Starshine keeps `StringRefsSec` as a real binary section, either keep documenting it as a local/proposal extension or refresh this snapshot when an upstream stringref/js-string-builtins specification defines a stable section id.
- If table explicit-initializer forms become more widely exercised by the generator, add a focused WAST/binary page or extend the generator ledger with the exact typed-null and non-null initializer shapes.
- If multi-memory or exception-handling work changes section-order assumptions, update this snapshot together with the relevant pass port-readiness pages.
