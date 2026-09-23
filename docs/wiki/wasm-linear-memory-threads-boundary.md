---
kind: concept
status: supported
last_reviewed: 2026-09-23
sources:
  - https://webassembly.github.io/threads/core/valid/instructions.html
  - https://webassembly.github.io/threads/core/exec/instructions.html
  - https://github.com/WebAssembly/proposals
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/basic/relaxed-atomics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/validation/relaxed-atomics.wast
  - wast/atomic-memory-instruction-authoring.md
  - validate/resource-sections-and-limits.md
  - wast/resource-declaration-authoring.md
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/validate.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/validate/gen_valid.mbt
  - ../../scripts/lib/optimizer-atomic-runtime.test.ts
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wasm-relaxed-atomics-boundary.md
  - wasm-memory-control-boundary.md
  - wasm-custom-page-sizes-boundary.md
  - wast/atomic-memory-instruction-authoring.md
  - wast/resource-declaration-authoring.md
  - wast/memory-argument-authoring.md
  - validate/resource-sections-and-limits.md
  - validate/memory-table-address-widths.md
  - binary/type-table-memory-global-tag-sections.md
  - fuzzing/generator-coverage-ledger.md
---

# Linear-Memory Threads And Shared-Memory Boundary

The Binaryen 132 intake records the linear-atomic WAST surface, including named/numeric memory selection, memory64/shared declarations and all three orders. Earlier text-parser-gap statements below are superseded by [atomic authoring](wast/atomic-memory-instruction-authoring.md). External execution support remains proposal-specific.

## Overview

Use this page when a Starshine claim mentions **linear shared memory**, **ordinary threads atomics**, or the local `shared` bit on a WebAssembly memory type. It is the living router between:

- current WebAssembly Core memory concepts such as ordinary memories, memory64, multi-memory, and bulk memory;
- the active **Threads** proposal/draft evidence for shared linear memories and `0xFE` atomics;
- Starshine's current core/binary/validator/generator implementation subset; and
- nearby but separate proposals such as Relaxed Atomics, Shared-Everything Threads / shared-GC atomics, Memory Control, and Custom Page Sizes.

For beginners: a WebAssembly module can define one or more linear memories. A **shared** memory is intended for multiple agents/threads, so it needs a maximum bound and can be used by atomic operations. Atomic operations are not just unusual loads and stores: they carry synchronization semantics that optimizers must preserve.

The Threads draft and current local typechecker agree on the static-validation boundary: [`memarg_check_atomic(...)`](../../src/validate/typecheck.mbt) accepts an existing selected memory whether it is shared or unshared, after ordinary index/alignment/offset checks. `AtomicFence` remains distinct because it has no memory argument or stack effect, but that difference is **not** a sharedness split. The shared-memory maximum and proposal execution distinctions are grounded below in current Threads sources and local resource/typechecker evidence. The shared Core/proposal status bridge [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md) keeps Threads as active Phase 4 status-only evidence, not proof of full local support.

## Boundary Map

