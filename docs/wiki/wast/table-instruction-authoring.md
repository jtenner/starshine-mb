---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md
  - ../raw/wasm/2026-05-19-wast-table-instruction-sources.md
  - ../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md
  - ../raw/wasm/2026-05-19-wast-element-segment-sources.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/wast/arbitrary.mbt
related:
  - element-segment-authoring.md
  - memory-argument-authoring.md
  - resource-declaration-authoring.md
  - function-call-and-module-authoring.md
  - tail-call-authoring.md
  - gc-type-authoring.md
  - gc-aggregate-instruction-authoring.md
  - ../binary/instruction-and-expression-encoding.md
  - ../binary/data-element-and-datacount-sections.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../validate/module-validation-phases.md
  - ../validate/ref-func-declarations.md
  - ../fuzzing/generator-coverage-ledger.md
---

# WAST Table Instruction Authoring

## Overview

Use this page when writing, debugging, or widening WAST fixtures that touch WebAssembly tables as runtime storage, not just table declarations. It covers:

- indirect calls: `call_indirect` and the table-index half of `return_call_indirect`;
- ordinary table access: `table.get`, `table.set`, `table.size`, `table.grow`, and `table.fill`;
- bulk table operations: `table.copy`, `table.init`, and `elem.drop`;
- the Starshine-specific index-order and table64 caveats that are easy to miss when moving between text, core IR, binary bytes, and validation.

Fixture-facing table declarations, limits, imports, exports, and table element abbreviations live in [`resource-declaration-authoring.md`](resource-declaration-authoring.md). Core/binary section ids, optional core table initializers, and whole-module remap checklists live in [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md). Function definitions/imports/exports/starts and direct `call` live in [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md). Shared WAST type-use rules for the `(type $sig)` half of `call_indirect` and `return_call_indirect` live in [`gc-type-authoring.md`](gc-type-authoring.md). Element segment modes and typed payload authoring live in [`element-segment-authoring.md`](element-segment-authoring.md). Tail-call return-type and terminator semantics for `return_call_indirect` live in [`tail-call-authoring.md`](tail-call-authoring.md). This page focuses on instructions that read, write, copy, grow, initialize, or indirectly call through tables.

## Layer Model

A single table instruction has different shapes at different layers:

