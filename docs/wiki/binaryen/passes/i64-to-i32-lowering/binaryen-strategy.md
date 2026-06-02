---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md
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
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/I64ToI32Lowering.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./flatness-helpers-and-boundaries.md
  - ./abi-surface-and-opcode-coverage.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy for `i64-to-i32-lowering`

## What the pass really is

Upstream Binaryen publishes this pass as `i64-to-i32-lowering`.

The reviewed implementation is a **whole-module AST legalization pass** whose real job is:

- split logical `i64` values into low/high `i32` halves,
- rewrite signatures, globals, locals, and expression trees around that split,
- and preserve `i64`-shaped semantics through helper locals, helper globals, and a few wasm2js runtime helpers.

That means the best mental model is:

- **pair-lowering with an ABI rewrite**
- not “replace an `i64` op with two `i32` ops” in isolation
- not “just legalize load/store widths”
- and not “a normal hot pass”

## Scheduler placement

`src/passes/pass.cpp` registers `i64-to-i32-lowering` as a normal public pass with the description:

- `lower all uses of i64s to use i32s instead`

The local repo makes the scheduler facts explicit in [`./starshine-strategy.md`](./starshine-strategy.md), with future implementation sequencing in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md):

- it remains boundary-only in `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt` has no module-pass dispatcher case for it
- `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md` still lists it among whole-module transforms
- it is absent from `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the upstream implementation itself requires flat input through `Flat::verifyFlatness(func)`

So the scheduler truth is:

- real public pass: yes
- current local active pass: no
- default no-DWARF `-O` / `-Os` pass: no
- whole-module transform: yes
- practical prerequisite on `flatten`: yes

## Implementation shape

The pass class is:

- `I64ToI32Lowering : WalkerPass<PostWalker<I64ToI32Lowering>>`

Important consequences:

- it is a normal post-order Binaryen tree walker
- it marks `addsEffects() = true`
- it is explicitly **not function-parallel**
- it rewrites both module-level declarations and function bodies

The non-parallel choice matters.
The comment says function types need to be lowered, so this is not just a body-local transform.

## Core algorithmic phases

## Phase 1: rewrite module globals and add the return side channel

`doWalkModule(Module* module)` performs the first important reshaping step.

For every existing global:

- if its type is not `i64`, the pass leaves it alone
- if its type is `i64`, the pass:
  - records the name in `originallyI64Globals`
  - changes the original global type to `i32`
  - creates a sibling global named `<name>$hi`
  - splits constant initializers into low/high `i32` pieces
  - mirrors `global.get` initializers through the sibling high-half global

After that, it creates one synthetic mutable global:

- `INT64_TO_32_HIGH_BITS`

That global is used to return the high half of a formerly-`i64` function result.

### Important boundary: imported i64 globals

The code still aborts on imported `i64` globals with:

- `Fatal() << "TODO: imported i64 globals"`

So a future Starshine port must not silently claim wider support than `version_129` actually provides.

## Phase 2: rebuild each function's locals and params

`doWalkFunction(Function* func)` begins with:

- `Flat::verifyFlatness(func)`

Then it:

- copies the old function into a temporary module with `ModuleUtils::copyFunction`
- clears the real function's params, vars, and local-name maps
- calls `Names::ensureNames(oldFunc)` so unnamed locals become nameable
- rebuilds the local list from scratch

For each old local or param:

- if the type is not `i64`, it gets one rebuilt slot
- if the type is `i64`, it gets:
  - a low slot with the old name
  - a high slot named `<old-name>$hi`
- `indexMap[oldIndex]` stores the new low-slot index

This yields a strong structural invariant used later everywhere else:

- for every original `i64` local, the high half lives at `mappedIndex + 1`

## Phase 3: rewrite the function result type and attach extra temp locals

`visitFunction(Function* func)` performs the final function-header cleanup.

If the function result type was `i64`, the pass:

- rewrites the function result to `i32`
- if the body still has an out-param high half, stores that high half to `INT64_TO_32_HIGH_BITS`
- returns only the low half directly

It also appends all temp locals accumulated during lowering, naming them as:

- `i64toi32_i32$0`
- `i64toi32_i32$1`
- ...

That temp-local naming is visible in the official lit output and is part of the real emitted shape, not just debug scaffolding.

## The hidden high-half side channel

The central mechanism in this pass is the pair:

- `setOutParam(Expression* e, TempVar&& var)`
- `fetchOutParam(Expression* e)`

The pass stores, for certain expressions, a temp local that contains the corresponding high half.

That gives the pass a two-channel value model:

- visible AST result = low `i32`
- hidden metadata = temp local containing high `i32`

This is why so many rewrites look odd at first glance.
The pass often leaves the expression itself as a normal `i32` node and separately records where the high half can be fetched later.

## Call-boundary lowering

## Generic call fixup

`visitGenericCall(...)` handles the common call ABI rewrite.

For each operand:

- the visible operand is pushed first
- if it carries an out param, the pass fetches the high-half temp and pushes that too

For the result:

- non-`i64` results are rebuilt directly
- `i64` results become:
  - a visible `i32` call result stored in a low temp
  - a `global.get INT64_TO_32_HIGH_BITS` stored in a high temp

That block is then recorded as carrying the high-half out param.

## Direct calls and imported calls

`visitCall(Call* curr)` adds one extra rule:

- if the fixed call targets an import, rewrite the target name to `legalfunc$<target>`

The code comment says this assumes `legalize-js-interface` already ran.

### Important boundary: i64 `return_call`

Direct `return_call` with an `i64` result still throws a fatal error.
So this pass is not a complete tail-call legalization layer.

## Indirect calls and funcref types

`visitCallIndirect` and `visitRefFunc` both rewrite signatures.

For signatures:

- each `i64` param becomes two `i32` params
- `i64` results become a single `i32` result, with the high half still using the global side channel

So this pass changes not only call sites, but also heap-type-visible function signatures.

## Local and global traffic

## `local.get`

For a rewritten `i64` local get:

- the node's index is remapped through `indexMap`
- the visible node becomes `i32`
- a temp is filled from `mappedIndex + 1`
- that temp becomes the out param

## `local.set` and `local.tee`

For a lowered value:

- the low half stays in the visible store
- the high half is written to the immediately-following high slot
- `tee` uses an extra temp so the low result value still flows onward while the high-half side effect also happens

## `global.get` and `global.set`

The same pattern is used for globals previously recorded in `originallyI64Globals`:

- visible low-half access remains on the original global name
- hidden high-half access uses `<name>$hi`

## Memory traffic

## Loads

`visitLoad` lowers only loads whose result type is `i64`.

It first saves the pointer in a temp so address evaluation happens once.
Then it changes the visible load to an `i32` low-half load.
The high half is computed as follows:

- if `bytes == 8`:
  - load another `i32` from `offset + 4`
- else if the original load was signed:
  - synthesize the high half by arithmetic-shifting the low half right by `31`
- else:
  - synthesize a zero high half

It also clamps:

- `bytes` to `4`
- `align` to `4`

### Important load boundary

The code asserts that atomic `i64` loads are not handled here.
So plain split-load lowering is only for non-atomic memory traffic.

## Stores

`visitStore` only runs the extra lowering when the stored value carries an out-param high half.

The visible store becomes an `i32` low-half store.
If the original width was 8 bytes, the pass also emits a second `i32.store` for the high half at `offset + 4`.
Pointer evaluation is again single-shot via a temp.

### Important store boundary

Atomic stores are explicitly asserted unsupported here too.

## Special helper-based lowering families

## Atomic helper calls

When an atomic RMW still returns an `i64`, the pass does **not** split it into ordinary wasm ops.
Instead it calls wasm2js helper imports such as:

- `ATOMIC_RMW_I64`
- `GET_STASHED_BITS`

Likewise, `AtomicWait` lowers its timeout argument through:

- `ATOMIC_WAIT_I32`

This is a crucial teaching boundary.
Some 64-bit semantics are preserved through helper calls, not pure pairwise wasm code.

### Important atomic boundaries

- `AtomicCmpxchg` on `i64` is still explicitly unsupported
- direct split lowering is only for non-atomic load/store paths

## Reinterpret helper calls

`lowerReinterpretFloat64` and `lowerReinterpretInt64` use wasm2js scratch-memory helpers:

- `SCRATCH_STORE_F64`
- `SCRATCH_LOAD_I32`
- `SCRATCH_STORE_I32`
- `SCRATCH_LOAD_F64`

The pass also calls:

- `MemoryUtils::ensureExists(getModule())`
- `ABI::wasm2js::ensureHelpers(getModule())`

So the reinterpret story is not “just bitcast two halves.”
The official strategy uses scratch-memory runtime support.

## Unary lowering strategy

Important unary families handled directly include:

- `eqz`
- sign and zero extension from `i32`
- sign-extension variants from smaller widths
- `wrap`
- reinterpret in both directions
- float->int64 truncation
- int64->float conversion
- `clz`

Some highlights:

- `eqz` becomes `i32.eqz(low | high)`
- `wrap` simply drops the high half
- sign extension computes the new high half from the sign bit of the low half
- float/int conversions use explicit arithmetic expressions instead of one large runtime helper

## Binary lowering strategy

Implemented binary families include:

- add with carry
- subtract with borrow
- bitwise and/or/xor
- shifts with distinct `< 32` and `>= 32` code paths
- equality and inequality
- signed and unsigned comparisons

These use classic two-limb algorithms.
The visible result is generally the low half, while the high half is stored in another temp and attached via `setOutParam(...)`.

## What the pass expects to have been removed already

Several `i64` families are still marked unreachable in the lowering file itself:

- `mul`
- signed and unsigned `div`
- signed and unsigned `rem`
- rotates
- `popcnt`
- `ctz`

So the real upstream contract is **not** “lower every remaining i64 op from arbitrary wasm.”
It is “lower the i64 surface that remains after earlier cleanup or legalization has already simplified some harder families.”

## `select`, `drop`, and `return`

## `select`

If both arms carry high halves, the pass:

- evaluates the condition once into a temp
- performs one `select` for low halves
- performs one `select` for high halves
- returns the low-half select visibly and stores the high-half select as the out param

## `drop`

If a dropped value has a high-half out param, the pass fetches it and discards it so temp-lifetime bookkeeping remains correct.

## `return`

When returning a lowered `i64` value, the pass:

- stores the visible low half in a temp
- stores the high half to `INT64_TO_32_HIGH_BITS`
- returns only the low half directly

This is the clearest visible ABI rewrite in the entire pass.

## Unreachable fallback logic

`handleUnreachable(...)` exists because some unreachable nodes can have mismatched low/high lowering state in dead code.

It only applies when:

- the current node's type is `unreachable`
- its children are unconditionally executed before the node itself

The code comment explicitly warns that this is **not valid for `if`**.
So even the fallback cleanup is structural and conservative.

## Important interactions with other passes and helpers

For the compact per-family support ledger that goes with this page, see [`./abi-surface-and-opcode-coverage.md`](./abi-surface-and-opcode-coverage.md).

The strongest neighbors and dependencies are:

- `flatten`
  - this is a real structural prerequisite, enforced by `Flat::verifyFlatness`
- `legalize-js-interface`
  - imported direct-call retargeting assumes it already ran
- earlier `i64` simplification/lowering work
  - several harder i64 unary/binary families are assumed gone already
- wasm2js helper machinery in `abi/js.h`
  - reinterpret and some atomic families depend on helper imports

So this pass should be taught as sitting in a **legalization pipeline**, not as a standalone optimizer.

## Current-main drift

A direct source comparison between `version_129` and current `main` found only one material diff on the pass file:

- a comment typo fix from `instrinsic` to `intrinsic`

So the `version_129` summary in this folder is still effectively current.

## Porting checklist

A future Starshine port must preserve at least these facts; the concrete first-slice and validation order now lives in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md):

1. flat-input precondition
2. low-half visible / high-half hidden value model
3. adjacent low/high local-slot policy
4. synthetic return-high global policy
5. single-evaluation temp insertion for duplicated uses
6. helper-call lowering for scratch reinterpret and some atomic families
7. explicit unsupported boundaries like imported `i64` globals and `return_call` `i64` results
8. honest scheduler dependence on earlier i64 cleanup

## Most common misconceptions to prevent

- This is not a normal hot pass.
- This is not in the default no-DWARF optimize path.
- This is not just about memory ops.
- This is not only function-local; it rewrites globals and signatures too.
- This is not a full arbitrary-i64 legalizer by itself.
- This is not a multivalue return lowering pass; it uses a synthetic global side channel.
