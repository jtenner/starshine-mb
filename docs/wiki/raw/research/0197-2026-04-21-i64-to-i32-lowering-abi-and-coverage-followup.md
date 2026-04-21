# Binaryen `i64-to-i32-lowering` follow-up research: ABI surface and opcode coverage

Date: 2026-04-21

## Scope

This follow-up revisits the existing `i64-to-i32-lowering` dossier and closes one specific remaining teaching gap.

The folder already had a good landing page, strategy page, implementation/test map, boundary page, and WAT-shape catalog.
What it still lacked was one compact living page that answers the beginner-to-intermediate question:

- **what does Binaryen actually lower here, and what does it explicitly expect to have been removed or handled elsewhere?**

That gap matters because `i64-to-i32-lowering` is unusually easy to mis-teach as:

- a full arbitrary-i64 legalizer
- a small arithmetic rewrite pass
- or a pass that only touches memory ops

The actual `version_129` contract is broader than any one of those summaries, but also narrower than a universal i64 lowering story.

## Candidate selection result

Chosen pass: `i64-to-i32-lowering`

Why this was still a fair target:

- it is **not** on the user’s forbidden pass list
- it is already an upstream-only boundary-only dossier rather than a fully "deep" canonical folder
- the existing dossier already documented the big picture, but it still lacked a single source-backed coverage ledger for ABI rewrites, supported opcode families, helper-backed families, and explicit unsupported families
- that missing compact ledger was a real future-port risk because the pass’s file mixes supported lowering with explicit `Fatal()` / `assert()` / `WASM_UNREACHABLE()` boundaries

## Backlog slice check

`agent-todo.md` still has **no dedicated `i64-to-i32-lowering` slice**.

That remains worth stating explicitly, because this pass is already named in the local boundary-only registry and whole-module transform map, but the durable contract still lives in wiki research rather than an active implementation slice.

## Sources reviewed for this follow-up

### Local repo sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/flatness-helpers-and-boundaries.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/wat-shapes.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

### Official Binaryen `version_129` sources

- `src/passes/I64ToI32Lowering.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/pass.h`
- `src/abi/js.h`
- `src/asmjs/shared-constants.h`
- `src/ir/flat.h`
- `src/ir/iteration.h`
- `src/ir/memory-utils.h`
- `src/ir/module-utils.h`
- `src/ir/names.h`
- `test/lit/passes/flatten_i64-to-i32-lowering.wast`
- current-main spot check of `src/passes/I64ToI32Lowering.cpp`

## Main findings

## 1. The real remaining gap was not “what is the pass?” but “where does the pass stop?”

The current folder already explained:

- flatness
- split params/locals/globals
- hidden high-half temps
- helper imports
- the synthetic return-high global

But it still required readers to mentally merge several pages before they could answer practical questions like:

- does Binaryen lower imported i64 globals here?
- does it lower `return_call` with `i64` results here?
- which unary ops become explicit pairwise wasm code, and which ones are expected to be gone already?
- which binary ops are helper-backed, pairwise lowered, or explicitly unsupported?
- which boundary rewrites affect module ABI versus only expression trees?

That is exactly the kind of gap that causes a future port to overclaim support.

## 2. The ABI rewrite surface is larger and more structured than the broad name suggests

The reviewed file rewrites at least these module-visible surfaces:

- defined `i64` globals become low/high `i32` global pairs
- every `i64` param/local becomes adjacent low/high `i32` slots
- direct-call signatures are widened at callsites
- indirect-call heap signatures are rewritten when they mention `i64`
- `ref.func` heap types are rewritten when they mention `i64`
- `i64` function returns become `i32` returns plus the synthetic mutable global `INT64_TO_32_HIGH_BITS`
- imported direct calls are retargeted to `legalfunc$...` shims after ordinary call lowering

That is why the new living page should teach the pass as an **ABI-and-IR coverage matrix**, not just as a list of arithmetic rewrites.

## 3. The supported expression families break into four buckets, not one

The reviewed implementation naturally clusters into four support classes.

### A. Direct pairwise AST lowering

These are handled directly in the pass with low/high-half logic:

