---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-relaxed-atomics-boundary-refresh.md
  - raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md
  - raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md
  - raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md
  - raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - wast/atomic-memory-instruction-authoring.md
  - wast/gc-aggregate-instruction-authoring.md
  - wast/simd-authoring.md
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/validate/gen_valid.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wast/atomic-memory-instruction-authoring.md
  - wast/gc-aggregate-instruction-authoring.md
  - wast/simd-authoring.md
  - binary/instruction-and-expression-encoding.md
  - fuzzing/generator-coverage-ledger.md
  - tooling/external-validator-adapters.md
---

# Relaxed Atomics Boundary

## Overview

Use this page when a fixture, external tool, proposal note, or future Starshine design mentions **Relaxed Atomics**. This is a separate active WebAssembly proposal, not a shorthand for ordinary threads atomics, not Core/finished relaxed SIMD, and not Starshine's current shared-GC `struct.atomic.get*` order spellings.

For beginners: ordinary WebAssembly atomic memory operations behave like synchronized memory accesses. A relaxed-atomics proposal tries to expose weaker ordering choices that can be faster on some hardware while still being explicit about what ordering is promised. That is a memory-model feature, so optimizer and validator work must be careful: changing an ordering byte is not just changing syntax.

The current source bridge is [`raw/wasm/2026-06-05-relaxed-atomics-boundary-refresh.md`](raw/wasm/2026-06-05-relaxed-atomics-boundary-refresh.md). It rechecked the official active proposals tracker, the Relaxed Atomics proposal repository and overview, and current Starshine code. The durable conclusion is simple: **current Starshine has ordinary linear-memory atomics and shared-GC atomic-get order spellings, but no documented relaxed-atomics support.**

## What The Proposal Adds

The proposal overview currently describes two feature families:

| Proposal surface | Meaning | Starshine status |
| --- | --- | --- |
| Release-acquire (`acqrel`) ordering for linear-memory atomic accesses | Atomic loads, stores, RMW, and cmpxchg operations can carry weaker ordering information instead of only sequential consistency. | No support. Current `MemArg` has alignment, optional memory index, and offset, but no linear-memory ordering field. |
| Ordering byte on `atomic.fence` | `atomic.fence` no longer means only the current zero-immediate form; the immediate selects an ordering. | No support. Current binary decode accepts `0xFE 0x03 0x00` only and rejects other fence immediates. |
| `pause` at `0xFE 0x04` | A spin-wait hint instruction with no stack operands/results. | No support. Current `0xFE` decode has no `pause` variant and routes unknown atomic subcodes to `InvalidAtomicInstruction`. |
| Binary encoding flag for memory ordering | Atomic `memarg` encodings can signal that an ordering byte follows the usual `memarg` and any memory index. | No support. Current Starshine extended `MemArg` already uses its own optional-memory-index encoding and has no ordering-presence bit or post-memarg ordering decode. |

This page intentionally does not try to freeze the future opcode contract beyond those source facts. The proposal is active Phase 2, and implementation should begin with a fresh source recheck.

## Current Starshine Non-Support Map

| Layer | Current evidence | Relaxed-atomics implication |
| --- | --- | --- |
| Core instruction model | [`Instruction`](../../src/lib/types.mbt) contains ordinary `MemoryAtomicNotify`, `MemoryAtomicWait32`, `MemoryAtomicWait64`, `AtomicFence`, atomic loads/stores, `AtomicRmw`, and `AtomicCmpxchg`. It has no `Pause` and no ordering field on linear-memory atomics. | No core carrier for relaxed-atomics ordering or `pause`. |
| Binary decode/encode | [`src/binary/decode.mbt`](../../src/binary/decode.mbt) handles `0xFE` subcodes for ordinary atomics and rejects nonzero `atomic.fence` immediates; [`src/binary/encode.mbt`](../../src/binary/encode.mbt) emits ordinary atomic subcodes and zero-immediate `AtomicFence`. | `0xFE 0x04` and ordering-bearing memargs are unsupported bytes today. |
| Validation | [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) typechecks `MemArg`-based atomics through the current shared-memory gate and treats `AtomicFence` as no stack effect. | No validation rule for relaxed ordering strength, `pause`, or ordering-immediate legality. |
| WAST text | [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) records that ordinary linear-memory atomic text keywords are already a WAST gap. | Relaxed-atomics text is also unsupported; do not add examples before parser/lowerer/printer tests. |
| Valid generator | [`GenValidProposalFeature`](../../src/validate/gen_valid.mbt) has `AtomicsFeature` and `RelaxedSimdFeature`, but no `RelaxedAtomicsFeature`. `[FZG]017` emits ordinary current-Starshine-valid atomics when shared memory exists. | Generator atomics coverage is not relaxed-atomics evidence. |
| HOT/effects/passes | Existing atomic effects are treated as memory/trap/order-sensitive ordinary atomics. | Any pass that moves, drops, merges, or rewrites a future relaxed atomic must understand ordering semantics first. |

