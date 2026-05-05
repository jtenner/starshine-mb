---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/research/0468-2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-precompute-primary-sources.md
  - ../../../raw/research/0132-2026-04-20-precompute-binaryen-research.md
  - ../../../raw/research/0229-2026-04-21-precompute-implementation-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./propagation-partial-precompute-and-gc-identity.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `precompute` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass family.
For the immutable manifest of the reviewed official release, source, and representative test URLs, see [`../../../raw/binaryen/2026-04-22-precompute-primary-sources.md`](../../../raw/binaryen/2026-04-22-precompute-primary-sources.md).
A 2026-05-05 current-main recheck in [`../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md) found no teaching-relevant drift on the reviewed owner, scheduler, and representative test surfaces.

Primary files:

- `src/passes/Precompute.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`

Most important helper dependencies:

- `src/wasm-interpreter.h`
- `src/ir/local-graph.h`
- `src/ir/properties.h`
- `src/ir/iteration.h`
- `src/ir/manipulation.h`
- `src/ir/literal-utils.h`
- `src/ir/utils.h`

For the compact owner/test attribution map, see [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

The shipped lit tests are also part of the contract here, especially:

- `precompute-effects.wast`
- `precompute-partial.wast`
- `precompute-propagate-partial.wast`
- `precompute_all-features.wast`
- `precompute-gc.wast`
- `precompute-gc-immutable.wast`
- `precompute-gc-atomics.wast`
- `precompute-gc-atomics-rmw.wast`
- `precompute-strings.wast`
- `precompute-ref-func.wast`
- `precompute-relaxed.wast`
- `precompute-stack-switching.wast`

## High-level intent

Binaryen uses the precompute family to **execute some code at compile time** when doing so is safe and useful.

That sounds like ordinary constant folding, but the real implementation is broader.

It combines:

- a bounded interpreter for expressions and transferred control flow
- optional retention of local/global writes that must survive replacement
- a separate higher-level partial-precompute algorithm for `select`
- an optional local-flow propagation phase
- GC identity tracking and emitability checks for references
- final type repair

A good short description is:

- **speculatively execute, then replace only if both semantics and re-emission stay honest**

## The pass family in one table

| Piece | What Binaryen does | Why it exists |
| --- | --- | --- |
| Public mode split | `precompute` vs `precompute-propagate` | Top-level `-O` / `-Os` and aggressive/nested flows do not use the exact same pass behavior |
| Interpreter layer | Evaluate expressions to `Flow` results | Learn constants, breaks, returns, and nonconstant failure in a semantic way |
| Main post-walk | Visit candidate expressions bottom-up | Child results are known before parent replacement |
| Child retention | Keep local/global-writing children when replacement would otherwise erase needed writes | Preserve semantics when the interpreter walked through side-effectful sets |
| Block-specific bailout | Refuse quadratic “tower of blocks” retry work | Keep performance sane on switch-like nested block shapes |
| Partial precompute | Push parent computation into `select` arms | Reduce some parents even when the original whole expression was not directly constant |
| Propagation phase | Use `LazyLocalGraph` to discover constant gets/sets and rerun once | Extend beyond purely local syntax under one node |
| Refinalization | Repair types after rewrites | Control and local/type facts can change after replacement |

## Public names really mean different things

`pass.cpp` registers:

- `precompute`
- `precompute-propagate`

The difference is not just naming.

### Plain `precompute`

- run the main compile-time execution walk
- run partial precompute when enabled by optimize level
- stop there

### `precompute-propagate`

- do all of the above
- then compute constant local propagation facts with `LazyLocalGraph`
- then rerun the main walk once if anything propagated

That distinction matters in the scheduler.

In `version_129`:

- top-level no-DWARF `-O` / `-Os` uses plain `precompute`
- top-level more aggressive settings and nested `optimizeAfterInlining(...)` cleanup use `precompute-propagate`

## Phase 1: `PrecomputingExpressionRunner` is the heart of the pass

The main helper class subclasses `ConstantExpressionRunner` from `wasm-interpreter.h`.

That means the pass is built on a semantic interpreter model, not a bag of syntax-only patterns.

Important runner state:

- `getValues`
  - concrete values discovered later by propagation for specific `local.get`s
- `heapValues`
  - a cache of GC allocations and their canonical `GCData` identities
- `MAX_DEPTH = 50`
- `MAX_LOOP_ITERATIONS = 1`

Those limits are part of the pass contract, not arbitrary tuning.

### Why the depth and loop limits exist

The source comments give two reasons for the depth cap:

- very large expressions are unlikely to be the best single precompute target all at once
- low depth avoids platform stack-budget differences during compile-time execution

The loop-iteration limit is even more semantic.

Binaryen only wants to replace a loop if doing so preserves the same visible behavior. If more than one iteration would be required before the result becomes concrete, the pass is unlikely to have enough information to compress that safely.

So the pass is willing to interpret loops, but only extremely conservatively.

## Phase 2: GC identity is tracked explicitly

One of the easiest things to miss in `Precompute.cpp` is that the pass does not just cache “heap contents.”
It caches **heap identities**.

`HeapValues` maps a source allocation expression such as:

- `struct.new`
- `array.new`
- `array.new_fixed`

onto a canonical `GCData` object.

That exists so later evaluation can preserve the distinction between:

- the same allocation seen again
- two different allocations with the same field contents

Why this is necessary:

- `ref.eq` depends on identity, not structural equality
- propagation may reevaluate the same set expression more than once
- loops and merges can make a source expression correspond to different runtime allocations on different executions

The pass handles this conservatively:

- if a merge makes multiple incoming identities possible, it stops inferring one concrete value
- if a cached allocation had effects, it reevaluates those effects before reusing the cached identity, and gives up if the reevaluation is no longer constant

That is why the pass can reason about some GC equality and immutable-field cases safely without pretending that arbitrary mutable heap data is constant.

## Phase 3: the main post-walk uses the interpreter speculatively

The pass shell is:

- `WalkerPass<PostWalker<Precompute, UnifiedExpressionVisitor<Precompute>>>`
- function-parallel

The top-level per-function flow is:

1. enable partial precompute only when `optimizeLevel >= 2`
2. run the main post-walk once
3. run the partial-precompute phase
4. if in propagate mode, run local propagation and rerun the main post-walk once if propagation succeeded
5. refinalize the function in `visitFunction()`

## Phase 4: `visitExpression()` does the real replacement work

`visitExpression()` deliberately skips several kinds of nodes up front:

- already-constant expressions
- `nop`
- `local.set`
- `global.set`
- `return`
- `loop`
- unconditional `br`

Those are either trivial or awkward to improve directly.

Then the pass runs `PrecomputingExpressionRunner` with `replaceExpression = false`.

That detail matters.

It means the interpreter is allowed to walk through local/global writes in order to understand the result value, but the pass is **not** yet committing to erase those writes.

### What happens after a successful speculative run

If the interpreter succeeds, the pass still checks several things before replacing the node:

- can the resulting `Literals` be emitted back into Binaryen IR as constants?
- did the flow end in `NONCONSTANT_FLOW` anyway?
- did the flow suspend?
- did the speculative evaluation record local/global writes that must be preserved?

If replacement is allowed, Binaryen builds either:

- a constant expression
- a `br`
- a `return`
- or `nop` if nothing remains

### Child retention is where the pass becomes nontrivial

If the interpreter walked through `local.set` or `global.set`, replacement must preserve those writes when they matter.

Binaryen uses `EffectAnalyzer` to keep children that write locals or globals.

The retained children are rebuilt as dropped expressions, then:

- if there is still a resulting value, it is appended
- otherwise the whole replacement may become just a block of dropped retained children

That makes the real rewrite shape closer to:

```wat
(foo A B)
```

becoming:

```wat
(block
  (drop A)
  (drop B)
  (const ...))
```

not:

```wat
(const ...)
```

when `A` and `B` contained relevant writes.

### But child retention has deliberate bailouts

Binaryen gives up rather than guessing when:

- the current expression is `block`, `if`, or `try`
  - because some children may not execute, and the pass does not track enough path sensitivity here
- the computed result is a break/return flow and preserving child order would become tricky

This is a very important lesson for a port:

- the pass is not “if interpreter succeeded, replace unconditionally”
- the pass is “if interpreter succeeded *and* replacement plus write preservation remains simple and honest, then replace”

## Phase 5: `visitBlock()` has a performance-specific bailout

`visitBlock()` mostly delegates to `visitExpression()`, but with one special guard.

If the first child of a block is itself still a block, Binaryen treats that as a likely “tower of blocks” pattern, which often comes from switch lowering.

Trying to fail precompute on each parent block in such a tower can become quadratic.
So Binaryen just bails early.

Important nuance:

- this is a performance optimization, not a semantic claim that outer blocks can never simplify
- if an inner block *did* simplify first, the outer one may still simplify later

## Phase 6: partial precompute is a separate upward-moving algorithm

When a whole expression cannot be directly replaced, the pass sometimes still has profitable work.

The dedicated partial-precompute phase looks for `select`s whose arms are promising enough and then walks **upward** through parents.

The source's key idea is:

- even if `Parent(select(...))` is not directly constant,
- `Parent(leftArm)` and `Parent(rightArm)` might each be constant,
- and that lets us rebuild a better `select`.

This can repeat through several parents, not just one.

### The positive target family

The phase only considers `select`s when:

- partial precompute is enabled (`optimizeLevel >= 2`)
- both arms satisfy `Properties::isValidConstantExpression(...)`
- the select is not the whole function body

Then `ExpressionStackWalker` is used to capture the full parent stack.

For each stack, Binaryen climbs outward and stops when a parent is:

- already modified by a previous successful partial-precompute rewrite
- non-concrete or tuple-typed
- a control-flow structure

Otherwise it speculatively substitutes the left arm and then the right arm into the parent, precomputes both variants, and if both become concrete constant results, rebuilds the select with those constant arms.

### Why Binaryen sometimes retries with more parents at once

The source comments explain an important GC case:

- one inner `struct.get` might land on an interior pointer that cannot be re-emitted
- but two nested `struct.get`s together may land on a scalar field or a global-rooted outer object result that *can* be simplified

So the algorithm keeps retrying with larger parent slices instead of assuming purely incremental success.

## Phase 7: partial-precompute uses a temporary heap cache on purpose

Speculative upward precompute could be incorrect if it polluted the pass's main heap identity cache.

The source explicitly uses a temporary `HeapValues` cache for those attempts.

Why:

- a speculative arm might avoid a trap or follow a different path
- caching its heap result globally could make later normal evaluation think some trapping or effectful shape was safe and removable

This is one of the most subtle correctness rules in the file.
A port must preserve it.

## Phase 8: the propagate variant is a real dataflow pass

If `propagate` is enabled, the pass does not merely rewrite some already-proven `local.get`s.
It runs a lazy local-flow analysis over the function.

The central helper is `LazyLocalGraph`, which can answer:

- which sets can reach a given get
- which gets are influenced by a set
- which sets are influenced by a get

### How `propagateLocals()` works

The implementation builds a worklist over two kinds of newly proven facts:

- constant `local.set` values
- constant `local.get` values

#### Step 1: discover constant sets

For each `local.set`, Binaryen tries to precompute the **fallthrough value** of the set expression using `Properties::getFallthrough(...)`.

That lets the pass look through wrappers like:

- tees
- certain simple flow-through shells

But it does not blindly trust that fallthrough value.

If the resulting constant's type is not a valid subtype of the full set expression's type, propagation is rejected. This matters in reference-typed cases such as casts, where the child value may look more concrete than the surrounding expression can actually guarantee.

#### Step 2: discover constant gets

A `local.get` only becomes constant if **all** reaching sets agree on the same concrete value.

Important special cases:

- params are never considered constant here
- a missing set for a local var means the default function-entry value
- for nondefaultable locals, that “missing set” story becomes a conservative bailout instead of assuming a zero-like value
- unreachable code may make `LocalGraph` slightly imprecise, and the pass simply declines to optimize those tricky cases further

#### Step 3: propagate through influence edges

Once a get or set is newly proven constant, Binaryen uses the influence graph to see whether:

- gets influenced by that set now become constant
- sets influenced by that get now become constant

This continues until the small worklist drains.

#### Step 4: rerun the main walk once

If anything propagated, Binaryen reruns the ordinary main post-walk once.

That second walk is important because it can exploit the newly learned `getValues` facts and unlock ordinary precompute opportunities that the first walk could not see.

The pass intentionally stops after that one extra rerun.
It does **not** rebuild `LazyLocalGraph` repeatedly for a deeper fixed point. The source comments say such rarer extra opportunities are left for later pass executions or for `--converge`.

## Phase 9: emitability is an explicit boundary

`canEmitConstantFor(...)` is a major semantic gate.

The pass only replaces an expression when the result can be emitted back into Binaryen IR.

In `version_129`:

- numeric literals: yes
- null refs: yes
- function refs: yes
- strings: yes, but only if the literal encodes valid UTF-16 for `string.const`
- all other refs: no

That explains a lot of surprising behavior.

The pass may know that some GC or nested-immutable expression is concrete, but still refuse to replace it because the result cannot be spelled as a legal constant expression.

This is especially important for beginners because it explains why some apparently “obvious” immutable-GC simplifications do not happen directly.

## Phase 10: refinalization is part of the contract

After all expression work, `visitFunction()` runs `ReFinalize`.

That is required because precompute can alter:

- block result structure
- break/return shapes
- local typing assumptions in unreachable regions
- reference nullability or other repaired types after control-flow simplification

The tests explicitly cover cases where removing a set or collapsing control flow would otherwise leave invalid local typing in unreachable code.

So the pass contract is not complete without this final repair step.

## Scheduler placement explains the intended use

## Early top-level slot

In the default function pipeline, the early precompute-family slot comes after:

- `optimize-instructions`
- `heap-store-optimization`
- `pick-load-signs`

and before:

- `code-pushing`
- `tuple-optimization`
- simplify-locals cleanup

That placement means early precompute is supposed to:

- exploit exact scalar/control shapes exposed by earlier canonicalizers
- simplify small result carriers before tuple/local cleanup
- reduce some expression trees before later local passes analyze them

## Late top-level slot

The late slot comes after:

- `merge-blocks`
- `remove-unused-brs`
- `remove-unused-names`
- `merge-blocks` again

and before:

- late `optimize-instructions`
- late `heap-store-optimization`
- `rse`
- final `vacuum`

That placement means late precompute is supposed to:

- exploit exact shapes exposed only after local and branch cleanup
- feed cleaner leftovers into the final redundancy-removal and garbage-pruning passes

## Nested optimizing reruns

`opt-utils.h` prepends `precompute-propagate` before rerunning default function passes after inlining.

So a future parity model must remember:

- the stronger propagation variant is part of the nested cleanup contract even when the top-level no-DWARF preset only uses plain `precompute`

## Bottom line

Binaryen `precompute` in `version_129` is a layered compile-time execution pass:

- interpret conservatively
- replace only when the result is concrete and re-emittable
- preserve needed writes where possible
- optionally push parents into select arms
- optionally propagate constants through locals
- refinalize at the end

The name sounds tiny.
The implementation is much broader and more semantic than that.
