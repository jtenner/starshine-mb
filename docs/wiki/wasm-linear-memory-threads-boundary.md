---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md
  - raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md
  - raw/wasm/2026-05-20-atomic-memory-instruction-sources.md
  - wast/atomic-memory-instruction-authoring.md
  - validate/resource-sections-and-limits.md
  - wast/resource-declaration-authoring.md
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/validate.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/validate/gen_valid.mbt
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

## Overview

Use this page when a Starshine claim mentions **linear shared memory**, **ordinary threads atomics**, or the local `shared` bit on a WebAssembly memory type. It is the living router between:

- current WebAssembly Core memory concepts such as ordinary memories, memory64, multi-memory, and bulk memory;
- the active **Threads** proposal/draft evidence for shared linear memories and `0xFE` atomics;
- Starshine's current core/binary/validator/generator implementation subset; and
- nearby but separate proposals such as Relaxed Atomics, Shared-Everything Threads / shared-GC atomics, Memory Control, and Custom Page Sizes.

For beginners: a WebAssembly module can define one or more linear memories. A **shared** memory is intended for multiple agents/threads, so it needs a maximum bound and can be used by atomic operations. Atomic operations are not just unusual loads and stores: they carry synchronization semantics that optimizers must preserve.

The current primary-source bridge is [`raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md). A follow-up bridge, [`raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md`](raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md), supersedes one older shorthand: Starshine's selected-memory sharedness gate applies to `MemArg`-based atomic memory operations, but **not** to standalone `AtomicFence`. The official active proposal routing bridge [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md) keeps Threads as active Phase 4 status-only evidence, not proof of full local support.

## Boundary Map

| Surface | Upstream status / source tier | Current Starshine layer | Owner page |
| --- | --- | --- | --- |
| Ordinary memory32/memory64 limits | Core / finished-feature evidence for address width and limits. | Core and binary model `I32Limits` and `I64Limits`; WAST declarations are still narrower. | [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md), [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md) |
| Shared linear memory | Threads proposal/draft evidence, not stable-Core-alone evidence. | `MemType(Limits, Bool)` stores sharedness; validation rejects shared memories without a maximum. | This page plus [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md) |
| Ordinary `0xFE` atomics | Threads proposal/draft instruction evidence. | Core, binary, validator, generator, HOT/effects support the current local subset. Linear-memory WAST keywords are absent. | [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) |
| `atomic.fence` | Threads proposal/draft ordering barrier. | Core/binary/validator support zero-immediate fence as standalone `[] -> []`; no selected memory and no sharedness check. | [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) |
| Relaxed Atomics | Separate active Phase-2 proposal for ordering immediates and `pause`. | No local support: no `pause`, no linear-memory ordering field, no nonzero fence ordering. | [`wasm-relaxed-atomics-boundary.md`](wasm-relaxed-atomics-boundary.md) |
| Shared-GC aggregate atomics | Shared-Everything / GC aggregate surface, not linear-memory `MemArg` atomics. | Focused `struct.atomic.get*` WAST/core/binary/validator support only; broader aggregate atomics remain future work. | [`wasm-shared-everything-threads-boundary.md`](wasm-shared-everything-threads-boundary.md), [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md) |
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
3. [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) routes `MemArg`-based atomics through `memarg_check_atomic(...)`, which first checks the ordinary memory argument and then requires the selected memory's `shared` bit.
4. `AtomicFence` is different: the typechecker accepts it as `Ok(st)` because it has no memory argument and no stack effect.
5. [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt) emits ordinary atomics only when `allow_atomics` is enabled and a shared memory exists.
6. Current high-level WAST keywords/parser arms do **not** expose `i32.atomic.load`, `memory.atomic.wait32`, `atomic.fence`, or sibling linear-memory atomic text. Use core builders, binary bytes, or `gen_valid` for tests until [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) is widened.

### Example: valid current-Starshine shared-memory core shape

```moonbit
let mem = @lib.MemType::new(@lib.Limits::i32(1, Some(2)), shared=true)
let ma = @lib.MemArg::new(@lib.U32(2), Some(@lib.MemIdx::new(0)), @lib.U64(0))
let body = [
  @lib.Instruction::i32_const(@lib.I32(0)),
  @lib.Instruction::i32_atomic_load(ma),
  @lib.Instruction::drop(),
]
```

This is a core/validator fixture shape, not WAST text. The memory's shared max is part of the module resource shape; the atomic instruction's `MemArg` selects that memory; and validation then checks the address type and sharedness before stack-typing the atomic operation.

### Example: invalid but useful shared-without-max specimen

```text
memory type flag 0x02: shared memory32 with min only
memory type flag 0x06: shared memory64 with min only
```

These bytes are useful when testing decode-versus-validation staging. They should decode into `MemType(..., shared=true)`, then fail `Validate for MemType` with the shared-memory maximum rule.

## Correctness And Optimizer Constraints

Treat shared memory and atomics as semantic constraints, not as incidental syntax:

- a pass that remaps, deletes, or reorders memories must repair every `MemArg` carrier, including atomic `MemArg`s;
- a pass that removes or moves atomic operations must have a memory-ordering proof, not just stack-type preservation;
- `atomic.fence` has no memory index to repair, but it is still an ordering barrier and must not be treated as a harmless `nop`;
- shared-memory maxima and memory64/table64 address-width facts belong in resource/validator evidence, not in WAST declaration examples unless the WAST text path has been widened; and
- external validators may accept a different proposal revision or feature default, so classify disagreements through [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md) before filing a Starshine bug.

## What This Page Does Not Prove

- It does not prove full Threads proposal support. Threads is an active proposal row; current Starshine has a documented local subset.
- It does not prove high-level WAST support for linear-memory atomic text.
- It does not prove Relaxed Atomics support. `acqrel` linear-memory ordering, nonzero `atomic.fence` ordering bytes, and `pause` route through [`wasm-relaxed-atomics-boundary.md`](wasm-relaxed-atomics-boundary.md).
- It does not prove full Shared-Everything Threads support. `struct.atomic.get*` is a focused shared-GC aggregate slice routed through [`wasm-shared-everything-threads-boundary.md`](wasm-shared-everything-threads-boundary.md) and [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md).
- It does not prove Memory Control or Custom Page Sizes support. Those proposals add separate memory-management and memory-type dimensions.

## Validation And Signoff Checklist

When touching shared memory or ordinary atomics:

1. **Resource validation:** cover valid shared-with-max and invalid shared-without-max for memory32 and memory64 when relevant.
2. **Binary staging:** keep decode-accepted / validation-invalid specimens (`0x02`, `0x06`) distinct from invalid-byte specimens.
3. **Atomic stack typing:** cover selected-memory index, address-width, alignment, operand order, and result shape for the atomic family being changed.
4. **Fence split:** test `AtomicFence` separately from `MemArg` atomics; it has no selected-memory sharedness check.
5. **Generator coverage:** keep `[FZG]006` shared-memory/resource coverage and `[FZG]017` ordinary atomics scoped to current Starshine-valid surfaces.
6. **WAST claims:** say “core/binary/validator/generator evidence” unless `src/wast/keywords.mbt`, `src/wast/parser.mbt`, lowering, printing, and WAST tests have actually been widened.
7. **Feature-status wording:** cite this page for ordinary Threads/shared-memory claims, [`wasm-relaxed-atomics-boundary.md`](wasm-relaxed-atomics-boundary.md) for relaxed ordering / `pause`, and [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md) for active-vs-finished proposal vocabulary.

## Sources

- Current shared-memory source bridge: [`raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md)
- Fence and unshared-memory reconciliation: [`raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md`](raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md)
- Active proposal routing: [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md)
- Atomic source manifest: [`raw/wasm/2026-05-20-atomic-memory-instruction-sources.md`](raw/wasm/2026-05-20-atomic-memory-instruction-sources.md)
- Living companion pages: [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md), [`wast/resource-declaration-authoring.md`](wast/resource-declaration-authoring.md), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md)
- WebAssembly Threads proposal and draft: <https://github.com/WebAssembly/threads/blob/main/proposals/threads/Overview.md>, <https://webassembly.github.io/threads/core/syntax/types.html#memory-types>, <https://webassembly.github.io/threads/core/binary/types.html#memory-types>, <https://webassembly.github.io/threads/core/valid/types.html#memory-types>, <https://webassembly.github.io/threads/core/syntax/instructions.html>, <https://webassembly.github.io/threads/core/valid/instructions.html>, <https://webassembly.github.io/threads/core/exec/instructions.html>
- Starshine code: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/validate/validate.mbt`](../../src/validate/validate.mbt), [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
