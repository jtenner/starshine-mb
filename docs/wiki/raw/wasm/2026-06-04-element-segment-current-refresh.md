# WebAssembly Element Segment Current Refresh

- Capture date: 2026-06-04
- Source family: current WebAssembly Core Specification 3.0 pages plus Starshine repository evidence
- Primary sources checked on 2026-06-04; opened spec pages identify themselves as WebAssembly 3.0 (2026-06-03):
  - WebAssembly Core Specification, `Syntax / Modules`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Text Format / Modules`: <https://webassembly.github.io/spec/core/text/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Validation / Modules`: <https://webassembly.github.io/spec/core/valid/modules.html>

## Durable takeaways

- The current official module syntax still models element segments as a reference type, zero or more element expressions, and a mode. Modes are active table-plus-offset, passive, or declarative.
- The current official text format exposes all three modes: omitted mode is passive, explicit table use plus offset is active, and `declare` is declarative. The `elemlist` grammar is broader than Starshine's current declarative text lane because the official `declare` form can carry an explicit reference type and `(item ...)` expressions, not only a `func` index list.
- The official text table-use abbreviation still defaults omitted table use to table `0`, and table-attached element abbreviations still expand into a separate active element segment with offset zero and a table use.
- The current official binary element section remains section id `9` with headers `0` through `7`: legacy function-index active/passive/active-explicit/declarative forms, expression active/passive/active-explicit/declarative forms, and typed-expression passive/active-explicit/declarative forms.
- The current official validation rule remains mode-sensitive: passive and declarative modes have no table or offset validation, while active mode requires the selected table, reference-type match into the table element type, and a constant offset expression of the selected table address type.
- Declarative mode remains semantically distinct from passive mode. It declares references for `ref.func` without providing a runtime element payload for `table.init`, `elem.drop`, `array.new_elem`, or `array.init_elem`.

## Starshine implications

- `src/lib/types.mbt` already has the full core mode/kind split: `ElemMode::{Passive, Active, Declarative}` and `ElemKind::{FuncsElemKind, FuncExprsElemKind, TypedExprsElemKind}`.
- `src/binary/decode.mbt` and `src/binary/encode.mbt` preserve all official binary element headers, including declarative function-list and typed-expression headers.
- `src/validate/validate.mbt` mirrors the official mode rule closely: `validate_elem_mode(...)` accepts passive/declarative without a parent table and checks active table existence, reference-type matching, and address-typed constant offsets. `Validate for ElemKind` separately validates function-index existence and constant payload expression types.
- `collect_declared_funcs_bitmap(...)` treats all element payload kinds as declaration sources: raw function-index payloads mark those functions directly, while expression payloads scan nested `ref.func` instructions.
- The current high-level WAST `ElemSegment` AST in `src/wast/parser.mbt` still has no explicit mode field. `parse_elem(...)` accepts the narrow declarative abbreviation `(elem declare func ...)`, but lowering in `src/wast/lower_to_lib.mbt` derives `ElemMode::passive()` from an empty offset, so declarative mode is not preserved through the WAST path.
- Because the official text grammar supports typed declarative element lists while Starshine currently only recognizes the narrow `declare func` branch and then lowers it as passive, typed declarative WAST should remain a text-surface gap. Use direct core or binary fixtures when the mode itself or header `7` is the evidence under test.

## Follow-up questions

- If the WAST AST grows an explicit element-mode field, update parser, printer, and lowerer tests so `(elem declare func $f)` lowers to `ElemMode::declarative()` while `(elem func $f)` remains passive.
- Decide separately whether the same WAST widening slice should add official typed declarative forms such as `(elem declare (ref null $t) (item ...))`; do not imply that fixing the function-list abbreviation automatically covers header `7` text.
- If WAST declarative lowering changes, refresh `wast/element-segment-authoring.md`, `validate/ref-func-declarations.md`, and invalid/spec-harness skip expectations together so declaration-source evidence and runtime-payload evidence stay separate.
