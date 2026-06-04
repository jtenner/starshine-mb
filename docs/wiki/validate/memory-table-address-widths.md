---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md
  - ../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md
  - ../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md
  - ../raw/wasm/2026-05-20-resource-section-validation-refresh.md
  - ../../../src/lib/types.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/validate.mbt
related:
  - ./module-validation-phases.md
  - ./resource-sections-and-limits.md
  - ../wast/memory-instruction-authoring.md
  - ../wast/table-instruction-authoring.md
  - ../wast/memory-argument-authoring.md
  - ../wast/resource-declaration-authoring.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../binary/instruction-and-expression-encoding.md
---

# Memory And Table Address-Width Validation

## Overview

Use this page when a fixture, validator change, generator, binary codec change, or optimizer rewrite touches **memory64**, **table64**, **multi-memory**, or **multi-table** stack typing. It is the validator-side bridge between resource declarations and executable instructions:

- [`resource-sections-and-limits.md`](resource-sections-and-limits.md) owns whether a memory/table declaration is valid and how `Limits` are range-checked.
- [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md), [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md), and [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md) own fixture-facing text shapes and current WAST gaps.
- This page owns the cross-cutting rule: **the selected resource's address type controls specific stack operands, but not every operand in that instruction family**.

The current source bridge is [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md). It rechecked the official WebAssembly Core 3.0 syntax/validation pages and the local Starshine typechecker. A fresh web check during this wiki pass found the same official rule on the current Core 3.0 pages: memory and table instructions use address types positionally, while segment source offsets for `memory.init` / `table.init` remain `i32`.

## Beginner Model

A WebAssembly memory or table has a **limit type**. In Starshine that is represented by [`Limits`](../../../src/lib/types.mbt), either `I32Limits(...)` or `I64Limits(...)`. The limit type answers two different questions:

1. **Resource validation:** is the declaration itself legal? For example, is `min <= max`, is the page/element count within Starshine's chosen maximum, and does a shared memory have a maximum?
2. **Instruction validation:** what value type should a stack operand have when an instruction indexes or sizes that resource?

Do not collapse those questions. A module can contain an `I64Limits` memory or table and still fail when a specific instruction validator has not yet been widened to table64/memory64.

```text
resource declaration            instruction stack typing
--------------------            ------------------------
(memory i64-limits ...)   --->   memory.size/result, grow delta/result, load/store address,
                                bulk-memory destination/source/length positions

(table i64-limits ...)    --->   table.get index, table.size result, table.grow delta/result,
                                table.fill destination/length, table.copy positions,
                                indirect-call table element index
```

The hard part is that not all positions widen together. `memory.init` and `table.init` still use `i32` for the passive segment source offset and length because those operands index a data/element segment, not the destination memory/table.

## Official Positional Matrix

`at`, `at1`, and `at2` mean the address types of the selected memory/table resources. `min(at1, at2)` means the narrower of two address types for a mixed-width copy length.

| Instruction family | Official stack-width rule | Why the split exists |
| --- | --- | --- |
| Scalar memory load/store | Address operand uses selected memory `at`; store value uses the instruction's value type. | The address indexes memory bytes; the value is not an address. |
| `memory.size` / `memory.grow` | `memory.size` returns `at`; `memory.grow` consumes page delta `at` and returns `at`. | Page counts follow the memory's address width. |
| `memory.fill` | Destination `at`, byte value `i32`, length `at`. | Destination and length count memory bytes; the fill byte is still an `i32` value. |
| `memory.copy` | Destination `at1`, source `at2`, length `min(at1, at2)`. | A mixed memory32/memory64 copy can only address a range representable by both memories. |
| `memory.init` | Destination `at`, data-segment source offset `i32`, length `i32`. | The destination indexes memory, but the source/length index a passive data segment. |
| `table.get` / `table.set` | Table element index uses selected table `at`; value uses table reference type `rt`. | Index width follows the table; element value type follows table contents. |
| `table.size` / `table.grow` | `table.size` returns `at`; `table.grow` consumes value `rt`, delta `at`, and returns `at`. | Table sizes/deltas follow table address width. |
| `table.fill` | Destination `at`, value `rt`, length `at`. | Destination and length index table elements; value follows the table reference type. |
| `table.copy` | Destination `at1`, source `at2`, length `min(at1, at2)`. | Mixed table32/table64 copies use the narrowest representable range. |
| `table.init` | Destination `at`, element-segment source offset `i32`, length `i32`. | The destination indexes a table, while source/length index a passive element segment. |
| `call_indirect` / `return_call_indirect` | Function parameters plus selected table element index `at`. | The extra operand indexes the selected table. |

## Current Starshine Alignment And Gaps

The local code already uses the selected memory/table address type in several places, but some instruction families still contain `i32` assumptions. Treat this table as the current contract until code and tests prove a wider one.

