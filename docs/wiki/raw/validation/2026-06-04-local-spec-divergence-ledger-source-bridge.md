# Validator Local/Spec Divergence Ledger Source Bridge

Capture date: 2026-06-04

Purpose: consolidate the already-documented validator-facing splits where current Starshine behavior is intentionally local, stricter than current WebAssembly Core 3.0, or currently narrower than the official rule. This bridge supports the living ledger at `docs/wiki/validate/local-spec-divergence-ledger.md`; it does not replace the focused pages that own each detailed rule.

## Primary external sources rechecked

- WebAssembly Core 3.0 validation instructions, dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Rechecked `ref.func`, memory/table address-width typing, exception-instruction tag result requirements, constant-expression instruction validation, and data/table/GC data-index instruction families.
- WebAssembly Core 3.0 validation modules, dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/modules.html>
  - Rechecked data-count presence, section/context construction, optional start validation, `refs` source construction for function references, tag-section validation, imports/exports, and constant-expression contexts.
- WebAssembly Core 3.0 validation types, dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/types.html>
  - Rechecked tag type validity and table/memory/type validation boundaries.
- WebAssembly Core 3.0 validation matching: <https://webassembly.github.io/spec/core/valid/matching.html>
  - Rechecked imported/exported external type matching boundaries and Core memory/table limit matching.

## Existing Starshine wiki/raw sources reused

- `docs/wiki/raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-exception-tag-current-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-data-count-code-data-index-recheck.md`
- `docs/wiki/raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-constant-expression-current-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`
- `docs/wiki/validate/module-validation-phases.md`
- `docs/wiki/validate/ref-func-declarations.md`
- `docs/wiki/validate/resource-sections-and-limits.md`
- `docs/wiki/validate/memory-table-address-widths.md`
- `docs/wiki/validate/data-count-and-code-data-indices.md`
- `docs/wiki/validate/import-export-and-external-type-matching.md`
- `docs/wiki/validate/constant-expressions.md`
- `docs/wiki/wasm-feature-status-and-proposal-boundaries.md`

## Repository evidence rechecked

- `src/validate/validate.mbt`
  - `collect_declared_funcs_bitmap(...)` excludes `start_sec` from Starshine's current `ref.func` declaration bitmap.
  - `Validate for TagType` still rejects resultful function types at tag import/tag-section validation time.
  - `validate_bulk_memory_data_count_requirement(...)` / `instr_uses_bulk_memory_data_count(...)` still precheck `MemoryInit` and `DataDrop` but not `ArrayNewData` or `ArrayInitData`.
  - `validate_const_instr(...)` remains both broader and narrower than current Core 3.0's constant-instruction set, as documented by the focused constant-expression page.
- `src/validate/typecheck.mbt`
  - `typecheck_memory_fill(...)` still types `len` as `i32` after resolving destination address type from the selected memory.
  - Table operations and indirect calls still retain several `i32` table-index/result assumptions; `table.copy` and `table.init` are already partially address-width-aware.
  - EH instruction validation consumes tag parameters and exception refs after `TagType` declaration validation has already enforced the current stricter local empty-result rule.
- `src/validate/match.mbt`
  - Starshine's reusable external-type matching includes local shared-memory flag equality in addition to Core limit/address-type matching.
- `src/lib/types.mbt`
  - Core instruction/type carriers include `ArrayNewData`, `ArrayInitData`, `MemoryFill`, table operations, `StringRefsSec`, and shared/memory64 limit shapes needed by the ledger.

## Durable conclusions

1. The existing focused pages are accurate but scattered. A small ledger page is useful as a navigation layer for maintenance work that changes validator behavior, invalid-fuzzer families, or pass output validity.
2. The ledger should not list every WAST text-surface gap. It should focus on validator semantics, local policy extensions, and proposal/local boundaries that can make a module accepted or rejected differently from current Core WebAssembly.
3. When one row is fixed or deliberately retained, update the focused owner page first, then the ledger and `docs/wiki/log.md` in the same change.

## No new uncertainty resolved

This pass did not discover a new divergence. It consolidated already-documented evidence and made the maintenance path easier to find from the wiki index and module-validation phase page.
