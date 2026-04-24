---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../memory-packing/index.md
  - ../instrument-memory/index.md
---

# Binaryen pass: `memory64-lowering`

## Purpose

`memory64-lowering` is Binaryen's wasm64-to-wasm32 index-width conversion pass for linear memory.
Its sibling `table64-lowering` applies the same idea to table indexes.
Both siblings matter to Starshine because Starshine already models memory/table limit widths, validates memory64 modules, and optimizes memory-heavy code, but it does **not** currently implement an index-width lowering pass.

The beginner version:

- memory64/table64 code uses `i64` indexes at the source level;
- wasm32 memory/table code uses `i32` indexes;
- Binaryen lowers declarations and inserts explicit casts so the final module is wasm32-typed while preserving the source-level typed context.

The advanced version:

- declarations change from 64-bit limits to 32-bit limits;
- former `i64` address-like operands become `i32.wrap_i64(...)` operands;
- former `i64` size/grow results become `i64.extend_i32_u(...)` around the lowered operation;
- bulk memory/table operations have destination/source/length width rules that depend on both participating memories or tables;
- active data and element offsets are part of the transform, not a function-body-only detail.

## Inputs and outputs

### Input shape

The input module may contain:

- memories with 64-bit limits;
- tables with 64-bit limits when running `table64-lowering`;
- memory/table instructions whose stack operands or results use `i64` because of those limits;
- active data or element segments with `i64` offset expressions.

### Output shape

The output module has:

- 32-bit memory/table limits for the lowered memories/tables;
- explicit `i32.wrap_i64` repairs around lowered address, delta, and length operands that used to be `i64`;
- explicit `i64.extend_i32_u` repairs around lowered `memory.size`, `memory.grow`, `table.size`, and `table.grow` results when the surrounding expression still expects `i64`;
- active offsets rewritten to 32-bit expression form.

## Correctness constraints

- **Type preservation:** every rewritten instruction must match the wasm32 operation signature after declarations are lowered.
- **Unsigned result repair:** size/grow results must use zero-extension, not sign-extension.
- **Bulk-operation width selection:** `copy`/`init`/`fill` operands are not all the same width. Destination, source, and length positions must be handled independently.
- **Segment offset repair:** active data and element offsets are observable initialization behavior and cannot be left at the old address type.
- **Out-of-range caveat:** this dossier does not claim Binaryen preserves semantics for 64-bit limits or offsets that cannot be represented in 32-bit output; the exact policy should be source-confirmed before porting.

## Notable edge cases

- Mixed memory32/memory64 or table32/table64 copies.
- `memory.size` / `table.size` in contexts that still use the source-level `i64` result.
- `memory.grow` / `table.grow`, which have both operand and result repair.
- SIMD and atomic memory instructions, which have normal address operands even though their payload/result types are unrelated to address width.
- Active data/element offsets outside function bodies.
- Table64 support in Starshine is currently uneven: `src/validate/typecheck.mbt` derives address widths for some table operations but still hard-codes `i32` for `table.get`, `table.set`, `table.size`, and `table.grow`.

## Validation strategy

For Binaryen parity research, use the official lit files:

- `test/lit/passes/memory64-lowering.wast`
- `test/lit/passes/table64-lowering.wast`

For a future Starshine port, add tests in this order:

1. declarations only: memory64/table64 limit records become 32-bit;
2. active data/element offset rewrites;
3. one scalar load/store positive;
4. `memory.size` / `memory.grow` result and operand repairs;
5. `memory.copy` mixed-width cases;
6. table64 `table.get` / `table.set` / `table.size` / `table.grow` after local typechecking is made coherent;
7. table copy/fill/init mixed-width cases;
8. SIMD and atomic address wrapping.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - source-backed Binaryen strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and official test surface.
- [`wat-shapes.md`](wat-shapes.md) - before/after shapes.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.

## Sources

- [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- [`../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md)
- Binaryen `Memory64Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp>
- Binaryen registration source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
