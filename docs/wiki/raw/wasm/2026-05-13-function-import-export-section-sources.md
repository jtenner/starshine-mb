# WebAssembly Function, Import, Export, Start, And Code Section Source Snapshot

- Capture date: 2026-05-13
- Source family: WebAssembly Core Specification 3.0 draft
- Primary sources:
  - WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Text Format / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/text/modules.html>

## Durable takeaways

- WebAssembly modules keep separate index spaces for types, functions, tables, memories, globals, tags, elements, data, labels, locals, and fields. Function, table, memory, global, and tag imports live in the same respective index spaces as definitions and always precede same-kind module-defined entries.
- Functions are declared by a type index plus locals and a body expression. In the binary format, defined-function signatures are split from bodies: section id `3` stores the type-index vector and section id `10` stores the parallel code-body vector. Code entries encode a byte length, compressed local runs, and the expression body.
- Import section id `2` stores a vector of `(module-name, field-name, extern-type)` entries. Import module/item name pairs are not required to be unique by the core syntax/source note.
- Export section id `7` stores `(export-name, extern-index)` entries. Export names are unique at validation time, and export indices must resolve in the relevant index space.
- Start section id `8` stores at most one function index. The start target must exist and expand to an empty-parameter, empty-result function type.
- Function bodies are mutually recursive at module-validation time: the validation context can know all imported and defined function signatures before checking each body. `ref.func` declaration sources come from function indices appearing in globals, tables, element segments, start, and exports according to the module validation rule.
- Text modules allow inline import/export abbreviations on definitions, named and numeric function references, and a start declaration that lowers to the same function index model.

## Starshine implications

- Starshine mirrors the official section split: `Module.import_sec`, `func_sec`, `export_sec`, `start_sec`, and `code_sec` are separate fields, while `FuncIdx` is a typed zero-based absolute function index.
- Starshine function indices follow the spec's imported-prefix rule. Imported functions are appended to the validation environment before defined functions; a defined body ordinal maps to absolute `FuncIdx(imported_func_count + body_idx)` through the proved helper functions in `src/validate_proof/func_index.mbt`.
- Starshine binary encode/decode uses section ids `2`, `3`, `7`, `8`, and `10`, and `Encode for Module` writes import, function, export, start, and code sections in canonical section order.
- Starshine validation rejects mismatched `FuncSec`/`CodeSec` presence or lengths, validates every function body against its resolved signature, enforces start-signature emptiness, and checks duplicate export names.
- Source reconciliation caveat: the official module-validation rule includes function indices occurring in the optional start section among the module `refs` set for `ref.func` declaration validity. Current Starshine intentionally has a regression asserting that `start` alone is not treated as a `ref.func` declaration source; keep that local/spec divergence visible until resolved.
- WAST lowering resolves inline and standalone imports/exports/start declarations into the same core `Import`, `FuncSec`, `Export`, `StartSec`, and `CodeSec` surfaces. A named text reference is therefore not preserved as a name after lowering; it becomes a numeric typed index.

## Follow-up questions

- If Starshine adds a function-reordering pass, keep this page as the canonical checklist for every `FuncIdx` carrier that must be remapped: direct/tail calls, `ref.func`, start, exports, element expressions and legacy function-index payloads, globals/table initializers, names, and annotations.
- If the WAST layer gains more exact round-trip metadata for named functions, document whether names are preserved only through `NameSec` / debug context or also through a new source-level binding table.
- If the validator's `ref.func` declaration policy changes, refresh this source snapshot together with `src/validate/validate.mbt` tests around exported functions, element declarations, globals, tables, and start sections.
