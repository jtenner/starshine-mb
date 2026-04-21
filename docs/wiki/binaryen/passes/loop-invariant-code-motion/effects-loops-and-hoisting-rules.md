---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# Effects, loops, and hoisting rules in `loop-invariant-code-motion`

## The real proof obligation

The most important thing to teach about LICM is that Binaryen is **not** asking only:

- “is this subtree pure?”

It is asking something closer to:

- does this subtree compute the same value on every loop iteration?
- can it be evaluated before the loop without changing observable effects?
- can all of its children also be made available before the loop?

That is why the real proof obligation is:

- **loop-invariant + effect-safe + child-hoistable**

## Loop invariance

An expression is not invariant just because it contains no constants or no obvious writes.
It must not depend on state that the loop changes.

The important beginner cases are:

- reads of locals untouched by the loop can still be invariant
- reads of loop-carried locals are not invariant
- loads from memory are only invariant if loop-side memory effects cannot invalidate them

## Effect safety

Even an invariant value may fail the second test: effect safety.

Moving an expression earlier is illegal if it can change:

- memory observation order
- whether a call happens before or after another effect
- whether a trap happens earlier
- whether an allocation or other observable runtime action occurs at a different point

This is why `EffectAnalyzer` is central.
LICM is really a semantics-preserving motion pass, not just a value-equivalence pass.

## Child hoistability

Parent expressions inherit the movement limits of their children.

If a parent expression depends on a child that is still stuck inside the loop, the parent is stuck too.
But once that child is hoisted in a first round, the parent may become movable in a later round.

That fixed-point behavior is a core part of the real algorithm.

## Helper-local insertion rule

When Binaryen hoists a value, it does not keep a hidden abstract fact.
It makes the motion explicit in the IR:

- fresh temp local before the loop
- `local.set temp, expr`
- in-loop replacement by `local.get temp`

That explicitness matters for future cleanup passes and for any future Starshine port.

## Common positive shapes

## 1. Arithmetic on outer-scope locals

If `x` and `y` are defined outside the loop and not modified inside it, then:

- `i32.add(x, y)`
- `i32.mul(i32.add(x, 1), y)` after child hoisting

are the kinds of shapes LICM can often hoist.

## 2. Reused invariant value trees

If the same invariant value feeds several later loop-body computations, the temp-local rewrite is especially natural.

## Common bailout shapes

## 1. Loop-carried locals

```wat
(loop $L
  ...
  (local.set $x ...)
  (drop (i32.add (local.get $x) (i32.const 1))))
```

This is not invariant with respect to the loop if `$x` changes inside the loop.

## 2. Memory-sensitive loads

```wat
(loop $L
  ...
  (i32.store (local.get $p) ...)
  (drop (i32.load (local.get $p))))
```

The pointer may be invariant, but the loaded contents are not necessarily invariant.

## 3. Trap timing hazards

```wat
(loop $L
  ...
  (drop (i32.div_s (local.get $x) (local.get $y)))
  ...)
```

If moving this before the loop could trap earlier or on an execution that would otherwise skip the expression, LICM must bail out.

## 4. Call-heavy expressions

```wat
(loop $L
  ...
  (drop (call $f (local.get $x)))
  ...)
```

Calls are conservative barriers in the general case.

## 5. Structure-heavy nodes

Branches, returns, and similar control-shaping nodes are not the pass's normal rewrite surface.
LICM targets reusable values, not arbitrary control motion.

## Easy-to-miss contrast with nearby passes

## Versus `code-pushing`

- `code-pushing` moves code deeper into selected control-flow arms
- LICM moves some loop-invariant values outward before a loop

## Versus `precompute`

- `precompute` can eliminate runtime work by folding constants
- LICM keeps runtime computation, but changes when it happens

## Versus `simplify-locals`

- LICM creates helper-local traffic
- `simplify-locals` can later clean some of that traffic up
- but LICM itself is responsible only for the safe hoist

## The one-sentence rule for future ports

If a future Starshine LICM port forgets everything else, it should preserve this:

> Only hoist a loop value when the loop cannot change the value, evaluating it earlier cannot change effects or trap timing, and the required child values can themselves exist before the loop.

## Sources

- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
