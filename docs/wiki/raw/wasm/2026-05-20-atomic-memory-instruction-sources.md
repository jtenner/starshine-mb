# Atomic Memory Instruction Source Snapshot

- Source family: WebAssembly threads proposal, official proposal-tracking metadata, and Starshine local source.
- Capture date: 2026-05-20.
- Reason for capture: Starshine already carries atomic memory instructions in the core instruction enum, binary codec, validator, HOT IR, and valid-generator ledger, while the higher-level WAST parser still does not expose atomic text keywords. This snapshot records the proposal/implementation boundary so FZG atomics coverage and future WAST widening stay honest.

## Primary external sources checked

1. WebAssembly threads proposal repository, proposal status metadata: <https://github.com/WebAssembly/proposals/blob/main/proposals/threads/Overview.md>
2. WebAssembly threads proposal, instruction syntax: <https://webassembly.github.io/threads/core/syntax/instructions.html>
3. WebAssembly threads proposal, text instruction syntax: <https://webassembly.github.io/threads/core/text/instructions.html>
4. WebAssembly threads proposal, binary instruction encoding: <https://webassembly.github.io/threads/core/binary/instructions.html>
5. WebAssembly threads proposal, instruction validation: <https://webassembly.github.io/threads/core/valid/instructions.html>
6. WebAssembly threads proposal, memory/module validation: <https://webassembly.github.io/threads/core/valid/modules.html>

## Source-backed takeaways

- Atomic instructions are proposal-sourced through the WebAssembly threads work rather than introduced by Starshine. The proposal tracking page is the status anchor; the threads draft pages are the instruction-level semantic anchor.
- The threads instruction family includes wait/notify, fence, atomic loads/stores, read-modify-write operators, and compare-exchange operators. It is a memory instruction family: almost every form carries a memory argument, consumes an address, and can trap on the same resource/range constraints as other memory operations.
- The binary encoding uses the atomic-prefixed opcode space. Starshine's binary codec mirrors that design by decoding and encoding `0xFE` plus subcode ids for notify/wait/fence/load/store/RMW/cmpxchg.
- Validation is not just byte decoding. Loads consume the selected memory address type and push the loaded integer type; stores consume address plus value; notify consumes address plus `i32` count and returns `i32`; wait consumes address, expected value, and `i64` timeout and returns `i32`; RMW consumes address plus one value and returns the old value; compare-exchange consumes address, expected value, replacement value, and returns the old value; fence preserves the operand stack.
- Shared-memory authoring is part of realistic atomic fixtures. Starshine's coverage-forced generator currently chooses an existing shared memory before emitting atomics, which keeps generator claims tied to the threads-memory context instead of treating atomics as ordinary scalar loads/stores.

## Starshine local source map

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `MemoryAtomicNotify`, `MemoryAtomicWait32`, `MemoryAtomicWait64`, `AtomicFence`, atomic load/store variants, `AtomicRmw`, `AtomicCmpxchg`, and the associated operator enums.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) decodes the `0xFE` atomic-prefixed family and rejects nonzero `atomic.fence` immediates.
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) emits the matching `0xFE` subcodes and the mandatory zero fence immediate.
- [`src/binary/tests.mbt`](../../../../src/binary/tests.mbt) has focused invalid-fence-immediate coverage.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) stack-types atomic loads/stores through shared load/store helpers and separately stack-types notify/wait/RMW/cmpxchg/fence.
- [`src/validate/typecheck_negative_tests.mbt`](../../../../src/validate/typecheck_negative_tests.mbt) covers positive notify/fence stack effects plus representative wrong-type, invalid-memory-index, alignment, and offset negatives.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) emits coverage-forced atomic loads, stores, RMW, cmpxchg, wait/notify, and fence only when a shared memory is available, and records the `Atomics` feature fact.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) exposes the `[FZG]017` `Atomics` ledger row and the coverage-forced validation anchor test.
- [`src/ir/hot_lift.mbt`](../../../../src/ir/hot_lift.mbt), [`src/ir/hot_lower.mbt`](../../../../src/ir/hot_lower.mbt), [`src/ir/effects.mbt`](../../../../src/ir/effects.mbt), and [`src/ir/hot_side_tables.mbt`](../../../../src/ir/hot_side_tables.mbt) keep atomics as HOT `Atomic` nodes with `MemArg` side-table data, exact-instruction lowering, and memory read/write/trap effects.
- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) does not register atomic text keywords today, and [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) has no atomic parser cases. Treat this as a WAST text-surface gap, not a core/binary/validator absence.
- [`src/lib/show.mbt`](../../../../src/lib/show.mbt) can print core atomic instruction variants for debugging, but that output should not be mistaken for accepted high-level WAST input until parser/lowerer/printer support lands.

## Current caveats to preserve

- Starshine core/binary/validator/generator support is broader than Starshine WAST text support for atomics.
- Atomic fixtures that need nonzero memory indices, shared memory, memory64, or direct opcode coverage should currently be direct core, binary, or generator fixtures, not hand-written WAST parser fixtures.
- Optimizer docs must keep atomic operations effectful and trap-sensitive. Atomic loads are reads and traps; atomic stores/notify are writes and traps; RMW/cmpxchg are reads plus writes plus traps; fence is not a memory read/write in Starshine's current effect mask but must not be erased or reordered casually without a memory-model proof.