| Surface | Upstream status / source tier | Current Starshine layer | Owner page |
| --- | --- | --- | --- |
| Ordinary memory32/memory64 limits | Core / finished-feature evidence for address width and limits. | Core and binary model `I32Limits` and `I64Limits`; WAST declarations are still narrower. | [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md), [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md) |
| Shared linear memory | Threads proposal/draft evidence, not stable-Core-alone evidence. | `MemType(Limits, Bool)` stores sharedness; validation rejects shared memories without a maximum. | This page plus [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md) |
| Ordinary `0xFE` atomics | Threads proposal/draft instruction evidence. | Core, binary, validator, generator, HOT/effects support the current local subset. `MemArg` forms typecheck against an existing shared **or unshared** memory; generator coverage intentionally chooses shared memory. The v132 WAST surface covers named/numeric memory selection, memory64/shared declarations and the represented order forms. | [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) |
| `atomic.fence` | Threads / ordering barrier. | Core/binary/validator carry `AtomicOrder::{SeqCst, AcqRel, Relaxed}` on the standalone `[] -> []` fence; it has no selected memory and no sharedness check. | [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) |
| Relaxed Atomics | Separate active Phase-2 proposal for ordering immediates and `pause`. | Partial local representation: linear loads/stores/RMW/cmpxchg/fence carry `SeqCst`, `AcqRel` or `Relaxed` through WAST, binary and HOT; `pause`, dedicated proposal gating and full runtime support remain absent. | [`wasm-relaxed-atomics-boundary.md`](wasm-relaxed-atomics-boundary.md) |
| Shared-GC aggregate atomics | Shared-Everything / GC aggregate surface, not linear-memory `MemArg` atomics. | Shared type metadata plus struct/array atomic get/RMW/cmpxchg are core/binary/validator/HOT-visible; WAST coverage is narrower and aggregate set/wait/notify remain future work. | [`wasm-shared-everything-threads-boundary.md`](wasm-shared-everything-threads-boundary.md), [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md) |
| Memory Control | Separate active Phase-1 runtime memory-management proposal. | No `memory.discard` / lazy commit / mapping / BYOB support. | [`wasm-memory-control-boundary.md`](wasm-memory-control-boundary.md) |
| Custom Page Sizes | Separate active-proposal memory-type dimension. | No page-size field, binary flag, validator dimension, or WAST spelling. | [`wasm-custom-page-sizes-boundary.md`](wasm-custom-page-sizes-boundary.md) |

## Starshine Implementation Shape

Starshine's memory type is intentionally small today:

```moonbit
pub enum Limits {
  I32Limits(UInt, UInt?)
  I64Limits(UInt64, UInt64?)
}

pub struct MemType(Limits, Bool)
```

The `Bool` is the local shared-memory flag. It is represented in core types at [`src/lib/types.mbt`](../../src/lib/types.mbt), in the memory-type binary flag matrix at [`src/binary/decode.mbt`](../../src/binary/decode.mbt) / [`src/binary/encode.mbt`](../../src/binary/encode.mbt), and in memory validation at [`src/validate/validate.mbt`](../../src/validate/validate.mbt).

The current binary memory-type matrix is:

| Flag byte | Meaning in Starshine decode/encode | Validation consequence |
| --- | --- | --- |
| `0x00` | memory32 min only | Valid if bounds fit. |
| `0x01` | memory32 min + max | Valid if `min <= max` and bounds fit. |
| `0x02` | shared memory32 min only | Decode-accepted but validation-invalid: shared memory lacks max. |
| `0x03` | shared memory32 min + max | Valid if bounds fit. |
| `0x04` | memory64 min only | Valid if bounds fit local memory64 policy. |
| `0x05` | memory64 min + max | Valid if bounds fit. |
| `0x06` | shared memory64 min only | Decode-accepted but validation-invalid: shared memory lacks max. |
| `0x07` | shared memory64 min + max | Valid if bounds fit. |

`Validate for MemType` enforces the high-value shared-memory invariant: if `shared=true`, the limit must include `Some(max)`. That makes `0x02` and `0x06` excellent invalid-binary / invalid-module fixtures, but they must not be described as successful shared-memory support examples.

## Atomic Instruction Split

Starshine's current ordinary linear-memory atomic support is real but layer-specific:

1. [`src/lib/types.mbt`](../../src/lib/types.mbt) has ordinary atomic instruction variants for wait/notify, fence, atomic loads/stores, RMW, and compare-exchange.
2. [`src/binary/decode.mbt`](../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../src/binary/encode.mbt) handle the `0xFE` atomic-prefixed family.
3. [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) routes `MemArg`-based atomics through `memarg_check_atomic(...)`, which currently performs ordinary memory-index, alignment, offset, and address-width checks but does **not** require the selected memory's `shared` bit. [`src/validate/typecheck_negative_wbtest.mbt`](../../src/validate/typecheck_negative_wbtest.mbt) locks the positive non-shared atomic-load case.
4. `AtomicFence` is different: the typechecker accepts it as `Ok(st)` because it has no memory argument and no stack effect.
5. [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt) emits its coverage prelude only when `allow_atomics` is enabled and it can find a shared memory. That is representative generator topology, not a validator precondition; the focused typechecker regression cited above is the local proof.
6. The v132 high-level WAST keywords/parser arms expose the represented linear-memory atomic text, including `i32.atomic.load`, `memory.atomic.wait32`, and `atomic.fence`. Use the focused authoring page for the supported spelling and keep any still-unrepresented proposal instruction on the core/binary/generated route.

