---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/wasm/2026-05-13-data-element-and-datacount-sources.md
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/passive_typed_elem_surface_test.mbt
  - ../../../src/wast/module_wast_tests.mbt
related:
  - function-import-export-and-code-sections.md
  - type-table-memory-global-tag-sections.md
  - custom-and-name-sections.md
  - ../wast/gc-type-authoring.md
  - ../validate/fuzz-hardening.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../binaryen/passes/memory-packing/index.md
  - ../binaryen/passes/remove-unused-module-elements/index.md
  - ../binaryen/passes/memory64-lowering/index.md
---

# Binary Data, Element, And Data-Count Sections

## Overview

Data and element segments are module-level initialization resources, not ordinary function-body instructions:

- **data segments** provide bytes for memories, either at instantiation time (`active`) or later through bulk-memory instructions (`passive`);
- **element segments** provide reference values for tables, either at instantiation time (`active`), later through table instructions (`passive`), or only as a declared pool of references (`declarative`);
- **data-count** records the number of data segments early enough for code-section validation of `memory.init` and `data.drop`.

The official WebAssembly 3.0 source snapshot in [`../raw/wasm/2026-05-13-data-element-and-datacount-sources.md`](../raw/wasm/2026-05-13-data-element-and-datacount-sources.md) is the primary source for section ids, segment modes, and data-count presence rules. Starshine mirrors those concepts in [`ElemMode`](../../../src/lib/types.mbt), [`ElemKind`](../../../src/lib/types.mbt), [`DataMode`](../../../src/lib/types.mbt), `ElemSec`, `DataCntSec`, and `DataSec`.

## Core Shapes

### Data segment modes

| Concept | Starshine representation | Binary shape | Validation contract |
| --- | --- | --- | --- |
| Active memory `0` | `DataMode::active(MemIdx(0), offset_expr)` | data header `0`, then offset expr, then bytes | memory `0` must exist; offset is a constant expression of that memory's address type. |
| Passive | `DataMode::passive()` | data header `1`, then bytes | no parent memory or offset to validate. |
| Active explicit memory | `DataMode::active(memidx, offset_expr)` | data header `2`, then `memidx`, offset expr, bytes | selected memory must exist; offset type follows that memory's limits. |

Text data segments in [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) accept an optional data id, optional memory use, optional `(offset ...)` wrapper, and one or more string literals. The lowering path in [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) treats an empty offset as passive data and a non-empty offset as active data.

### Element segment modes and kinds

| Concept | Starshine representation | Binary shape | Validation contract |
| --- | --- | --- | --- |
| Active function-index list on table `0` | `Elem(Active(TableIdx(0), offset), FuncsElemKind(funcs))` | elem header `0` | functions must exist; table `0` must accept `funcref`; offset is a constant address expression. |
| Passive function-index list | `Elem(Passive, FuncsElemKind(funcs))` | elem header `1`, kind byte `0` | functions must exist; no table or offset is checked. |
| Active function-index list on explicit table | `Elem(Active(tableidx, offset), FuncsElemKind(funcs))` | elem header `2`, table index, offset, kind byte `0` | selected table must exist and accept the segment ref type. |
| Declarative function-index list | `Elem(Declarative, FuncsElemKind(funcs))` | elem header `3`, kind byte `0` | functions must exist; no table or offset is checked. |
| Active expression list on table `0` | `Elem(Active(TableIdx(0), offset), FuncExprsElemKind(exprs))` | elem header `4` | each expression is a constant `funcref`; active-table checks still apply. |
| Passive typed expression list | `Elem(Passive, TypedExprsElemKind(rt, exprs))` | elem header `5`, ref type, expressions | ref type validates; each expression must be a constant of that ref type. |
| Active typed expression list | `Elem(Active(tableidx, offset), TypedExprsElemKind(rt, exprs))` | elem header `6`, table index, offset, ref type, expressions | selected table element type must accept the segment ref type. |
| Declarative typed expression list | `Elem(Declarative, TypedExprsElemKind(rt, exprs))` | elem header `7`, ref type, expressions | no table or offset; expressions still typecheck. |

[`src/binary/encode.mbt`](../../../src/binary/encode.mbt) and [`src/binary/decode.mbt`](../../../src/binary/decode.mbt) are the canonical local code map for these headers. The `FuncExprsElemKind` cases encode through the expression segment headers and synthesize a `funcref` ref type where the binary form requires one. Function-index element payloads use the same imported-prefix absolute `FuncIdx` model as calls, starts, and exports; see [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md). Active element and data modes also name table and memory index spaces whose imported-prefix rule and validation order are covered in [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md).

## Data-Count Rules

`DataCntSec` is section id `12`, while the actual data section is section id `11`. That ordering is intentional: function bodies in the code section can mention data indices before the decoder has reached the data section.

Starshine enforces two separate rules in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt):

1. [`validate_datacnt(...)`](../../../src/validate/validate.mbt) accepts absent data count, but when present it must equal the length of `DataSec`; `DataCntSec(0)` without a data section is accepted, while a nonzero count without `DataSec` is rejected.
2. `validate_bulk_memory_data_count_requirement(...)` rejects a module with no data-count section when any defined function body contains `memory.init` or `data.drop`.

This split is useful for diagnostics: a mismatched count is a section-level `datacnt` problem, while missing data count for a bulk-memory instruction is reported against the function body that required it.

