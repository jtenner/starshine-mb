---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md
  - ../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../monomorphize/index.md
---

# Usefulness gate and sibling split in `monomorphize-always`

This page covers the easiest part of the pass family to explain badly.

The question is not “what does contextual specialization do?” The neighboring [`../monomorphize/index.md`](../monomorphize/index.md) dossier covers that.

The question here is: **what exactly changes when Binaryen says `monomorphize-always`?**

## Short answer

`monomorphize-always` keeps the same legal, nontrivial specializations that ordinary `monomorphize` can build, but it does not discard them just because the measured payoff is too small.

That is all.

And that is a lot.

## What stays the same

The sibling still requires:

- direct calls
- defined callees
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

Ordinary `monomorphize` tries to justify the clone economically. The sibling stops asking for that extra justification.

In beginner terms:

- careful mode asks “is this legal, nontrivial, and helpful enough?”
- always mode asks “is this legal and nontrivial?”

## Why Binaryen exposes a separate sibling

The usefulness gate hides real specialization behavior.

Suppose a direct call passes:

- a constant
- a more refined reference
- a movable allocation or computation
- or a dropped-result context

and Binaryen can legally build a specialized clone. If the nested optimizer cannot shrink enough, careful mode discards evidence that the specialization machinery worked. That is good for production size policy, but bad for testing and teaching. The sibling preserves those otherwise-legal clones.

## Direct test surface

The direct `--monomorphize-always` lit evidence is `monomorphize-types.wast`.

`monomorphize-benefit.wast` is still useful, but for a different reason: it shows the ordinary pass's threshold policy and therefore explains the axis that the sibling removes. Do not cite it as if it directly runs the sibling.

## Shape family 1: refined-type wins that are real but modest

A more-specific reference argument may let the specialized callee:

- sharpen a parameter type
- simplify a cast path
- or expose a small local cleanup

That may not clear the default usefulness threshold.

So:

- ordinary mode may leave the original generic call untouched
- always mode lets the specialized variant survive

## Shape family 2: constant context with small code-size payoff

A constant or movable allocation context can be a legal specialization but only lead to minor simplification.

Again:

- ordinary mode may reject
- always mode keeps

## Shape family 3: dropped-result specialization that is structurally cleaner but weak

The sibling also keeps legal dropped-result clones whose immediate code-size win is weak. That helps reveal the real rewrite surface of the pass family.

## Why this is not merely “min benefit = 0”

Inference from sources:

`--monomorphize --pass-arg=monomorphize-min-benefit@0` is very close to the sibling and appears beside it in official type-focused tests. But the repo-facing rule should still be:

- preserve the separate public sibling in docs and registry design
- do not flatten it into one undocumented pass-arg recipe
- describe exact equivalence as uncertain unless a future port re-derives every branch

That keeps Starshine aligned with upstream's public pass surface.

## Porting rule

A faithful port should implement the family in two layers:

1. shared specialization engine
2. separate usefulness-policy entrypoints

That preserves both correctness and the public surface users/tests expect.

## Sources

- [`../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md)
- [`../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md`](../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