### Example: valid shared-memory core shape (but sharedness is not an atomic validation precondition)

```moonbit
let mem = @lib.MemType::new(@lib.Limits::i32(1, Some(2)), shared=true)
let ma = @lib.MemArg::new(@lib.U32(2), Some(@lib.MemIdx::new(0)), @lib.U64(0))
let body = [
  @lib.Instruction::i32_const(@lib.I32(0)),
  @lib.Instruction::i32_atomic_load(ma),
  @lib.Instruction::drop(),
]
```

This is a core/validator fixture shape, not WAST text. The memory's shared max is part of the module resource shape; the atomic instruction's `MemArg` selects that memory; and validation then checks the selected memory, address type, alignment, offset, and stack shape. It does not reject this instruction merely because a selected memory is unshared.

### Example: invalid but useful shared-without-max specimen

```text
memory type flag 0x02: shared memory32 with min only
memory type flag 0x06: shared memory64 with min only
```

These bytes are useful when testing decode-versus-validation staging. They should decode into `MemType(..., shared=true)`, then fail `Validate for MemType` with the shared-memory maximum rule.

## Correctness And Optimizer Constraints

Treat shared memory and atomics as semantic constraints, not as incidental syntax:

- a pass that remaps, deletes, or reorders memories must repair every `MemArg` carrier, including atomic `MemArg`s;
- a pass that removes or moves atomic operations must have a memory-ordering proof, not just stack-type preservation; this remains true for atomics on unshared memories;
- reviewed two-worker `i32.atomic.rmw.add` transformations can use the bounded allowed-outcome executor in [`fuzzing/semantic-optimizer-campaigns.md`](fuzzing/semantic-optimizer-campaigns.md#bounded-atomic-litmus-observations); its focused fixtures cover memory32, a low-address memory64 RMW, redirecting a nonzero-memory RMW to memory `0`, and selecting memory64 beside a memory32 sentinel, while every allowed set comes from the Threads execution contract rather than sampled original executions;
- `atomic.fence` has no memory index to repair, but it is still an ordering barrier and must not be treated as a harmless `nop`;
- shared-memory maxima and memory64/table64 address-width facts belong in resource/validator evidence, not in WAST declaration examples unless the WAST text path has been widened; and
- external validators may accept a different proposal revision or feature default, so classify disagreements through [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md) before filing a Starshine bug.

## What This Page Does Not Prove

- It does not prove full Threads proposal support. Threads is an active proposal row; current Starshine has a documented local subset.
- The bounded multi-thread fixtures check sequentially consistent `i32.atomic.rmw.add` on memory32 and one-page shared memory64 at address zero, mixed memory32/memory64 target selection at address zero, and the memory64 transition from the last valid aligned `i32` word at byte `65532` to an out-of-bounds access at byte `65536`. Per-thread memory bounds traps are normalized and compared; unrelated worker failures remain blocked. The suite also checks `i32.atomic.rmw.cmpxchg` winner identity, one completed `memory.atomic.wait32`/`memory.atomic.notify` pairing, a fail-closed required wake witness under bounded retry, and preservation of nonzero imported-memory targets for RMW-add and compare-exchange. The wake witness blocks acceptance when absent; it does not prove general wait/notify liveness or scheduler fairness. Node still classifies exact acquire-release and relaxed store/fence binaries as blocked at compilation. An opt-in Chromium capability probe executes the exact acquire-release store and fence once and observes the store write, but does not exercise a concurrent schedule; Relaxed order 2 remains unsupported. A separate Node fixture observes one shared-GC struct RMW from two workers and rejects add-by-two corruption. These fixtures do not prove weaker-order schedule semantics, memory64 addresses above 4 GiB, every access-width boundary, memory64 wait/notify, broader mixed-width programs, broader shared-GC atomic families, or arbitrary schedules.
- It does not prove high-level WAST support for linear-memory atomic text.
- It does not prove complete Relaxed Atomics support. Starshine carries `SeqCst` / `AcqRel` on linear atomics and fence, but `pause`, full proposal gating, high-level text, and runtime conformance route through [`wasm-relaxed-atomics-boundary.md`](wasm-relaxed-atomics-boundary.md).
- It does not prove full Shared-Everything Threads support. Starshine's shared type and struct/array aggregate atomic representation is substantial but still layer-specific; route exact gaps through [`wasm-shared-everything-threads-boundary.md`](wasm-shared-everything-threads-boundary.md) and [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md).
- It does not prove Memory Control or Custom Page Sizes support. Those proposals add separate memory-management and memory-type dimensions.

## Validation And Signoff Checklist

When touching shared memory or ordinary atomics:

1. **Resource validation:** cover valid shared-with-max and invalid shared-without-max for memory32 and memory64 when relevant.
2. **Binary staging:** keep decode-accepted / validation-invalid specimens (`0x02`, `0x06`) distinct from invalid-byte specimens.
3. **Atomic stack typing:** cover selected-memory index, address-width, alignment, operand order, and result shape for the atomic family being changed. Include an unshared-memory positive when changing `memarg_check_atomic(...)` policy, because current local validation accepts it.
4. **Fence split:** test `AtomicFence` separately from `MemArg` atomics; it has no selected-memory lookup at all.
5. **Generator coverage:** keep `[FZG]006` shared-memory/resource coverage and `[FZG]017` ordinary atomics scoped to their current shared-memory generation topology; neither is a validator sharedness requirement.
6. **WAST claims:** say “core/binary/validator/generator evidence” unless `src/wast/keywords.mbt`, `src/wast/parser.mbt`, lowering, printing, and WAST tests have actually been widened.
7. **Feature-status wording:** cite this page for ordinary Threads/shared-memory claims, [`wasm-relaxed-atomics-boundary.md`](wasm-relaxed-atomics-boundary.md) for relaxed ordering / `pause`, and [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md) for active-vs-finished proposal vocabulary.
8. **Concurrent runtime evidence:** for a reviewed ordinary atomic transform, declare the full allowed outcome set and run the bounded two-worker litmus on original and candidate. Treat any candidate observation outside the set as a semantic mismatch; treat only-in-set observations as bounded evidence rather than exhaustive proof.

## Sources

- Threads validation/execution: [validation](https://webassembly.github.io/threads/core/valid/instructions.html) and [execution](https://webassembly.github.io/threads/core/exec/instructions.html)
- Shared Core/proposal status source: [WebAssembly proposals tracker](https://github.com/WebAssembly/proposals)
- Living companion pages: [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md), [`wast/resource-declaration-authoring.md`](wast/resource-declaration-authoring.md), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md)
- WebAssembly Threads proposal and draft: <https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md>, <https://webassembly.github.io/threads/core/syntax/types.html#memory-types>, <https://webassembly.github.io/threads/core/binary/types.html#memory-types>, <https://webassembly.github.io/threads/core/valid/types.html#memory-types>, <https://webassembly.github.io/threads/core/syntax/instructions.html>, <https://webassembly.github.io/threads/core/valid/instructions.html>, <https://webassembly.github.io/threads/core/exec/instructions.html>
- Starshine code: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/validate/validate.mbt`](../../src/validate/validate.mbt), [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`../../src/validate/typecheck_negative_wbtest.mbt`](../../src/validate/typecheck_negative_wbtest.mbt), [`../../src/validate/invalid_fuzzer.mbt`](../../src/validate/invalid_fuzzer.mbt), [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
