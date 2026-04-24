---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md
  - ../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0175-2026-04-21-i64-to-i32-lowering-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/abi/js.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/asmjs/shared-constants.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/iteration.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/memory-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flatness-helpers-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Upstream implementation structure and tests for `i64-to-i32-lowering`

## File map

## `src/passes/I64ToI32Lowering.cpp`

This is the real contract file.
Nearly everything important lives here.

It defines:

- the pass class
- module-global rewriting
- function signature and local splitting
- the hidden high-half temp mechanism
- call-boundary lowering
- local/global/load/store/atomic rewrites
- unary and binary lowering helpers
- `select` / `drop` / `return` repairs
- the unreachable fallback helper

If future repo docs disagree with this file, this file wins.

## `src/passes/pass.cpp`

This file proves:

- the public pass name is exactly `i64-to-i32-lowering`
- the public description is `lower all uses of i64s to use i32s instead`
- this is a normal public registered pass, not a hidden test-only pass

It also proves a negative scheduler fact by omission:

- the pass is not part of Binaryen's default optimize preset tables here

## `src/passes/passes.h`

This file proves the factory name:

- `createI64ToI32LoweringPass()`

That matters because it confirms this is treated as a first-class pass surface alongside the other public transforms.

## `src/pass.h`

This file contributes the generic pass-framework facts used by the implementation:

- pass registration model
- public versus hidden pass distinction
- normal pass creator plumbing

It is not pass-specific, but it explains why `i64-to-i32-lowering` showing up in `pass.cpp` is enough to treat it as a real public user-facing pass.

## `src/ir/flat.h`

This file matters because the lowering pass calls:

- `Flat::verifyFlatness(func)`

So `flat.h` is part of the real legality story, not background trivia.

The major takeaway is:

- flattened input is a hard precondition for the reviewed implementation

## `src/ir/iteration.h`

This file provides the child iteration helper used by `handleUnreachable(...)`.
That matters because the unreachable fallback works only for node kinds whose children are unconditionally evaluated.

## `src/ir/memory-utils.h`

This file matters because reinterpret lowering calls:

- `MemoryUtils::ensureExists(getModule())`

That proves scratch-memory helper lowering can force the module to have a memory, because the pass relies on wasm2js scratch-memory roundtrips for reinterpret behavior.

## `src/ir/module-utils.h`

This file matters because `doWalkFunction(...)` copies the old function before rebuilding locals.
That temporary-copy pattern is part of how Binaryen preserves old local metadata while constructing the new split local list.

## `src/ir/names.h`

This file matters because the pass uses:

- `Names::ensureNames(oldFunc)`

That is what makes `$hi` sibling naming practical even when original locals were unnamed.

## `src/abi/js.h`

This file is crucial.
It declares the wasm2js helper imports used by the pass, including helper names for:

- scratch-memory reinterpret support
- atomic helper lowering
- general helper import materialization through `ensureHelpers(...)`

Without this file, it is easy to misread the pass as pure wasm-to-wasm lowering.
It is not.

## `src/asmjs/shared-constants.h`

This file matters because it declares symbolic names used by the pass, including:

- `INT64_TO_32_HIGH_BITS`

That symbol is the synthetic global used to carry return high halves.

## Test surface

## `test/lit/passes/flatten_i64-to-i32-lowering.wast`

This is the dedicated official lit file for the pass.
The run line is important:

- `wasm-opt -all --flatten --i64-to-i32-lowering -S -o -`

This proves two things immediately:

1. the test expects a flattened-input pipeline
2. the official public behavior surface is checked in text form after both steps

### What this test proves

The checked output demonstrates all of these visible contracts:

- a synthetic mutable global `i64toi32_i32$HIGH_BITS` is created
- a function returning `i64` is rewritten to return `i32`
- original `i64` locals are split into low and `$hi` locals
- extra temp locals named `i64toi32_i32$N` are added
- pairwise arithmetic lowering is emitted as explicit low/high logic
- the lowered code shape is blocky and temp-heavy, not a tiny peephole rewrite

### What this test does not prove alone

The single lit file is broad, but not exhaustive by filename.
It does not mean the pass supports every imaginable `i64` feature combination.
The source file itself still contains explicit fatal or unreachable boundaries for several families.
So the source file remains the primary truth for unsupported shapes.

## Current-main freshness note

The immutable 2026-04-24 raw manifest now records the `version_129` owner, helper, test, and current-`main` URLs used by the dossier.
The older 2026-04-21 comparison found only a comment typo fix on the checked owner-file surface; this run did not discover a new teaching-relevant contract to add beyond that `version_129` story.
Treat this as a narrow freshness note, not a whole-repository equivalence proof.

## Practical reading order for future port work

If you need to re-study this pass later, use this order:

1. `src/passes/pass.cpp`
   - confirm the pass is real and public
2. `src/passes/I64ToI32Lowering.cpp`
   - read the actual algorithm and boundaries
3. `test/lit/passes/flatten_i64-to-i32-lowering.wast`
   - see the emitted shapes Binaryen expects
4. `src/ir/flat.h`
   - understand the flatness contract
5. `src/abi/js.h`
   - understand helper-import assumptions
6. `src/ir/module-utils.h` and `src/ir/names.h`
   - understand how local rebuilding and naming work

## Starshine follow-along map

For the local code surfaces a future port must read after this upstream file/test map, see [`./starshine-strategy.md`](./starshine-strategy.md).
That page records the current boundary-only registry status and the exact Starshine files that own pass dispatch, type/index structures, WAT lowering, binary codec support, and validation.

## Short source-backed summary

The official Binaryen contract is not hidden in many tiny sibling files.
It is mostly one large pass file plus one broad lit file, with a handful of helper headers proving the structural preconditions and runtime-helper dependencies.
That makes `i64-to-i32-lowering` relatively easy to locate, but easy to mis-teach unless the helper and boundary files are mentioned explicitly.