| Layer | Owner | What to remember |
| --- | --- | --- |
| WAST text | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt) | Many table indices may be omitted; omitted means table `0`. `table.init` has a special `elemidx`-only shorthand. |
| WAST print | [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Starshine prints explicit table/element indices after parsing, so roundtrip text may be less abbreviated than the input. |
| Lowered core | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/lib/types.mbt`](../../../src/lib/types.mbt) | `$` identifiers are resolved to imported-prefix numeric indices. Core `TableInit` stores `(ElemIdx, TableIdx)`, not the text spelling order. |
| Binary bytes | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | `table.get` / `table.set` are one-byte opcodes; bulk table ops are `0xFC` subcodes. Binary `call_indirect` stores type index before table index. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | The typechecker proves the table/element/type indices exist, stack operands match the selected table's element/address type, and indirect-call tables are function-reference compatible. |

The main invariant for authors is: **do not infer core or binary immediate order from the WAST spelling.** Keep the source layer explicit when documenting a fixture or a pass rewrite.

## Instruction Families And Stack Shapes

The official validation model uses a selected table's reference type `rt` and address type `at`. For ordinary table32 fixtures, `at` is `i32`. For table64, `at` should be `i64`, but see the local caveat below. The targeted 2026-05-20 refresh in [`../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md`](../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md) corrected the earlier shorthand that treated local `table.fill` as fully address-width-aware; the 2026-06-04 refresh in [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md) confirms the official Core 3.0 pages dated 2026-06-03 still use the same table address-width matrix and records the current Starshine code-map anchors.

| WAST instruction | Text immediates | Stack before | Stack after | Starshine notes |
| --- | --- | --- | --- | --- |
| `call_indirect` | optional `tableidx`, then `typeuse` | call params..., table element index | call results... | Parser defaults omitted table to `0`; lowerer resolves type use to `TypeIdx` and table to `TableIdx`. Typechecker requires a function type and a funcref-compatible table; [`gc-type-authoring.md`](gc-type-authoring.md) owns rec-group and inline-signature type-use caveats. |
| `return_call_indirect` | optional `tableidx`, then `typeuse` | call params..., table element index | unreachable | Same table/type checks as `call_indirect`, plus results must match the current function return type; see [`tail-call-authoring.md`](tail-call-authoring.md) for the return/CFG side. |
| `table.get` | optional `tableidx` | `at` | `rt` | Parser defaults omitted table to `0`; current local typechecker expects `i32` for the index. |
| `table.set` | optional `tableidx` | `at`, `rt` | none | Current local typechecker expects `i32` for the index. |
| `table.size` | optional `tableidx` | none | `at` | Current local typechecker returns `i32`. |
| `table.grow` | optional `tableidx` | `rt`, delta `at` | previous size `at` or `-1` | Current local typechecker consumes an `i32` delta and returns `i32`. |
| `table.fill` | optional `tableidx` | destination `at`, value `rt`, length `at` | none | Officially both destination and length use `at`; current Starshine uses the table limit address type for the destination/start operand but still hard-codes the length operand to `i32`. |
| `table.copy` | optional destination `tableidx`, optional source `tableidx` | destination `at1`, source `at2`, length `min(at1, at2)` | none | If both indices are omitted, parser uses table `0` for both. Typechecker requires source reference type to match destination reference type. |
| `table.init` | either `elemidx` or `tableidx elemidx` | destination `at`, source `i32`, length `i32` | none | Text `table.init elemidx` means table `0`. Lowered core stores `TableInit(ElemIdx, TableIdx)`. |
| `elem.drop` | `elemidx` | none | none | Validates the element segment index; it does not inspect table stack operands. |

### Why `table.init` order is special

`table.init` crosses three order conventions:

```wat
;; WAST text, explicit form: table first, element second
(table.init $tab $seg
  (i32.const 0) ;; destination table offset
  (i32.const 0) ;; source element-segment offset
  (i32.const 1)) ;; length

;; WAST text, shorthand: element only, table defaults to 0
(table.init $seg
  (i32.const 0)
  (i32.const 0)
  (i32.const 1))
```

Starshine's parser records the explicit text order in [`parse_opcode_instruction(...)`](../../../src/wast/parser.mbt). Lowering resolves both identifiers, then emits [`Instruction::table_init(ElemIdx, TableIdx)`](../../../src/wast/lower_to_lib.mbt). Binary encoding also writes the element index before the table index for the `0xFC 12` form in [`src/binary/encode.mbt`](../../../src/binary/encode.mbt). When writing tests, name variables as `table_idx` and `elem_idx` instead of `x` / `y` so an order bug is obvious.

## Concrete WAST Shapes

### Default-table indirect call

```wasm
(module
  (type $sig (func (param i32) (result i32)))
  (table 1 funcref)
  (elem (i32.const 0) func $callee)
  (func $callee (param i32) (result i32) (local.get 0))
  (func (param i32 i32) (result i32)
    (local.get 0) ;; callee param
    (local.get 1) ;; table element index
    (call_indirect (type $sig))))
```

The omitted table index means table `0`. Starshine parses that abbreviation in [`src/wast/parser.mbt`](../../../src/wast/parser.mbt), resolves `$sig` through the type-use lowerer, and typechecks the selected table as function-reference-compatible.

### Explicit-table `table.copy`

```wasm
(module
  (table $dst 4 funcref)
  (table $src 4 funcref)
  (func
    (table.copy $dst $src
      (i32.const 0) ;; destination offset
      (i32.const 1) ;; source offset
      (i32.const 2)))) ;; length
```

This is the safe shape for multi-table fixtures because it makes destination/source order visible. If both indices are omitted, Starshine follows the official abbreviation and uses `0, 0`; that is useful for tiny single-table tests but poor evidence for table-index remapping passes.

### Passive element segment consumed by `table.init`

```wasm
(module
  (table $t 4 funcref)
  (func $f)
  (elem $e func $f)
  (func
    (table.init $t $e
      (i32.const 0)
      (i32.const 0)
      (i32.const 1))
    (elem.drop $e)))
```

Use a passive segment for `table.init` / `elem.drop` fixtures. The focused element segment guide explains the passive-versus-declarative split, typed-expression payloads, and why current Starshine WAST lowering still has a declarative-mode preservation gap plus no proven typed-declarative text surface: [`element-segment-authoring.md`](element-segment-authoring.md).

### Table64 caution fixture

Do **not** use WAST `table64` instruction fixtures as complete validation evidence yet. The official rules use a table address type, but Starshine's current typechecker is mixed:

- [`typecheck_table_copy(...)`](../../../src/validate/typecheck.mbt#L1431-L1461) uses destination/source table limit widths plus mixed-width length selection, and [`typecheck_table_init(...)`](../../../src/validate/typecheck.mbt#L1464-L1492) uses the destination table limit width while source and length remain `i32`;
- [`typecheck_table_fill(...)`](../../../src/validate/typecheck.mbt#L1495-L1519) is only partially widened locally: the destination/start operand uses the table limit width, but the length operand still uses `i32` even though the official table64 rule uses `at`;
- [`typecheck_table_get(...)`](../../../src/validate/typecheck.mbt#L555-L565), [`typecheck_table_set(...)`](../../../src/validate/typecheck.mbt#L570-L586), [`typecheck_table_size(...)`](../../../src/validate/typecheck.mbt#L593-L598), [`typecheck_table_grow(...)`](../../../src/validate/typecheck.mbt#L603-L624), [`typecheck_call_indirect(...)`](../../../src/validate/typecheck.mbt#L899-L934), and [`typecheck_return_call_indirect(...)`](../../../src/validate/typecheck.mbt#L994-L1028) still use `i32` index/result assumptions locally.

Until that gap is fixed and tested, table64 table-instruction work belongs in a validation-widening task, not ordinary WAST authoring documentation. The Binaryen feature-lowering sibling is tracked from the pass side in [`../binaryen/passes/memory64-lowering/index.md`](../binaryen/passes/memory64-lowering/index.md), which also records table64-lowering context. Keep resource-section support (`TableType` can carry `I64Limits`) separate from these instruction-stack caveats.

## Rewrite And Validation Guidance

When a pass or generator change touches table instructions, use this checklist:

1. **Table remaps:** update `TableIdx` carriers in `call_indirect`, `return_call_indirect`, `table.get`, `table.set`, `table.size`, `table.grow`, `table.fill`, `table.copy`, `table.init`, active element modes, table exports/imports, table names, and table initializer expressions.
2. **Element remaps:** update `ElemIdx` carriers in `table.init`, `elem.drop`, `array.new_elem`, `array.init_elem`, element names, and any element-section payload references documented in [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md). The `array.*` element-backed forms are core/binary/validator-visible but not current WAST text; route fixture-format decisions through [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md).
3. **Function remaps:** indirect-call tables often start from element payloads; function reordering/deletion must also update element payloads, `ref.func` declaration sources, exports, starts, calls, names, and annotations as described in [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md).
4. **Segment mode:** use passive element segments for runtime `table.init` / `elem.drop` payload fixtures; declarative element segments are for declaration effects. Do not paper over the current WAST declarative-mode lowering gap or the separate typed-declarative text gap.
5. **Type validation:** after table or element rewrites, re-run module validation so reference-type matching, address-width stack types, table index existence, element index existence, and indirect-call funcref compatibility are checked.
6. **Fuzz evidence:** generator/table work should update the coverage-ledger page and route WAST arbitrary claims through [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md) rather than treating parser acceptance as semantic validation.

## Source Map

- Primary-source and local-code manifest: [`../raw/wasm/2026-05-19-wast-table-instruction-sources.md`](../raw/wasm/2026-05-19-wast-table-instruction-sources.md)
- Current address-width refresh: [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md)
- Targeted table64 / `table.fill` validation correction: [`../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md`](../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md)
- WAST opcode vocabulary and parser: [`../../../src/wast/types.mbt`](../../../src/wast/types.mbt), [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt)
- WAST printer and lowerer: [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Core instruction model: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt)
- Binary codec: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Validation and generation: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt)
- Related guides: [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md), [`element-segment-authoring.md`](element-segment-authoring.md), [`tail-call-authoring.md`](tail-call-authoring.md), [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md), [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md)
