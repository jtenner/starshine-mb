# 0175 - Binaryen `i64-to-i32-lowering` research

Date: 2026-04-21
Status: completed research ingest
Pass: `i64-to-i32-lowering`
Local registry status: boundary-only
Upstream status: public Binaryen pass in `version_129`

## Why this pass was chosen

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

The original no-DWARF queue is already dossier-covered.
The earlier tracker-expansion queue is dossier-covered too.
So this thread needed either:

- a justified major-gap fallback inside an already-deep folder, or
- a source-backed expansion to another still-undocumented upstream-only registry pass.

I chose `i64-to-i32-lowering` because:

1. it is already a real local boundary-only registry name in `src/passes/optimize.mbt`
2. it is also called out in the local pass-port map under whole-module transforms
3. it has a large, official `version_129` implementation file
4. it has a dedicated official lit surface via `flatten_i64-to-i32-lowering.wast`
5. it sits near already-documented neighbors like `flatten`, `inlining`, and JS-interface legalization, so a future port will benefit from a dedicated canonical explanation
6. `agent-todo.md` currently has **no dedicated `i64-to-i32-lowering` slice**

## Scope and beginner summary

Binaryen's `i64-to-i32-lowering` is not a small arithmetic peephole pass.
It is a whole-function plus module-signature legalization pass that rewrites 64-bit integer traffic into pairs of `i32` values.

The key beginner model is:

- one logical `i64` value becomes **low 32 bits + high 32 bits**
- params and locals are split into neighboring `i32` slots
- most expression rewrites leave the low half as the visible expression result
- the matching high half is threaded through a temporary-local side channel
- `i64` function returns are lowered to `i32` returns plus a synthetic mutable global that carries the high bits

That means the pass is best taught as:

- **whole-program i64 ABI reshaping for wasm2js-style targets**
- not generic integer optimization
- not just load/store splitting
- and not a default Binaryen optimize-path pass

## Official upstream sources reviewed

Primary implementation and registry sources:

- `https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp`
- `https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp`
- `https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h`
- `https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h`

Important helper and dependency sources:

- `https://github.com/WebAssembly/binaryen/blob/version_129/src/abi/js.h`
- `https://github.com/WebAssembly/binaryen/blob/version_129/src/asmjs/shared-constants.h`
- `https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h`
- `https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/iteration.h`
- `https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/memory-utils.h`
- `https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h`
- `https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h`

Official test source:

- `https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast`

Freshness check:

- `https://github.com/WebAssembly/binaryen/blob/main/src/passes/I64ToI32Lowering.cpp`

## What the implementation actually does

## 1. The pass is module-shaped, not function-parallel

The pass class is:

- `I64ToI32Lowering : WalkerPass<PostWalker<I64ToI32Lowering>>`

but it explicitly overrides:

- `addsEffects() -> true`
- `isFunctionParallel() -> false`

The function-parallel override is disabled because function signatures and globals are rewritten, not just function bodies.

## 2. It rewrites module globals before walking functions

`doWalkModule(Module* module)` first scans globals.
For every `i64` global it:

- remembers the original name in `originallyI64Globals`
- changes the original global's type from `i64` to `i32`
- creates a sibling global named `<name>$hi`
- initializes the low and high halves separately for constant initializers
- or mirrors `global.get` initializers through the high-half sibling

Important hard boundary:

- imported `i64` globals still hit `Fatal() << "TODO: imported i64 globals"`

After that, the pass always adds one special mutable global:

- `INT64_TO_32_HIGH_BITS`

This global is the out-of-band carrier for **function return high bits**.

## 3. It requires already-flat function bodies

At the start of `doWalkFunction(Function* func)` the pass calls:

- `Flat::verifyFlatness(func)`

That is a real contract, not a convenience check.
The dedicated official test also runs:

- `wasm-opt -all --flatten --i64-to-i32-lowering`

So the real upstream story is:

- this pass expects flattened input
- it is not responsible for flattening nested expression trees itself
- `flatten` is part of the practical prerequisite story

This also explains why the only dedicated lit file is a combined flatten-plus-lowering file.

