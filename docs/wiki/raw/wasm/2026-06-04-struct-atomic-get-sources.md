# Struct Atomic Get Source Snapshot

- Source family: WebAssembly shared-everything threads proposal, Binaryen shared-GC atomics tests, and Starshine local source.
- Capture date: 2026-06-04.
- Reason for capture: Starshine is growing a WAST/core/binary/validator surface for `struct.atomic.get`, `struct.atomic.get_s`, and `struct.atomic.get_u`. The existing atomic-memory page covered linear-memory threads atomics only, so this snapshot records the separate shared-GC aggregate surface and its current local caveats.

## Primary external sources checked

1. WebAssembly shared-everything threads proposal overview: <https://github.com/WebAssembly/shared-everything-threads/blob/main/proposals/shared-everything-threads/Overview.md>
2. WebAssembly shared-everything threads proposal instructions section: <https://github.com/WebAssembly/shared-everything-threads/blob/main/proposals/shared-everything-threads/Overview.md#instructions>
3. Binaryen `vacuum-gc-atomics.wast` lit fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-gc-atomics.wast>
4. Binaryen `gsi.wast` lit fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi.wast>

## Source-backed takeaways

- Shared-everything threads is a proposal-family surface, not part of the older linear-memory threads atomics page. The proposal overview defines shared heap types as explicitly shared types and says shared structs and arrays may be accessed by both atomic and non-atomic instructions, with atomic updates avoiding data races while nonatomic accesses trap on shared inputs.
- The proposal instruction surface includes shared-GC aggregate atomics such as `struct.atomic.get`, `struct.atomic.get_s`, `struct.atomic.get_u`, `array.atomic.get*`, `struct.atomic.rmw*`, `array.atomic.rmw*`, and compare-exchange families. This means `struct.atomic.get*` belongs with GC aggregate authoring and optimizer aggregate/effect reasoning, not with `MemArg`-carrying linear-memory atomics.
- Binaryen uses these instructions in optimizer lit fixtures. `vacuum-gc-atomics.wast` proves the family is observable enough that generic cleanup must not delete it merely because a result is dropped, and `gsi.wast` uses immutable-field `struct.atomic.get*` cases as part of global-struct-inference coverage.
- Text spelling is not fully unified across sources. Binaryen examples have historically used compact order spellings such as `acqrel` and `seqcst`. The current Starshine WAST surface uses and prints `acq_rel` and `seq_cst`, while accepting `acqrel` as an alias for acquire-release; as of this snapshot, no `seqcst` alias is documented in local parser code.
- These instructions do not carry a linear-memory `MemArg`. Their immediates are an atomic order, type index, and field index. Runtime operand stack behavior follows ordinary struct get shape: consume the struct reference and push the field value, with packed fields read through signed or unsigned variants.

## Starshine local source map

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `AtomicOrder`, `StructAtomicGet`, `StructAtomicGetS`, and `StructAtomicGetU` plus constructor helpers.
- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) registers `struct.atomic.get`, `struct.atomic.get_s`, and `struct.atomic.get_u` keyword spellings.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses an atomic order followed by type and field indices. It accepts `seq_cst`, `acq_rel`, and `acqrel`; `seqcst` is not currently an accepted alias.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) resolves named or numeric type indices and lowers WAST atomic get nodes into core instructions.
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prints canonical `seq_cst` / `acq_rel` order spellings.
- [`src/wast/struct_atomic_get_surface_test.mbt`](../../../../src/wast/struct_atomic_get_surface_test.mbt) covers folded parse, print, and lowering shapes.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt), and [`src/binary/tests.mbt`](../../../../src/binary/tests.mbt) cover the `0xFE 0x5C..0x5E` binary subcodes plus the order/type/field immediates.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) reuses the ordinary struct-get stack rules for the atomic-get variants, including packed-field signedness checks.
- [`src/ir/effects.mbt`](../../../../src/ir/effects.mbt), [`src/ir/hot_lift.mbt`](../../../../src/ir/hot_lift.mbt), [`src/passes/precompute.mbt`](../../../../src/passes/precompute.mbt), [`src/passes/simplify_locals.mbt`](../../../../src/passes/simplify_locals.mbt), and [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt) currently model the instructions conservatively as atomic reads that may trap.
- [`src/passes/remove_unused_module_elements.mbt`](../../../../src/passes/remove_unused_module_elements.mbt), [`src/passes/dead_argument_elimination.mbt`](../../../../src/passes/dead_argument_elimination.mbt), [`src/passes/duplicate_function_elimination.mbt`](../../../../src/passes/duplicate_function_elimination.mbt), and [`src/passes/rse.mbt`](../../../../src/passes/rse.mbt) preserve and remap the referenced type index where needed.

## Current caveats to preserve

- This snapshot is about struct atomic gets only. It does not imply Starshine has WAST/core support for `struct.atomic.set`, `struct.atomic.rmw*`, `struct.atomic.cmpxchg`, array atomic aggregate operations, or wait/notify-on-aggregate families.
- Linear-memory atomics (`i32.atomic.load`, `memory.atomic.wait32`, `atomic.fence`, and friends) remain a different family with shared-memory `MemArg`/resource rules. Keep them routed through `atomic-memory-instruction-authoring.md` and `memory-argument-authoring.md`.
- Generic passes should continue treating `struct.atomic.get*` as effectful/trap-sensitive unless a pass-specific source proof says an immutable-field atomic read is safe to fold. Binaryen's `global-struct-inference` has such an immutable-field family; Starshine's focused GSI slice now covers immutable-field direct-global and closed-world local/param folds/selects, while broader atomic aggregate parity and generic motion/deletion remain separate questions.
- Because text order spellings differ across sources, WAST fixtures intended for Starshine should use canonical `seq_cst` / `acq_rel` today, or explicitly test the `acqrel` compatibility alias. Do not assume Binaryen's compact `seqcst` spelling parses locally until code proves it.
