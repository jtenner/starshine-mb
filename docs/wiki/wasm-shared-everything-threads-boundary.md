---
kind: concept
status: supported
last_reviewed: 2026-07-28
sources:
  - https://github.com/WebAssembly/proposals
  - https://github.com/WebAssembly/shared-everything-threads/blob/main/proposals/shared-everything-threads/Overview.md
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/wast/struct_atomic_get_surface_test.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/ir/effects.mbt
  - ../../src/passes/heap_store_optimization.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wasm-linear-memory-threads-boundary.md
  - wasm-gc-core-boundary.md
  - wast/gc-aggregate-instruction-authoring.md
  - wast/atomic-memory-instruction-authoring.md
  - wasm-relaxed-atomics-boundary.md
---

# Shared-Everything Threads Boundary

## Overview

Use this page when a claim mentions **Shared-Everything Threads**, **shared GC heap values**, **shared heap types**, or **shared-GC aggregate atomics**. It keeps four related surfaces apart:

1. **Linear-memory Threads:** shared memories and `MemArg`-based atomics such as `i32.atomic.load`, `memory.atomic.wait32`, and `memory.atomic.notify`.
2. **Ordered linear atomics / Relaxed Atomics:** Starshine now carries `AtomicOrder::{SeqCst, AcqRel}` on linear-memory loads, stores, RMW, cmpxchg, and fences, but this remains narrower than full proposal support because `pause`, a dedicated proposal feature gate, and high-level WAST syntax are still absent.
3. **Shared-Everything Threads:** active proposal work for shared heap objects, shared heap types, and aggregate atomics over GC values.
4. **Starshine's current local slice:** a broad core/binary/validator/HOT representation for shared type metadata and struct/array aggregate atomics, with a narrower WAST text surface and no claim of complete runtime-thread or proposal conformance.

For beginners: WebAssembly linear memory is a byte array. WebAssembly GC adds typed heap objects such as structs and arrays. Shared-Everything Threads is about making those **typed heap objects** safely shareable between agents. Aggregate atomics therefore need GC type, field/element, effect, trap, and synchronization reasoning rather than only the selected-memory `MemArg` rules used by linear-memory atomics.

The active proposals tracker and Shared-Everything Threads overview remain proposal-status evidence. Starshine's widened representation is local implementation evidence, not proof that every proposal rule or runtime integration is complete.

## Boundary Table

| Topic | Correct owner | Current Starshine evidence | Do not infer |
| --- | --- | --- | --- |
| Shared linear memories | [`wasm-linear-memory-threads-boundary.md`](wasm-linear-memory-threads-boundary.md) | `MemType(Limits, shared)` plus validation that shared memories have a maximum. | Shared heap objects or GC aggregate atomics. |
| Ordered linear-memory atomics | [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`wasm-relaxed-atomics-boundary.md`](wasm-relaxed-atomics-boundary.md) | Core/binary/validator/HOT instructions carry `SeqCst` or `AcqRel` on loads, stores, RMW, cmpxchg, and fence. | `pause`, complete Relaxed Atomics feature gating, or WAST text support. |
| Shared heap-type representation | This page plus [`wasm-gc-core-boundary.md`](wasm-gc-core-boundary.md) | `TypeMetadata.shared`, shared abstract heap types, sharedness queries, and binary shared-type encoding are present. | Complete proposal subtype/runtime semantics or broad shared-type WAST authoring. |
| Shared-GC aggregate atomics | This page plus [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md) | Struct atomic get/RMW/cmpxchg and array atomic get/RMW/cmpxchg are represented, encoded/decoded, validated, lifted/lowered through HOT, and effect-classified. | A distinct aggregate atomic `set`, aggregate wait/notify, or complete engine/runtime support. |
| WAST aggregate-atomic text | [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md) | `struct.atomic.get*`, struct RMW/cmpxchg, and array RMW/cmpxchg have parser/lowerer/printer coverage. | Every core-carried array get variant, explicit order spelling on every WAST aggregate form, or full proposal text syntax. |

