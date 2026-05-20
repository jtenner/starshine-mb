---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-wast-element-segment-source-refresh.md
  - ../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md
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
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - index.md
  - ../binary/data-element-and-datacount-sections.md
  - ../binary/function-import-export-and-code-sections.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../validate/constant-expressions.md
  - ../validate/ref-func-declarations.md
  - ../validate/module-validation-phases.md
  - ../fuzzing/generator-coverage-ledger.md
  - table-instruction-authoring.md
  - resource-declaration-authoring.md
  - gc-type-authoring.md
  - gc-aggregate-instruction-authoring.md
  - reference-instruction-authoring.md
  - static-assertion-harness.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
---

# WAST Element Segment Authoring

## Overview

Element segments are module-level reference payloads. They are most visible when they initialize tables, but they also affect validation because their function references can declare which functions may later appear in `ref.func` instructions. Use this page when writing WAST fixtures, reducing element-segment bugs, or deciding whether a test should live at the WAST, core/binary, validator, or generator layer.

There are two independent questions to keep separate:

1. **Mode:** active, passive, or declarative.
2. **Payload kind:** a legacy function-index list, a `funcref` expression list, or an explicitly typed reference-expression list.

Official WebAssembly models both axes. Starshine's core, binary, validator, and generator layers can represent the full matrix, but the current WAST text path loses one important bit: parsed `(elem declare func ...)` source has no explicit mode field in the WAST AST, so lowering treats it like a passive segment. The 2026-05-20 source refresh records the current official and local evidence in [`../raw/wasm/2026-05-20-wast-element-segment-source-refresh.md`](../raw/wasm/2026-05-20-wast-element-segment-source-refresh.md).

## Layer Contract

