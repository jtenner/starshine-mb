# WebAssembly WAST Element Segment Source Refresh

- Capture date: 2026-05-20
- Source family: WebAssembly Core Specification 3.0 draft and current Starshine repository evidence
- Purpose: refresh the focused WAST element-segment page with a beginner-to-advanced mode/kind matrix, typed-expression examples, text/core/binary/generator boundaries, and current Starshine caveats.

## Primary sources checked

- WebAssembly Core Specification, `Text Format / Modules`: <https://webassembly.github.io/spec/core/text/modules.html> (opened 2026-05-20; page header identifies the current draft as WebAssembly 3.0 dated 2026-05-14).
- WebAssembly Core Specification, `Syntax / Modules`: <https://webassembly.github.io/spec/core/syntax/modules.html> (opened 2026-05-20; page header identifies the current draft as WebAssembly 3.0 dated 2026-05-14).
- WebAssembly Core Specification, `Binary Format / Modules`: <https://webassembly.github.io/spec/core/binary/modules.html> (opened 2026-05-20; page header identifies the current draft as WebAssembly 3.0 dated 2026-05-14).
- WebAssembly Core Specification, `Validation / Modules`: <https://webassembly.github.io/spec/core/valid/modules.html> (opened 2026-05-20; page header identifies the current draft as WebAssembly 3.0 dated 2026-05-14).
- WebAssembly Core Specification, `Validation / Instructions`: <https://webassembly.github.io/spec/core/valid/instructions.html> (opened 2026-05-20; page header identifies the current draft as WebAssembly 3.0 dated 2026-05-14).

## Durable takeaways

- Element segments have two independent axes that docs and tests should not collapse:
  - **Mode:** active, passive, or declarative.
  - **Payload kind:** legacy function-index lists, `funcref` expression lists, or explicitly typed reference-expression lists.
- Official text supports active segments with optional table use and offset, passive segments without a mode keyword, declarative segments with `declare`, typed element payloads, explicit `(item ...)` wrappers, and legacy function-index abbreviations equivalent to `ref.func` expressions.
- Official binary element headers `0` through `7` combine the mode and payload-kind axes. Headers `3` and `7` are declarative; headers `5` and `6` carry explicit reference types for passive and active typed-expression segments; header `7` is the typed-expression declarative form.
- Official validation checks function existence and element-expression constant-expression typing for all element segments, plus parent table existence, table reference-type compatibility, and constant offset typing for active segments. `table.init` and `elem.drop` are runtime table/element-index consumers, so fixture authors should use passive segments when they need a reusable runtime payload rather than a declaration-only segment.
- `ref.func` declaration behavior makes element segments semantically important even when no table is initialized. Function-index payloads and `ref.func` element expressions are declaration sources for later `ref.func` uses.

## Starshine evidence checked

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `ElemMode::{Passive, Active, Declarative}` and `ElemKind::{FuncsElemKind, FuncExprsElemKind, TypedExprsElemKind}`.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) preserve the full element-header family, including declarative function-list and typed-expression headers.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) stores WAST element segments as `id`, `table_index`, `offset`, `func_indices`, `elem_exprs`, and `elem_type`; it has no explicit source-mode field. The parser accepts the function-list declarative abbreviation `(elem declare func ...)`, but the branch returns an empty offset and no mode marker.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) resolves element function indices through the imported-prefix function-index model, preserves explicit typed intent as `TypedExprsElemKind`, and still derives mode from `offset.length()`: empty offset becomes `ElemMode::passive()`, non-empty offset becomes `ElemMode::active(...)`.
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) cannot print `declare` from the current WAST AST because the declarative/passive distinction has already been lost before printing.
- [`src/wast/passive_typed_elem_surface_test.mbt`](../../../../src/wast/passive_typed_elem_surface_test.mbt) is the focused text-level proof for a passive typed empty element segment.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) validates passive and declarative modes without parent table/offset checks, validates active modes against the selected table and offset type, and records valid-generator coverage facts for passive/declarative element presence.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) naturally and coverage-forced generates active, passive, declarative, function-list, function-expression, and typed-expression element segments, including non-`funcref` typed-table cases where available.
- [`src/lib/arbitrary.mbt`](../../../../src/lib/arbitrary.mbt) exercises declarative function-list and typed-expression core element shapes independently of WAST text.

## Starshine implications

- The living WAST authoring page should present the mode/kind matrix explicitly. Otherwise beginners may assume `(elem func ...)`, `(elem (ref null ...))`, and `(elem declare func ...)` are just spelling variants.
- The WAST text path is narrower than the core/binary/generator path in two ways that should remain visible:
  - declarative mode is not preserved by parsed WAST today;
  - typed declarative text should be treated as a future text-widening target unless a new parser test proves support.
- Table element abbreviations on `(table ... (elem ...))` lower to active element segments, not to the optional core table-initializer expression field. This remains a resource-declaration/element-segment boundary.
- Active offset expressions and element payload expressions are constant-expression contexts. Keep this page linked to the focused constant-expression validator page instead of duplicating the complete allow-list.

## Follow-up questions

- Should the first WAST AST fix add only a source-mode enum, or also normalize Starshine's explicit-table syntax toward the official `(table ...)` / `(offset ...)` element segment spelling at the same time?
- Should `module_to_wast(...)` print the shortest official spelling or preserve the user's chosen passive/typed/function-list style when the core module was built from text?
- Before widening typed declarative text, add a failing parser/lowerer/printer test that distinguishes function-list declarative, typed declarative, and passive typed-expression forms.