## Three Easy Confusions

### Relaxed Atomics versus ordinary linear-memory atomics

Starshine already models the current ordinary linear-memory atomic family under the `0xFE` prefix: loads, stores, RMW, cmpxchg, wait/notify, and `atomic.fence`. That evidence lives in [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) and [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md). It proves current core/binary/validator/generator coverage for those instructions, not ordering-immediate support.

### Relaxed Atomics versus shared-GC `struct.atomic.get*`

Starshine's [`AtomicOrder`](../../src/lib/types.mbt) enum currently has `SeqCst` and `AcqRel`, and WAST can parse order spellings for `struct.atomic.get`, `struct.atomic.get_s`, and `struct.atomic.get_u`. That is a shared-GC aggregate instruction surface documented in [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md). It is not the same representation as linear-memory atomic ordering bytes and does not make `i32.atomic.load acqrel` or `pause` valid.

### Relaxed Atomics versus relaxed SIMD

Relaxed SIMD is a finished/Core-3.0 SIMD instruction family with its own local WAST/binary/validation support and generator gates; see [`wast/simd-authoring.md`](wast/simd-authoring.md). Relaxed Atomics is still active Phase 2 and needs its own representation and signoff. Do not route it through `RelaxedSimdFeature`, the `remove-relaxed-simd` pass, or SIMD oracle lanes.

## Future Implementation Checklist

A faithful Starshine slice should update all of these together:

1. **Source recheck.** Re-open the proposal tracker, Relaxed Atomics repository, overview, formatted spec build, and any external tool/oracle source before choosing opcode or text spellings.
2. **Core representation.** Add an explicit linear-memory ordering carrier and a `pause` instruction rather than reusing shared-GC `AtomicOrder` accidentally.
3. **Binary codec.** Decode/encode ordering-present memarg bits, post-memarg ordering bytes, nonzero `atomic.fence` ordering immediates, and `0xFE 0x04` `pause`; add malformed, overwide, reserved-ordering, and truncated-input tests.
4. **Validation.** Define which ordering values are legal for each instruction family, preserve ordinary stack typing, and keep shared-memory/resource checks separate from memory-order checks.
5. **WAST text and printing.** Add keyword/parser/lowerer/printer coverage only after deciding whether Starshine should use the proposal spelling directly or keep initial support core/binary-only.
6. **Generator gates.** Add a dedicated relaxed-atomics feature row instead of folding it into `AtomicsFeature` or `RelaxedSimdFeature`; keep `[FZG]017` scoped to ordinary atomics unless deliberately widened.
7. **Effects and passes.** Treat relaxed ordering as semantic information. No optimizer may erase, strengthen, weaken, or move these operations without a documented memory-model proof and Binaryen/tool comparison where available.
8. **Docs and health.** Update this page, [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md), [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`binary/instruction-and-expression-encoding.md`](binary/instruction-and-expression-encoding.md), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md), and external-validator routing notes.

## Validation And Signoff Guidance

Until implementation lands, classify relaxed-atomics inputs as unsupported-feature or proposal-gap evidence, not as regressions in ordinary atomics. If an external validator accepts `pause`, acqrel atomic memory operations, or nonzero `atomic.fence` immediates while Starshine rejects them, preserve the exact command and tool version, then use [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md) and [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md) before filing a local bug.

After implementation, signoff should include:

- binary decode/encode roundtrips for every ordering and `pause` form;
- invalid-binary fixtures for malformed ordering immediates and wrong fence/pause encodings;
- typechecker tests proving stack and resource rules still hold independently from ordering;
- generator coverage with a dedicated relaxed-atomics feature gate;
- pass tests proving effects and ordering prevent unsafe motion/deletion; and
- external oracle comparison when a stable tool supports the same draft revision.

## Sources

- Focused source bridge: [`raw/wasm/2026-06-05-relaxed-atomics-boundary-refresh.md`](raw/wasm/2026-06-05-relaxed-atomics-boundary-refresh.md)
- Earlier routing bridges: [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md), [`raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md`](raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md)
- Current ordinary atomics evidence: [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md`](raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md), [`raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md)
- Shared-GC atomic-get evidence: [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md), [`raw/wasm/2026-06-04-struct-atomic-get-sources.md`](raw/wasm/2026-06-04-struct-atomic-get-sources.md)
- Local code: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt), [`../../src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`../../src/wast/parser.mbt`](../../src/wast/parser.mbt)