## 4. It splits every `i64` param/local into two `i32` slots

Still in `doWalkFunction`, Binaryen copies the old function into a temporary module, clears params and locals from the real function, ensures names exist, and rebuilds the local list.

For each old local:

- non-`i64` locals keep one slot
- `i64` locals get a low slot with the original name and a high slot with `name$hi`
- `indexMap` records old-index -> new-low-index

So the canonical slot policy is:

- `old i64 local k` becomes `new local k_low` and `new local k_hi`
- later rewrites assume the high half is exactly `mappedIndex + 1`

## 5. Expression lowering uses a hidden high-half side channel

The most important internal mechanism is the pair:

- `setOutParam(Expression* e, TempVar&& var)`
- `fetchOutParam(Expression* e)`

The pass keeps a map from rewritten expressions to a temporary local containing the matching high bits.
That means:

- the visible AST node usually becomes an `i32` low-half expression
- the high half is tracked separately in `highBitVars`
- later users must explicitly `fetchOutParam(...)` when they need the high half

This is the core shape future Starshine docs and ports must preserve.
Without it, the rest of the pass logic is hard to understand.

## 6. Calls are fixed up at ABI boundaries

`visitGenericCall(...)` rewrites call operands and results.
For each argument:

- original operand is pushed as the low half
- if that operand has an out param, its high-half local is appended immediately after

For results:

- non-`i64` results are rebuilt directly
- `i64` results become an `i32` call result plus a read from `INT64_TO_32_HIGH_BITS`

The pass also rewrites imported direct-call targets to:

- `legalfunc$<target>`

and explicitly says this assumes:

- `legalize-js-interface` has already run

Important hard boundaries:

- `return_call` with `i64` results is still fatal for both direct and indirect calls
- the pass rewrites `CallIndirect` signatures by splitting `i64` params and demoting `i64` results to `i32`
- `RefFunc` heap types are also rewritten to the lowered signature shape

## 7. Local/global traffic is rewritten symmetrically

For `local.get` of an original `i64` local:

- the node becomes a low-half `i32` get
- a block first copies `mappedIndex + 1` into a temp high-half local
- that temp is attached as the out param

For `local.set` / `local.tee` of a lowered value:

- the low half stays in the visible `local.set`
- the high half is stored into `mappedIndex + 1`
- `tee` uses an extra temp so the low-half result value still flows onward

For globals, the same policy uses sibling `<name>$hi` globals.

## 8. Memory traffic is only partly split directly

### Loads

When a load produces `i64`, the pass:

- saves the pointer once in a temp
- rewrites the visible load to an `i32` low-half load
- computes the high half in one of two ways:
  - for 8-byte loads: loads the upper 4 bytes from `offset + 4`
  - for smaller sign/zero-extending loads: synthesizes the high half from sign extension or zero
- caps bytes and align to `4`

Important boundary:

- atomic `i64` loads are *not* lowered here; the code asserts they are not present

### Stores

When a store consumes a lowered `i64` value:

- the visible store is rewritten to an `i32` low-half store
- for 8-byte stores only, a second `i32.store` writes the high half at `offset + 4`
- pointer evaluation is still single-shot via a temp

Important boundary:

- atomic stores are also not handled by direct splitting here

## 9. Some atomic operations are replaced by wasm2js helper calls

The pass has special lowering for:

- `AtomicRMW` returning `i64`
- `AtomicWait` with an `i64` timeout argument

`AtomicRMW` is lowered to helper calls such as:

- `ABI::wasm2js::ATOMIC_RMW_I64`
- `ABI::wasm2js::GET_STASHED_BITS`

and `AtomicWait` is lowered to:

- `ABI::wasm2js::ATOMIC_WAIT_I32`

This is a major teaching point:

- Binaryen does **not** always split a 64-bit operation into two plain wasm operations
- for atomic cases it sometimes lowers to helper imports because the semantics must stay atomic or otherwise need runtime support

Hard boundary:

- `AtomicCmpxchg` with `i64` is still explicitly unsupported in this pass

## 10. Consts and many unary/binary ops become pairwise arithmetic

### Constants

`i64.const` becomes:

