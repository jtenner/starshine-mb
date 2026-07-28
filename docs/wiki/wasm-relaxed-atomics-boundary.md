---
kind: concept
status: supported
last_reviewed: 2026-07-28
sources:
  - wasm-linear-memory-threads-boundary.md
  - https://github.com/WebAssembly/proposals
  - https://github.com/WebAssembly/relaxed-atomics/blob/main/proposals/relaxed-atomics/Overview.md
  - raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md
  - raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - wast/atomic-memory-instruction-authoring.md
  - wast/gc-aggregate-instruction-authoring.md
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/ir/effects.mbt
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

Use this page when a fixture, external tool, proposal note, or Starshine design mentions **Relaxed Atomics**. This is a separate active WebAssembly proposal, not shorthand for ordinary threads atomics, Core relaxed SIMD, or shared-GC aggregate atomics.

Starshine's boundary changed in July 2026: linear-memory atomic loads, stores, RMW, cmpxchg, and `atomic.fence` now carry `AtomicOrder::{SeqCst, AcqRel}` in the core IR and binary codec. That is real partial proposal-facing support. It is still not a complete Relaxed Atomics implementation because `pause`, high-level WAST text, a dedicated generator gate, and complete proposal/runtime signoff remain absent.

For beginners: changing an atomic order is semantic, not cosmetic. Optimizers must preserve acquire, release, and sequentially consistent edges in the correct direction.

## Current Surface

| Proposal surface | Meaning | Starshine status |
| --- | --- | --- |
| Release/acquire ordering on linear-memory accesses | Atomic loads, stores, RMW, and cmpxchg carry weaker ordering than sequential consistency. | Represented by `AtomicOrder::{SeqCst, AcqRel}` on the instruction variants; binary decode/encode and HOT/effects preserve it. |
| Ordered `atomic.fence` | The standalone fence carries ordering information. | `AtomicFence(AtomicOrder)` is represented and encoded/decoded; it remains a no-memory, no-stack-effect ordering barrier. |
| `pause` | Spin-wait hint with no stack operands/results. | Unsupported: there is no `Pause` instruction, WAST spelling, codec arm, validator rule, or generator gate. |
| Ordering-bearing binary forms | Atomic encodings preserve an order value in addition to the memory argument or fence opcode. | Supported for the currently represented `SeqCst` / `AcqRel` slice; malformed and future-order values remain codec/validation boundaries. |
| High-level WAST text | Human-authored ordered linear atomics such as ordered loads/stores. | Unsupported: ordinary linear-memory atomic keywords/parser cases remain absent. |
| Dedicated proposal generation/runtime signoff | Generate and execute proposal-specific modules under an explicit feature mode. | Unsupported: existing atomics generation is not a complete Relaxed Atomics gate or runtime-conformance lane. |

Because the proposal is active Phase 2, future widening should recheck the proposal source before assuming the current local order bytes, spelling, or instruction set are complete.

## Layer Map

| Layer | Current evidence | Boundary |
| --- | --- | --- |
| Core instruction model | [`src/lib/types.mbt`](../../src/lib/types.mbt) carries `AtomicOrder` on linear loads/stores, `AtomicRmw`, `AtomicCmpxchg`, and `AtomicFence`. | `SeqCst` / `AcqRel` are represented; `Pause` is absent. |
| Binary decode/encode | [`src/binary/decode.mbt`](../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../src/binary/encode.mbt) preserve the current order encodings. | This proves the local codec slice, not every future proposal order or opcode. |
| Validation | [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) retains ordinary selected-memory/alignment/offset/address/stack checks and treats fence as no stack effect. | Ordering legality is currently bounded by the two-value carrier; no `pause` rule exists. |
| WAST text | [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) records the ordinary linear-atomic text gap. | Use core builders, bytes, or generated modules for ordered linear-atomic fixtures. |
| Valid generator | [`GenValidProposalFeature`](../../src/validate/gen_valid.mbt) has ordinary atomics support but no dedicated complete Relaxed Atomics mode. | Existing `[FZG]017` shared-memory topology is not full proposal evidence. |
| HOT/effects/passes | [`src/ir/hot_lift.mbt`](../../src/ir/hot_lift.mbt), [`src/ir/hot_lower.mbt`](../../src/ir/hot_lower.mbt), and [`src/ir/effects.mbt`](../../src/ir/effects.mbt) preserve atomic instructions; HSO adds directional shared ordering analysis. | Every motion/deletion/rewrite still needs an acquire/release/seq-cst proof. |

