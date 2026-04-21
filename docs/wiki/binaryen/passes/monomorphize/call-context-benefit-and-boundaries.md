---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# Call context, usefulness, and safety boundaries in `monomorphize`

This page focuses on the half of `monomorphize` that is easiest to misread:

- what Binaryen considers callsite **context**
- what it is willing to move into a cloned callee
- when it refuses to specialize even legal-looking cases

## 1. “Context” means executable operand IR, not just metadata

The context is not a little summary like “arg0 is constant” or “arg1 is more specific.”
Instead, Binaryen stores a transformed operand list that becomes the top of the specialized callee.

That means context can include:

- constants
- more-refined reference values
- movable GC allocations
- and, in some cases, the fact that the original call result was dropped

This is why the pass comments call the transformation **reverse-inlining**.

## 2. Binaryen tries to move a lot of code inward, but only with proof

The implementation comment is surprisingly aggressive in spirit:

- if larger context gives the optimizer more to work with, that is often good
- even when the immediate values are not constant yet

For example, moving a GC allocation into the callee can expose nonescape cleanup there even if its fields are still dynamic.

But that aggressiveness is checked by real safety rules.

## 3. The movement proof is effect-order sensitive

Binaryen does not ask only “is this subtree pure?”
It asks whether moving a subtree into the callee would reorder it incorrectly past the nonmoving operand code after it.

So the proof is about **crossing** other operand work safely.

That is why the implementation uses:

- postorder listing of operand trees
- reverse traversal
- accumulated effects of nonmoved expressions
- invalidation checks against those effects

A future port that skips this and just pattern-matches constants will miss real positive cases and may also miscompile effectful ones.

## 4. The main immovable families

`canBeMovedIntoContext(...)` rejects movement for expressions that:

- branch out or have external break targets
- access locals
- perform calls
- are control-flow structures
- involve tuple-child cases that would force tuple params

These are the main “looks tempting, but no” families.

### Beginner translation

- moving local traffic between functions is not allowed here
- moving inner calls would complicate recursion and ordering
- moving control flow would be much more than “specialize a call”
- tuple traffic is kept out because the cloned signature machinery is scalar-oriented here

## 5. Trivial contexts are filtered out before cloning

A context is trivial when every operand is just a same-typed passthrough `local.get` and the call result is not dropped.

That is a crucial negative rule.
Even if specialization would be mechanically possible, Binaryen refuses to waste time cloning a callee when the callsite contributes no new optimization information.

## 6. Dropped-call context is a real positive family

When a call is immediately dropped, that can be useful context.
If Binaryen specializes successfully, it can:

- change the specialized callee’s result type to `none`
- remove returns from that specialized copy
- erase the caller-side `drop`

The dedicated `monomorphize-drop.wast` file is the best official evidence for this family.

## 7. But dropped-call specialization has a tail-call boundary

The pass first finds functions that are return-callers.
If the target of a candidate call is one of those, the pass refuses to pull an outer `drop` into the callee.

Why?
Because turning a `return_call*` path into an ordinary call-plus-return-removal shape can change stack behavior.

This is one of the easiest correctness details to miss when reading only the happy-path tests.

## 8. Usefulness is measured after nested optimization

The pass does not simply ask “did we remove a constant param?”
It asks whether the specialized copy became **meaningfully cheaper after optimization**.

That is why `monomorphize-benefit.wast` is so important.
It proves that:

- some legal specializations are rejected at higher thresholds
- `0`, `33`, `66`, and `100` produce visibly different results
- usefulness depends on what later optimizations can exploit from the context

## 9. Why refined types are not always enough

`monomorphize-types.wast` shows a subtle rule:

- a more-refined reference argument may justify a specialized clone in `monomorphize-always`
- but careful `monomorphize` can still reject that same specialization if the optimizer cannot do anything useful with the refined type inside the callee

So “more precise type” is a positive input, not an automatic win.

## 10. Why large inner work can still be worth it

The same profitability logic explains why a long function and a short function can behave differently.

If the cloned context allows the optimizer to remove:

- only a tiny cast inside a huge callee body,

then a high threshold may reject it.
But if the same context removes most of a short callee, it may pass.

This is the real reason the official benefit test varies both thresholds and function shapes.

## 11. Parameter limits are part of the safety-and-practicality boundary

Binaryen rejects specialized functions whose new signature still ends up too wide.
The reviewed source sets `MaxParams = 20`.

This is not just a convenience rule.
It exists because huge specialized signatures can create large stack frames and can also exceed binary limits if unchecked.

The interesting nuance shown by `monomorphize-limits.wast` is:

- many original params are okay if most of them become fully in-context constants
- the real problem is too many **surviving dynamic** inputs after context extraction

## 12. What a future Starshine port must preserve

The most important contract here is not one specific rewrite shape, but the decision structure:

1. build a context conservatively but usefully
2. distinguish movable and nonmovable operand code by effect-safe motion
3. skip trivial contexts
4. keep dropped-result and return-call boundaries honest
5. enforce a hard specialized-signature limit
6. run nested optimization and measure actual benefit before committing

If a future port keeps those rules, it will still feel like Binaryen `monomorphize` even if some smaller heuristics change.

## Sources

- [`../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md`](../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