- low half = low 32 bits as `i32.const`
- high half = upper 32 bits in a temp

### Unary ops

The pass directly lowers important unary families such as:

- `i64.eqz`
- `i64.extend_i32_s`
- `i64.extend_i32_u`
- sign-extension variants
- reinterpret pairs `i64 <-> f64`
- float-to-int64 truncations
- int64-to-float conversions
- `clz`

Several of these use real algorithmic decompositions, not simple halfwise rewrites.
For example:

- `eqz` ORs low/high halves and applies `i32.eqz`
- `reinterpret` uses scratch-memory wasm2js helpers
- float/int conversions build multi-step numeric expressions instead of calling an all-purpose runtime helper

Important upstream honesty boundaries:

- `i64.popcnt`, `i64.ctz`, multiplication, division, remainder, and rotates are all treated as things that **should already have been removed** before this pass runs
- the file uses `WASM_UNREACHABLE` for those families rather than implementing them locally

So the real scheduler contract is stricter than the pass name implies.
A future port cannot just run this pass on arbitrary raw wasm and expect every `i64` op family to lower.

### Binary ops that are implemented here

Implemented pairwise families include:

- add with carry
- subtract with borrow
- bitwise ops
- left/right shifts with `< 32` versus `>= 32` split logic
- equality/inequality
- signed and unsigned comparisons

These are classic two-limb lowering patterns.
The visible result is often the low-half `i32` value while the high-half temp is attached as the out param.

## 11. `select`, `drop`, and `return` have dedicated repair rules

For `select` on lowered `i64` values:

- the condition is evaluated once into a temp
- Binaryen selects low halves and high halves separately
- the low-half `select` becomes the visible result
- the high-half `select` is stored in a temp out param

For `drop`:

- if the dropped value has a high-half out param, the pass fetches and discards it so temp bookkeeping stays consistent

For `return` of a lowered `i64` value:

- low half becomes the explicit returned `i32`
- high half is written into `INT64_TO_32_HIGH_BITS`

That `return` rule is the most important visible ABI rewrite in the pass.

## 12. Unreachable handling is conservative and shape-limited

`handleUnreachable(...)` exists because some nodes can have only one half lowered before DCE or other cleanup has removed dead pieces.
The helper only applies when:

- the current node itself is `unreachable`
- its children are unconditionally evaluated before the node

The implementation comment explicitly says this is **not valid for `if`**.
So even the fallback cleanup path is shape-sensitive.

## Important helper dependencies

The most important dependencies are:

- `Flat::verifyFlatness` from `src/ir/flat.h`
- `ChildIterator` from `src/ir/iteration.h`
- `MemoryUtils::ensureExists` from `src/ir/memory-utils.h`
- `ModuleUtils::copyFunction` from `src/ir/module-utils.h`
- `Names::ensureNames` from `src/ir/names.h`
- wasm2js helper declarations from `src/abi/js.h`
- shared symbolic names from `src/asmjs/shared-constants.h`

What each one contributes:

- `flat.h`: formal prerequisite; this pass expects flattened IR
- `iteration.h`: child iteration for unreachable fallback logic
- `memory-utils.h`: ensures a memory exists before scratch-memory reinterpret helpers are used
- `module-utils.h`: copies the original function before rebuilding its param/local layout
- `names.h`: guarantees local names exist so the new `$hi` locals can be named predictably
- `abi/js.h`: declares helper imports used for scratch memory and atomic runtime calls
- `shared-constants.h`: provides stable symbol names like `INT64_TO_32_HIGH_BITS`

## Important IR / WAT shapes

Positive families:

- direct `i64.const`
- direct calls with `i64` params/results
- `call_indirect` and `ref.func` signature rewrites
- `local.get` / `local.set` / `local.tee` on original `i64` locals
- `global.get` / `global.set` on rewritten non-imported `i64` globals
- `i64.load` / `i64.store` split into two `i32` operations
- `i64.eqz`
- `i64.add` / `i64.sub`
- bitwise and comparison families
- shift families with explicit `< 32` vs `>= 32` handling
- `select` on lowered i64 pairs
- `return` with global-based high-half out param

