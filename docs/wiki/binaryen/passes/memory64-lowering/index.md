---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md
  - ../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./static-offsets-dynamic-operands-and-grow-repair.md
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
- dynamic former `i64` address-like operands become `i32.wrap_i64(...)` operands, even when the operand expression is syntactically `i64.const`;
- static `MemArg.offset` immediates at or above `2^32` become `unreachable` rather than wrapping;
- active data/element offset expressions are lowered to the new 32-bit address type; the reviewed source does not prove a high-active-offset trap special case;
- former `i64` size results become `i64.extend_i32_u(...)` around the lowered operation;
- former `i64` grow results need failure-sentinel repair: the lowered grow result is checked for `i32 -1`, successful lowered `i32` results are zero-extended, and failed grows map back to the 64-bit failure sentinel;
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
- explicit `i32.wrap_i64` repairs around dynamic lowered address, delta, and length operands that used to be `i64`;
- `unreachable` replacements for statically out-of-range `MemArg.offset` immediates;
- explicit unsigned-extension repairs around lowered `memory.size` and `table.size` results when the surrounding expression still expects `i64`;
- failure-aware repairs around lowered `memory.grow` and `table.grow` results so the wasm32 `-1` sentinel becomes the wasm64 failure sentinel;
- active offsets rewritten to 32-bit expression form.

## Correctness constraints

- **Type preservation:** every rewritten instruction must match the wasm32 operation signature after declarations are lowered.
- **Unsigned result repair:** size results and successful grow results must use zero-extension, not sign-extension.
- **Grow failure repair:** wasm32 grow returns `i32 -1` on failure, but wasm64 callers expect the 64-bit failure sentinel; lowered grows need explicit sentinel repair.
- **Bulk-operation width selection:** `copy`/`init`/`fill` operands are not all the same width. Destination, source, and length positions must be handled independently.
- **Segment offset repair:** active data and element offsets are observable initialization behavior and cannot be left at the old address type; the reviewed source lowers those offset expressions to 32-bit form rather than proving the static-memarg high-offset trap rule for active segments.
- **Limit caveat:** max limits above the 32-bit maximum are clamped, but the reviewed source asserts that min limits fit after lowering instead of exposing a polished user-facing diagnostic contract.

## Notable edge cases

- Mixed memory32/memory64 or table32/table64 copies.
- `memory.size` / `table.size` in contexts that still use the source-level `i64` result.
- `memory.grow` / `table.grow`, which have operand wrapping plus failure-sentinel result repair, not just blind zero-extension.
- SIMD and atomic memory instructions, which have normal address operands even though their payload/result types are unrelated to address width.
- Active data/element offsets outside function bodies.
- Table64 support in Starshine is currently uneven: `src/validate/typecheck.mbt` derives address widths for some table operations but still hard-codes `i32` for `table.get`, `table.set`, `table.size`, and `table.grow`.

## Validation strategy

For Binaryen parity research, use the official lit files:

- `test/lit/passes/memory64-lowering.wast`
- `test/lit/passes/table64-lowering.wast`

For a future Starshine port, add tests in this order:

1. declarations only: memory64/table64 limit records become 32-bit;
2. active data/element offset rewrites to the lowered address type;
3. one dynamic scalar load/store positive with `i32.wrap_i64`;
4. one dynamic `i64.const` address operand positive that still wraps rather than becoming `unreachable`;
5. one static high-`offset=` scalar load/store case that becomes `unreachable` with child effects preserved;
6. `memory.size` unsigned result repair;
7. `memory.grow` operand wrapping plus failure-sentinel result repair;
8. `memory.copy` mixed-width cases;
9. table64 `table.get` / `table.set` / `table.size` / `table.grow` after local typechecking is made coherent;
10. table copy/fill/init mixed-width cases;
11. SIMD and atomic address wrapping plus high static `offset=` replacement.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - source-backed Binaryen strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and official test surface.
- [`static-offsets-dynamic-operands-and-grow-repair.md`](static-offsets-dynamic-operands-and-grow-repair.md) - corrected guide to static `offset=` immediates, dynamic operands, active offsets, and grow failure repair.
- [`wat-shapes.md`](wat-shapes.md) - before/after shapes.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.

## Sources

- [`../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md)
- [`../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md`](../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md)
- [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- [`../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md)
- Binaryen `Memory64Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp>
- Binaryen registration source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
