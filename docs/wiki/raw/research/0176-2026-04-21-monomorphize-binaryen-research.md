# 0176 - Binaryen `monomorphize` research

Date: 2026-04-21
Status: completed research ingest
Pass: `monomorphize`
Local registry status: `boundary-only` in `src/passes/optimize.mbt`
Related public sibling: `monomorphize-always`

## Why this pass was chosen

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered in the living tracker.
The prompt also excluded nearly all of the recently dossiered fallback candidates.
That left two honest options:

1. justify a major-gap fallback inside an already-deep folder, or
2. widen the tracker again with another real upstream pass that is already named in the local registry and still lacks dedicated docs.

I chose option 2.

`monomorphize` is a strong candidate because:

- it is a real public Binaryen pass on `version_129`
- it is already named in the local boundary-only registry in `src/passes/optimize.mbt`
- it sits near already-documented neighbors like `inlining`, `inline-main`, and the GC/type passes, but solves a meaningfully different problem
- it has a substantial official implementation file plus a broad dedicated lit-test surface
- it is easy to misunderstand as “just inlining with constants,” which is false

`agent-todo.md` currently has **no dedicated `monomorphize` slice**.

## Primary official sources reviewed

### Core implementation and registration

- Binaryen `version_129` `src/passes/Monomorphize.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- relevant helper headers included by the pass:
  - `src/ir/cost.h`
  - `src/ir/effects.h`
  - `src/ir/find_all.h`
  - `src/ir/manipulation.h`
  - `src/ir/module-utils.h`
  - `src/ir/names.h`
  - `src/ir/properties.h`
  - `src/ir/return-utils.h`
  - `src/ir/type-updating.h`
  - `src/ir/utils.h`
  - `src/wasm-limits.h`

### Official lit tests reviewed or indexed

- `test/lit/passes/monomorphize-benefit.wast`
- `test/lit/passes/monomorphize-consts.wast`
- `test/lit/passes/monomorphize-context.wast`
- `test/lit/passes/monomorphize-drop.wast`
- `test/lit/passes/monomorphize-limits.wast`
- `test/lit/passes/monomorphize-mvp.wast`
- `test/lit/passes/monomorphize-types.wast`
- `test/lit/passes/no-inline-monomorphize-inlining.wast`

## High-level conclusion

Binaryen `monomorphize` is a **whole-module contextual specialization pass**.

It scans direct calls, computes a **callsite context**, clones the callee into a fresh specialized function, runs a nested optimization pipeline on both the old and new bodies, and then keeps the specialized copy only if the measured cost improvement is large enough.

That means the real mental model is:

- not classic template-style monomorphization by static type only
- not exact duplicate merging
- not inlining the callee into the caller
- but also not a tiny peephole pass

Instead it is best described as:

- **empirical callsite-driven specialization**
- with **reverse-inlined call-context code** moved from caller to callee
- and a **measured profitability gate** based on nested optimization results

## The most important source-backed takeaways

1. The pass only handles **direct `call`** nodes in `version_129`.
2. Imported targets are ignored.
3. Recursive self-calls are ignored.
4. Unreachable calls are ignored.
5. Calls whose targets perform `return_call*` are treated specially: the pass refuses to pull an outer `drop` into those callees because removing returns could break tail-call stack behavior.
6. The context is not just “constants.” It can also encode:
   - more-refined reference types
   - GC allocations
   - dropped-call result context
   - and other movable expression fragments
7. The pass tries to move **as much operand code as possible** into the context, but only when effect ordering and movement rules allow it.
8. A context is rejected early if it is **trivial**, meaning it communicates no more information than the original signature already had.
9. The specialized function gets a **new signature**, often with fewer params and sometimes with `none` results if the original call was dropped.
10. Binaryen then runs nested function optimizations on both original and specialized versions to decide whether the specialization is worth keeping.
11. The default minimum benefit threshold in the reviewed source is `95%`, but the pass exposes `--pass-arg=monomorphize-min-benefit@N`.
12. The specialized function is rejected if it still has too many parameters; the reviewed hard cap is `MaxParams = 20`.
13. `monomorphize-always` is not a different algorithm. It is the same core specialization machinery with the “only keep it when helpful” gate disabled.

## Implementation structure

## 1. The pass is centered on three small data models

### `CallInfo`

Tracks:

- the direct `Call*`
- and an optional pointer to the enclosing `drop`

That `drop` pointer matters because successful specialization of a dropped call may replace `(drop (call ...))` with just `(call ...)` after the callee’s result type becomes `none`.

### `CallContext`

This is the real heart of the pass.
It stores:

- `operands`: transformed operand expressions that will appear in the specialized callee’s prelude
- `dropped`: whether the original call result was dropped

Each operand is either:

- copied inward into the new callee, or
- replaced by a `local.get` placeholder, meaning that part still arrives as a normal parameter to the specialized function

So the context is not just metadata; it is actual executable IR.

### `funcContextMap`

Memoizes `(target function name, call context) -> chosen target name`.

Important subtlety:

- it can memoize a failure by mapping the pair back to the original target
- so identical later calls skip recomputation even when specialization was not worthwhile

## 2. `CallFinder` finds the optimization opportunities

The pass walks each original defined function and collects direct calls.
For each call it records whether the immediate parent is a `drop`.

This is intentionally narrow:

- no indirect call surface
- no whole-CFG call graph rewrite
- no table patching

## 3. `CallContext::buildFromCall(...)` computes the specialization surface

This is the most important algorithm in the file.

Binaryen walks the call operands and tries to move as much code as possible from caller to callee.
That is why the pass comments describe it as **reverse-inlining**.

### What “moving into context” means

If the original code is roughly:

```wat
(call $foo
  (i32.const 10)
  (i32.add (local.get $x) (local.get $y)))
