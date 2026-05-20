---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-atomic-memory-instruction-sources.md
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/tests.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/typecheck_negative_tests.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/ir/hot_lift.mbt
  - ../../../src/ir/hot_lower.mbt
  - ../../../src/ir/effects.mbt
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
related:
  - ./memory-instruction-authoring.md
  - ./memory-argument-authoring.md
  - ./resource-declaration-authoring.md
  - ../binary/instruction-and-expression-encoding.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../validate/module-validation-phases.md
---

# Atomic Memory Instruction Authoring

## Overview

Atomic memory instructions are the threads/proposal-backed memory operations that synchronize through linear memory: `memory.atomic.notify`, `memory.atomic.wait32`, `memory.atomic.wait64`, `atomic.fence`, atomic loads/stores, atomic read-modify-write (RMW), and atomic compare-exchange. In Starshine they are **real core instructions** with binary, validation, generator, HOT-IR, and effect-model coverage, but they are **not yet high-level WAST parser syntax**.

Use this page when a fixture, pass, fuzzer row, or wiki claim mentions atomics. Use [`memory-instruction-authoring.md`](memory-instruction-authoring.md) for ordinary scalar and bulk memory instructions, [`memory-argument-authoring.md`](memory-argument-authoring.md) for `MemArg` alignment/offset/index rules, and [`resource-declaration-authoring.md`](resource-declaration-authoring.md) for memory definitions, imports, shared-memory caveats, and the current WAST declaration limits path.

The source manifest is [`../raw/wasm/2026-05-20-atomic-memory-instruction-sources.md`](../raw/wasm/2026-05-20-atomic-memory-instruction-sources.md). It checks the official WebAssembly threads proposal pages plus Starshine core, binary, validator, generator, HOT, and WAST surfaces.

## Layer Boundary: Core Yes, WAST Text No

Starshine currently has this split:

