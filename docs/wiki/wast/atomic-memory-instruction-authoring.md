---
kind: concept
status: supported
last_reviewed: 2026-07-10
sources:
  - ../wasm-linear-memory-threads-boundary.md
  - ../wasm-relaxed-atomics-boundary.md
  - ../raw/wasm/2026-07-10-webassembly-core3-proposal-dashboard-recheck.md
  - ../raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md
  - ../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
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
  - ./gc-aggregate-instruction-authoring.md
  - ./resource-declaration-authoring.md
  - ../validate/resource-sections-and-limits.md
  - ../wasm-linear-memory-threads-boundary.md
  - ../binary/instruction-and-expression-encoding.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../validate/module-validation-phases.md
  - ../wasm-relaxed-atomics-boundary.md
---

# Atomic Memory Instruction Authoring

## Overview

Atomic memory instructions are the threads/proposal-backed operations that synchronize through **linear memory**: `memory.atomic.notify`, `memory.atomic.wait32`, `memory.atomic.wait64`, atomic loads/stores, atomic read-modify-write (RMW), atomic compare-exchange, and the sibling ordering barrier `atomic.fence`. In Starshine they are **real core instructions** with binary, validation, generator, HOT-IR, and effect-model coverage, but they are **not yet high-level WAST parser syntax**. Be precise about the split: every `MemArg`-based atomic helper selects a memory and currently validates against either a shared or unshared selected memory after ordinary memarg checks; `atomic.fence` has no `MemArg`, no selected memory, and no stack effect.

Do not use this page as the owner for every instruction whose name contains `atomic`. The Shared-Everything Threads proposal also has **shared-GC aggregate atomics** such as `struct.atomic.get*`. Starshine now has a focused WAST/core/binary/validator surface for `struct.atomic.get`, `struct.atomic.get_s`, and `struct.atomic.get_u`; route the proposal boundary through [`../wasm-shared-everything-threads-boundary.md`](../wasm-shared-everything-threads-boundary.md) and the local aggregate authoring details through [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md) instead of through `MemArg`-based memory rules. The official proposals tracker also now lists **Relaxed Atomics** as a separate active Phase-2 proposal for linear-memory ordering and `pause`; current Starshine ordinary atomics, `AtomicsFeature`, shared-GC `AtomicOrder::AcqRel`, and `RelaxedSimdFeature` are not evidence for relaxed-atomics support. Keep relaxed-atomics fixtures out of this page's positive examples until local AST/binary/validator/generator evidence exists, and route the detailed status vocabulary through [`../wasm-relaxed-atomics-boundary.md`](../wasm-relaxed-atomics-boundary.md) plus [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md).

Use this page when a fixture, pass, fuzzer row, or wiki claim mentions linear-memory atomics. Use [`../wasm-linear-memory-threads-boundary.md`](../wasm-linear-memory-threads-boundary.md) when the claim spans Threads proposal status, shared linear memory, `MemType(..., shared)`, ordinary atomics, `atomic.fence`, and nearby proposal boundaries. Use [`memory-instruction-authoring.md`](memory-instruction-authoring.md) for ordinary scalar and bulk memory instructions, [`memory-argument-authoring.md`](memory-argument-authoring.md) for `MemArg` alignment/offset/index rules, [`../wasm-shared-everything-threads-boundary.md`](../wasm-shared-everything-threads-boundary.md) for Shared-Everything proposal status, [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md) for `struct.atomic.get*`, [`resource-declaration-authoring.md`](resource-declaration-authoring.md) for memory declarations/imports in WAST text, and [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md) for validator-side memory limits, memory64, and Starshine-local shared-memory maximum policy.

The current Threads/local evidence summarized by [`../wasm-linear-memory-threads-boundary.md`](../wasm-linear-memory-threads-boundary.md) corrects the stale June local-policy claim: the threads draft validates ordinary `MemArg` atomics without a sharedness premise, and current Starshine's `memarg_check_atomic(...)` likewise checks memory existence, alignment, offset, and address width without rejecting unshared memory. The focused regression is [`Typecheck atomic load accepts non-shared memory`](../../../src/validate/typecheck_negative_tests.mbt). `AtomicFence` remains standalone `[] -> []` locally and in the draft. The older shared-memory and fence notes remain historical evidence for the shared-memory maximum rule, generator topology, and fence shape; they are superseded only for the current local unshared-atomic validation claim. The shared feature-status vocabulary for this Core-vs-proposal-vs-local distinction is [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md). The Shared-Everything proposal boundary is [`../wasm-shared-everything-threads-boundary.md`](../wasm-shared-everything-threads-boundary.md).

## Layer Boundary: Linear-Memory Core Yes, WAST Text No

Starshine currently has this split for linear-memory atomics:

