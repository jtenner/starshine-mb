# WebAssembly WAST Element Segment Source Refresh

- Capture date: 2026-05-19
- Source family: WebAssembly Core Specification 3.0 draft and current Starshine repository evidence
- Primary sources checked on 2026-05-19; opened spec pages identify themselves as WebAssembly 3.0 (2026-05-14):
  - WebAssembly Core Specification, `Text Format / Modules`: <https://webassembly.github.io/spec/core/text/modules.html>
  - WebAssembly Core Specification, `Syntax / Modules`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Validation / Modules`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions`: <https://webassembly.github.io/spec/core/valid/instructions.html>

## Durable takeaways

- Official element segments have three semantic modes: active, passive, and declarative. Declarative segments are not table initializers and are retained for validation and declaration effects rather than runtime table population.
- Official text format has explicit `declare` element-segment syntax, optional table-use/offset syntax for active segments, typed element expression forms, and function-list abbreviations that are equivalent to typed `ref.func` element expressions.
- Official binary format uses element headers `0` through `7`. Headers `3` and `7` are the declarative forms: legacy function-index declarative segments and typed-expression declarative segments respectively.
- Official validation treats element segments as part of the module context: referenced functions must exist, element expressions validate at the declared reference type, and active element segments additionally check the target table and offset expression.
- Official `ref.func` validation depends on a module-level declaration set. Element segments are one source of those declarations, which is why Starshine's declarative text-lowering gap is also a `ref.func` declaration fidelity gap.

## Starshine implications

- Starshine's core library representation already has `ElemMode::declarative()` and binary encode/decode coverage for declarative function-list and typed-expression element headers.
- Starshine's WAST parser recognizes `(elem declare func ...)`, but `src/wast/parser.mbt`'s `ElemSegment` currently stores only `id`, `table_index`, `offset`, `func_indices`, `elem_exprs`, and `elem_type`. It does not store a source mode.
- Starshine's WAST lowerer currently derives the core element mode from `offset.length()`: empty offset becomes passive; non-empty offset becomes active. That means `(elem declare func $f)` lowers as a passive function-list element through the text path today.
- The current printer likewise cannot re-emit `declare`, because the parsed WAST AST has already lost the distinction between a passive function-list segment and a declarative function-list segment with no offset.
- Direct binary/lib/generator paths remain broader than WAST lowering: `src/lib/types.mbt`, `src/binary/decode.mbt`, `src/binary/encode.mbt`, and `src/lib/arbitrary.mbt` can represent and exercise declarative segments.

## Follow-up questions

- If text roundtrip fidelity for declarative segments becomes user-visible, add an explicit element mode to `src/wast/parser.mbt`'s `ElemSegment`, preserve it in `src/wast/module_wast.mbt`, and lower it to `ElemMode::declarative()` in `src/wast/lower_to_lib.mbt`.
- The first regression should distinguish `(elem declare func $f)` from `(elem func $f)` after `wast_to_binary_module(...)`, then add printer roundtrip coverage so `module_to_wast(...)` can preserve `declare` instead of silently printing a passive segment.
- Keep `validate/ref-func-declarations.md` linked when changing this path: declarative segment preservation affects which functions can be legally referenced by `ref.func`.
