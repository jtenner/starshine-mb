---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md
  - ../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./call-context-benefit-and-boundaries.md
  - ./clone-construction-signature-rebuild-and-dropped-call-rewrites.md
  - ./wat-shapes.md
---

# Binaryen strategy for `monomorphize`

## What the pass really is

The reviewed implementation is a **whole-module contextual specialization pass**.
It is not normal inlining and not just constant propagation.

The pass looks at a direct call, asks “what extra information does this callsite tell us about the callee?”, clones a specialized copy of the callee that bakes in that information, runs nested function optimization, and keeps the new copy only if that actually helped enough.

That means the best mental model is:

- **reverse-inline useful callsite context into a cloned callee**
- then **measure** whether the result was worth keeping

## Public surface and sibling variant

`src/passes/pass.cpp` registers two related passes:

- `monomorphize`
- `monomorphize-always`

The important split is:

- `monomorphize` = default usefulness-gated empirical pass
- `monomorphize-always` = same specialization machinery, but keep nontrivial cases even when the measured usefulness gate would reject them

So `monomorphize-always` is best understood as a **testing and debugging sibling**, not a separate algorithm.

## Default scheduler placement

A key negative fact is also important:

- the repo's current no-DWARF `-O` / `-Os` page does **not** schedule `monomorphize`
- the reviewed `pass.cpp` registration proves it is a real public pass, but not part of that default pathway

So this dossier is a justified tracker expansion for a real registry pass outside the current default parity queue.

## Core data structures

### `CallInfo`

Represents one callsite the pass may optimize.
It stores:

- the direct `Call*`
- a pointer to the enclosing `drop` location when the call result is immediately dropped

That `drop` pointer is what lets the pass transform `(drop (call ...))` into a plain specialized call when the cloned callee’s result becomes `none`.

### `CallContext`

This is the central abstraction.
It stores:

- `operands`: the transformed operand IR that will become the specialized callee’s prelude
- `dropped`: whether the original call’s result was dropped

The important teaching point is that these operands are **actual IR**, not a symbolic summary.
Some operand subtrees are copied inward into the new callee, while the remaining dynamic parts are represented as `local.get`s that become new function params.

### `funcContextMap`

Memoizes `(target function name, call context) -> chosen target name`.

This includes both:

- successes that map to a new specialized function, and
- failures that map back to the original function name

That second case matters: once Binaryen proves a context is not worth specializing, it does not recompute the same failure later.

## Main algorithmic phases

## Phase 1: scan direct calls in original defined functions

The pass first gathers the names of all currently defined functions.
That snapshot matters because successful specialization adds new functions to the module, and the pass intentionally does **not** recursively iterate over those newly added clones in the same run.

For each original function it then walks the body with `CallFinder` to collect direct calls plus immediate-drop information.

### Early hard bailouts

Before deeper work, `processCall(...)` rejects:

- unreachable calls
- recursive self-calls
- imported targets

It also weakens one potential optimization surface:

- if the target function is known to perform `return_call*`, Binaryen refuses to treat an enclosing outer `drop` as part of the context

That last rule is subtle but very important: removing returns from a tail-calling function can change stack behavior.

## Phase 2: build the call context

`CallContext::buildFromCall(...)` tries to move as much operand code as possible into the specialized callee.
The file explicitly calls this **reverse-inlining**.

### What gets moved

If the caller does:

```wat
(call $foo
  (i32.const 10)
  (i32.add (local.get $x) (local.get $y)))
```

then the specialized callee may start by assigning:

- a fully moved `i32.const 10` into the old first parameter’s replacement local
- and a still-dynamic value received through a new param for the second operand

So the specialized function prelude holds the call context.

### Why movement is hard

Moving caller code into the callee changes execution order.
Whatever remains in the caller now executes before the call, while the moved code executes inside the callee.
So Binaryen must prove that each moved subtree can legally cross over the nonmoved code after it.

### The safety proof Binaryen actually uses

The implementation:

1. collects operand subexpressions in postorder
2. walks that list in reverse
3. accumulates the effects of code that must stay in the caller
4. rejects movement when a candidate expression would invalidate or be invalidated by those nonmoving effects

This is why `effects.h` is a real dependency instead of incidental include noise.

## Phase 3: classify movable versus immovable expression families

`canBeMovedIntoContext(...)` contains the main movement-boundary matrix.
The reviewed source rejects movement for expressions that:

- branch out or have external break targets
- access locals
- call other functions
- are control-flow structures
- contain tuple-child situations that would force tuple params

This is one of the most important negative boundaries to teach.
A future port must not silently turn this into “move all pure-looking trees” without equivalent proof.