- `Const`
- `LocalGet` / `LocalSet` / `tee`
- `GlobalGet` / `GlobalSet` on previously-recorded defined i64 globals
- direct calls, indirect calls, and `ref.func`
- non-atomic `i64` loads/stores
- `select`
- `drop`
- `return`
- several unary ops like `eqz`, `wrap`, sign-extends, float/int conversions, `clz`
- several binary ops like add/sub, bitwise ops, shifts, equality, and ordered comparisons

### B. Helper-backed lowering

Some families remain supported, but not through pure pairwise wasm code:

- reinterpret between `i64` and `f64` goes through wasm2js scratch helpers
- some atomic-RMW and wait paths go through wasm2js helper imports like `ATOMIC_RMW_I64`, `GET_STASHED_BITS`, and `ATOMIC_WAIT_I32`

### C. Structural cleanup / fallback handling

The pass also has narrow cleanup logic for:

- unreachable subtrees where children execute unconditionally

That is not ordinary opcode lowering, but it is still part of the public behavior surface.

### D. Explicit unsupported / assumed-gone families

Several families are **not** lowered here in the general case:

- imported `i64` globals still hit `Fatal() << "TODO: imported i64 globals"`
- `return_call` / `return_call_indirect` with `i64` results still hit a fatal error
- `AtomicCmpxchg` on `i64` is still asserted unsupported
- direct atomic `i64` load/store splitting is asserted unsupported in the ordinary load/store visitors
- `mul`, `div`, `rem`, rotates, and some count ops are treated as shapes that “should already be removed by now”

This is one of the most important durable facts to keep visible.

## 4. The pass’s “coverage” is pipeline-sensitive on purpose

The follow-up source read makes one thing even clearer than the first dossier pass:

`i64-to-i32-lowering` is not intended to accept arbitrary raw wasm with arbitrary remaining i64 ops.
It lives inside a broader legalization story.

The source-backed prerequisites now worth teaching together are:

- **flat input** through `Flat::verifyFlatness(func)`
- **legalize-js-interface already run** for imported direct-call retargeting to make sense
- **earlier i64 cleanup** for harder ops that this pass still treats as impossible leftovers
- **wasm2js helper availability** for reinterpret and some atomic paths

This was already partially visible in the folder, but the new page should state it in one compact place.

## 5. The official lit file proves the ABI side channel is a first-class output shape

`flatten_i64-to-i32-lowering.wast` already showed:

- the synthetic mutable global `i64toi32_i32$HIGH_BITS`
- `$hi` locals
- temp locals like `i64toi32_i32$0`
- visible `i32` returns where the old source returned `i64`

The new follow-up insight is that the lit surface is best read as a proof of the pass’s **coverage categories**:

- direct pairwise lowering for many arithmetic and structural families
- synthetic ABI side channels for returns and temps
- block-heavy output because the pass needs single-evaluation and high-half transport

## 6. Current upstream `main` still does not contradict the version_129 coverage summary

A fresh spot check of `src/passes/I64ToI32Lowering.cpp` on current upstream `main` again showed only the earlier comment typo cleanup, not a semantic expansion of the supported-family matrix.

So the `version_129` coverage matrix remains a good current durable contract for this dossier.

## Living-doc consequences

This follow-up justifies adding one new living page to the folder:

- `abi-surface-and-opcode-coverage.md`

That page should become the canonical answer to:

- what Binaryen lowers directly here
- what it lowers via helpers
- what it only handles as ABI shape rewrites
- what it still rejects or expects to have been removed earlier

The landing page, pass index, tracker, and top-level wiki index should then mention that the folder now includes this compact ABI/opcode coverage ledger, so future recursive campaign threads do not reopen the same “is this a universal i64 legalizer?” gap.

## Source URLs

- Binaryen `version_129` `I64ToI32Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Binaryen `version_129` `pass.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- Binaryen `version_129` `abi/js.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/abi/js.h>
- Binaryen `version_129` `shared-constants.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/asmjs/shared-constants.h>
- Binaryen `version_129` `flat.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- Binaryen `version_129` `iteration.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/iteration.h>
- Binaryen `version_129` `memory-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/memory-utils.h>
- Binaryen `version_129` `module-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- Binaryen `version_129` `names.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
- Binaryen `version_129` `flatten_i64-to-i32-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>
- Binaryen current `main` spot-check file: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/I64ToI32Lowering.cpp>