## WAST Authoring Examples

### Active data for memory `0`

```wasm
(module
  (memory 1)
  (data (i32.const 8) "abc" "def"))
```

Starshine parses this as a data segment with concatenated bytes `abcdef`, default memory index `0`, and a non-empty offset. Lowering emits `DataMode::active(MemIdx(0), Expr([i32.const 8]))`.

### Passive data used by bulk memory

```wasm
(module
  (memory 1)
  (data $payload "hello")
  (func
    (memory.init $payload (i32.const 0) (i32.const 0) (i32.const 5))
    (data.drop $payload)))
```

A valid binary for this shape needs a data-count section because the code section names a data index. Starshine's WAST lowering emits `DataCntSec` whenever it emits any data segments, which satisfies this requirement for ordinary text-to-binary paths.

### Active typed element segment

```wasm
(module
  (type $f (func))
  (func $target)
  (table 1 (ref null $f))
  (elem (i32.const 0) (ref null $f) (item (ref.func $target))))
```

This lowers to a typed expression element segment. Validation checks both the expression's reference type and the active table's element type.

### Passive typed empty element segment

```wasm
(module
  (type $f (func))
  (table 0 (ref null $f))
  (elem (ref null $f)))
```

This unusual but important fixture is covered directly by [`src/wast/passive_typed_elem_surface_test.mbt`](../../../src/wast/passive_typed_elem_surface_test.mbt): parse and print preserve the typed empty declaration, lowering emits `ElemMode::passive()` plus `ElemKind::typed_exprs(...)`, and the result validates.

## Decode / Encode / Validation Flow

1. **Binary decode** reads `ElemSec` section `9`, `DataCntSec` section `12`, and `DataSec` section `11` into the structured module fields. Invalid element or data headers are decode errors.
2. **WAST parse** resolves text surface shape only: ids, table/memory uses, offsets, string payloads, function-index items, and typed item expressions.
3. **WAST lower** resolves ids to numeric indices, chooses `FuncsElemKind` when every item is a simple function reference and no explicit typed intent is present, chooses typed expression kinds for richer payloads, and inserts `DataCntSec` when data segments exist.
4. **Validation** checks parent memories/tables, offset const-ness and address type, element expression type, function/data/element index bounds, data-count equality, and the special code-section data-count requirement.
5. **Passes** that delete or reorder memories, tables, functions, data segments, or element segments must repair every affected surface: segment modes, payload references, bulk-memory/table-init instructions, exports, names, and any pass-local metadata.

## Edge Cases And Invariants

- **Active offsets are const expressions.** Non-constant active data or element offsets are validator failures and are intentionally covered by invalid-generation lanes.
- **Table/memory index defaults are syntax sugar.** Text forms can omit parent indices; lowering resolves them to numeric `TableIdx(0)` or `MemIdx(0)` only when the segment is active.
- **Typed element segments are not function-index lists.** Once an explicit element type or explicit `(item ...)` expression is present, preserve expression typing instead of collapsing blindly to `FuncsElemKind`.
- **Declarative-mode caveat in WAST lowering.** The core library and binary surfaces support `ElemMode::declarative()`, and generator/validation code exercises it. The WAST parser recognizes `(elem declare func ...)`, but the current WAST `ElemSegment` AST has no explicit mode field, so text-to-lib lowering infers mode from offset emptiness and does not yet preserve declarative mode as a distinct lowered mode. Treat this as a known WAST fidelity gap, not as evidence that Starshine's core representation lacks declarative elements.
- **Data-count presence and count equality are different checks.** Keep them distinct when adding diagnostics or invalid repros.
- **Name-section maps are coupled.** Element/data name maps in [`custom-and-name-sections.md`](custom-and-name-sections.md) must be rewritten or cleared whenever segment indices change.
- **Parent table and memory spaces are separate from segment spaces.** Deleting or reordering a memory/table requires repairing active segment modes in this page plus the parent resource indices documented in [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md).

## Related Pass And Tooling Notes

- [`memory-packing`](../binaryen/passes/memory-packing/index.md) is the segment-layout transform with the strongest data-segment contract: it may split active segments, delete dead passive segments, and rewrite `memory.init` / `data.drop` users.
- [`remove-unused-module-elements`](../binaryen/passes/remove-unused-module-elements/index.md) treats active segment startup effects and passive segment reachability as liveness roots or deletion candidates depending on mode and trap policy.
- [`memory64-lowering`](../binaryen/passes/memory64-lowering/index.md) must lower active data/element offset expressions as module-level initialization expressions; do not confuse those offsets with static `MemArg.offset` immediates.
- [`fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) tracks element/data segment range coverage, and [`validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) tracks AST/binary invalid families for element, data, data-count, and name-section segment indices.

## Sources

- Primary-source snapshot: [`../raw/wasm/2026-05-13-data-element-and-datacount-sources.md`](../raw/wasm/2026-05-13-data-element-and-datacount-sources.md)
- Core representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt)
- Binary decode/encode: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- WAST parse/lower/print evidence: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/passive_typed_elem_surface_test.mbt`](../../../src/wast/passive_typed_elem_surface_test.mbt), [`../../../src/wast/module_wast_tests.mbt`](../../../src/wast/module_wast_tests.mbt)
- Validation and fuzzing: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/gen_invalid_tests.mbt`](../../../src/validate/gen_invalid_tests.mbt), [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md)
