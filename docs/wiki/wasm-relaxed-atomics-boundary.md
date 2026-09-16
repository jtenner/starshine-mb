---
kind: concept
status: supported
last_reviewed: 2026-09-10
sources:
  - wasm-linear-memory-threads-boundary.md
  - https://github.com/WebAssembly/proposals
  - https://github.com/WebAssembly/relaxed-atomics/blob/main/proposals/relaxed-atomics/Overview.md
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

The September 2026 v132 upgrade adds `AtomicOrder::Relaxed` alongside `SeqCst`
and `AcqRel` in the core carrier and binary codec. Binary order bytes are 0/1/2;
RMW pairs are 0x00/0x11/0x22, independent of enum declaration order. Linear and GC atomic text preserves all three orders through parsing, lowering
and printing, including stores, RMWs and fences.

Binaryen v132 renames the former feature to **acquire-release-atomics** and adds
**relaxed-atomics** as a separate capability. These names must not alias one
another. Starshine exposes separate CLI enable/disable flags and validator
`disabled_features` controls for the two orders. Defaults accept implemented
orders; `--all-features` clears explicit disabling. This supersedes the previous
missing-gate and linear-text boundaries. `pause` remains outside this intake.

For beginners: changing an atomic order is semantic, not cosmetic. Optimizers must preserve acquire, release, and sequentially consistent edges in the correct direction.

## Current Surface

| Proposal surface | Meaning | Starshine status |
| --- | --- | --- |
| Release/acquire ordering on linear-memory accesses | Atomic loads, stores, RMW, and cmpxchg carry weaker ordering than sequential consistency. | Represented by `AtomicOrder::{SeqCst, AcqRel, Relaxed}` on the instruction variants; binary decode/encode and HOT/effects preserve it. |
| Ordered `atomic.fence` | The standalone fence carries ordering information. | `AtomicFence(AtomicOrder)` is represented and encoded/decoded; it remains a no-memory, no-stack-effect ordering barrier. |
| `pause` | Spin-wait hint with no stack operands/results. | Unsupported: there is no `Pause` instruction, WAST spelling, codec arm, validator rule, or generator gate. |
| Ordering-bearing binary forms | Atomic encodings preserve an order value in addition to the memory argument or fence opcode. | Supported for the currently represented `SeqCst` / `AcqRel` / `Relaxed` slice; malformed and future-order values remain codec/validation boundaries. |
| High-level WAST text | Human-authored ordered linear atomics such as ordered loads/stores. | Supported for all 66 linear atomic operations and fence, with order-aware parsing and printing. |
| Dedicated proposal generation/runtime signoff | Generate and execute proposal-specific modules under an explicit feature mode. | The `binaryen132-atomic-orders` profile varies orders, linear/GC heaps, sharing, fences and RMW patterns. Independent execution remains unavailable for some draft forms. |

Because the proposal is active Phase 2, future widening should recheck the proposal source before assuming the current local order bytes, spelling, or instruction set are complete.

## Layer Map

| Layer | Current evidence | Boundary |
| --- | --- | --- |
| Core instruction model | [`src/lib/types.mbt`](../../src/lib/types.mbt) carries `AtomicOrder` on linear loads/stores, `AtomicRmw`, `AtomicCmpxchg`, and `AtomicFence`. | `SeqCst` / `AcqRel` / `Relaxed` are represented; `Pause` is absent. |
| Binary decode/encode | [`src/binary/decode.mbt`](../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../src/binary/encode.mbt) preserve the current order encodings. | This proves the local codec slice, not every future proposal order or opcode. |
| Validation | [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) retains ordinary selected-memory/alignment/offset/address/stack checks and treats fence as no stack effect. | Feature inference and explicit disabling distinguish both drafts; no `pause` rule exists. |
| WAST text | [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) documents the supported linear-atomic syntax. | Tests cover exact order/offset/alignment roundtrips. |
| Valid generator | [`gen_valid_atomic_orders.mbt`](../../src/validate/gen_valid_atomic_orders.mbt) implements the dedicated v132 profile. | Generated structural validity is separate from concurrency execution. |
| HOT/effects/passes | [`src/ir/hot_lift.mbt`](../../src/ir/hot_lift.mbt), [`src/ir/hot_lower.mbt`](../../src/ir/hot_lower.mbt), and [`src/ir/effects.mbt`](../../src/ir/effects.mbt) preserve atomic instructions; HSO adds directional shared ordering analysis. | Every motion/deletion/rewrite still needs an relaxed/acquire/release/seq-cst proof. |

## Three Easy Confusions

### Relaxed Atomics versus ordinary threads atomics

