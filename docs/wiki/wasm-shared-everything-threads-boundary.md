---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-shared-everything-threads-boundary-refresh.md
  - raw/wasm/2026-06-04-struct-atomic-get-sources.md
  - raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md
  - ../../src/lib/types.mbt
  - ../../src/wast/struct_atomic_get_surface_test.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/ir/effects.mbt
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

Use this page when a claim mentions **Shared-Everything Threads**, **shared GC heap values**, **shared heap types**, or **shared-GC aggregate atomics** such as `struct.atomic.get`. It keeps four similar-looking surfaces apart:

1. **Linear-memory Threads:** shared memories and `MemArg`-based atomics such as `i32.atomic.load`, `memory.atomic.wait32`, and `memory.atomic.notify`.
2. **Relaxed Atomics:** active proposal work for linear-memory orderings and `pause`.
3. **Shared-Everything Threads:** active proposal work for shared heap objects, shared heap types, and aggregate atomics over GC values.
4. **Starshine's current local slice:** WAST/core/binary/validator support for `struct.atomic.get`, `struct.atomic.get_s`, and `struct.atomic.get_u` only.

For beginners: WebAssembly linear memory is a byte array. WebAssembly GC adds typed heap objects such as structs and arrays. Shared-Everything Threads is about making those **typed heap objects** safely shareable between agents. That is why a `struct.atomic.get` claim belongs with GC aggregate/type/effect reasoning, not with the selected-memory `MemArg` rule used by linear-memory atomics.

The current source bridge is [`raw/wasm/2026-06-05-shared-everything-threads-boundary-refresh.md`](raw/wasm/2026-06-05-shared-everything-threads-boundary-refresh.md), which rechecked the active proposals tracker, the Shared-Everything Threads overview, the already-ingested [`raw/wasm/2026-06-04-struct-atomic-get-sources.md`](raw/wasm/2026-06-04-struct-atomic-get-sources.md), and current Starshine source. As of this review, Shared-Everything Threads is **active Phase 1 proposal evidence**, not stable Core WebAssembly 3.0.

## Boundary Table

| Topic | Correct owner | Current Starshine evidence | Do not infer |
| --- | --- | --- | --- |
| Shared linear memories | [`wasm-linear-memory-threads-boundary.md`](wasm-linear-memory-threads-boundary.md) | `MemType(Limits, shared)` plus validation that shared memories have a max. | Shared heap objects or shared GC atomics. |
| Linear-memory atomics | [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) | Core/binary/validator/generator support for a current `0xFE` subset; WAST text gap. | Aggregate atomic operations over structs/arrays. |
| Relaxed Atomics | [`wasm-relaxed-atomics-boundary.md`](wasm-relaxed-atomics-boundary.md) | No `pause`, no linear-memory ordering field, no relaxed-atomic generator gate. | Support from `AtomicOrder::AcqRel` on `struct.atomic.get*`. |
| Shared-Everything proposal | This page | Proposal-status and future-design routing. | Full Starshine support. |
| `struct.atomic.get*` | This page plus [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md) | WAST/core/binary/validator/pass-remap surface for three struct-read forms. | `struct.atomic.set`, aggregate RMW/cmpxchg, array atomics, wait/notify, or shared heap-type syntax. |

## Current Starshine Struct-Atomic-Get Slice

Starshine currently documents one proposal-shaped shared-GC slice:

```wat
(module
  (type $S (struct (field i32) (field (mut i8))))
  (func (param (ref $S)) (result i32)
    (struct.atomic.get seq_cst $S 0
      (local.get 0)))
  (func (param (ref $S)) (result i32)
    (struct.atomic.get_s acq_rel $S 1
      (local.get 0))))
```

The local WAST shape is:

```text
struct.atomic.get   <order> <typeidx> <fieldidx>
struct.atomic.get_s <order> <typeidx> <fieldidx>
struct.atomic.get_u <order> <typeidx> <fieldidx>
```

Current order spellings are canonicalized to `seq_cst` and `acq_rel`. The parser also accepts `acqrel` as a compatibility alias. Do not assume a compact `seqcst` alias parses locally until `src/wast/parser.mbt` and tests say so.

## Layer Map