```

Binaryen wants the specialized callee to begin with something like:

```wat
(local.set $old_param0 (i32.const 10))
(local.set $old_param1 (local.get $new_param0))
```

So:

- fully movable code becomes part of the callee prelude
- nonmovable code stays in the caller and is replaced in the context by a new parameter read

### Why Binaryen uses reverse postorder effects analysis here

Moving code into the callee changes execution order.
Code that remains in the caller will execute before the call, while moved code now executes inside the callee.
So Binaryen must prove that every moved expression can legally cross over the nonmoved expressions after it.

The implementation therefore:

- collects operand subexpressions in postorder
- iterates in reverse
- accumulates the effects of nonmoving code
- rejects movement when a candidate invalidates or is invalidated by those effects

This is the safety proof that keeps the pass from reordering traps, state changes, or control flow incorrectly.

## 4. `canBeMovedIntoContext(...)` defines the most important bailout matrix

The reviewed source rejects movement for expressions that:

- branch out or have external break targets
- access locals
- call other functions
- are control-flow structures
- contain tuple-typed children in ways that would force tuple params

This is a major teaching correction.
The pass is **not** “move any constant-looking tree into the callee.”
It is deliberately conservative.

## 5. `isTrivial(...)` avoids useless work

A context is trivial when:

- the call is not dropped, and
- every operand is just a same-typed `local.get` passthrough

That means the callsite offers no new optimization information.
Such cases are memoized as failures immediately.

## 6. `makeMonoFunctionWithContext(...)` performs the actual specialization

This routine:

1. creates a fresh valid function name
2. copies the original function with `ModuleUtils::copyFunctionWithoutAdd(...)`
3. scans the context operands for all surviving `local.get`s to build the new parameter list
4. changes the result type to `none` if the call was dropped
5. remaps all locals because params may disappear or shift
6. preserves local names where possible for debuggability
7. emits the prelude `local.set`s that materialize the reverse-inlined context
8. rewrites local indices in the copied body
9. removes `return`s if the result was reverse-inlined as a drop

This is a strong whole-function rewrite, not a tiny callsite substitution.

## 7. `processCall(...)` is where profitability is decided

If the pass is running in normal `monomorphize` mode, it:

- optimizes the original callee
- estimates cost before specialization as:
  - optimized old callee body
  - plus the context operands still living at the callsite
- optimizes the specialized callee
- computes a percentage benefit
- keeps the specialization only if benefit exceeds `MinPercentBenefit`

The reviewed implementation defaults `MinPercentBenefit` to `95`.

That explains the official lit split between:

- `monomorphize-always`
- `monomorphize --pass-arg=monomorphize-min-benefit@0`
- and more demanding thresholds like `33`, `66`, and `100`

## Helper dependencies that matter

### `CostAnalyzer`

This is the profitability oracle used after nested optimization.
A future port must preserve the idea that the pass is **empirical**:

- specialize first
- optimize both sides
- measure cost difference
- then decide

Without that, the port becomes a completely different heuristic pass.

### `ReturnUtils::findReturnCallers(...)` and `removeReturns(...)`

These helpers define a subtle safety boundary.
Dropped-call specialization can turn a returning callee into a `none`-result specialized version, but not when doing so would illegally destroy tail-call structure.

### `ExpressionManipulator::{copy, flexibleCopy}`

These do the real IR cloning work for the context and cloned body.
A port must preserve structural copying plus selective subtree replacement.

### `ModuleUtils::copyFunctionWithoutAdd(...)`

This supplies the cloned starting point for the specialized function before local-remap and prelude insertion.

### `Names::{getValidFunctionName, getValidLocalName}`

Fresh naming is not the semantic core, but it is part of the practical whole-function rewrite contract and test surface.

## Official test surface distilled

### `monomorphize-benefit.wast`

This is the best proof that the pass is **empirical and threshold-driven**.
It varies `monomorphize-min-benefit` and shows that different callsites are accepted at `0`, `33`, `66`, and `100` depending on how much optimized code disappears.
It also uses `-tnh` to make some deeper optimizations easier to expose.

### `monomorphize-context.wast`

This shows the real breadth of movable-versus-immovable context fragments.
It includes complex operand shapes, globals, memory, branches, calls, locals, and reference values, proving the pass is about general callsite context, not only constants.

### `monomorphize-drop.wast`

This proves the dropped-call path is real.
Binaryen can reverse-inline the outer `drop` into the specialized callee, then erase unnecessary result plumbing.

### `monomorphize-limits.wast`

This proves the parameter-count limit is not just theory.
Calls with many constant operands can still specialize because constants disappear from the signature, while too many surviving dynamic values keep the original call.

### `monomorphize-mvp.wast`

This proves the pass is still meaningful in non-GC MVP mode, mainly through constant-driven specialization.
So GC is helpful, but not required for the pass to exist.

### `monomorphize-types.wast`

This proves a second major positive family: more-refined reference types from callsites.
It also proves that `always` mode can force specializations that careful mode rejects as unhelpful.

### `no-inline-monomorphize-inlining.wast`

This proves the pass’s relation to inlining and inline-control metadata.
It is useful evidence that monomorphization and inlining are neighbors, but not identical.

## Important WAT / IR shape families

## Positive shapes

- direct calls with constant operands
- direct calls with more-refined reference operands
- direct calls whose operand contains a movable GC allocation
- direct calls whose result is immediately dropped
- calls where specialization removes enough code after nested `-O3` function optimization

## Negative / bailout shapes

- imported callees
- recursive self-calls
- unreachable calls
- targets that are return-callers when the only extra context is the outer drop
- operands whose moved portion would cross effectful nonmoved code unsafely
- operands that access locals directly
- operands containing calls or control-flow structures
- tuple-child cases that would force tuple params
- trivial passthrough contexts
- specialized functions still exceeding `MaxParams`
- specializations that fail the measured benefit threshold

## Pass interactions

### With inlining

The pass comments explicitly frame monomorphization as related to inlining.
But the direction is reversed:

- inlining moves callee code into caller
- monomorphization moves selected caller context into a cloned callee

They can unlock some of the same optimizer wins, but via opposite motion.

### With nested function optimization

This pass depends on nested optimization to judge usefulness.
The reviewed file currently runs `optimizeLevel = 3` function passes and explicitly mentions needing `precompute-propagate` and friends.
So the nested optimizer is part of the real contract, not optional cleanup.

### With return-call handling

Tail-call structure is a correctness boundary, not just a missed optimization.
That is one of the easiest details to miss.

### With GC passes

WasmGC makes the pass much stronger because moving allocations or refined refs into the callee can expose large optimizations there.
But the pass is still useful in MVP constant cases.

## What is easy to misunderstand

1. **It is not type-only monomorphization.**
   The real driver is full callsite context, not only static type differences.
2. **It is not just constants.**
   Constants are the simplest case, but dropped-call context and movable GC constructions matter too.
3. **It is not ordinary inlining.**
   It clones the callee instead of splicing the callee into the caller.
4. **It is not purely heuristic.**
   The source tries the transformation and then measures optimized cost.
5. **`monomorphize-always` is not the default pass.**
   It is the same machinery without the “only when helpful” gate and exists mainly to simplify testing and debugging.
6. **The movement proof is conservative and explicit.**
   A future port must not silently widen it without equivalent effect-order reasoning.

## Porting invariants for Starshine

A future Starshine port must preserve at least these behaviors:

1. whole-module iteration over original defined functions only, not newly added specializations
2. direct-call-only scope unless a later design explicitly widens it
3. imported-target and self-recursion bailouts
4. return-call / outer-drop safety boundary
5. context building based on effect-safe code motion, not just operand-pattern matching
6. trivial-context early exit
7. specialized-signature rebuilding from surviving dynamic values
8. dropped-call result elimination to `none`
9. full local-index remap after param-count changes
10. empirical profitability based on nested optimization and cost comparison
11. hard parameter-count ceiling for specialized functions
12. memoization of both wins and failures per `(target, context)`

## Open questions or follow-up ideas

These are **from source TODOs or source-backed inference**, not current facts:

- the upstream file mentions possible future flags for max function size, max optimized size, and max absolute size increase
- it also mentions possible multi-cycle or root-to-leaf scheduling for stronger chained specialization
- indirect-call support is explicitly left out because table / vtable updating is complex
- a future Starshine design might want to reuse existing local equivalence reasoning when only some subtrees stay dynamic

## Deliverables created from this note

This research is filed back into the living wiki as:

- `docs/wiki/binaryen/passes/monomorphize/index.md`
- `docs/wiki/binaryen/passes/monomorphize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/monomorphize/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/monomorphize/call-context-benefit-and-boundaries.md`
- `docs/wiki/binaryen/passes/monomorphize/wat-shapes.md`

It also requires tracker and index updates so `monomorphize` is now a first-class documented upstream-only registry pass.

## Sources

- Local registry:
  - `src/passes/optimize.mbt`
- Repo scheduler orientation:
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
- Official Binaryen `version_129`:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-consts.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-mvp.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