| Layer | Code / source | What it proves | Caveat |
| --- | --- | --- | --- |
| Official text/syntax/validation | WebAssembly 3.0 text, syntax, binary, and validation pages captured in the raw refresh | Element segments have active/passive/declarative modes; payloads are reference expressions; function-index lists abbreviate `ref.func` payloads; active offsets and element expressions are constant-expression contexts. | The official text grammar is broader than Starshine WAST in this snapshot. |
| Starshine core model | [`ElemMode`](../../../src/lib/types.mbt) and [`ElemKind`](../../../src/lib/types.mbt) | Core modules can carry `Passive`, `Active(TableIdx, Expr)`, `Declarative`, `FuncsElemKind`, `FuncExprsElemKind`, and `TypedExprsElemKind`. | Core support does not automatically imply text support. |
| Binary codec | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Binary headers `0` through `7` roundtrip the full mode/kind family, including declarative typed-expression segments. | Byte-level roundtrip does not prove source-id or text-printer fidelity. |
| WAST parse/print/lower | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) | WAST can author common active/passive function-list and typed-expression segments, table element abbreviations, and passive typed empty fixtures. | [`ElemSegment`](../../../src/wast/parser.mbt) has no mode field; `(elem declare func ...)` parses but lowers/prints as passive. Typed declarative text is not a proven text surface today. |
| Validation | [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md), [`../validate/constant-expressions.md`](../validate/constant-expressions.md) | Element payload functions must exist; element expressions must typecheck as constants at the segment reference type; active segments also check parent table existence, table element type compatibility, and offset type. | `ref.func` declaration checks are a separate whole-module phase, so do not judge declaration safety from instruction typechecking alone. |
| Generation/fuzzing | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/lib/arbitrary.mbt`](../../../src/lib/arbitrary.mbt), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) | Valid generation exercises active/passive/declarative, function-list, function-expression, and typed-expression element families; core arbitrary exercises declarative headers. | Generator coverage is core/validator evidence; mirror text fixtures through this WAST page before assuming parser/printer support. |

## Mode And Payload Matrix

| Mode | Meaning | WAST shape to prefer | Starshine status |
| --- | --- | --- | --- |
| Active | Copies references into a table during instantiation. | `(elem (i32.const 0) func $f)` or table abbreviations such as `(table funcref (elem $f))`. | WAST lowers non-empty offsets to `ElemMode::active(...)`; binary headers `0`, `2`, `4`, and `6` are covered. |
| Passive | Provides a reusable runtime payload for `table.init` / `elem.drop`, and for core `array.new_elem` / `array.init_elem`. | `(elem func $f)` or `(elem (ref null $t) (item ...))` with no offset. | WAST lowers empty offsets to `ElemMode::passive()`; binary headers `1` and `5` are covered. |
| Declarative | Declares references without being a table initializer or reusable runtime payload. This is the canonical way to forward-declare `ref.func` targets. | Use direct core/binary fixtures today when the mode itself is under test. | Core/binary/generator support `ElemMode::declarative()` and headers `3` / `7`; current WAST text accepts only the `(elem declare func ...)` abbreviation and then loses the mode during lowering/printing. |

| Payload kind | Meaning | Starshine lowering rule |
| --- | --- | --- |
| Function-index list | Compact legacy list of function indices, equivalent to `ref.func` constants. | If there is no explicit element type and no explicit `(item ...)`, lowering emits `ElemKind::funcs(...)`. |
| Function-expression list | Core/binary `funcref` expression payloads. | Core/binary can represent `FuncExprsElemKind`; WAST lowering often canonicalizes simple `ref.func` items either into `FuncsElemKind` or typed expressions depending on explicit typed intent. |
| Typed-expression list | Explicit reference type plus item expressions, including empty typed payloads. | If the source supplies an element type or explicit `(item ...)`, lowering emits `ElemKind::typed_exprs(...)` and preserves the declared reference type. |

### Binary header cheat sheet

| Header | Mode | Payload kind | Notes |
| ---: | --- | --- | --- |
| `0` | Active table `0` | Function-index list | Legacy active form. |
| `1` | Passive | Function-index list | Has the element-kind byte. |
| `2` | Active explicit table | Function-index list | Carries a table index before the offset expression. |
| `3` | Declarative | Function-index list | Declaration-only legacy function list. |
| `4` | Active table `0` | `funcref` expressions | Expression-form active segment. |
| `5` | Passive | Typed expressions | Carries an explicit reference type. |
| `6` | Active explicit table | Typed expressions | Carries table index, offset, reference type, expressions. |
| `7` | Declarative | Typed expressions | Core/binary/generator-visible; not a proven WAST text surface today. |

## Concrete WAST Shapes

### Active function-list element segment

```wasm
(module
  (table 1 funcref)
  (func $f)
  (elem (i32.const 0) func $f))
```

The offset expression makes the segment active. Starshine resolves `$f` through the imported-prefix function-index space, resolves the parent table to table `0`, and lowers to `ElemMode::active(TableIdx(0), ...)` plus `FuncsElemKind`. The offset is a constant-expression context; use [`../validate/constant-expressions.md`](../validate/constant-expressions.md) for the official-vs-local allow-list.

### Passive function-list segment for `table.init`

```wasm
(module
  (table $t 1 funcref)
  (func $f)
  (elem $e func $f)
  (func
    (table.init $t $e
      (i32.const 0)  ;; destination table offset
      (i32.const 0)  ;; source element offset
      (i32.const 1)) ;; length
    (elem.drop $e)))
```

Use passive segments for runtime element payloads. `table.init` and `elem.drop` syntax, stack order, table/element immediate ordering, and table64 caveats live in [`table-instruction-authoring.md`](table-instruction-authoring.md). Core `array.new_elem` and `array.init_elem` are also element-index users, but they are not current Starshine high-level WAST text forms; route aggregate fixture-format and initializer caveats through [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md) and [`../validate/constant-expressions.md`](../validate/constant-expressions.md).

### Passive typed empty element segment

```wasm
(module
  (type $f (func))
  (table 0 (ref null $f))
  (elem (ref null $f)))
