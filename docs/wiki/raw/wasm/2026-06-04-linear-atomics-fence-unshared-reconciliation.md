---
kind: raw-source
status: supported
last_reviewed: 2026-06-04
sources:
  - https://webassembly.github.io/threads/core/valid/instructions.html
  - https://webassembly.github.io/threads/core/exec/instructions.html
  - https://webassembly.github.io/threads/core/binary/instructions.html
  - https://webassembly.github.io/threads/core/syntax/instructions.html
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
related:
  - ../../wast/atomic-memory-instruction-authoring.md
  - ../../validate/resource-sections-and-limits.md
  - ../../wasm-feature-status-and-proposal-boundaries.md
  - ./2026-06-04-linear-memory-threads-shared-memory-refresh.md
---

# Linear Atomics Fence And Unshared-Memory Reconciliation (2026-06-04)

## Why this note exists

The earlier 2026-06-04 shared-memory refresh correctly routed linear-memory atomics through the threads proposal/draft instead of stable Core 3.0 alone, but its shorthand wording was too broad in two ways:

1. `atomic.fence` is part of the atomic instruction family but has no `MemArg`, no selected memory, no stack operands, and may validate even in a module with no memories.
2. The threads draft validates the `MemArg`-based atomic memory instructions against a default memory and exact alignment, while execution distinguishes unshared and shared memories. Starshine currently rejects unshared memories during validation for every `MemArg`-based atomic helper by routing them through `memarg_check_atomic(...)`.

This note supersedes only those two shorthands. The broader [`2026-06-04-linear-memory-threads-shared-memory-refresh.md`](2026-06-04-linear-memory-threads-shared-memory-refresh.md) remains the shared source for memory-type flags, shared-memory maximum requirements, WAST declaration gaps, and GenValid `[FZG]006` / `[FZG]017` routing.

## Primary sources rechecked

- Threads draft validation lists `atomic.fence` as `[] -> []` and explicitly notes that it may occur in modules that declare no memory.
- Threads draft validation for `atomic.load`, packed atomic loads, atomic stores, RMW, cmpxchg, notify, and wait checks that memory `0` exists and that alignment equals the natural access width; it does not make sharedness part of those validation rules.
- Threads draft execution models unshared atomic loads/stores/RMW/cmpxchg through ordinary byte operations, while `memory.atomic.wait*` traps immediately on an unshared memory.
- Threads draft binary encoding maps `0xFE 0x03 0x00` to `atomic.fence`, unlike the neighboring `0xFE 0x00..0x02` forms that carry a `MemArg`.

## Starshine local evidence

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) represents `AtomicFence` as a standalone `Instruction` variant, separate from `MemoryAtomicNotify(MemArg)`, `MemoryAtomicWait32(MemArg)`, `MemoryAtomicWait64(MemArg)`, the atomic load/store variants, `AtomicRmw(AtomicRmwOp, MemArg)`, and `AtomicCmpxchg(AtomicCmpxchgOp, MemArg)`.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) dispatches `AtomicFence => Ok(st)`, so the instruction has no memory lookup and no stack effect locally.
- The same file routes atomic loads/stores/notify/waits/RMW/cmpxchg through `memarg_check_atomic(...)`, which calls the ordinary `memarg_check(...)` and then rejects an existing selected memory whose `MemType(..., shared)` flag is false with `"atomic memory access requires shared memory"`.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) decodes `0xFE` subcode `3` only when followed by immediate byte `0x00`; any other immediate is `InvalidAtomicFenceImmediate`.
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) emits subcode `3` plus the required zero immediate for `AtomicFence`.

## Durable conclusions

1. Use **linear-memory atomic memory instruction** or **`MemArg`-based atomics** when the claim depends on a selected memory, sharedness, address typing, or `MemArg` alignment/offset repair.
2. Treat `atomic.fence` as a sibling atomic-ordering instruction, not as a memory-access instruction: it has no `MemArg`, no memory-index repair obligation, no stack effect, and no shared-memory validation requirement in Starshine or the threads draft.
3. Starshine's current validation is conservative relative to the threads draft for every `MemArg`-based atomic helper: it rejects unshared-memory operands at validation time instead of accepting the module and letting execution choose the unshared/shared behavior.
4. Pass docs must still preserve `atomic.fence` as an ordering barrier. The absence of stack and memory operands does not make it equivalent to `nop` for transformations.
5. Future validation widening should be described as changing the `memarg_check_atomic(...)` policy for `MemArg`-based atomics, not as changing `AtomicFence`.