## Phase 4: trivial-context early exit

After building the context, Binaryen checks whether it is **trivial** relative to the call.

A trivial context means:

- the call result is not dropped, and
- every context operand is just a same-typed passthrough `local.get`

If so, there is no new information to exploit, so the failure is memoized immediately.

## Phase 5: clone a specialized function

`makeMonoFunctionWithContext(...)` performs the real function rewrite.

It:

1. creates a fresh valid function name
2. copies the original function with `ModuleUtils::copyFunctionWithoutAdd(...)`
3. rebuilds the signature from the context by scanning the transformed context operands for surviving `local.get`s
4. changes the result type to `none` when the call was dropped
5. turns old params into locals and shifts old vars by the param-count delta
6. preserves local names where possible
7. emits prelude `local.set`s that materialize the reverse-inlined context
8. rewrites local indexes in the cloned body
9. removes returns when the new specialized version is effect-only because the original result was dropped

For the exact source-confirmed mechanics here, including why signature rebuilding comes from the context IR itself and how caller-side `(drop (call ...))` is repaired afterwards, see:

- [`./clone-construction-signature-rebuild-and-dropped-call-rewrites.md`](./clone-construction-signature-rebuild-and-dropped-call-rewrites.md)

## Phase 6: enforce hard limits

After cloning, the pass rejects the specialized function if it still has too many parameters.

The reviewed source sets:

- `MaxParams = 20`

and asserts that this remains below the broader web limitation for function params.

This is a first-class bailout, not just a performance afterthought.

## Phase 7: empirical usefulness check

This is the core strategic idea of the pass.

In default `monomorphize` mode, Binaryen does not guess with a simple front-end heuristic.
Instead it:

1. optimizes the original callee
2. computes `costBefore` as:
   - optimized original callee body cost
   - plus the cost of the context operands still living at the callsite
3. optimizes the specialized clone
4. computes `costAfter` from the specialized body
5. derives a percentage benefit
6. keeps the specialization only if benefit exceeds `MinPercentBenefit`

The reviewed source defaults:

- `MinPercentBenefit = 95`

and also exposes:

- `--pass-arg=monomorphize-min-benefit@N`

So the official pass is not merely “specialize if context looks good.”
It is “specialize, optimize, measure, then decide.”

## Phase 8: rewrite the original callsite if specialization won

If the specialization is accepted:

- the call target is updated to the new specialized function
- the call operands are replaced by the reduced `newOperands`
- and, when the original call result was dropped, the enclosing `drop` is removed and the call type is rewritten to `none`

That is the exact visible WAT-level payoff.

## Nested optimizer interaction

`doOpts(...)` runs a nested function optimization pipeline with:

- `optimizeLevel = 3`
- default function optimization passes
- nested-pass mode enabled

The source comment explicitly calls out `precompute-propagate` as something it really wants in that nested optimizer.

So a port that omits the nested optimizer would not merely be a slower or weaker version; it would change the decision rule that defines the pass.

## Helper dependencies that matter

### `CostAnalyzer`

This is the profitability oracle.
It is why `monomorphize` is empirical instead of heuristic-only.

### `EffectAnalyzer` and `ShallowEffectAnalyzer`

These define the motion-safety proof for reverse-inlined context.

### `ReturnUtils`

These helpers define both:

- the return-caller safety check, and
- the dropped-result return-removal rewrite in accepted specializations

### `ExpressionManipulator`

This powers selective subtree copying into the call context and cloned callee.

### `ModuleUtils`

This provides the function clone and the defined-function iteration surfaces that keep the run bounded to original functions.

### `Names`

These keep the cloned function and remapped locals printable and valid.

## Clone-and-rewrite mechanics page

The strategy above is still the high-level flow.
For the source-confirmed details that are easiest to mis-port, see:

- [`./clone-construction-signature-rebuild-and-dropped-call-rewrites.md`](./clone-construction-signature-rebuild-and-dropped-call-rewrites.md)

That page isolates:

- signature rebuilding from surviving `LocalGet`s in transformed context operands
- old-param-to-new-local conversion
- old-var shifting by the param-count delta
- prelude `local.set` construction
- dropped-result `Type::none` plus `removeReturns(...)`
- caller-side `drop` replacement in `updateCall(...)`

## Beginner-facing summary of the real contract

If you want the shortest accurate rule, it is this:

- find a direct call with nontrivial callsite information
- prove what caller code can be moved safely into a cloned callee
- build that specialized callee and retype/remap it correctly
- optimize both versions
- keep the specialization only if it helps enough

That is the real Binaryen strategy for `monomorphize`.

## Sources

- [`../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md`](../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md)
- [`../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md`](../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md)
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
