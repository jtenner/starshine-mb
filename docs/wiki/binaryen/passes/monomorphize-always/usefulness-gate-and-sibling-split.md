---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../monomorphize/index.md
---

# Usefulness gate and sibling split in `monomorphize-always`

This page covers the easiest part of the pass family to explain badly.

The question is not:

- "what does contextual specialization do?"

The neighboring `monomorphize` dossier already covers that.

The real question here is:

- **what exactly changes when Binaryen says `monomorphize-always`?**

## The short answer

`monomorphize-always` keeps the same legal, nontrivial specializations that ordinary `monomorphize` can build, but it does not discard them just because the measured payoff is too small.

That is all.

And that is a lot.

## What stays the same

The sibling still requires:

- direct calls
- movable callsite context
- effect-safe movement
- nontrivial context
- safe dropped-result handling
- acceptable specialized signature size

So the sibling does **not** mean:

- specialize imports
- specialize recursion
- specialize through illegal effects
- specialize trivial passthrough calls
- specialize impossible giant signatures

## What changes

Ordinary `monomorphize` tries to justify the clone economically.
The sibling stops asking for that extra justification.

In beginner terms:

- careful mode asks "is this legal, nontrivial, and helpful enough?"
- always mode asks "is this legal and nontrivial?"

## Why Binaryen exposes a separate sibling at all

Because the usefulness gate hides real specialization behavior.

Suppose a direct call passes:

- a constant
- a more-refined reference
- or a dropped result context

and Binaryen can legally build a specialized clone.

If the nested optimizer cannot shrink the result enough, careful mode discards the evidence that the specialization machinery worked.

That is good for a production-minded pass.
But it is bad for teaching and testing.

The sibling solves that problem by preserving the otherwise-legal clone.

## Shape family 1: refined-type wins that are semantically real but modest

This is the most important beginner-facing family.
A more-specific reference argument may let the specialized callee:

- sharpen a param type
- simplify a cast path
- or expose a small local cleanup

But that may not be enough to clear the default usefulness threshold.

So:

- careful mode may leave the original generic call untouched
- always mode lets you see the specialized variant anyway

## Shape family 2: constant context with small code-size payoff

A constant or movable allocation context can still be a legal specialization but only lead to minor simplification.

Again:

- ordinary mode may reject
- always mode keeps

## Shape family 3: dropped-result specialization that is structurally cleaner but not obviously worth it

The sibling also keeps legal dropped-result clones whose immediate code-size win is weak.
That helps reveal the real rewrite surface of the pass family.

## Why this is not just "min benefit = 0"

Inference from sources:

The official lit surface strongly links the sibling to the threshold-controlled policy story, so the two are clearly related.

But the durable repo-facing rule should still be:

- preserve the separate public sibling in docs and registry design
- do not flatten it into one undocumented pass-arg recipe

That is how upstream exposes it, and that is the simplest way to keep future docs truthful.

## Porting rule

A faithful port should therefore implement the family in two layers:

1. shared specialization engine
2. separate usefulness-policy entrypoints

That preserves both:

- correctness
- and the public surface users/tests expect

## Sources

- [`../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md`](../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
