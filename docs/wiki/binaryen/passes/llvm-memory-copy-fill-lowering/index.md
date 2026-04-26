---
kind: pass
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../raw/research/0384-2026-04-26-llvm-memory-copy-fill-lowering-source-dossier.md
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0414-2026-04-26-llvm-memory-copy-fill-lowering-port-readiness.md
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/passes/optimize.mbt
related:
  - ../memory64-lowering/index.md
  - ../multi-memory-lowering/index.md
  - ../memory-packing/index.md
  - ../signext-lowering/index.md
---

# `llvm-memory-copy-fill-lowering`

## What this pass does

Binaryen `llvm-memory-copy-fill-lowering` is a compatibility-lowering pass for the bulk-memory instructions `memory.copy` and `memory.fill`.

It is not a size optimizer, data-segment optimizer, or many-memory layout pass. Its job is to rewrite bulk-memory copy/fill operations into helper calls for toolchains that need the older LLVM/Emscripten-style helper-call surface instead of the raw WebAssembly bulk-memory opcodes. The source-backed owner is Binaryen's `LLVMMemoryCopyFillLowering.cpp`; the public pass name is registered separately from `memory-packing` and `multi-memory-lowering`.[^sources]

## Current Starshine status

Starshine does **not** currently implement or register this pass.

The local codebase does already understand the underlying instructions, and the 2026-04-26 port-readiness bridge now pins Binaryen's exact helper model: module-local `__memory_copy` / `__memory_fill` functions with `(i32, i32, i32) -> none` signatures, memory32/single-memory-only support, fatal boundaries for memory64, multi-memory, passive segment/table-bulk surfaces, and bulk-memory feature cleanup after lowering.

- WAST opcode names include `MemoryFill` and `MemoryCopy` in `src/wast/types.mbt:309-310` and lower them to lib instructions in `src/wast/lower_to_lib.mbt:2295-2301`.
- Binary encoding writes the bulk-memory prefix/opcodes for `MemoryCopy` and `MemoryFill` in `src/binary/encode.mbt:3055-3074`.
- Typechecking dispatches to `typecheck_memory_copy` and `typecheck_memory_fill` in `src/validate/typecheck.mbt:3137-3138`.
- HOT lift/lower can roundtrip `MemoryCopy` and `MemoryFill` via `src/ir/hot_lift.mbt:717-718` and `src/ir/hot_lower.mbt:970-977`.
- The pass registry arrays in `src/passes/optimize.mbt:107-129` do not list `llvm-memory-copy-fill-lowering` as hot, module, boundary-only, or removed.

So the honest local status is: representation yes, transformation pass no.

## Correctness constraints

A faithful port must preserve:

- operand evaluation order for destination, source/value, and length operands;
- memory-write effects and possible traps;
- helper function declarations, bodies, and call signatures;
- memory index semantics, especially because Starshine's lib IR represents `MemoryCopy(MemIdx, MemIdx)` and `MemoryFill(MemIdx)`;
- validation after adding helper functions and replacing instructions with calls.

## Inputs and outputs

Input instructions:

- `(memory.copy ...)`
- `(memory.fill ...)`

Output shape:

- module-local helper functions named from `__memory_copy` and `__memory_fill`, if the relevant opcode is used;
- calls to helper functions carrying the same logical operands;
- no change to unrelated `memory.init`, `data.drop`, active/passive data segment layout, table bulk operations, or memory declaration layout.

Binaryen's implementation creates temporary empty helper stubs, rewrites uses, populates only used helper bodies, removes unused helpers, and clears the bulk-memory optional feature after successful lowering.

## Important edges

- `memory.copy` and `memory.fill` do not require the data-count section rule that applies to `memory.init` / `data.drop`; Starshine's validator reflects that split in `src/validate/validate.mbt:2086-2118`.
- A first Starshine port should be memory-zero-only to match Binaryen's current fatal on multi-memory; do not drop `MemoryCopy(dst, src)` indices by accident.
- Memory64 is an upstream fatal boundary here; sequence [`../memory64-lowering/index.md`](../memory64-lowering/index.md) before this pass if a pipeline needs both.
- Because helper calls replace memory operations, downstream effect analysis must see call effects conservatively unless helper purity/effect metadata is also modeled.
- Binaryen explicitly does not model LLVM pointer-overflow undefined behavior in this pass; tests should not require stronger behavior than the oracle provides.

## Validation plan for a future port

1. Add reduced WAT tests for direct `memory.copy` and `memory.fill` lowering.
2. Add operand-order tests with trapping/effectful operands.
3. Add validation tests proving helper functions are declared with the expected signatures and bodies.
4. Compare with Binaryen using `wasm-opt --llvm-memory-copy-fill-lowering` on the same reduced fixtures.
5. Add negative tests for memory64, multi-memory, passive segment, and `table.copy` / `table.fill` boundaries.
6. Run `moon info`, `moon fmt`, `moon test`, then a targeted pass-fuzz comparison if the pass enters the public registry.

## Pages in this dossier

- [`binaryen-strategy.md`](binaryen-strategy.md) - upstream strategy and source map.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files, proof surfaces, and test caveats.
- [`wat-shapes.md`](wat-shapes.md) - transformed and non-transformed instruction shapes.
- [`helper-call-lowering-and-boundaries.md`](helper-call-lowering-and-boundaries.md) - helper-call ABI, traps, effects, and neighboring-pass boundaries.
- [`starshine-strategy.md`](starshine-strategy.md) - current local status and future port map.
- [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) - first-slice implementation order, validation ladder, and oracle boundaries.

[^sources]: See the primary-source manifest in [`../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md).