```

This is a useful edge case because it proves that an explicit element type can exist with zero payload expressions. [`src/wast/passive_typed_elem_surface_test.mbt`](../../../src/wast/passive_typed_elem_surface_test.mbt) proves parse, print, lower, and validation for this WAST shape. Lowering emits `ElemMode::passive()` plus `ElemKind::typed_exprs(ref null $f, [])`.

### Active typed element expression for a non-`funcref` table

```wasm
(module
  (type $s (struct))
  (table 1 (ref null $s))
  (elem (i32.const 0)
    (ref null $s)
    (item (ref.null $s))))
```

Use this shape when proving that table element types, element segment reference types, and item expression types agree. This belongs to the typed-expression path, not the function-list path. If a pass changes table types, type indices, or element expressions, it must rerun module validation because active element checks combine parent table typing and payload typing.

### Table element abbreviation

```wasm
(module
  (func $f)
  (table funcref (elem $f)))
```

Starshine parses table element abbreviations in [`parse_table(...)`](../../../src/wast/parser.mbt) and lowers them to active element segments. They are **not** the same thing as the optional core [`Table(TableType, Expr?)`](../../../src/lib/types.mbt) initializer field. Declaration syntax and table resource caveats live in [`resource-declaration-authoring.md`](resource-declaration-authoring.md); binary resource fields live in [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md).

### Declarative function-list element segment

```wasm
(module
  (type $f (func))
  (func $target)
  (elem declare func $target)
  (func (drop (ref.func $target))))
```

Officially, this is a declarative segment: it should provide declaration effects without acting like a passive runtime payload. Current Starshine WAST parses the `declare func` abbreviation, but the parsed `ElemSegment` has no mode field and lowering derives mode from empty offset, so this source lowers as passive today. Treat WAST `declare` fixtures as syntax/declaration smoke tests, not declarative-mode preservation evidence, until the AST is fixed.

The existing typed-ref parser/lowerer smoke tests use `(elem declare func $dummy)` as a convenient declaration source in [`parser.mbt`](../../../src/wast/parser.mbt) and [`lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt). They prove parse acceptance and whole-module validation, not declarative-mode roundtrip fidelity.

## Current Flow And Invariants

1. **Parse:** `parse_elem(...)` handles `(elem declare func ...)` first, then general active/passive/typed forms. The returned `ElemSegment` records ids, table index, offset instructions, function indices, item expressions, and an optional type, but not source mode.
2. **Print:** `module_to_wast(...)` prints from the WAST AST. Because mode is absent, it cannot decide to print `declare` and cannot distinguish passive function-list syntax from parsed declarative syntax.
3. **Lower:** `wast_to_binary_module(...)` resolves ids to numeric indices. Empty offset becomes passive; non-empty offset becomes active. Explicit element type or explicit `(item ...)` syntax keeps typed-expression intent.
4. **Validate:** Element kind validation checks referenced function existence and expression typing. Element mode validation checks active table/index/offset constraints only for active mode. The separate `ref.func` declaration phase scans element payloads and expressions as declaration sources; see [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md).
5. **Generate/fuzz:** `gen_valid` tracks the `[FZG]021` element-segment-range surface for multi-element segments, nonzero table targets, and non-`funcref` typed-expression segments; route text mirrors back through this page.

Keep these invariants visible:

- **Mode is semantic, not just syntax.** Passive and declarative segments can both have no offset, but they are not interchangeable for runtime payload use or roundtrip fidelity.
- **Typed intent should survive.** Explicit element type or explicit `(item ...)` syntax must not collapse blindly to `FuncsElemKind`.
- **Element expressions are constant expressions.** Moving ordinary body instructions into element payloads is not safe unless the validator accepts them as constants.
- **Function indices are absolute after lowering.** Element payloads use the same imported-prefix `FuncIdx` model as calls, exports, starts, and `ref.func` declarations; see [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md).
- **Direct core/binary proof is sometimes the right layer.** If a test specifically needs declarative typed-expression header `7` or exact declarative-mode preservation, use a direct core/binary fixture or fix WAST mode preservation first.

