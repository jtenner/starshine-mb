---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-memory64-lowering-alias-current-main-recheck.md
  - ../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md
  - ../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./static-offsets-dynamic-operands-and-grow-repair.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `memory64-lowering` implementation structure and tests

## Owner files

### `src/passes/Memory64Lowering.cpp`

This is the owner file behind both public aliases:

- `memory64-lowering`
- `table64-lowering`

`pass.cpp` constructs the same parameterless `Memory64Lowering` visitor for either spelling. Neither name selects a memory-only or table-only mode.

The important implementation pieces are:

- declaration lowering helpers for memory/table limits;
- address/index helpers that insert `i32.wrap_i64` for dynamic operands but produce `i32.const` or `unreachable` for constant operands depending on range;
- result repair helpers that zero-extend size results and repair grow failure sentinels;
- visitors for ordinary memory ops, SIMD memory ops, atomics, bulk memory operations, data offsets, table operations, element offsets, and module declarations.

The file should be read as a whole-module feature-lowering pass, not as a local peephole optimizer.

### `src/passes/pass.cpp`

`pass.cpp` publishes two discoverable names and their resource-focused help text. The registrations intentionally preserve familiar CLI vocabulary, but both construct the same combined transform; users cannot use the spelling to lower only memory64 or only table64.

### `src/passes/passes.h`

`passes.h` exposes the pass constructors in the ordinary Binaryen pass-constructor roster.

## Official test surface

### `test/lit/passes/memory64-lowering.wast`

This is the primary memory-focused proof file.
It covers the visible families a future Starshine port should mirror first; the exact local sequencing is maintained in [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md):

- memory declaration lowering;
- active data offset lowering to the new address type;
- scalar loads/stores;
- SIMD loads/stores;
- atomic memory operations;
- `memory.size` zero-extension and `memory.grow` operand plus failure-sentinel repair;
- bulk memory instructions such as `memory.init`, `memory.copy`, and `memory.fill`.

### One combined fixture, two invocations

`test/lit/passes/memory64-lowering.wast` is the official proof file for both public aliases. Its RUN lines invoke `--memory64-lowering` and `--table64-lowering` separately, then compare each result with the same expected output. That output includes the table declaration, active-element-offset, `table.get` / `table.set`, `table.size` / `table.grow`, `table.fill`, `table.init`, and `table.copy` families as well as the memory families.

This is an important test-design constraint: separate local memory-first and table-later fixtures are useful for implementation staging, but upstream parity must eventually show that either public spelling produces the same combined result on a mixed module.

## Source-location map for readers

| Question | Where to read first |
| --- | --- |
| Where are public pass names defined? | Binaryen `src/passes/pass.cpp` registrations for `memory64-lowering` and `table64-lowering` |
| What file owns the transform? | Binaryen `src/passes/Memory64Lowering.cpp` |
| How are source-level `i64` address operands repaired? | `Memory64Lowering.cpp` address/index helpers and the memory/table visitors that call them; dynamic operands, including syntactic `i64.const` operands, wrap with `i32.wrap_i64(...)`; the separate high-offset `unreachable` family is static `MemArg.offset`, not arbitrary operand constants |
| How are `memory.size` / `table.size` results repaired? | `Memory64Lowering.cpp` result-extension helpers plus size visitors |
| How are `memory.grow` / `table.grow` results repaired? | `Memory64Lowering.cpp` grow helper; deltas are lowered for the wasm32 grow and the lowered `i32` result gets failure-aware repair so `i32 -1` maps to the wasm64 sentinel |
| How do active data/element offsets get rewritten? | module/segment visitors in `Memory64Lowering.cpp` |
| What lit file proves both aliases? | `test/lit/passes/memory64-lowering.wast`; its two RUN lines invoke both public names against one expected output. |

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

- [`../../../raw/binaryen/2026-07-11-memory64-lowering-alias-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-memory64-lowering-alias-current-main-recheck.md)
- [`../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md`](../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md)
- [`../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md`](../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md)
- [`../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md)
- Binaryen `Memory64Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `memory64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast>
