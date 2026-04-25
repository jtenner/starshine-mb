---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md
  - ../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./static-offsets-dynamic-operands-and-grow-repair.md
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
- address/index helpers that insert `i32.wrap_i64` for dynamic operands but produce `i32.const` or `unreachable` for constant operands depending on range;
- result repair helpers that zero-extend size results and repair grow failure sentinels;
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
- active data offset lowering to the new address type;
- scalar loads/stores;
- SIMD loads/stores;
- atomic memory operations;
- `memory.size` zero-extension and `memory.grow` operand plus failure-sentinel repair;
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
| How are source-level `i64` address operands repaired? | `Memory64Lowering.cpp` address/index helpers and the memory/table visitors that call them; dynamic operands, including syntactic `i64.const` operands, wrap with `i32.wrap_i64(...)`; the separate high-offset `unreachable` family is static `MemArg.offset`, not arbitrary operand constants |
| How are `memory.size` / `table.size` results repaired? | `Memory64Lowering.cpp` result-extension helpers plus size visitors |
| How are `memory.grow` / `table.grow` results repaired? | `Memory64Lowering.cpp` grow helper; deltas are lowered for the wasm32 grow and the lowered `i32` result gets failure-aware repair so `i32 -1` maps to the wasm64 sentinel |
| How do active data/element offsets get rewritten? | module/segment visitors in `Memory64Lowering.cpp` |
| What lit file proves memory lowering? | `test/lit/passes/memory64-lowering.wast` |
| What lit file proves table lowering? | `test/lit/passes/table64-lowering.wast` |

## Tests that are especially important for a port

1. `memory.size` and `table.size` must preserve apparent `i64` results by adding `i64.extend_i32_u`.
2. `memory.grow` and `table.grow` must preserve wasm64 failure semantics, not only successful result width.
3. Dynamic load/store address wrappers must not disturb payload types.
4. Dynamic operand constants, static high `offset=` immediates, and active offsets need separate tests because Binaryen does not treat them as the same surface.
5. SIMD and atomic instructions need the same address repair as scalar loads/stores.
6. Bulk memory/table operations must pick widths by operand position, not by one global pass flag.
7. Segment offsets must be rewritten outside function bodies.
8. Mixed table32/table64 and memory32/memory64 copies need explicit regression coverage.

## Caveat: out-of-range limits and offsets

The 2026-04-25 static-offset correction narrowed the earlier constant/offset behavior: static memory-access `offset=` immediates at or above `2^32` become `unreachable`, but dynamic operand constants wrap and active segment offsets lower through expression repair. Max limits above the 32-bit maximum are still clamped. What remains uncertain is the user-facing policy for impossible minimum limits: the reviewed source asserts that lowered minimums fit after max clamping, but the dossier does not claim a polished diagnostic contract.

Before Starshine implements the pass, decide and test whether local impossible-minimum behavior should mirror Binaryen's internal assertion, reject at request time, or report a validation/lowering error. Also keep static-memarg-offset tests separate from dynamic-operand and active-segment tests.

## Sources

- [`../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md)
- [`../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md`](../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md)
- [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- [`../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md)
- Binaryen `Memory64Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `memory64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast>
- Binaryen `table64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/table64-lowering.wast>