## Rewrite And Signoff Guidance

When a pass or lowering change touches elements, check every affected index and semantic surface:

1. **Table indices:** active element modes, `table.init`, table declarations/imports/exports, table names, and optional core table initializer expressions.
2. **Element indices:** `table.init`, `elem.drop`, core `array.new_elem` / `array.init_elem`, element name maps, and remove-unused-module-elements roots.
3. **Function indices:** function-list payloads, nested `ref.func` expressions, calls, exports, starts, names, annotations, and declaration-source bitmaps.
4. **Type indices and reference types:** typed element segment reference types, table element types, typed item expressions, casts/tests that rely on those types, and GC type-section rewrites.
5. **Mode preservation:** passive versus declarative mode must be a deliberate choice; do not repair a failing `table.init` fixture by silently converting a declarative proof into a passive payload.
6. **Validation:** rerun module validation after any element rewrite. For pass parity work, pair focused fixtures with `bun fuzz compare-pass --pass <name> ...` when the pass can touch tables, functions, types, or module elements.

## WAST Declarative-Mode Fix Plan

A faithful text fix should be test-first:

1. Add a failing lowering test that distinguishes `(elem declare func $f)` from `(elem func $f)`: the former must lower to `ElemMode::declarative()`, the latter to `ElemMode::passive()`.
2. Add an explicit mode field to [`ElemSegment`](../../../src/wast/parser.mbt). Use a WAST-local enum if that keeps parser syntax separate from `@lib.ElemMode`.
3. Update `parse_elem(...)` so the `declare func` branch records declarative mode instead of using empty offset as the only signal.
4. Update `module_to_wast(...)` so declarative function-list segments print `declare func` and do not roundtrip as passive syntax.
5. Decide separately whether to add typed declarative text support and official `(table ...)` element table-use spelling in the same patch or in later, focused patches.
6. Re-run focused WAST tests, module validation tests, and the relevant validation/fuzz gates from [`../tooling/validation-gates.md`](../tooling/validation-gates.md). If declaration behavior changes, update [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md) and invalid-generation expectations.

## Common Mistakes

- Treating parse acceptance of `(elem declare func ...)` as proof that declarative mode survives WAST lowering.
- Using a declarative segment as the payload for a runtime `table.init` fixture when the test really needs a passive segment.
- Forgetting that table element abbreviations become active element segments and therefore participate in active-offset validation and element-section rewrites.
- Collapsing typed empty or explicitly typed item segments into function-index lists because they happen to contain no non-`ref.func` expressions.
- Updating `FuncIdx`, `TableIdx`, `ElemIdx`, or `TypeIdx` carriers in function bodies but forgetting module-level element payloads, element expressions, element names, or declaration-source bitmaps.

## Source Map

- Focused current-source refresh: [`../raw/wasm/2026-05-20-wast-element-segment-source-refresh.md`](../raw/wasm/2026-05-20-wast-element-segment-source-refresh.md)
- Aggregate/initializer boundary: [`../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md`](../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md), [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md), [`../validate/constant-expressions.md`](../validate/constant-expressions.md)
- Earlier element-source refresh: [`../raw/wasm/2026-05-19-wast-element-segment-sources.md`](../raw/wasm/2026-05-19-wast-element-segment-sources.md)
- Broader data/element/data-count source snapshot: [`../raw/wasm/2026-05-13-data-element-and-datacount-sources.md`](../raw/wasm/2026-05-13-data-element-and-datacount-sources.md)
- WAST parser AST and element parser: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt)
- WAST printer: [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt)
- WAST lowerer: [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Passive typed empty element tests: [`../../../src/wast/passive_typed_elem_surface_test.mbt`](../../../src/wast/passive_typed_elem_surface_test.mbt)
- Core element representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt)
- Binary decode/encode: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Validation and generation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md)