## Three Easy Confusions

### Relaxed Atomics versus ordinary threads atomics

The existing `0xFE` family includes wait/notify, fence, loads/stores, RMW, and cmpxchg. The addition of order fields widens that local representation, but resource validation and proposal execution remain separate. `MemArg` atomics still use selected-memory, alignment, offset, address-width, and stack checks; local typechecking does not require the selected memory to be shared.

### Relaxed Atomics versus shared-GC atomics

Struct/array aggregate atomics also use `AtomicOrder`, but they operate on GC heap objects rather than linear memory. Route shared heap types and aggregate atomic get/RMW/cmpxchg through [`wasm-shared-everything-threads-boundary.md`](wasm-shared-everything-threads-boundary.md). Shared use of the enum does not make the instruction families interchangeable.

### Relaxed Atomics versus relaxed SIMD

Relaxed SIMD is Core 3.0 / finished behavior with separate SIMD opcodes and generator policy. Relaxed Atomics remains active Phase 2. Do not route it through `RelaxedSimdFeature`, SIMD tests, or `remove-relaxed-simd`.

## Optimizer Invariants

- Acquire behavior is attached to reads; release behavior is attached to writes; RMW/cmpxchg can carry both directions.
- `SeqCst` operations participate in stronger global ordering and cannot be treated as plain memory reads/writes.
- `atomic.fence` has no memory operand but is still an ordering barrier, never an incidental `nop`.
- A pass must not erase, strengthen, weaken, duplicate, or move an ordered atomic without a documented memory-model proof.
- Validation and binary roundtrip success do not establish safe motion.

## Remaining Work

1. Recheck the active proposal before adding more order values, flags, or opcode forms.
2. Add `pause` representation, codec, validation, WAST, generator, and effect coverage if that proposal slice is selected.
3. Add high-level ordered linear-atomic WAST keyword/parser/lowerer/printer tests.
4. Add a dedicated Relaxed Atomics generator/feature row rather than relying on ordinary atomics coverage.
5. Expand malformed/reserved order tests and external-tool adapters for the exact supported draft revision.
6. Add runtime and optimizer signoff that proves acquire/release/seq-cst behavior, not merely module validity.
7. Keep this page, the feature-status router, linear Threads page, atomic authoring guide, index, and log synchronized.

## Signoff Guidance

For the current partial slice, test:

- binary roundtrips for `SeqCst` and `AcqRel` loads, stores, RMW, cmpxchg, and fence;
- invalid/reserved order encodings;
- unchanged stack/resource validation across both orders;
- HOT lift/lower preservation;
- pass regressions that prevent unsafe movement in both acquire and release directions; and
- explicit classification of `pause`, unsupported text, generator-gate, or runtime failures as remaining proposal gaps rather than ordinary atomic regressions.

## Sources

- Official proposal sources: <https://github.com/WebAssembly/proposals>, <https://github.com/WebAssembly/relaxed-atomics/blob/main/proposals/relaxed-atomics/Overview.md>
- Linear-memory boundary: [`wasm-linear-memory-threads-boundary.md`](wasm-linear-memory-threads-boundary.md)
- Atomic authoring: [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md)
- Shared-GC boundary: [`wasm-shared-everything-threads-boundary.md`](wasm-shared-everything-threads-boundary.md)
- Local code: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`../../src/ir/effects.mbt`](../../src/ir/effects.mbt)