| Layer | Status | Evidence |
| --- | --- | --- |
| Core instruction enum | Supported | [`src/lib/types.mbt`](../../../src/lib/types.mbt) defines notify/wait/fence, atomic load/store variants, `AtomicRmw`, `AtomicCmpxchg`, and operator enums. |
| Binary codec | Supported | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) handle the `0xFE` atomic-prefixed family. |
| Validation | Supported | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) routes atomic loads/stores, notify, wait, RMW, and cmpxchg through `memarg_check_atomic(...)`, which delegates to ordinary memory-index/alignment/offset/address-width validation and does **not** inspect the selected memory's shared bit. `AtomicFence` remains the no-memory, no-stack-effect sibling (`Ok(st)`). [`typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt) locks both invalid-memarg behavior and acceptance of an atomic load on unshared memory. This matches the threads draft's static validation split; draft execution still distinguishes unshared behavior, especially wait traps. |
| Valid generator / FZG | Supported | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt) emits coverage-forced atomics when a shared memory exists; [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) owns the `[FZG]017` `Atomics` ledger row. |
| HOT IR / effects | Supported | [`src/ir/hot_lift.mbt`](../../../src/ir/hot_lift.mbt) classifies atomics as `HotOp::Atomic`; [`src/ir/hot_lower.mbt`](../../../src/ir/hot_lower.mbt) lowers exact instructions; [`src/ir/effects.mbt`](../../../src/ir/effects.mbt) assigns memory/trap effects. |
| WAST keywords/parser | Not exposed for linear-memory atomics | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt) has no `i32.atomic.load`, `memory.atomic.wait32`, `atomic.fence`, or other linear-memory atomic keyword registrations, and [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) has no parser cases for those families. This does **not** describe `struct.atomic.get*`, which now has its own WAST surface. |
| Core debug printing | Debug-only for linear-memory atomics | [`src/lib/show.mbt`](../../../src/lib/show.mbt) can display core linear-memory atomics, but that output is not accepted high-level WAST input today. |

Do not read the linear-memory WAST gap as lack of Starshine support. It only means human-authored text fixtures for `i32.atomic.load`, `memory.atomic.wait32`, `atomic.fence`, and friends should use direct core builders, binary bytes, or `gen_valid` until a parser/lowerer/printer widening slice lands.

## Shared-GC Struct Atomic Get Boundary

`struct.atomic.get*` looks related by name, but it is a GC aggregate instruction rather than a linear-memory instruction:

| Family | Runtime operand | Immediates | Starshine WAST text | Owner page |
| --- | --- | --- | --- | --- |
| Linear-memory atomics | memory address plus value operands as needed | `MemArg` with alignment, offset, and selected memory | Not exposed today | This page plus [`memory-argument-authoring.md`](memory-argument-authoring.md) |
| `struct.atomic.get` / `_s` / `_u` | one struct reference | atomic order, type index, field index | Exposed with canonical `seq_cst` / `acq_rel` order spellings; `acqrel` is accepted as a compatibility alias | [`../wasm-shared-everything-threads-boundary.md`](../wasm-shared-everything-threads-boundary.md), [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md) |

Current Starshine source/tests document the get-only WAST slice, not aggregate atomic set/RMW/cmpxchg families; generic optimizer surfaces model the get variants conservatively as reads that may trap; focused regressions cover local-cse non-merging, precompute dropped-effect preservation, optimize-instructions load-call barriers, and simplify-locals no-sink ordering; and the focused local `global-struct-inference` slice covers immutable-field direct-global and closed-world local/param folds without turning generic atomic reads into freely movable pure operations.

## Beginner Model

Linear-memory atomic instructions combine four ideas:

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
| `atomic.fence` | unchanged | unchanged | ordering barrier; no stack effect, no `MemArg`, no selected-memory/sharedness check |

The concrete stack order is grounded in [`typecheck_atomic_notify(...)`](../../../src/validate/typecheck.mbt), [`typecheck_atomic_wait(...)`](../../../src/validate/typecheck.mbt), [`typecheck_atomic_rmw(...)`](../../../src/validate/typecheck.mbt), and [`typecheck_atomic_cmpxchg(...)`](../../../src/validate/typecheck.mbt). Atomic loads and stores use parallel atomic-specific helpers that first call `memarg_check_atomic(...)`, so `MemArg` alignment, offset, selected-memory existence, and address typing stay shared with ordinary memory checks. The local typechecker does not require that selected memory to be shared. `AtomicFence` bypasses all of those helpers because it is not a memory access.

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

For broad generator coverage, use the existing coverage-forced path instead of hand-writing every variant. [`gen_valid_append_atomic_ops(...)`](../../../src/validate/gen_valid.mbt) emits representative loads, stores, RMW, cmpxchg, wait/notify, and fence once [`gen_valid_atomic_shared_mem_idx(...)`](../../../src/validate/gen_valid.mbt) finds a shared memory. This is a deliberate shared-memory coverage choice, not a current Starshine `MemArg`-atomic stack requirement; `AtomicFence` is emitted in the same coverage slice but has no selected memory. The broader validity of that shared memory remains the resource-section contract; keep shared-memory maximum and memory64 declaration details routed through [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md) and the threads/shared-memory bridge. The retained invalid-AST id `invalid-function-body-atomic-load-non-shared-memory` is historical deterministic-repro vocabulary: its current mutation is invalid because it uses oversized alignment, not because its memory is unshared.

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