## Current Starshine Aggregate-Atomic Slice

The core instruction model includes:

- `StructAtomicGet`, `StructAtomicGetS`, and `StructAtomicGetU`;
- `StructAtomicRmw` and `StructAtomicCmpxchg`;
- `ArrayAtomicGet`, `ArrayAtomicGetS`, and `ArrayAtomicGetU`;
- `ArrayAtomicRmw` and `ArrayAtomicCmpxchg`.

The local WAST surface is narrower. It includes the three ordered struct-read forms and aggregate RMW/cmpxchg spellings such as:

```wat
(module
  (type $S (struct (field (mut i32))))
  (type $A (array (mut i32)))
  (func (param (ref $S)) (param i32) (result i32)
    (struct.atomic.rmw.add $S 0
      (local.get 0)
      (local.get 1)))
  (func (param (ref $A)) (param i32) (param i32) (result i32)
    (array.atomic.rmw.add $A
      (local.get 0)
      (local.get 1)
      (local.get 2))))
```

`struct.atomic.get*` accepts and preserves `seq_cst` / `acq_rel`; `acqrel` remains a compatibility alias. Do not generalize those exact text-order rules to every aggregate instruction without checking the parser and lowerer.

## Layer Map

| Layer | Current owner files | Contract |
| --- | --- | --- |
| Core type model | [`src/lib/types.mbt`](../../src/lib/types.mbt) | Defines `TypeMetadata.shared`, shared abstract heap types, `HeapType::is_shared`, `AtomicOrder::{SeqCst, AcqRel}`, ordered linear atomics, and struct/array aggregate atomic instruction carriers. |
| WAST text | [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../src/wast/module_wast.mbt), [`src/wast/struct_atomic_get_surface_test.mbt`](../../src/wast/struct_atomic_get_surface_test.mbt) | Covers `struct.atomic.get*`, struct RMW/cmpxchg, and array RMW/cmpxchg. This is still narrower than the core representation and is not broad shared-type declaration syntax. |
| Binary codec | [`src/binary/decode.mbt`](../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../src/binary/encode.mbt), [`src/binary/tests.mbt`](../../src/binary/tests.mbt) | Encodes/decodes shared type markers, ordered linear atomics, and the represented struct/array aggregate atomic families with their required immediates. |
| Validation | [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../src/validate/validate.mbt) | Typechecks aggregate receiver/index/value shapes, mutable fields/elements, signedness, and result types; shared-type graph and proposal-wide runtime completeness remain separate questions. |
| Generator facts | [`src/validate/validate.mbt`](../../src/validate/validate.mbt), [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt) | Recognizes aggregate atomic families and shared/atomic feature facts, but does not by itself prove a complete Shared-Everything proposal generator mode. |
| HOT/effects | [`src/ir/effects.mbt`](../../src/ir/effects.mbt), [`src/ir/hot_lift.mbt`](../../src/ir/hot_lift.mbt), [`src/ir/hot_lower.mbt`](../../src/ir/hot_lower.mbt), [`src/ir/hot_verify.mbt`](../../src/ir/hot_verify.mbt) | Preserves aggregate atomic instructions and classifies reads, writes, traps, and synchronization-sensitive effects for optimizer safety. |
| Passes | [`src/passes/heap_store_optimization.mbt`](../../src/passes/heap_store_optimization.mbt), [`src/passes/optimize_instructions.mbt`](../../src/passes/optimize_instructions.mbt), [`src/passes/global_struct_inference.mbt`](../../src/passes/global_struct_inference.mbt), [`src/passes/rse.mbt`](../../src/passes/rse.mbt) | Includes pass-specific ordering, lowering, immutable-field, subtype-retargeting, and remap logic. Generic movement, deletion, or CSE still requires a local synchronization and trap proof. |

