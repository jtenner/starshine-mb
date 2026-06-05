# Shared-Everything Threads Boundary Refresh

- Capture date: 2026-06-05
- Source family: WebAssembly active-proposal tracker, Shared-Everything Threads proposal overview, already-ingested struct-atomic source snapshot, and current Starshine WAST/core/binary/validator/generator/pass evidence.
- Primary sources checked on 2026-06-05:
  - WebAssembly proposals tracker, current `main`: <https://github.com/WebAssembly/proposals>
  - WebAssembly Shared-Everything Threads overview, current `main`: <https://github.com/WebAssembly/shared-everything-threads/blob/main/proposals/shared-everything-threads/Overview.md>
  - WebAssembly Shared-Everything Threads instructions section: <https://github.com/WebAssembly/shared-everything-threads/blob/main/proposals/shared-everything-threads/Overview.md#instructions>
- Local Starshine sources checked:
  - `src/lib/types.mbt`
  - `src/wast/keywords.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast.mbt`, `src/wast/struct_atomic_get_surface_test.mbt`
  - `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/binary/tests.mbt`
  - `src/validate/typecheck.mbt`, `src/validate/validate.mbt`, `src/validate/gen_valid.mbt`
  - `src/ir/effects.mbt`, `src/ir/hot_lift.mbt`, `src/ir/hot_verify.mbt`
  - `src/passes/precompute.mbt`, `src/passes/simplify_locals.mbt`, `src/passes/global_struct_inference.mbt`, `src/passes/rse.mbt`, `src/passes/duplicate_function_elimination.mbt`, `src/passes/dead_argument_elimination.mbt`, `src/passes/remove_unused_module_elements.mbt`

## Current official/proposal takeaways

- The WebAssembly proposals tracker still routes Shared-Everything Threads as an active Phase-1 proposal. It is not stable Core WebAssembly 3.0 and it is not the same feature row as the older Threads proposal for shared linear memories.
- The proposal overview frames the feature around shared heap objects, shared types, and typed sharedness so Wasm GC values can cross agents without reusing the linear-memory sharedness model.
- The proposal distinguishes shared and unshared heap types. Shared objects may be accessed by atomic and non-atomic aggregate operations; non-atomic accesses to shared values are trap-sensitive in the proposal model.
- The overview's instruction surface is broad: it includes `struct.atomic.get*`, `array.atomic.get*`, aggregate atomic set/RMW/compare-exchange forms, wait/notify-style aggregate operations, and conversion/identity surfaces around shared values.
- Shared-Everything atomics do not use `MemArg`. Their immediates and validation obligations belong with GC aggregate/type/effect reasoning, not the selected-linear-memory rule used by `i32.atomic.load`, `memory.atomic.wait32`, or `memory.atomic.notify`.
- The proposal can change before standardization. Recheck the overview and proposals tracker before adding array atomics, aggregate RMW/cmpxchg, wait/notify, shared heap-type syntax, or JS/runtime-thread claims.

## Starshine current-code reconciliation

- Starshine has a focused local/proposal-shaped slice for `struct.atomic.get`, `struct.atomic.get_s`, and `struct.atomic.get_u` only.
- `src/lib/types.mbt` defines `AtomicOrder::SeqCst`, `AtomicOrder::AcqRel`, and core `StructAtomicGet*` instruction variants. It does not define array atomic, aggregate atomic set/RMW/cmpxchg, wait/notify, or general shared heap-type instruction families.
- `src/wast/keywords.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast.mbt`, and `src/wast/struct_atomic_get_surface_test.mbt` give high-level WAST support for the struct-get slice. Starshine prints canonical `seq_cst` / `acq_rel`; the parser accepts `acqrel` as a compatibility alias but not a documented `seqcst` alias.
- `src/binary/decode.mbt`, `src/binary/encode.mbt`, and `src/binary/tests.mbt` cover binary subcodes `0xFE 0x5C..0x5E` plus order/type/field immediates for the struct-get slice.
- `src/validate/typecheck.mbt` validates `StructAtomicGet*` with ordinary struct-get stack/type rules plus packed-field signedness checks. The current slice does not require or consult `MemType(..., shared)`, because it is not a linear-memory atomic operation.
- `src/ir/effects.mbt`, `src/ir/hot_lift.mbt`, and `src/ir/hot_verify.mbt` treat these instructions as one-operand aggregate reads that may read memory/state and trap. This is the conservative default optimizer boundary.
- Several passes preserve/remap or handle the type indices carried by `StructAtomicGet*`. `global_struct_inference.mbt` has a focused immutable-field fold path for this slice; generic deletion, movement, CSE, and precompute still need pass-specific proofs because shared aggregate reads are trap/effect-sensitive.
- `GenValidProposalFeature::SharedMemoryAtomics` names the ordinary shared-linear-memory atomic lane, not this whole Shared-Everything proposal. The struct-atomic-get slice is visible through GC surface facts, not as a full proposal gate.

## Documentation consequences

- Add a focused living boundary page so Shared-Everything Threads no longer appears only as a generic feature-status row or as a `struct.atomic.get*` footnote on WAST aggregate pages.
- Route linear-memory shared memories and `MemArg` atomics through `wasm-linear-memory-threads-boundary.md` and `wast/atomic-memory-instruction-authoring.md`.
- Route the current local struct-atomic-get text/validator/pass surface through `wast/gc-aggregate-instruction-authoring.md` plus the new boundary page.
- Keep broader shared heap types, array atomics, aggregate set/RMW/cmpxchg, wait/notify, and JS/runtime threading as future proposal work unless exact Starshine representation, binary, WAST, validator, generator, and optimizer evidence is added.

## Supersession and uncertainty

- This refresh supplements `2026-06-04-struct-atomic-get-sources.md` by adding the active-proposal boundary page and a current proposal-status recheck. It does not supersede the detailed struct-atomic-get source map in that older snapshot.
- The Shared-Everything proposal remains early and broad. Treat this note as routing evidence, not as an implementation plan or a claim that Starshine has full proposal support.