| Layer | Current owner files | Contract |
| --- | --- | --- |
| Core model | [`src/lib/types.mbt`](../../src/lib/types.mbt) | Defines `AtomicOrder::{SeqCst, AcqRel}` and `StructAtomicGet*` instruction carriers. No array atomic, aggregate set/RMW/cmpxchg, wait/notify, or shared heap-type variants are present. |
| WAST text | [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../src/wast/module_wast.mbt), [`src/wast/struct_atomic_get_surface_test.mbt`](../../src/wast/struct_atomic_get_surface_test.mbt) | Recognizes, lowers, and prints the three `struct.atomic.get*` forms with order/type/field immediates. |
| Binary codec | [`src/binary/decode.mbt`](../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../src/binary/encode.mbt), [`src/binary/tests.mbt`](../../src/binary/tests.mbt) | Encodes/decodes the current `0xFE 0x5C..0x5E` struct-atomic-get subcodes and immediates. |
| Validation | [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) | Reuses ordinary struct-get stack/type checks plus packed-field signedness rules. It does not require a shared linear memory. |
| Generator facts | [`src/validate/validate.mbt`](../../src/validate/validate.mbt), [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt) | Treats the slice as GC aggregate surface evidence; `SharedMemoryAtomics` remains the linear-memory atomic feature row. |
| HOT/effects | [`src/ir/effects.mbt`](../../src/ir/effects.mbt), [`src/ir/hot_lift.mbt`](../../src/ir/hot_lift.mbt), [`src/ir/hot_verify.mbt`](../../src/ir/hot_verify.mbt) | Models these as one-operand aggregate reads that may read state and trap. |
| Passes | [`src/passes/global_struct_inference.mbt`](../../src/passes/global_struct_inference.mbt), [`src/passes/rse.mbt`](../../src/passes/rse.mbt), [`src/passes/duplicate_function_elimination.mbt`](../../src/passes/duplicate_function_elimination.mbt), [`src/passes/dead_argument_elimination.mbt`](../../src/passes/dead_argument_elimination.mbt), [`src/passes/remove_unused_module_elements.mbt`](../../src/passes/remove_unused_module_elements.mbt) | Preserve/remap type indices or handle focused immutable-field folds. Generic motion/deletion/CSE still needs pass-specific proof. |

## Invariants And Edge Cases

- **No `MemArg` sharedness check.** `struct.atomic.get*` consumes a struct reference and has no selected memory index. Do not use `MemType(..., shared)` evidence to justify it, and do not use it to prove linear-memory atomics.
- **Effectful/trap-sensitive by default.** Even when a result is dropped, an aggregate atomic read can still matter as a trap/effect boundary. Passes must cite a local proof before deleting, moving, or duplicating it.
- **Packed signedness matters.** Plain `struct.atomic.get` is not valid for packed fields where signedness is required; use `_s` or `_u` with the intended extension behavior.
- **Order is currently only `seq_cst` / `acq_rel`.** This is not the Relaxed Atomics proposal and not a general ordering lattice.
- **Shared heap types are not modeled as a general type qualifier.** Current Starshine GC type pages can discuss structs/arrays and descriptor metadata, but there is no full shared heap-type representation, WAST syntax, subtype rule, or generator gate for the proposal.
- **Array aggregate atomics are future work.** `array.atomic.get*`, aggregate `set`, RMW, cmpxchg, wait/notify, and related families need new core variants, binary/WAST support, validation, generator facts, effect modeling, and pass rewrite rules before being documented as Starshine-supported.

## Examples Of Correct Claims

- “Shared-Everything Threads is active Phase 1 proposal evidence; Starshine only has a focused `struct.atomic.get*` slice today.”
- “`struct.atomic.get*` is a GC aggregate operation with type/field immediates, not a linear-memory atomic with `MemArg`.”
- “A pass that folds `struct.atomic.get*` must cite a pass-specific immutable-field or effect proof; ordinary validation success is not enough.”
- “`SharedMemoryAtomics` in GenValid names the linear-memory lane; do not use it as a full Shared-Everything proposal gate.”

## Future Implementation Checklist

1. **Representation:** add explicit shared heap-type and aggregate atomic instruction carriers for the exact proposal surface being implemented.
2. **Binary codec:** decode/encode new subcodes and immediates, including malformed order/type/field/index cases.
3. **WAST:** add keyword, parser, lowerer, printer, and roundtrip tests. Keep order spelling compatibility deliberate.
4. **Validation:** define stack types, shared/unshared heap-type rules, mutability and packed-field checks, trap behavior, and subtype interactions.
5. **Effects/HOT:** classify reads, writes, traps, synchronization, and barriers so optimizers cannot reorder or delete operations accidentally.
6. **Generators/fuzzing:** add proposal-feature facts only after the generated modules are Starshine-valid and externally classified.
7. **Pass signoff:** use Binaryen oracle fixtures where available, but classify mismatches through Starshine's transform contract and current proposal revision.
8. **Docs:** update this page, [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md), focused WAST/validation pages, [`index.md`](index.md), and [`log.md`](log.md).

## Source Map

- Focused boundary refresh: [`raw/wasm/2026-06-05-shared-everything-threads-boundary-refresh.md`](raw/wasm/2026-06-05-shared-everything-threads-boundary-refresh.md)
- Struct-atomic-get source snapshot: [`raw/wasm/2026-06-04-struct-atomic-get-sources.md`](raw/wasm/2026-06-04-struct-atomic-get-sources.md)
- Active-proposal routing: [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md)
- Linear-memory Threads boundary: [`wasm-linear-memory-threads-boundary.md`](wasm-linear-memory-threads-boundary.md)
- Linear-memory atomic WAST authoring: [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md)
- GC aggregate authoring: [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md)
- GC Core boundary: [`wasm-gc-core-boundary.md`](wasm-gc-core-boundary.md)
- Relaxed Atomics boundary: [`wasm-relaxed-atomics-boundary.md`](wasm-relaxed-atomics-boundary.md)
