---
kind: guide
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../raw/research/0384-2026-04-26-llvm-memory-copy-fill-lowering-source-dossier.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../memory-packing/index.md
  - ../multi-memory-lowering/index.md
---

# Helper-call lowering and pass boundaries

## Why helper-call lowering is subtle

Replacing `memory.copy` or `memory.fill` with a call sounds mechanical, but it changes the surrounding module shape:

- a helper import or helper function may need to be added;
- call indices and type indices may change;
- the operation changes from a memory opcode to a call opcode;
- effect summaries may become less precise unless helper effects are modeled;
- validation now depends on both the call and the helper declaration.

For Starshine this means the pass is probably not just a HOT node rewrite. The HOT layer can see `HotOp::MemoryCopy` and `HotOp::MemoryFill`, but helper declaration insertion is module metadata work.

## Operand order invariant

The lowering must preserve the stack operand order:

- `memory.copy`: destination address, source address, length.
- `memory.fill`: destination address, fill value, length.

If any operand has side effects or can trap, that behavior must occur before the helper body runs, just as operand evaluation occurs before the original instruction.

## Trap and memory effects

The helper must preserve the original trap behavior:

- out-of-bounds copy/fill must still trap;
- overlapping `memory.copy` must have the same semantics as the instruction;
- `memory.fill` must write the same bytes as the instruction.

Downstream Starshine effects should treat the helper call conservatively unless the implementation also adds source-backed helper effect metadata.

## Boundary with `memory-packing`

[`memory-packing`](../memory-packing/index.md) is about data segments:

- active segment trimming/splitting;
- passive segment replacement decisions;
- `memory.init` / `data.drop` interactions;
- data-byte profitability and trap preservation.

`llvm-memory-copy-fill-lowering` does not start from segment bytes. It starts from already-emitted `memory.copy` and `memory.fill` instructions.

## Boundary with `multi-memory-lowering`

[`multi-memory-lowering`](../multi-memory-lowering/index.md) is about memory layout:

- combine multiple memories into one;
- add offset globals;
- shift memory-operation addresses;
- synthesize size/grow helpers for virtual memories.

`llvm-memory-copy-fill-lowering` does not combine memories. If a future Starshine port sees `MemoryCopy(dst, src)` with nonzero memory indices, it must either implement source-confirmed multi-memory helper semantics or reject/skip that shape explicitly.

## Boundary with `memory64-lowering`

[`memory64-lowering`](../memory64-lowering/index.md) is about address width and declaration width. It repairs 64-bit memory/table operations into 32-bit-compatible operations.

`llvm-memory-copy-fill-lowering` is about native bulk-memory opcode availability. Address width can interact with helper signatures, but the passes solve different compatibility problems.

## Beginner rule of thumb

Ask this question first:

> Am I removing `memory.copy` / `memory.fill` opcodes and replacing them with calls?

If yes, this dossier applies.

If you are repacking data, combining memories, changing memory address width, or rewriting `memory.init`, use the neighboring dossiers instead.
