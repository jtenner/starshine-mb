---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md
  - ../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./interference-and-ordering.md
  - ../local-subtyping/index.md
---

# `coalesce-locals` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `coalesce-locals` pass.

## Provenance note

Use [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md) as the immutable source manifest for the official Binaryen release/source/test URLs rechecked on 2026-04-22.
Use [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md) as the narrow current-`main` freshness bridge.
A focused 2026-04-25 spot check did not surface teaching-relevant drift beyond the `version_129` shape families summarized here. For the upstream lit-test region map, see [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## Read this page with one mental model

Binaryen is not asking:

- “which locals look similar?”

It is asking:

- “which locals can safely reuse the same storage slot?”

That means three questions matter most:

1. are both locals the **same exact type**?
2. are they ever live at the same time with **different** values?
3. would sharing one slot also delete useful copies?

## Important note about the examples

The `after` snippets below are often **conceptual**.

In real Binaryen output, the chosen local numbers may vary because:

- params stay fixed
- greedy order matters
- Binaryen may keep several equally-good-looking locals separate if the heuristic says so

So read the shapes as “what family rewrites or stays put,” not “the exact printed index numbers in every case.”

## Quick glossary

- **storage slot**: the local index that survives after coalescing
- **interference**: two locals are simultaneously live with different values
- **effective set**: a write that some later get may actually read
- **ineffective set**: a dead write that later cleanup can erase
- **copy slot**: a local relationship where coalescing can also remove copy code

## Shape 1: two unused same-typed locals can collapse to one slot

Before:

```wat
(local $x i32)
(local $y i32)
(nop)
```

After, conceptually:

```wat
(local $x i32)
(nop)
```

Why it rewrites:

- both locals have the same type
- neither creates a meaningful live-range conflict
- one slot is enough

This is the simplest positive case.

## Shape 2: different local types do not coalesce

Before and after stay the same in the important part:

```wat
(local $x i32)
(local $y f32)
```

Why Binaryen keeps both:

- the coloring stage requires exact type equality
- this pass does not do subtype-aware or coercion-aware merging

This is the fastest way to remember that `coalesce-locals` is not `local-subtyping`.

## Shape 3: overlapping live ranges with different values do interfere

Before and after stay the same in the important part:

```wat
(local.set $x (i32.const 0))
(local.set $y (i32.const 1))
(drop (local.get $x))
(drop (local.get $y))
```

Why Binaryen keeps both:

- both locals are live together
- they hold different values
- one slot would lose information

That is the `leave-interfere` family.

## Shape 4: non-overlapping same-typed locals can hand off one slot

Before:

```wat
(local.set $x (i32.const 0))
(drop (local.get $x))
(local.set $y (i32.const 0))
(drop (local.get $y))
```

After, conceptually:

```wat
(local.set $slot (i32.const 0))
(drop (local.get $slot))
(local.set $slot (i32.const 0))
(drop (local.get $slot))
```

Why it rewrites:

- `$x` dies before `$y` becomes live
- the shared slot never has to represent two different live values at once

That is the `almost-interfere` family.

## Shape 5: equal live values can share one slot

Before:

```wat
(local.set $x (i32.const 42))
(local.set $y (i32.const 42))
(drop (local.get $x))
(drop (local.get $y))
```

After, conceptually:

```wat
(local.set $slot (i32.const 42))
(local.set $slot (i32.const 42))
(drop (local.get $slot))
(drop (local.get $slot))
```

Why it rewrites:

- the live ranges overlap
- but the pass proves both locals hold the same current value
- therefore there is no semantic conflict

This is the single easiest shape to miss if you think the pass is only about lifetime overlap.

## Shape 6: different equal-looking constant writes do not share

Before and after stay the same in the important part:

```wat
(local.set $x (i32.const 42))
(local.set $y (i32.const 1337))
(drop (local.get $x))
(drop (local.get $y))
```

Why Binaryen keeps both:

- the values differ
- so overlapping liveness still means interference

The `different-constants*` tests exist to keep this distinction sharp.

## Shape 7: implicit zero-init locals can share one slot

Before:

```wat
(local $x i32)
(local $y i32)
(drop (local.get $x))
(drop (local.get $y))
```

After, conceptually:

```wat
(local $slot i32)
(drop (local.get $slot))
(drop (local.get $slot))
```

Why it rewrites:

- both body locals begin with the same implicit zero value
- the pass treats that zero-init as real state for interference purposes

This is why wasm default values are part of the algorithm, not just background trivia.

## Shape 8: copy chains can disappear after coalescing

Before:

```wat
(local.set $x (i32.const 0))
(local.set $y (local.get $x))
(drop (local.get $y))
```

After, conceptually:

```wat
(local.set $slot (i32.const 0))
(nop)
(drop (local.get $slot))
```

Why it rewrites:

- once `$x` and `$y` share the same slot,
- the copy from `$x` to `$y` becomes a self-copy,
- so Binaryen deletes it

This is the `redundant-copy` family.

## Shape 9: dead sets become `drop` or a plain value

Before:

```wat
(local.set $x
  (side-effecting-value ...))
```

After, conceptually:

```wat
(drop
  (side-effecting-value ...))
```

Why it rewrites:

- the liveness scan proved the set is ineffective
- but the child expression may still have side effects
- Binaryen preserves the child work and removes the pointless local write

For dead tees, the replacement may be the raw child value instead of a `drop`, and that can require later `ReFinalize()`.

## Shape 10: tiny source-order flips can block a merge

Positive shape (`if5`-style):

```wat
(drop (local.get $x))
(local.set $y (i32.const 1))
(drop (local.get $y))
```

Negative shape (`if5-flip`-style):

```wat
(local.set $y (i32.const 1))
(drop (local.get $x))
(drop (local.get $y))
```

Why the second one fails:

- `$y` starts to matter before `$x` finishes
- so the ranges overlap with different values

This is a very good reminder that the pass is sensitive to actual live-range boundaries, not just coarse “same block” intuition.

## Shape 11: `if` / `else` control flow can still coalesce locals

Before, conceptually:

```wat
(if
  (i32.const 0)
  (then
    (drop (local.get $x)))
  (else
    (drop (local.get $y))))
```

After, conceptually:

```wat
(local $slot i32)
(if
  (i32.const 0)
  (then
    (drop (local.get $slot)))
  (else
    (drop (local.get $slot))))
```

Why it rewrites:

- the structured CFG and liveness reasoning show the two paths can reuse one slot safely
- this is not limited to straight-line code

The official tests include many `if` families because structured-control lifetimes are part of the real surface.

## Shape 12: dead code after `br`, `return`, or `unreachable` should not block coalescing

Before:

```wat
(block $b
  (return)
  (drop (local.get $x))
  (drop (local.get $y)))
```

After, conceptually:

```wat
(block $b
  (return)
  (drop (i32.const 0))
  (drop (i32.const 0)))
```

Why it matters:

- dead local traffic is not allowed to create fake interference
- Binaryen rewrites unreachable local gets/sets into safer placeholder shapes early

The `interfere-in-dead*`, `in-unreachable`, and `nop-in-unreachable` families exist for this reason.

## Shape 13: params stay fixed even if body locals merge heavily

Before and after stay the same in the important part:

```wat
(func $f (param $p i32) (param $q f32)
  (local $x i32)
  (local $y i32)
  (local $z i32)
  ...)
```

Why Binaryen keeps param order:

- params are outside the normal coalescing game
- the function ABI fixes them in place
- only body locals are packed down around them

That is the `params` family.

## Shape 14: loop backedge copies get extra preference

Conceptual before:

```wat
(loop $top
  ...
  (local.set $next ...)
  (local.set $phi (local.get $next))
  (br $top))
```

Conceptual after:

```wat
(loop $top
  ...
  (local.set $phi-or-next ...)
  (nop)
  (br $top))
```

Why Binaryen prefers this kind of win:

- the backedge copy is extra annoying
- the pass gives such copies extra weight during ordering

This is the exact lesson of the `loop-backedge` test.

## Shape 15: some valued `if` sets count as copy candidates too

Before, conceptually:

```wat
(local.set $x
  (if (result i32)
    (i32.const 1)
    (then (local.get $x))
    (else (local.get $y))))
```

Why it matters:

- the helper copy detector is broader than plain `local.set x (local.get y)`
- small valued-`if` forms can also influence copy-removal priorities

This is what the `if-copy*` families are teaching.

## Shape 16: dead tee cleanup must still preserve typing

Before, conceptually:

```wat
(local.tee $x
  (if (result f64)
    ...
    (then (local.get $x))
    (else (unreachable))))
```

Why this family matters:

- removing a dead tee is not always a trivial text deletion
- the tee may have carried a more refined outward type than its child expression
- Binaryen may need `ReFinalize()` after such cleanup

The `tee_if_with_unreachable_else` and `tee_if_with_unreachable_true` families exist so this subtlety is not lost.

## What later passes tend to do with the new shape

`coalesce-locals` is not the end of local cleanup.
It creates better input for nearby passes.

### Unlock family 1: `local-cse`

Once several locals share one slot, repeated local-fed expressions may become more obvious to `local-cse`.

### Unlock family 2: `simplify-locals`

After copy removal and dead-set cleanup, full `simplify-locals` may find new sink/canonicalization opportunities.

### Unlock family 3: `reorder-locals`

After coalescing reduces the live local set, `reorder-locals` can compact the final numbering again.

### Unlock family 4: `remove-unused-brs` and `rse`

`pass.cpp` explicitly comments that later branch cleanup profits from `coalesce-locals`, and that `rse` should run only after all coalescing is done.

## A simple rule of thumb

When you look at a possible `coalesce-locals` candidate, ask these questions in order:

1. Do the locals have the same exact type?
2. Are they ever simultaneously live with different values?
3. Is any overlap actually an equal-value overlap?
4. Is one of the writes dead anyway?
5. Would sharing a slot delete a useful copy, especially on a loop backedge?

If the answer to question 1 or 2 is “no,” expect Binaryen to keep separate slots.

## Source strength note

- The positive and negative shapes above come directly from Binaryen's shipped `coalesce-locals` lit tests plus the current `version_129` implementation comments.
- The unlock examples are derived explanations of why `coalesce-locals` sits where it does in the local-cleanup cluster.

## Sources

- [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md)
- [`../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md`](../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md)
- [`../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md`](../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md`](../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md)
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