## Invariants And Edge Cases

- **Linear-memory and aggregate atomics are distinct.** Aggregate atomics consume struct/array references and field or element operands; they do not use a selected linear-memory `MemArg`.
- **Ordered effects are directional.** `AcqRel` reads contribute acquire behavior and `AcqRel` writes contribute release behavior; `SeqCst` participates in stronger ordering. Passes must preserve the relevant direction rather than treating every atomic as an undifferentiated read/write bit.
- **Effectful/trap-sensitive by default.** A dropped atomic result can still preserve a trap, write, synchronization edge, or returned old value. Validation success alone does not justify deletion, movement, or duplication.
- **Packed signedness matters.** Plain atomic gets are not interchangeable with signed/unsigned packed reads.
- **Shared type representation exists but is not a completeness claim.** `TypeMetadata.shared` and shared heap variants are real IR/binary state. Proposal-wide subtype restrictions, WAST declaration coverage, host/runtime threading, and engine execution still need exact layer-specific evidence.
- **The represented aggregate family still has gaps.** There is no distinct aggregate atomic `set` instruction carrier and no aggregate wait/notify family. Array atomic gets are core/binary/validator/HOT-visible even where the high-level WAST surface remains narrower.
- **`pause` remains absent.** Ordered atomic fields do not imply the entire Relaxed Atomics proposal is implemented.

## Examples Of Correct Claims

- “Starshine represents shared heap-type metadata and broad struct/array aggregate atomic families, but does not claim complete Shared-Everything runtime or proposal support.”
- “Starshine linear-memory atomics now carry `SeqCst` / `AcqRel`; `pause` and full Relaxed Atomics gating remain unsupported.”
- “Struct and array aggregate RMW/cmpxchg are core/binary/validator/HOT-supported, while WAST coverage is narrower and aggregate `set` plus wait/notify remain gaps.”
- “An optimizer moving an aggregate atomic must cite order-direction, alias/effect, and trap proofs; module validation is not enough.”

## Future Implementation Checklist

1. **Representation gaps:** add only still-missing proposal entities, including any distinct aggregate `set`, wait/notify, or additional order variants required by the selected proposal revision.
2. **Binary codec:** keep exact shared markers, opcodes, reserved immediates, and order bytes round-trip-tested, including malformed cases.
3. **WAST:** widen shared-type declarations and currently core-only aggregate forms deliberately; keep order spelling compatibility explicit.
4. **Validation:** finish proposal-specific shared/unshared domain, subtype graph, mutability, packed-field, and ordering legality rules rather than inferring them from carrier presence.
5. **Effects/HOT:** preserve directional acquire/release/seq-cst behavior across every lift, lower, remap, and rewrite.
6. **Generators/fuzzing:** add a dedicated full-proposal gate only when generated modules are both Starshine-valid and externally classifiable.
7. **Runtime:** separately prove host/engine shared-object execution; codec, validator, and optimizer coverage are not runtime conformance.
8. **Docs:** keep this page, the feature-status router, linear/relaxed atomic pages, WAST guides, index, and log synchronized whenever a layer widens.

## Source Map

- Official proposal sources: <https://github.com/WebAssembly/proposals>, <https://github.com/WebAssembly/shared-everything-threads/blob/main/proposals/shared-everything-threads/Overview.md>
- Core representation: [`src/lib/types.mbt`](../../src/lib/types.mbt)
- Binary codec: [`src/binary/decode.mbt`](../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../src/binary/encode.mbt)
- Validation: [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt)
- HOT/effects: [`src/ir/hot_lift.mbt`](../../src/ir/hot_lift.mbt), [`src/ir/hot_lower.mbt`](../../src/ir/hot_lower.mbt), [`src/ir/effects.mbt`](../../src/ir/effects.mbt)
- Ordered HSO consumer: [`src/passes/heap_store_optimization.mbt`](../../src/passes/heap_store_optimization.mbt)