| Layer | Status | Evidence |
| --- | --- | --- |
| Core instruction enum | Supported | [`src/lib/types.mbt`](../../../src/lib/types.mbt) defines notify/wait/fence, atomic load/store variants, `AtomicRmw`, `AtomicCmpxchg`, and operator enums. |
| Binary codec | Supported | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) handle the `0xFE` atomic-prefixed family. |
| Validation | Supported | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) stack-types atomic loads/stores, notify, wait, RMW, cmpxchg, and fence; [`typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt) covers representative positives and negatives. |
| Valid generator / FZG | Supported | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt) emits coverage-forced atomics when a shared memory exists; [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) owns the `[FZG]017` `Atomics` ledger row. |
| HOT IR / effects | Supported | [`src/ir/hot_lift.mbt`](../../../src/ir/hot_lift.mbt) classifies atomics as `HotOp::Atomic`; [`src/ir/hot_lower.mbt`](../../../src/ir/hot_lower.mbt) lowers exact instructions; [`src/ir/effects.mbt`](../../../src/ir/effects.mbt) assigns memory/trap effects. |
| WAST keywords/parser | Not exposed | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt) has no atomic keyword registrations and [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) has no atomic instruction parser cases. |
| Core debug printing | Debug-only | [`src/lib/show.mbt`](../../../src/lib/show.mbt) can display core atomics, but that output is not accepted high-level WAST input today. |

Do not read the WAST gap as lack of Starshine support. It only means human-authored text fixtures should use direct core builders, binary bytes, or `gen_valid` until a parser/lowerer/printer widening slice lands.

## Beginner Model

Atomic instructions combine four ideas:

1. **A memory argument**: most forms carry `MemArg(align, mem?, offset)`, just like ordinary loads/stores.
2. **An address operand**: the first runtime operand is the selected memory's address type (`i32` for memory32, `i64` for memory64).
3. **A synchronization operation**: loads read, stores write, RMW/cmpxchg read and write, wait/notify interact with waiting agents, and fence orders memory operations.
4. **Trap/effect sensitivity**: successful validation does not prove runtime safety. Bounds, alignment/resource checks, and synchronization semantics mean optimizer passes must preserve order unless they have a real memory-model proof.

A useful mental table:

| Family | Stack before instruction | Stack after instruction | Starshine effect intuition |
| --- | --- | --- | --- |
| Atomic load | address | loaded `i32`/`i64` value | memory read + trap |
| Atomic store | address, value | nothing | memory write + trap |
| Atomic RMW | address, value | old value | memory read + write + trap |
| Atomic compare-exchange | address, expected, replacement | old value | memory read + write + trap |
| `memory.atomic.notify` | address, `i32` count | `i32` wake count | memory write + trap locally |
| `memory.atomic.wait32` | address, `i32` expected, `i64` timeout | `i32` status | memory read + trap locally |
| `memory.atomic.wait64` | address, `i64` expected, `i64` timeout | `i32` status | memory read + trap locally |
| `atomic.fence` | unchanged | unchanged | ordering barrier; no stack effect |

The concrete stack order is grounded in [`typecheck_atomic_notify(...)`](../../../src/validate/typecheck.mbt), [`typecheck_atomic_wait(...)`](../../../src/validate/typecheck.mbt), [`typecheck_atomic_rmw(...)`](../../../src/validate/typecheck.mbt), and [`typecheck_atomic_cmpxchg(...)`](../../../src/validate/typecheck.mbt). Loads and stores intentionally reuse the same `typecheck_load(...)` and `typecheck_store(...)` helpers as ordinary memory instructions, so `MemArg` alignment, offset, and selected-memory address typing stay shared.

## Concrete Core Fixture Shapes

Until WAST text support lands, prefer direct core fixtures for focused validator/pass tests:

```moonbit
let ma = @lib.MemArg::new(@lib.U32(2), Some(@lib.MemIdx::new(0)), @lib.U64(0))
let body = [
  @lib.Instruction::i32_const(@lib.I32(0)),
  @lib.Instruction::i32_atomic_load(ma),
  @lib.Instruction::drop(),
]
```

RMW and compare-exchange fixtures need the extra value operands:

```moonbit
let ma = @lib.MemArg::new(@lib.U32(2), Some(@lib.MemIdx::new(0)), @lib.U64(0))
let rmw = [
  @lib.Instruction::i32_const(@lib.I32(0)),  // address
  @lib.Instruction::i32_const(@lib.I32(1)),  // new operand
  @lib.Instruction::atomic_rmw(@lib.AtomicRmwOp::i32_add(), ma),
  @lib.Instruction::drop(),                  // old value
]
let cmpxchg = [
  @lib.Instruction::i32_const(@lib.I32(0)),  // address
  @lib.Instruction::i32_const(@lib.I32(1)),  // expected
  @lib.Instruction::i32_const(@lib.I32(2)),  // replacement
  @lib.Instruction::atomic_cmpxchg(@lib.AtomicCmpxchgOp::i32(), ma),
  @lib.Instruction::drop(),                  // old value
]
```

For broad generator coverage, use the existing coverage-forced path instead of hand-writing every variant. [`gen_valid_append_atomic_ops(...)`](../../../src/validate/gen_valid.mbt) emits representative loads, stores, RMW, cmpxchg, wait/notify, and fence once [`gen_valid_atomic_shared_mem_idx(...)`](../../../src/validate/gen_valid.mbt) finds a shared memory.

## Binary Encoding Contract

Binary atomics live under Starshine's `0xFE` prefixed opcode family:

- subcodes `0..2`: `memory.atomic.notify`, `memory.atomic.wait32`, `memory.atomic.wait64`;
- subcode `3`: `atomic.fence`, followed by a required zero immediate;
- subcodes `16..22`: atomic loads;
- subcodes `23..29`: atomic stores;
- subcodes `30..71`: atomic RMW operators;
- subcodes `72..78`: atomic compare-exchange operators.

The exact local map is in [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`atomic_rmw_op_id(...)`](../../../src/binary/encode.mbt), and [`atomic_cmpxchg_op_id(...)`](../../../src/binary/encode.mbt). [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) locks the local `atomic.fence` immediate rejection path so `0xFE 0x03 0x01` remains invalid.

## Validation And Signoff Guidance

When touching atomics:

1. **Validate stack effects, not just decode.** Add positive and negative coverage near [`src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt) for operand order, expected value type, invalid memory index, alignment, and offset-width failures.
2. **Keep shared-memory/resource context explicit.** The valid generator emits atomics only when a shared memory is available. Direct fixtures should explain whether they are testing local stack typing, proposal-level shared-memory semantics, or byte-codec coverage.
3. **Preserve memory ordering and trap behavior.** Treat atomic loads as reads, atomic stores/notify as writes, RMW/cmpxchg as read-write, and wait operations as read/trap-sensitive. `atomic.fence` has no stack effect, but it is still an ordering operation; do not delete or move it as if it were a `nop` without a memory-model proof.
4. **Keep WAST claims scoped.** If a test uses `@lib.Instruction` or raw bytes, call it core/binary evidence. Do not call it WAST text coverage until `src/wast/keywords.mbt`, `src/wast/parser.mbt`, lowering, printing, and WAST tests are widened.
5. **After memory remaps, repair `MemArg`s.** Atomics carry the same `MemArg` memory-index/offset/alignment risks as ordinary loads and stores. Pair this page with [`memory-argument-authoring.md`](memory-argument-authoring.md).
6. **For pass parity, classify mismatches carefully.** An output that validates can still be wrong if an atomic operation was reordered across another memory effect or if a fence vanished. Cite effect analysis, Binaryen oracle behavior, or an inspected semantic proof before calling a mismatch safe.

## Current Gaps And Caveats

- Starshine WAST does not currently accept atomic text keywords such as `i32.atomic.load`, `memory.atomic.wait32`, or `atomic.fence`.
- Core debug `Show` output for atomics is not a parser roundtrip contract.
- WAST memory declarations still lower through the `i32` limits path and have no shared-memory spelling; use direct core/binary fixtures for shared-memory atomic cases today.
- The generator's `[FZG]017` row is strong core/binary/validator evidence for atomics, not evidence that arbitrary WAST text can author those shapes.

## Sources

- Source manifest: [`../raw/wasm/2026-05-20-atomic-memory-instruction-sources.md`](../raw/wasm/2026-05-20-atomic-memory-instruction-sources.md)
- WebAssembly threads proposal sources: <https://github.com/WebAssembly/proposals/blob/main/proposals/threads/Overview.md>, <https://webassembly.github.io/threads/core/syntax/instructions.html>, <https://webassembly.github.io/threads/core/text/instructions.html>, <https://webassembly.github.io/threads/core/binary/instructions.html>, <https://webassembly.github.io/threads/core/valid/instructions.html>, <https://webassembly.github.io/threads/core/valid/modules.html>
- Starshine implementation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/ir/hot_lift.mbt`](../../../src/ir/hot_lift.mbt), [`../../../src/ir/hot_lower.mbt`](../../../src/ir/hot_lower.mbt), [`../../../src/ir/effects.mbt`](../../../src/ir/effects.mbt), [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt)
