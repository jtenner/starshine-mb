---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-20
sources:
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - https://webassembly.github.io/spec/core/text/instructions.html
  - https://webassembly.github.io/spec/core/binary/instructions.html
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/validate.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
related:
  - ../../wast/table-instruction-authoring.md
  - ../../validate/module-validation-phases.md
  - ../../binaryen/passes/memory64-lowering/index.md
supersedes:
  - 2026-05-19-wast-table-instruction-sources.md#local-table-fill-width-summary
---

# Table64 Table Instruction Validation Refresh (2026-05-20)

Purpose: targeted correction for the table64 / table-address-width caveat in [`../../wast/table-instruction-authoring.md`](../../wast/table-instruction-authoring.md), especially the stale local claim in [`2026-05-19-wast-table-instruction-sources.md`](2026-05-19-wast-table-instruction-sources.md) that grouped `table.fill` with fully address-width-aware table operations.

## Primary sources rechecked

1. WebAssembly Core Specification 3.0, validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html> (opened 2026-05-20; page header shows WebAssembly 3.0 dated 2026-05-14).
   - `table.get` has instruction type `at -> rt` for the selected table.
   - `table.set` has instruction type `at rt -> epsilon`.
   - `table.size` has instruction type `epsilon -> at`.
   - `table.grow` has instruction type `rt at -> at`.
   - `table.fill` has instruction type `at rt at -> epsilon`; both destination and length use the selected table address type.
   - `table.copy` uses destination `at1`, source `at2`, and length `min(at1, at2)`.
   - `table.init` uses destination `at` but keeps element-segment source and length as `i32`.
2. WebAssembly Core Specification 3.0, text instructions: <https://webassembly.github.io/spec/core/text/instructions.html> (opened 2026-05-20; page header shows WebAssembly 3.0 dated 2026-05-14).
   - Table instruction text may omit table indices; omitted indices default to table `0`.
   - `table.copy` omission defaults both destination and source to `0`.
   - `table.init elemidx` is an abbreviation for `table.init 0 elemidx`.
3. WebAssembly Core Specification 3.0, binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html> (opened 2026-05-20; page header shows WebAssembly 3.0 dated 2026-05-14).
   - `table.get` / `table.set` are opcodes `0x25` / `0x26` with a table index immediate.
   - Prefixed table ops use `0xFC` subcodes `12..17` for `table.init`, `elem.drop`, `table.copy`, `table.grow`, `table.size`, and `table.fill`.
   - Binary `table.init` encodes element index before table index even though text spells table index before element index.

## Starshine local evidence rechecked

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `Limits::I32Limits` and `Limits::I64Limits`; `Limits::addr_valtype(...)` maps limits to `i32` or `i64`; `min_addr_valtype(...)` models mixed-width copy length selection.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt):
  - `typecheck_table_get(...)`, `typecheck_table_set(...)`, `typecheck_table_size(...)`, and `typecheck_table_grow(...)` still hard-code `i32` for index/result/delta positions.
  - `typecheck_call_indirect(...)` and `typecheck_return_call_indirect(...)` still hard-code the table element index operand as `i32`.
  - `typecheck_table_copy(...)` uses destination/source table limit address types plus `min_addr(...)` for length.
  - `typecheck_table_init(...)` uses the destination table limit address type, while source and length remain `i32`, matching the official split.
  - `typecheck_table_fill(...)` uses the destination table limit address type for the start index, but still hard-codes the length operand to `i32`. This is the correction to the older manifest and living page wording.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) uses selected table address types for active element offsets and validates table types/optional table initializer expressions during `tablesec`.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) and [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) preserve the text abbreviation and immediate-order split documented in the 2026-05-19 table-instruction source manifest; this refresh does not change those claims.

## Durable conclusions

1. The official table64 validation model is address-type-driven for ordinary runtime table indexes, sizes, grows, fills, copies, and active element offsets, with explicit exceptions for `table.init` source/length and mixed-width `table.copy` length.
2. Starshine's current table instruction validator is **partially** address-width-aware, not fully coherent for table64.
3. The previous shorthand "`table.fill` consults table address width" was incomplete: locally only the destination/start operand uses `lim.addr_valtype()`, while the length operand remains `i32`.
4. Future `table64-lowering` docs should list `table.fill` length cleanup beside `table.get`, `table.set`, `table.size`, `table.grow`, and indirect-call index cleanup before claiming table64 positive validation evidence.
5. WAST table-declaration text still lowers through `I32Limits`, so direct core or binary fixtures remain the right validation lane for table64 until the declaration surface is widened.
