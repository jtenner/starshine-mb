---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# `dae2`: fixed point, forwarding, type trees, and expression removal

This page focuses on the hardest part of `dae2` to teach correctly:

- why “unused parameter” is really a graph problem here,
- why indirect/reference calls drag function-type trees into the analysis,
- and why removing the parameter often means removing more than one expression, but not in a careless way.

## The key beginner correction

A parameter in `dae2` is **not** automatically used just because you can find a `local.get` of it.

The real question is:

> after accounting for slot reuse, pure forwarding, direct calls, indirect calls, and escapes, does anything semantically observable still depend on the incoming value?

That is why the pass is built around a fixed point instead of a one-pass direct matcher.

## Part 1: forwarding is the core abstraction

`dae2` separates two categories of parameter traffic.

### Actually used

The value affects something that cannot be removed or safely treated as mere forwarding.
Examples include:

- flowing into a global write that matters,
- flowing into an `if` condition,
- flowing through an effectful wrapper,
- being needed by an unrewritable referenced/type-tree surface.

### Only forwarded

The value is only being moved onward toward another call, possibly through pure intermediate wrappers.
If all the destinations turn out to have dead params too, the original incoming value can still disappear.

That is how the pass can optimize cycles that would look “used” to a simpler local scan.

## Part 2: direct forwarding vs indirect/reference forwarding

## Direct forwarding

For direct calls, the pass stores edges like:

- caller param `i` forwards to callee param `j`.

Those edges are keyed by target function name.

## Indirect/reference forwarding

For `call_ref` and `call_indirect`, the pass cannot always know the exact callee function.
So it reasons at the level of the **root function-type tree** instead.

That means the analysis stores edges like:

- caller param `i` forwards to param `j` of root function-type tree `T`.

This is the crucial reason `dae2` needs both per-function and per-root-type-tree state.

## Part 3: why root function-type trees matter

Suppose several referenced functions share related function types under one root supertype.
An indirect call or `call_ref` can observe parameter structure through that type tree even when it does not name one exact function directly.

So Binaryen requires a tree-wide rule:

- params in that tree must agree on used vs unused status when the pass is optimizing referenced functions.

That is why a single referenced/public/unrewritable function can keep a whole parameter position alive for the relevant tree.

## Part 4: the reverse graph is what makes cycle optimization work

The scan phase builds **forward** facts:

- this caller param forwards to that callee param.

But the fixed point needs the opposite question:

- if the callee param is used, which caller params become used too?

So `prepareReverseGraph()` builds reverse `callerParams` edges.
Then `computeFixedPoint()` starts from known used params and walks backward.

The result is elegant:

- pure forwarding cycles with no external real use stay unused;
- any cycle with one real use becomes live along the relevant reverse edges.

## Part 5: why imports, exports, `ref.func`, public types, and continuations matter differently

These are all “blockers”, but not for exactly the same reason.

### Imports and exports

Binaryen does not own the full boundary, so it cannot freely delete params there.

### `ref.func`

A function reference may escape and be observed elsewhere, so the function becomes referenced.

### Public function types

Even in closed world, Binaryen does not globally rewrite public type roots here.

### Continuation and tag-related roots

The pass explicitly avoids rewriting those associated function-type trees today.

### `call.without.effects`

Not a general escape, but still a blocker because the pass does not yet know how to update that ABI/import surface correctly.

So the correct mental model is:

- multiple conservative walls feed into the same usage/type-tree constraints,
- but they are source-distinct walls, not one vague escape flag.

## Part 6: expression removal is wider than operand removal

Once a parameter is proven dead, Binaryen may need to remove more than the matching call operand.

Example shape, conceptually:

```wat
(call $callee
  (i32.add
    (local.get $dead)
    (i32.const 1)))
```

If the `i32.add` is only a pure forwarding wrapper around a dead param, removing the dead argument may also remove that wrapper.

So the optimizer tracks:

- the `local.get` of dead params that still read the incoming value,
- and then climbs outward through removable parents,
- stopping at calls or when the value is no longer just propagating.

That is why the pass stores `paramGets` and later uses `removedExpressions`-style bookkeeping in the optimizer.

## Part 7: but expression removal is *not* arbitrary tree erasure

There are explicit conservative limits.

### `if` conditions

The condition is always a real use because changing it can change the executed arm.

### Effectful parents

An effectful wrapper means the value is not safely “just forwarded”.
The param becomes used instead.

### Loops and structured wrappers with effects

Even when the dead value itself disappears, the surrounding structure may need to stay so effects still happen the correct number of times and in the correct order.

This is why many `dae2.wast` regressions look like:

- “remove the parameter, but keep the control scaffold”.

## Part 8: replacement types solve a very specific correctness problem

The biggest non-obvious correctness trap is this:

1. referenced and unreferenced functions may share a function type,
2. only the unreferenced ones should lose params,
3. but later global rewriting of referenced types could otherwise force the wrong optimized type onto the unreferenced siblings.

Binaryen solves that by assigning the unreferenced functions a `replacementType` first when needed.

The replacement type may be:

- an existing public type with the desired signature,
- an existing old type that will rewrite to the desired signature,
- or a freshly created unique rec-group type.

That means replacement types are not an optimization gimmick.
They are a **routing mechanism** for the later global type rewrite.

## Part 9: why `closed-world + GC` changes so much

Without that mode:

- referenced functions are conservatively treated as non-optimizable for the type-tree half,
- indirect/reference call reasoning is much weaker,
- and the pass mostly becomes an unreferenced direct cleanup.

With that mode:

- referenced functions can participate,
- indirect/reference callers can lose dead operands too,
- and the type graph itself may change.

So when reading a candidate `dae2` win, always ask first:

- is this a direct unreferenced-function case,
- or is this one of the closed-world + GC type-tree wins?

## Part 10: current non-goals explain several preserved shapes

The source comment and tests make it clear that some preserved shapes are deliberate.

### No result analysis yet

A param may disappear while result traffic remains unchanged.

### No constant propagation yet

A param that is constant across callers is **not** turned into a callee-local fact here the way plain `dae` can do.

### No param/result type propagation yet

The pass is not currently trying to tighten signatures by LUB or exactness inference.

### Conservative tuple handling

Tuple extraction can still count as use because the pass is not precise enough about tuple element tracking yet.

These are not omissions in the wiki; they are current upstream boundaries.

## Quick checklist for reading a `dae2` candidate

When you see a possible optimization, ask:

1. Is the incoming param value truly used, or only forwarded?
2. If forwarded, is it direct or indirect/reference forwarding?
3. Does a real use seed the reverse graph somewhere downstream?
4. Is the relevant function or type tree referenced?
5. Are public/tag/continuation/intrinsic boundaries blocking rewrite?
6. Would removal cross an `if` condition or effectful parent?
7. If referenced-function rewriting happens, does an unreferenced sibling need a replacement type?
8. Is this a result/constant/type-propagation idea that `dae2` does not even attempt yet?

## Bottom line

The hardest part of `dae2` is not deleting dead params.
It is correctly answering:

- which params are only part of a forwarding graph,
- which type trees may legally change,
- and how much surrounding expression structure must remain after the dead value itself disappears.
