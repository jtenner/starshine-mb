---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./usefulness-gate-and-sibling-split.md
  - ./wat-shapes.md
  - ../monomorphize/index.md
---

# Binaryen strategy for `monomorphize-always`

## What the pass really is

The reviewed implementation makes `monomorphize-always` a **whole-module direct-call contextual-specialization pass** that shares the same engine as ordinary `monomorphize`.

The best mental model is:

- build the same callsite context
- clone the same specialized callee
- run the same nested optimization
- but skip the final "was this helpful enough?" rejection policy

So the pass is not:

- a separate algorithm
- a broad all-calls cloner
- or ordinary inlining under another name

## Public surface and sibling split

`src/passes/pass.cpp` registers two related public passes:

- `monomorphize`
- `monomorphize-always`

The durable split is:

- `monomorphize` = usefulness-gated empirical pass
- `monomorphize-always` = same specialization machinery, but keep legal nontrivial specializations even when the measured benefit is too small for the default pass

That is why this sibling deserves a dedicated folder.
The pass boundary is not just folklore or a test hack.

## Default scheduler placement

A key negative fact also matters:

- the repo's current no-DWARF `-O` / `-Os` page does **not** schedule `monomorphize-always`
- the reviewed `pass.cpp` registration proves it is real public surface, but not part of that default pathway

So this dossier is a justified tracker expansion for a real local-registry pass outside the current parity queue.

## The shared core algorithm still applies

Because both variants live in the same `Monomorphize.cpp` machinery, `monomorphize-always` still performs these same phases:

1. scan original defined functions for candidate direct calls
2. reject imported, recursive, unreachable, or tail-call-sensitive bad fits
3. build a `CallContext` by reverse-inlining movable operand code into the future callee
4. reject trivial contexts
5. clone a specialized function and rebuild its signature from the surviving dynamic inputs
6. adjust result type to `none` for dropped-call cases when that is safe
7. remap locals and preserve names where possible
8. run the nested optimization helper
9. retarget the call to the specialized clone

The only major policy difference comes after nested optimization.

## The central policy difference

In ordinary `monomorphize`, the pass computes a cost/benefit comparison and rejects weak wins.
The neighboring dossier already captures that as the default `MinPercentBenefit` gate.

`monomorphize-always` removes **that** rejection layer.

The important teaching point is what it does **not** remove:

- not the direct-call-only restriction
- not the effect-order movement proof
- not the trivial-context bailout
- not the parameter-limit bailout
- not the dropped-result safety rules

This is why “always” is easy to misread.
It means **always keep legal nontrivial specializations**, not **always specialize regardless of safety or shape**.

## Why legality still matters

`CallContext::buildFromCall(...)` is still the heart of the pass family.
The builder tries to reverse-inline operand code from the caller into the specialized callee.
That changes execution order, so Binaryen still has to prove movement legality using effect analysis.

This shared proof still blocks contexts involving:

- external control flow
- local-sensitive motion
- call-sensitive motion
- unsupported tuple or control families
- other cases where moving code inward would reorder visible effects

So `monomorphize-always` is **less profitability-conservative**, not **less correctness-conservative**.

## Dropped-call-result behavior stays the same

The sibling also preserves one of the easiest parts of the family to underestimate:

- if the original call result is immediately dropped
- and the call is safe to specialize that way
- Binaryen can produce a clone whose result type becomes `none`
- then remove the outer `drop` when retargeting the callsite

That rewrite surface is shared between the two variants.
The only question the sibling changes is whether a weak-payoff version of that rewrite is still kept.

## The nested optimizer still matters

A future port must preserve that both variants still rely on nested optimization.
The point is not only to make the clone prettier.
The nested optimizer is part of the very definition of the pass family's usefulness story.

Even in always mode, the nested optimization still matters because it:

- exposes simplifications the specialized clone was created to unlock
- shapes the final clone body that will be kept
- determines how visible the sibling's extra aggressiveness is in printed WAT

So omitting the nested optimizer would not merely reduce performance; it would change the sibling's visible contract.

## Positive rewrite families that the sibling makes easier to observe

## 1. Weak-benefit constant contexts

A direct call may carry a real constant or movable constructor-like context that creates a valid specialized callee but only small body shrinkage.

- ordinary `monomorphize` may reject it
- `monomorphize-always` keeps it

## 2. Refined-reference contexts with small immediate payoff

A more specific reference argument may sharpen a specialized callee signature or unlock some local cleanup without clearing the default usefulness threshold.

- ordinary `monomorphize` may reject it
- the sibling keeps it

This is one reason the type-oriented lit file matters so much.

## 3. Dropped-result contexts with modest cleanup wins

The dropped-result rewrite can still be structurally meaningful even when it does not satisfy the default measured-benefit policy.
The sibling keeps those shapes visible.

## Negative families that remain negative

`monomorphize-always` still refuses:

- imported callees
- recursive self-calls
- unreachable calls
- trivial passthrough contexts
- illegal context motion across effect/order barriers
- unsupported context shapes
- over-budget specialized signatures
- unsafe dropped-result folds around return-call-sensitive code

This is the most important beginner-friendly correction to the name.

## Relationship to threshold tuning

Inference from sources:

The official lit files compare this sibling against threshold-tuned `monomorphize`, so Binaryen clearly treats both surfaces as related ways to expose the usefulness-policy dimension.

But the durable docs rule to preserve is still:

- `monomorphize-always` is a separate public pass name
- it is not merely documentation shorthand for a pass-arg recipe

That matters for registry design, CLI exposure, and future port completeness.

## What a future Starshine port must preserve

1. Separate public identity for `monomorphize-always` in the registry and CLI.
2. Shared specialization engine with ordinary `monomorphize`.
3. The full legality/triviality/limit gates.
4. The same dropped-result and local-remap repair behavior.
5. The same nested-optimization dependency.
6. The exact public policy split: always mode skips usefulness rejection, not safety rejection.

## Sources

- [`../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md`](../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
