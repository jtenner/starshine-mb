---
kind: concept
status: supported
last_reviewed: 2026-05-19
sources:
  - ../raw/wasm/2026-05-19-wast-element-segment-sources.md
  - ../raw/wasm/2026-05-13-data-element-and-datacount-sources.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/passive_typed_elem_surface_test.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/lib/arbitrary.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
related:
  - ../binary/data-element-and-datacount-sections.md
  - ../validate/ref-func-declarations.md
  - ../validate/module-validation-phases.md
  - ../fuzzing/generator-coverage-ledger.md
  - table-instruction-authoring.md
  - static-assertion-harness.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
---

# WAST Element Segment Authoring

## Overview

Use this page when authoring, debugging, or widening text-format element segments in Starshine. Element segments sit between four layers:

1. **Official Wasm semantics:** element segments can be active, passive, or declarative; payloads are reference expressions, with legacy function-index lists treated as abbreviations for `ref.func` expressions.
2. **Starshine core model:** [`ElemMode`](../../../src/lib/types.mbt#L198-L202) and [`ElemKind`](../../../src/lib/types.mbt#L204-L209) can represent active, passive, declarative, function-list, function-expression, and typed-expression element forms.
3. **Starshine binary model:** [`Encode for Elem`](../../../src/binary/encode.mbt#L1377-L1464) and [`Decode for Elem`](../../../src/binary/decode.mbt#L1590-L1721) cover the official binary element header family, including declarative headers.
4. **Starshine WAST model:** [`ElemSegment`](../../../src/wast/parser.mbt#L208-L215) currently stores id, table index, offset, function indices, typed item expressions, and an optional element type, but not the source element mode.

That last point is the important local caveat. The parser recognizes `(elem declare func ...)` in [`parse_elem(...)`](../../../src/wast/parser.mbt#L3380-L3469), but the parsed AST has no mode field. Lowering then derives mode from offset emptiness in [`lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt#L3361-L3395): empty offset becomes `ElemMode::passive()`, non-empty offset becomes `ElemMode::active(...)`. So the current text path can parse declarative syntax, but it does **not** preserve declarative mode into the lowered core module.

## Why Element Mode Matters

| Mode | Official meaning | Starshine core/binary status | Current WAST status |
| --- | --- | --- | --- |
| Active | Copies element values into a table at instantiation time. | Supported by `ElemMode::active(...)`, binary headers `0`, `2`, `4`, and `6`, and text lowering when an offset expression is present. | Use `(elem (i32.const 0) ...)` or table abbreviations. |
| Passive | Provides a segment that later code can consume with `table.init` / `elem.drop`; instruction authoring details live in [`table-instruction-authoring.md`](table-instruction-authoring.md). | Supported by `ElemMode::passive()` and binary headers `1` and `5`. | Use `(elem func $f)` or `(elem (ref null $t) ...)` with no offset. |
| Declarative | Declares element references without initializing a table or being available for later `table.init`. It still contributes `ref.func` declaration information. | Supported by `ElemMode::declarative()` and binary headers `3` and `7`; arbitrary generation exercises both declarative function-list and typed-expression cases in [`src/lib/arbitrary.mbt`](../../../src/lib/arbitrary.mbt#L140-L168). | Parser accepts `(elem declare func ...)`, but lowering/printer currently lose the mode and treat it as passive. |

Do not interpret the WAST caveat as a core-library limitation. Direct lib modules, binary decode, binary encode, and generator paths can carry declarative elements. The gap is only the higher-level text AST/lowering/printer path.

## Concrete WAST Shapes

### Active function-list element segment

```wasm
(module
  (table 1 funcref)
  (func $f)
  (elem (i32.const 0) func $f))
```

Current lowering should produce an active `FuncsElemKind` segment. The offset is present, so the lowerer resolves the parent table and emits `ElemMode::active(...)`.

### Passive typed empty element segment

```wasm
(module
  (type $f (func))
  (table 0 (ref null $f))
  (elem (ref null $f)))
```

This is the best-supported WAST-only edge case today. [`passive_typed_elem_surface_test.mbt`](../../../src/wast/passive_typed_elem_surface_test.mbt#L2-L83) proves parse, print, lower, and validate behavior for the empty typed passive form. It is intentionally distinct from the declarative caveat: this source has no `declare` token, so `ElemMode::passive()` is correct.

### Declarative function-list element segment

```wasm
(module
  (type $f (func))
  (func $target)
  (elem declare func $target)
  (func (drop (ref.func $target))))
```

Officially, the element segment is declarative: it should not be a passive segment and should not be usable as a `table.init` payload. In current Starshine WAST lowering, this source parses but lowers through the same empty-offset path as a passive segment. That can matter for roundtrip fidelity and for tests that are specifically proving `ref.func` declarations from declarative segments rather than passive segments.

The existing typed-ref parser/lowerer smoke tests use `(elem declare func $dummy)` as a convenient declaration source in [`parser.mbt`](../../../src/wast/parser.mbt#L5417-L5438) and [`lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt#L6548-L6571). Those tests prove the parser accepts the syntax and the lowered module validates; they do not prove declarative-mode preservation.

## Current Flow And Invariants

1. **Parse:** `parse_elem(...)` handles the special `declare func` abbreviation first, then general active/passive/typed forms. The returned `ElemSegment` has no mode field, so source-mode intent is lost immediately for declarative forms.
2. **Print:** `module_to_wast(...)` prints `(elem ... )` based on offset/type/items in [`module_wast.mbt`](../../../src/wast/module_wast.mbt#L917-L945). Because the AST has no mode field, it cannot decide to print `declare`.
3. **Lower:** `wast_to_binary_module(...)` translates empty offset to passive and non-empty offset to active. Function-index-only payloads become `ElemKind::funcs(...)`; typed intent or non-`ref.func` items become `ElemKind::typed_exprs(...)`.
4. **Validate:** Core validation then checks segment mode, element payload type, table/offset constraints for active segments, and the function-reference declaration set. See [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md) and [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md).

Keep these invariants visible:

- **Mode is semantic, not just syntax.** Passive and declarative segments can both have no offset, but they are not interchangeable once `table.init` / `elem.drop` and `ref.func` declarations are considered. Use [`table-instruction-authoring.md`](table-instruction-authoring.md) when the fixture consumes the segment at runtime.
- **Typed intent should survive.** Explicit element type or explicit `(item ...)` syntax must keep the segment in a typed-expression representation instead of collapsing blindly to a function-index list.
- **Function indices are absolute after lowering.** Element payloads use the same imported-prefix `FuncIdx` model as calls, exports, starts, and `ref.func` declarations; see [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md).
- **Do not hide the declarative gap.** If a fixture needs real declarative-mode proof today, prefer a direct core/binary fixture or first fix the WAST AST mode field.

## Fix/Expansion Plan

A faithful WAST declarative-mode fix should be small but test-first:

1. Add an explicit element mode field to [`ElemSegment`](../../../src/wast/parser.mbt#L208-L215). Use a WAST-local enum if that keeps parser concepts separate from `@lib.ElemMode`.
2. Add a failing lowering test that distinguishes `(elem declare func $f)` from `(elem func $f)`: the former must lower to `ElemMode::declarative()`, the latter to `ElemMode::passive()`.
3. Update `parse_elem(...)` so the `declare func` branch records declarative mode instead of relying on `offset: []` as an implicit signal.
4. Update `module_to_wast(...)` so declarative function-list segments print `declare func` and do not roundtrip as passive syntax.
5. Re-run focused WAST tests, then the relevant validation/fuzz gates from [`../tooling/validation-gates.md`](../tooling/validation-gates.md). If `ref.func` declaration behavior changes, also update [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md) and invalid-generation expectations.

## Source Map

- Focused primary-source refresh: [`../raw/wasm/2026-05-19-wast-element-segment-sources.md`](../raw/wasm/2026-05-19-wast-element-segment-sources.md)
- Broader data/element/data-count source snapshot: [`../raw/wasm/2026-05-13-data-element-and-datacount-sources.md`](../raw/wasm/2026-05-13-data-element-and-datacount-sources.md)
- WAST parser AST and element parser: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt)
- WAST printer: [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt)
- WAST lowerer: [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Passive typed empty element tests: [`../../../src/wast/passive_typed_elem_surface_test.mbt`](../../../src/wast/passive_typed_elem_surface_test.mbt)
- Core element representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt)
- Binary element decode/encode: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