1. **Validate selected-memory and stack rules, not just decode.** Add positive and negative coverage near [`src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt) for existing shared and unshared selected memories, operand order, expected value type, invalid memory index, alignment, and offset-width failures; pair that with a separate `AtomicFence` check when the no-operand ordering barrier is what matters.
2. **Keep generator topology separate from validator policy.** The valid generator currently emits atomics only when a shared memory is available, but direct fixtures may intentionally use unshared memory to prove current static validation. Explain whether a fixture tests local stack typing, proposal-level execution semantics, byte-codec coverage, or the resource-section rule that shared memories need a maximum; route that last rule through [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md) and [`../wasm-linear-memory-threads-boundary.md`](../wasm-linear-memory-threads-boundary.md).
3. **Preserve memory ordering and trap behavior.** Treat atomic loads as reads, atomic stores/notify as writes, RMW/cmpxchg as read-write, and wait operations as read/trap-sensitive. `atomic.fence` has no stack effect and no memory operand, but it is still an ordering operation; do not delete or move it as if it were a `nop` without a memory-model proof.
4. **Keep WAST claims scoped.** If a linear-memory atomic test uses `@lib.Instruction` or raw bytes, call it core/binary evidence. Do not call it WAST text coverage until `src/wast/keywords.mbt`, `src/wast/parser.mbt`, lowering, printing, and WAST tests are widened. `struct.atomic.get*` is the exception with its own WAST surface and source snapshot.
5. **After memory remaps, repair `MemArg`s.** Atomic loads/stores, wait/notify, RMW, and cmpxchg carry the same `MemArg` memory-index/offset/alignment risks as ordinary loads and stores; `AtomicFence` does not. Pair this page with [`memory-argument-authoring.md`](memory-argument-authoring.md).
6. **For pass parity, classify mismatches carefully.** An output that validates can still be wrong if an atomic operation was reordered across another memory effect or if a fence vanished. Cite effect analysis, Binaryen oracle behavior, or an inspected semantic proof before calling a mismatch safe.

## Current Gaps And Caveats

- Starshine WAST does not currently accept **linear-memory** atomic text keywords such as `i32.atomic.load`, `memory.atomic.wait32`, or `atomic.fence`.
- Core debug `Show` output for linear-memory atomics is not a parser roundtrip contract.
- WAST memory declarations still lower through the `i32` limits path and have no shared-memory spelling; use direct core/binary fixtures for shared-memory atomic cases today, and cite [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md) for the validator-side shared-memory maximum rule.
- The generator's `[FZG]017` row is strong current-Starshine core/binary/validator evidence for ordinary linear-memory atomics, not evidence that arbitrary WAST text can author those shapes, that Starshine exactly matches every proposal execution distinction, or that the active Relaxed Atomics proposal is supported. Its shared-memory selection is generator topology, while current validator acceptance also covers unshared `MemArg` atomics. Relaxed-atomics work needs a future source recheck and the representation/codec/validator/generator checklist in [`../wasm-relaxed-atomics-boundary.md`](../wasm-relaxed-atomics-boundary.md).

## Sources

- Relaxed Atomics boundary: [`../wasm-relaxed-atomics-boundary.md`](../wasm-relaxed-atomics-boundary.md) and its cited official proposal sources
- Shared Core/proposal status bridge: [`../raw/wasm/2026-07-10-webassembly-core3-proposal-dashboard-recheck.md`](../raw/wasm/2026-07-10-webassembly-core3-proposal-dashboard-recheck.md)
- Current linear-memory Threads boundary: [`../wasm-linear-memory-threads-boundary.md`](../wasm-linear-memory-threads-boundary.md)
- Historical fence/unshared-memory reconciliation: [`../raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md`](../raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md)
- Historical linear-memory threads/shared-memory refresh: [`../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](../raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md)
- WebAssembly threads proposal sources: <https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md>, <https://webassembly.github.io/threads/core/syntax/types.html#memory-types>, <https://webassembly.github.io/threads/core/valid/types.html#memory-types>, <https://webassembly.github.io/threads/core/syntax/instructions.html>, <https://webassembly.github.io/threads/core/text/instructions.html>, <https://webassembly.github.io/threads/core/binary/instructions.html>, <https://webassembly.github.io/threads/core/valid/instructions.html>, <https://webassembly.github.io/threads/core/exec/instructions.html>
- Starshine implementation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/ir/hot_lift.mbt`](../../../src/ir/hot_lift.mbt), [`../../../src/ir/hot_lower.mbt`](../../../src/ir/hot_lower.mbt), [`../../../src/ir/effects.mbt`](../../../src/ir/effects.mbt), [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/struct_atomic_get_surface_test.mbt`](../../../src/wast/struct_atomic_get_surface_test.mbt)
