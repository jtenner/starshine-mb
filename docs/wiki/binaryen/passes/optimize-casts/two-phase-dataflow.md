---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
---

# `optimize-casts` Two-Phase Dataflow

This page exists for one reason:

- the easiest mistake to make about `optimize-casts` is to think it is one algorithm.

It is not.

Binaryen deliberately splits the pass into **two** internal dataflow passes because the safety question is different in each one.

## The short version

| Question | Earlier-motion phase | Later-reuse phase |
| --- | --- | --- |
| What is being changed? | A cast is duplicated **earlier** than before | A cast stays where it is, but later gets reuse its refined value |
| Main risk | The cast might trap **sooner** than before | The cast’s trap point does not move |
| Walker mode | strict linear windows | linear windows plus adjacent dominated blocks |
| Key state | earliest target get + best cast to move there | best cast seen so far + later gets that should use it |
| Rewrite shape | wrap an earlier get in duplicated cast(s) | add a fresh refined local and replace the original cast with a `local.tee` |
| Why `ReFinalize`? | inserted casts refine surrounding types | redirected gets and fresh locals refine types |

If you remember only one thing, remember this:

- **moving a trap earlier is scarier than reusing a value later**

That is why Binaryen does not use one shared safety rule for both halves.

## Phase A: “Can I safely put the cast earlier?”

Conceptual shape:

Before:

```wat
(drop
  (local.get $x))
(drop
  (ref.cast (ref $A)
    (local.get $x)))
```

After, conceptually:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
(drop
  (ref.cast (ref $A)
    (local.get $x))) ;; later cleanup may simplify this
```

That looks simple, but it changes **when** the cast executes.

If the later cast could have been skipped before, moving it earlier would be wrong.

So Binaryen is strict here.

## Why calls and side effects matter in Phase A

Imagine this:

```wat
(drop
  (local.get $x))
(call $maybe_exits)
(drop
  (ref.cast (ref $A)
    (local.get $x)))
```

If `call $maybe_exits` throws, traps, returns via a return-call path, or otherwise prevents the later code from running, then the old program never executed the cast.

Moving the cast before the call would make the trap happen even when the old program skipped it.

That is why `EarlyCastFinder` uses effect barriers.

The same logic explains why these are barriers for earlier motion:

- visible side effects like `global.set`
- same-index `local.set`
- non-linear control flow boundaries

## Phase B: “Now that the cast happened, who can reuse it later?”

Conceptual shape:

Before:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
(drop
  (local.get $x))
(drop
  (local.get $x))
```

After, conceptually:

```wat
(local $tmp (ref $A))
(drop
  (local.tee $tmp
    (ref.cast (ref $A)
      (local.get $x))))
(drop
  (local.get $tmp))
(drop
  (local.get $tmp))
```

This does **not** move the cast earlier.

The cast still runs at the old spot.

So the safety question is easier:

- if control never reaches the old cast, we still do not use the new local later
- if control does reach the old cast, then the cast has already trapped or succeeded before later gets try to reuse it

That is why Binaryen allows this phase to be looser.

## Why adjacent blocks are allowed only in Phase B

`BestCastFinder` turns on `connectAdjacentBlocks = true`.

That allows cheap reuse across trivial domination shapes like:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
(if
  (i32.const 1)
  (then
    (drop
      (local.get $x))))
```

in cases where the walker sees a straightforward adjacent dominated block.

Binaryen does **not** give the same freedom to Phase A, because moving the cast into an earlier block could make it execute in situations where it did not before.

So the rule of thumb is:

- **reusing later may cross a little farther than moving earlier**

## Same-index writes are barriers in both phases

This shape is the core invalidation rule:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
(local.set $x
  (call $other_value))
(drop
  (local.get $x))
```

Why Binaryen stops:

- before the `local.set`, `$x` means the old value
- after the `local.set`, `$x` means a new value
- so any remembered refinement for `$x` must die there

This is simple, and it is one of the most important invariants for a future port.

## Why one local index can keep moving while another is blocked

The pass tracks each local index separately.

So this is legal:

```wat
(drop
  (local.get $x))
(drop
  (local.get $y))
(local.set $x
  (local.get $y))
(drop
  (ref.as_non_null
    (local.get $y)))
```

The write to `$x` blocks remembered facts about `$x`, but not remembered facts about `$y`.

That is why the shipped tests include separate-index cases.

## Why `ref.as_non_null` is even stricter than it first looks

Binaryen only moves or reuses `ref.as_non_null` when it is actually doing something useful.

If the target get is already non-nullable, the pass ignores the `ref.as_non_null` for movement purposes.

That can feel surprising at first, but it matches the pass’s purpose:

- it wants better local typing and reuse
- not pointless syntactic duplication

## Why `getFallthrough(..., NoTeeBrIf)` appears in Phase B

One subtle source detail is that Phase B does not just ask for the full fallthrough immediately.

It first asks for fallthrough **without** looking through `local.tee` / `br_if`-style carriers.

That gives Binaryen a chance to notice patterns like:

```wat
(ref.cast (ref $A)
  (local.tee $y
    (local.get $x)))
```

If it looked through the tee too early, it would miss the fact that `$y` itself is now a refined carrier.

So Phase B does this in two steps:

1. notice the tee carrier
2. then keep looking through to the underlying get

That is a very easy detail to miss in a shallow read.

## Why the pass does not delete the old cast immediately

Both phases prefer simple, local rewrites.

They do **not** try to solve all cleanup immediately.

Instead, Binaryen is happy to leave shapes like:

- repeated now-redundant casts
- new `local.tee`s
- fresh carrier locals

for later cleanup neighbors such as:

- `simplify-locals`
- `coalesce-locals`
- `local-cse`
- `rse`

That design choice keeps `optimize-casts` focused on one job:

- improve where refined values are available

not:

- perform all downstream cleanup itself

## Why `ReFinalize` runs twice

A good beginner question is:

- “why does the pass keep refinalizing instead of just editing the local/get types directly?”

Because the rewrite changes more than one local node.

Phase A can:

- insert new earlier casts
- change which cast becomes the most refined one in a chain

Phase B can:

- add a fresh local
- change later `local.get` indices
- change those gets’ types
- replace an expression with a `local.tee`

`ReFinalize` is the cheap, reliable way Binaryen propagates those type consequences through the rewritten IR.

## A compact rule of thumb

When reading `optimize-casts`, ask two questions in order:

1. **Is Binaryen trying to move the cast earlier, or only reuse it later?**
2. **What barrier model applies in that half?**

If you ask those two questions first, most of the test outcomes stop being mysterious.

## The one thing a future Starshine port must not collapse away

Do not turn these two halves into one common “best cast propagation” routine unless you preserve the safety difference.

Specifically:

- a transform that moves traps earlier needs stricter barriers
- a transform that only reuses an already-computed cast can be looser

That asymmetry is the heart of the upstream algorithm.

## Sources

- [`../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md`](../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>
- Binaryen `version_129` linear-execution helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- Binaryen `version_129` fallthrough helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- Binaryen `version_129` effects helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>