Negative or bailout families:

- imported `i64` globals
- `return_call` / `return_call_indirect` with `i64` results
- direct handling of `i64` atomic cmpxchg
- direct handling of atomic loads/stores as split memory ops
- raw nested non-flat IR
- mul/div/rem/rot/popcnt/ctz families that upstream expects earlier passes to remove

Subtle families easy to misunderstand:

- `reinterpret` is not just bitwise pair splitting; it uses scratch-memory helper imports
- atomic RMW is not split into ordinary non-atomic wasm ops; it calls wasm2js helpers
- return values use a global side channel, not multivalue or hidden extra params
- not every operation leaves a visible block; some only update the hidden high-half temp

## Test surface and what it proves

The dedicated official test surface is:

- `test/lit/passes/flatten_i64-to-i32-lowering.wast`

That is important for two reasons.
It proves:

1. upstream expects flattened input before this pass
2. the official behavior examples cover the combined lowering story rather than isolated micro-tests per opcode family

The checked test includes evidence for:

- the added `INT64_TO_32_HIGH_BITS` global
- import and defined-function signature changes
- split low/high locals with `$hi` names
- pairwise arithmetic lowering
- explicit temp-local scaffolding

## Freshness check against current `main`

A direct source diff between:

- `version_129/src/passes/I64ToI32Lowering.cpp`
- `main/src/passes/I64ToI32Lowering.cpp`

found only one change:

- a comment typo fix from `instrinsic` to `intrinsic`

So the reviewed implementation summary is still materially current as of this research pass.

## What a future Starshine port must preserve

A faithful port must preserve at least these invariants:

1. **flatness precondition**
   - do not silently treat this as a generic nested-AST lowering pass
2. **two-channel value model**
   - visible low-half expression plus hidden high-half carrier
3. **stable local splitting policy**
   - high half immediately follows low half for original `i64` locals
4. **return side-channel policy**
   - low half returned directly, high half stored in a synthetic global
5. **single-evaluation rules**
   - pointer expressions and selected conditions are saved before duplicated use
6. **runtime-helper boundaries**
   - scratch-memory reinterpret and atomic helper calls are part of the real contract
7. **upstream bailout honesty**
   - imported `i64` globals and `return_call` `i64` results are not silently supported in `version_129`
8. **scheduler coupling**
   - this pass depends on flattening and on earlier elimination/lowering of several harder `i64` ops

## Easy misconceptions to avoid

1. `i64-to-i32-lowering` is **not** a default `-O` / `-Os` pass.
2. It is **not** only about loads/stores.
3. It is **not** function-local only; it rewrites globals and function signatures too.
4. It does **not** use multivalue to preserve `i64` returns; it uses a synthetic mutable global.
5. It does **not** fully support every `i64` family by itself.
6. It does **not** lower arbitrary unflattened wasm trees.

## Uncertainty and inference notes

The source facts above are direct.
Two narrower teaching inferences are worth labeling explicitly:

- **Inference:** the practical scheduler neighborhood is strongly tied to wasm2js-style legalization, because the pass directly uses `ABI::wasm2js` helper names and assumes imported-call legalization has already happened.
- **Inference:** the dedicated combined `flatten -> i64-to-i32-lowering` test likely exists because flatness is not just a validator preference but a real structural precondition for the rewriting strategy.

Both inferences are strongly supported by the source, but they are still interpretive summaries rather than single-line explicit upstream comments.

## Files to update in the living wiki

- `docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/flatness-helpers-and-boundaries.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Short conclusion

`i64-to-i32-lowering` is a real, large, source-backed upstream-only registry pass and a good next campaign target because it still had no dedicated living dossier.
The real Binaryen `version_129` contract is:

- module-aware signature and global rewriting
- flattened-function lowering
- low-half visible values plus high-half temp/global side channels
- selective direct splitting for locals, globals, loads, stores, and many integer ops
- helper-based lowering for reinterpret and some atomic families
- explicit unsupported or pre-lowered boundaries for several harder shapes

That is much richer than the pass name suggests, and it deserved a dedicated wiki home.
