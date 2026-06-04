# Memory/Table Address-Width Validation Refresh (2026-06-04)

## Purpose

This manifest refreshes the focused wiki guidance for WebAssembly memory64/table64 instruction stack widths and Starshine's current validator caveats. It supersedes the narrow freshness of the 2026-05-20 memory64 and table64 notes only for the official WebAssembly 3.0 page dates and for the local code-map anchors; their broader conclusions still stand.

## Primary external sources checked

- WebAssembly Core 3.0 syntax types, dated 2026-06-03: <https://webassembly.github.io/spec/core/syntax/types.html>
  - Address types are `i32` or `i64`.
  - `min(at1, at2)` chooses the address type with the smaller bit width.
  - Memory types and table types both carry an explicit address type plus limits.
- WebAssembly Core 3.0 validation instructions, dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Ordinary table instructions (`table.get`, `table.set`, `table.size`, `table.grow`) use the selected table address type `at`, not always `i32`.
  - `table.fill` uses `at, rt, at`; `table.copy` uses destination `at1`, source `at2`, and `min(at1, at2)` for length; `table.init` uses destination `at` plus `i32` source and length into the element segment.
  - `memory.size` / `memory.grow` use the selected memory address type.
  - `memory.fill` uses destination `at`, byte `i32`, and length `at`; `memory.copy` uses destination `at1`, source `at2`, and `min(at1, at2)` for length; `memory.init` uses destination `at` plus `i32` source and length into the data segment.
- WebAssembly Core 3.0 validation modules, dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/modules.html>
  - Module memory and table declarations validate through their memory/table types.
  - Core table initializers validate as constant expressions of the table element reference type; active element offsets validate against the target table address type.

## Local Starshine sources checked

- `src/validate/typecheck.mbt`
  - `typecheck_memory_size(...)` and `typecheck_memory_grow(...)` call `mem_at_of(...)`, so current Starshine uses the selected memory address type for size/grow.
  - `typecheck_memory_init(...)` pops length `i32`, source `i32`, and destination `at`, matching the official positional rule.
  - `typecheck_memory_copy(...)` reads both memories and uses `min_addr_valtype(lim1, lim2)` for length, matching the official mixed-width rule.
  - `typecheck_memory_fill(...)` still pops length `i32`, byte `i32`, and destination `at`, so memory64 `memory.fill` remains narrower than the official rule.
  - `typecheck_table_copy(...)` reads both tables, checks source reference type against destination reference type, and uses `min_addr(l1, l2)` for length, matching the official mixed-width rule.
  - `typecheck_table_init(...)` pops length `i32`, source `i32`, and destination `at`, matching the official positional rule.
  - `typecheck_table_fill(...)` still pops length `i32`, value `rt`, and start `at`, so table64 `table.fill` remains partially widened only.
  - `typecheck_table_get(...)`, `typecheck_table_set(...)`, `typecheck_table_size(...)`, `typecheck_table_grow(...)`, `typecheck_call_indirect(...)`, and `typecheck_return_call_indirect(...)` still use `i32` table indices/results/deltas locally, so ordinary table64 instruction validation remains incomplete.
- `src/validate/validate.mbt`
  - `Validate for MemType` allows `I64Limits` and enforces the local shared-memory maximum rule.
  - Active data offsets use the selected memory address type; active element offsets use the selected table address type.
  - `Validate for TableType` still validates table limits with the local 32-bit element-count cap recorded in `resource-sections-and-limits.md`.

## Durable conclusions

1. The official 2026-06-03 Core 3.0 pages continue to make memory/table address width positional, not family-wide: segment source offsets and segment lengths for `memory.init` / `table.init` stay `i32`, while runtime memory/table destinations use the selected resource address type.
2. Starshine is aligned on memory `size`/`grow`, `memory.init`, `memory.copy`, table `copy`, and table `init` address-width typing.
3. Starshine still has validation gaps for memory64 `memory.fill` length, table64 `table.fill` length, and ordinary table64 `table.get` / `set` / `size` / `grow` plus indirect-call table-index typing.
4. Resource-section validation can accept i64 table/memory limits before instruction validation is fully table64/memory64-complete. Wiki pages should keep the resource-level and instruction-level claims separate.

## Follow-ups

- If Starshine fixes `memory.fill` length typing, update `wast/memory-instruction-authoring.md`, `validate/module-validation-phases.md`, and any memory64-lowering pass-readiness notes that cite the caveat.
- If Starshine fixes ordinary table64 instruction typing, update `wast/table-instruction-authoring.md`, `validate/resource-sections-and-limits.md`, `validate/module-validation-phases.md`, and the memory64/table64 lowering dossier.
- If WAST text grows first-class memory64/table64 declarations or nonzero memory/table immediates, update the fixture-facing WAST pages separately from this validator refresh.