| Surface | Current Starshine status | Code route |
| --- | --- | --- |
| Memory declaration limits | `I32Limits` and `I64Limits` validate at the resource layer; shared memory requires a maximum under the local/proposal threads model. | [`Validate for MemType`](../../../src/validate/validate.mbt), [`Limits::addr_valtype`](../../../src/lib/types.mbt) |
| Table declaration limits | `I32Limits` and `I64Limits` are represented, but table validation still uses a 32-bit element-count cap as documented by the resource-section page. | [`Validate for TableType`](../../../src/validate/validate.mbt) |
| Memory loads/stores and memargs | Selected memory address type is used for the dynamic address; WAST text still has nonzero-memory-index gaps. | [`memarg_check`](../../../src/validate/typecheck.mbt), [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md) |
| `memory.size` / `memory.grow` | Aligned: uses selected memory `at` for result and grow delta/result. | [`typecheck_memory_size`](../../../src/validate/typecheck.mbt), [`typecheck_memory_grow`](../../../src/validate/typecheck.mbt) |
| `memory.copy` | Aligned: destination `at1`, source `at2`, length `min(at1, at2)`. | [`typecheck_memory_copy`](../../../src/validate/typecheck.mbt) |
| `memory.init` | Aligned: destination `at`; data source and length `i32`. | [`typecheck_memory_init`](../../../src/validate/typecheck.mbt) |
| `memory.fill` | Gap: destination uses selected memory `at`, but length is still hard-coded to `i32`; memory64 positive fixtures with `i64` length are expected follow-up evidence. | [`typecheck_memory_fill`](../../../src/validate/typecheck.mbt) |
| `table.copy` | Aligned: destination/source widths plus mixed-width length; also checks source element reference type matches destination. | [`typecheck_table_copy`](../../../src/validate/typecheck.mbt) |
| `table.init` | Aligned for the destination/source split: destination `at`, element source and length `i32`. | [`typecheck_table_init`](../../../src/validate/typecheck.mbt) |
| `table.fill` | Gap: destination uses selected table `at`, but length is still `i32`; table64 positive fixtures with `i64` length are follow-up evidence. | [`typecheck_table_fill`](../../../src/validate/typecheck.mbt) |
| `table.get` / `table.set` / `table.size` / `table.grow` | Gap: ordinary table operations still use `i32` index/result/delta assumptions locally. | [`typecheck_table_get`](../../../src/validate/typecheck.mbt), [`typecheck_table_set`](../../../src/validate/typecheck.mbt), [`typecheck_table_size`](../../../src/validate/typecheck.mbt), [`typecheck_table_grow`](../../../src/validate/typecheck.mbt) |
| `call_indirect` / `return_call_indirect` | Gap: selected-table index is still popped as `i32` locally even though table64 should use selected table `at`. | [`typecheck_call_indirect`](../../../src/validate/typecheck.mbt), [`typecheck_return_call_indirect`](../../../src/validate/typecheck.mbt) |

## Concrete Fixture Guidance

### Memory64 bulk-memory positives and negatives

When widening or testing memory64, include all three bulk-memory shapes instead of only loads/stores:

```wat
;; Official memory64-positive shape, but current Starshine rejects the i64 length.
(memory.fill
  (i64.const 0)  ;; destination in memory64
  (i32.const 7)  ;; byte value
  (i64.const 4)) ;; length in memory64

;; Official memory64-positive shape Starshine already matches: segment offsets stay i32.
(memory.init 0
  (i64.const 0)  ;; destination in memory64
  (i32.const 0)  ;; source offset in data segment
  (i32.const 4)) ;; source length in data segment
```

For mixed-width `memory.copy`, test both memory directions if the change touches source/destination order. The length should be the narrower address type.

### Table64 positives and current local rejections

For table64 work, keep the ordinary-table and bulk-table surfaces separate:

```wat
;; Official table64-positive shape, but current Starshine still expects i32 index.
(table.get 0
  (i64.const 0))

;; Official table64-positive shape, but current Starshine still expects i32 length.
(table.fill 0
  (i64.const 0)  ;; destination in table64
  (ref.null func)
  (i64.const 1)) ;; length in table64

;; Official table64-positive shape Starshine already matches for destination only.
(table.init 0 0
  (i64.const 0)  ;; destination in table64
  (i32.const 0)  ;; source offset in element segment
  (i32.const 1)) ;; source length in element segment
```

Current high-level WAST declaration support is narrower than core/binary resource support, so many memory64/table64 tests should be direct core, binary, or generator fixtures rather than ordinary WAST text until the WAST pages say otherwise.

## Rewrite And Validation Checklist

Use this checklist for passes, generators, binary roundtrips, and validator changes:

1. **Name each operand role.** Say `destination`, `source`, `length`, `byte`, `value`, or `table element index`; do not say only "the memory/table operand".
2. **Keep resource validity separate from instruction validity.** Adding an `I64Limits` resource is not proof that every instruction using that resource is table64/memory64-valid.
3. **For copy operations, test mixed widths.** `memory.copy` and `table.copy` are the best regression surfaces for `min(at1, at2)` mistakes.
4. **For init operations, preserve segment `i32` operands.** Do not widen data/element segment source offsets or segment lengths just because the destination resource is memory64/table64.
5. **After changing a rule, update every routed page.** At minimum, update this page, [`module-validation-phases.md`](module-validation-phases.md), [`resource-sections-and-limits.md`](resource-sections-and-limits.md), and the matching WAST authoring page.
6. **Classify failures precisely.** A memory64/table64 body rejected by a known local `i32` assumption is a validator-widening gap, not malformed bytes and not necessarily a WAST parser gap.

## Sources

- Current focused source bridge: [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md)
- Earlier focused memory64 bridge: [`../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md`](../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md)
- Earlier focused table64 correction: [`../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md`](../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md)
- Resource-section validation bridge: [`../raw/wasm/2026-05-20-resource-section-validation-refresh.md`](../raw/wasm/2026-05-20-resource-section-validation-refresh.md)
- Official WebAssembly sources: <https://webassembly.github.io/spec/core/syntax/types.html>, <https://webassembly.github.io/spec/core/valid/instructions.html>, <https://webassembly.github.io/spec/core/valid/modules.html>
- Starshine implementation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
