---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `memory64-lowering` implementation structure and tests

## Owner files

### `src/passes/Memory64Lowering.cpp`

This is the owner file for both public siblings:

- `memory64-lowering`
- `table64-lowering`

The important implementation pieces are:

- declaration lowering helpers for memory/table limits;
- address/index wrapping helpers that insert `i32.wrap_i64`;
- result repair helpers that insert `i64.extend_i32_u`;
- visitors for ordinary memory ops, SIMD memory ops, atomics, bulk memory operations, data offsets, table operations, element offsets, and module declarations.

The file should be read as a whole-module feature-lowering pass, not as a local peephole optimizer.

### `src/passes/pass.cpp`

`pass.cpp` publishes the pass names and their help text.
The pass names are separate because users may lower memory64 without lowering table64, or vice versa.

### `src/passes/passes.h`

`passes.h` exposes the pass constructors in the ordinary Binaryen pass-constructor roster.

## Official test surface

### `test/lit/passes/memory64-lowering.wast`

This is the primary memory-focused proof file.
It covers the visible families a future Starshine port should mirror first:

- memory declaration lowering;
- active data offset lowering;
- scalar loads/stores;
- SIMD loads/stores;
- atomic memory operations;
- `memory.size` and `memory.grow` result/operand repair;
- bulk memory instructions such as `memory.init`, `memory.copy`, and `memory.fill`.

### `test/lit/passes/table64-lowering.wast`

This is the table-focused sibling proof file.
It covers:

- table declaration lowering;
- active element offset lowering;
- `table.get` and `table.set` index repair;
- `table.size` and `table.grow` result/operand repair;
- `table.fill`, `table.init`, and `table.copy` width-sensitive operands.

## Source-location map for readers

| Question | Where to read first |
| --- | --- |
| Where are public pass names defined? | Binaryen `src/passes/pass.cpp` registrations for `memory64-lowering` and `table64-lowering` |
| What file owns the transform? | Binaryen `src/passes/Memory64Lowering.cpp` |
| How are source-level `i64` address operands repaired? | `Memory64Lowering.cpp` address/index wrapping helpers and the memory/table visitors that call them |
| How are `memory.size` / `table.size` results repaired? | `Memory64Lowering.cpp` result-extension helpers plus size/grow visitors |
| How do active data/element offsets get rewritten? | module/segment visitors in `Memory64Lowering.cpp` |
| What lit file proves memory lowering? | `test/lit/passes/memory64-lowering.wast` |
| What lit file proves table lowering? | `test/lit/passes/table64-lowering.wast` |

## Tests that are especially important for a port

1. `memory.size` and `memory.grow` must preserve apparent `i64` results by adding `i64.extend_i32_u`.
2. Load/store address wrappers must not disturb payload types.
3. SIMD and atomic instructions need the same address repair as scalar loads/stores.
4. Bulk memory/table operations must pick widths by operand position, not by one global pass flag.
5. Segment offsets must be rewritten outside function bodies.
6. Mixed table32/table64 and memory32/memory64 copies need explicit regression coverage.

## Caveat: out-of-range limits and offsets

The reviewed tests prove the ordinary lowering surface. They should not be overread as a complete policy document for every impossible-to-fit 64-bit limit or offset.
Before Starshine implements the pass, source-confirm the exact Binaryen behavior for:

- memory/table minimums or maximums that exceed 32-bit output limits;
- active data or element offsets that do not fit in the lowered address space;
- any diagnostics or assertions around those cases.

## Sources

- [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- [`../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md)
- Binaryen `Memory64Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `memory64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast>
- Binaryen `table64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/table64-lowering.wast>