The existing `0xFE` family includes wait/notify, fence, loads/stores, RMW, and cmpxchg. The addition of order fields widens that local representation, but resource validation and proposal execution remain separate. `MemArg` atomics still use selected-memory, alignment, offset, address-width, and stack checks; local typechecking does not require the selected memory to be shared.

### Relaxed Atomics versus shared-GC atomics

Struct/array aggregate atomics also use `AtomicOrder`, but they operate on GC heap objects rather than linear memory. Route shared heap types and aggregate atomic get/RMW/cmpxchg through [`wasm-shared-everything-threads-boundary.md`](wasm-shared-everything-threads-boundary.md). Shared use of the enum does not make the instruction families interchangeable.

### Relaxed Atomics versus relaxed SIMD

Relaxed SIMD is Core 3.0 / finished behavior with separate SIMD opcodes and generator policy. Relaxed Atomics remains active Phase 2. Do not route it through `RelaxedSimdFeature`, SIMD tests, or `remove-relaxed-simd`.

## Released v132 optimizer update

An earlier atomic load, at Relaxed or stronger order, cannot move after a later
atomic store at Relaxed or stronger order, even across disjoint memory/GC heap
classes. The new rule is directional; it is not C++ relaxed ordering and does not
make every access a full barrier. Shared effect helpers own this rule and HSO
uses them in its existing directional motion analysis. Other effect consumers
retain their conservative alias/trap barriers.

Both Precompute variants evaluate eligible immutable unshared Relaxed/AcqRel GC
reads. SeqCst, shared objects and mutable fields remain nonconstant, matching
replays on the pinned v132 binary. Atomic struct reads now reach the HOT evaluator
instead of being bypassed by the raw candidate scan.

Evidence: [binary fixtures](../../src/binary/binaryen132_atomic_wbtest.mbt),
[text roundtrips](../../src/wast/binaryen132_atomic_test.mbt),
[directional motion](../../src/passes/binaryen132_effects_wbtest.mbt), and
[Precompute behavior](../../src/passes/binaryen132_precompute_test.mbt).
Runtime concurrency validation remains separate from these structural checks.

## Optimizer Invariants

- Acquire behavior is attached to reads; release behavior is attached to writes; RMW/cmpxchg can carry both directions.
- `SeqCst` operations participate in stronger global ordering and cannot be treated as plain memory reads/writes.
- `atomic.fence` has no memory operand but is still an ordering barrier, never an incidental `nop`.
- A pass must not erase, strengthen, weaken, duplicate, or move an ordered atomic without a documented memory-model proof.
- Validation and binary roundtrip success do not establish safe motion.

## Remaining Work

1. Recheck the active proposal before adding more order values, flags, or opcode forms.
2. Add `pause` representation, codec, validation, WAST, generator, and effect coverage if that proposal slice is selected.
3. Expand malformed/reserved order tests and external-tool adapters for the exact supported draft revision.
4. Add runtime and optimizer signoff that proves relaxed/acquire/release/seq-cst behavior, not merely module validity.
5. Keep this page, the feature-status router, linear Threads page, atomic authoring guide, index, and log synchronized.

## Signoff Guidance

For the current partial slice, test:

- binary roundtrips for `SeqCst`, `AcqRel` and `Relaxed` loads, stores, RMW, cmpxchg, and fence;
- invalid/reserved order encodings;
- unchanged stack/resource validation across all three orders;
- HOT lift/lower preservation;
- pass regressions that prevent unsafe movement in both acquire and release directions; and
- explicit classification of `pause` and unavailable external runtime features as remaining proposal gaps rather than ordinary atomic regressions.

## Sources

- Official proposal sources: <https://github.com/WebAssembly/proposals>, <https://github.com/WebAssembly/relaxed-atomics/blob/main/proposals/relaxed-atomics/Overview.md>
- Linear-memory boundary: [`wasm-linear-memory-threads-boundary.md`](wasm-linear-memory-threads-boundary.md)
- Atomic authoring: [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md)
- Shared-GC boundary: [`wasm-shared-everything-threads-boundary.md`](wasm-shared-everything-threads-boundary.md)
- Local code: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`../../src/ir/effects.mbt`](../../src/ir/effects.mbt)

## September 10, 2026 feature controls

The earlier absence of a dedicated gate is superseded. CLI
`--enable-acquire-release-atomics` / `--disable-acquire-release-atomics` and
`--enable-relaxed-atomics` / `--disable-relaxed-atomics` control separate orders.
The validator's `disabled_features` argument exposes the same policy; defaults
continue accepting the implemented orders. Disabling either draft does not
disable the other. `--all-features` clears explicit disabling. Codecs preserve
the exact released order bytes; runtime engine support remains separately
classified. See [policy implementation](../../src/validate/proposal_features.mbt)
and [command tests](../../src/cmd/proposal_features_wbtest.mbt).
