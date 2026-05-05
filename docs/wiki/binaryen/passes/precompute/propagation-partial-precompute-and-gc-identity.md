---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/research/0468-2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/research/0132-2026-04-20-precompute-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
---

# `precompute`: propagation, partial precompute, and GC identity

This page covers the three parts of Binaryen `precompute` that are easiest to underestimate:
A 2026-05-05 current-main recheck kept this split and the GC-identity / emitability story stable on the reviewed surfaces.

1. `precompute` and `precompute-propagate` are not the same pass mode
2. partial precompute is a separate upward-moving algorithm, not a minor special case
3. GC identity and emitability are what keep the pass from making unsound “constant” claims

## The biggest beginner misunderstanding

The easy wrong model is:

- `precompute` looks only at one expression at a time and folds it if every child is already constant

The real model is:

- Binaryen can evaluate an expression semantically,
- optionally learn constant local facts and propagate them,
- and in some cases even push parent computation into a `select`'s arms.

That is a much more powerful and much more constrained pass than the name suggests.

## Part 1: `precompute` versus `precompute-propagate`

## Plain `precompute`

The plain pass does two things:

- the main compile-time execution walk
- partial precompute when optimize level allows it

It does **not** do local-flow propagation.

## `precompute-propagate`

The propagate variant does all of the above and then also:

- uses `LazyLocalGraph` to discover constant sets and gets
- records concrete values for specific `local.get`s in `getValues`
- reruns the main walk once if any propagation succeeded

That extra work is why upstream Binaryen exposes a second CLI pass name instead of treating propagation as an invisible implementation detail.

## Why the scheduler uses both names

In `version_129`:

- top-level no-DWARF `-O` / `-Os` uses plain `precompute`
- more aggressive top-level settings use `precompute-propagate`
- `optimizeAfterInlining(...)` also prepends `precompute-propagate` in nested cleanup reruns

So a future parity model must preserve both stories:

- plain top-level no-DWARF slots
- propagated aggressive and nested slots

## Part 2: propagation is really “all reaching sets agree”

## What `LazyLocalGraph` provides

`LazyLocalGraph` gives the pass three crucial query families:

- `getSets(get)`
  - which `local.set`s can reach a `local.get`
- `getSetInfluences(set)`
  - which gets may read from a set
- `getGetInfluences(get)`
  - which sets may depend on a get

Binaryen uses those queries lazily because most local traffic never becomes provably constant.

## How constant sets are discovered

For each `local.set`, Binaryen tries to precompute the **fallthrough** value of the set expression.

This matters because the value of a set may be easier to reason about than the exact wrapper syntax around it.

Example idea:

```wat
(local.set $x
  (local.tee $y
    (i32.const 7)))
```

The whole expression is not a simple constant node, but the fallthrough value is still the constant `7`.

That is why the pass uses `Properties::getFallthrough(...)`.

But it also checks one more thing:

- the propagated constant must be a valid subtype of the full set expression's type

That avoids unsound propagation in reference-typed cases where a child looked concrete but the surrounding cast or wrapper means that value cannot safely substitute for the full expression.

## How constant gets are discovered

A `local.get` becomes constant only if **all** reaching sets agree on the same concrete value.

This is more conservative than a lot of beginner descriptions of constant propagation.

Binaryen is not asking:

- “did we see *a* constant set?”

It is asking:

- “do all possible incoming sets give the exact same concrete value?”

That is why these families differ:

### Positive family

```wat
(local.set $x (i32.const 7))
(local.get $x)
```

Here every reaching set agrees.

### Negative family

```wat
(if (local.get $cond)
  (then (local.set $x (i32.const 7)))
  (else (local.set $x (i32.const 9))))
(local.get $x)
```

Now the get has two reaching sets with different values, so propagation stops.

### Default-entry family

If a local variable has no reaching set on some path, Binaryen treats that as the function-entry default value.

That is important for wasm locals because their default value is real semantic input.

### Parameter family

If the local is actually a parameter, Binaryen gives up.

A parameter's incoming value is not a compile-time constant just because there are no in-function sets yet.

### Nondefaultable-local family

If the local is nondefaultable and a missing-set path appears, Binaryen gives up rather than inventing a value.

## The worklist is intentionally bounded

Once a set or get becomes constant, it enters a worklist.

Binaryen then checks:

- gets influenced by that set
- sets influenced by that get

This can unlock chains like:

```wat
(local.set $x (i32.const 7))
(local.set $y (local.get $x))
(i32.add (local.get $y) (i32.const 1))
```

But the pass does not rebuild the whole graph repeatedly.

If propagation finds anything at all, Binaryen just reruns the main walk **once** and stops there. Rarer deeper fixed points are left for later executions of the pass or for `--converge`.

That boundedness is part of the design, not a missing optimization.

## Part 3: partial precompute is really a parent-into-`select` algorithm

## The idea in one sentence

Binaryen can sometimes simplify a parent by pretending the `select` chose the left arm, then simplifying the same parent again pretending it chose the right arm, and finally rebuilding a better `select`.

## The basic shape

Before:

```wat
(i32.eqz
  (select
    (i32.const 42)
    (i32.const 1337)
    (local.get $cond)))
```

After:

```wat
(select
  (i32.const 0)
  (i32.const 0)
  (local.get $cond))
```

What changed:

- Binaryen did **not** precompute the whole `select`
- Binaryen precomputed the parent operation separately on each arm

## Why this is not just one-parent-at-a-time

The source explicitly explains that incremental success is not enough.

A useful GC example is:

```wat
(struct.get $outer-field
  (struct.get $inner-field
    (select
      (global.get $A)
      (global.get $B)
      ...)))
```

One inner `struct.get` by itself might land on a GC interior object that cannot be emitted as a constant.
But applying **both** `struct.get`s together may land on a scalar value that can be emitted.

So Binaryen walks upward through the parent stack and tries:

- immediate parent only
- parent plus grandparent
- and so on

That is why the algorithm lives outside the main walk in its own stack-aware phase.

## What qualifies as a promising `select`

Binaryen only considers a `select` when:

- optimize level is at least `2`
- both arms pass `Properties::isValidConstantExpression(...)`
- the `select` is not the whole function body

That is a very specific definition of “promising.”

It is not trying every `select` in the function.

## Why control-flow parents stop the climb

As the pass climbs through parents above the `select`, it stops if a parent is:

- non-concrete
- tuple-typed
- a control-flow structure

That is because the pass wants to build a **new `select`** with concrete arms. Once the parent itself becomes something like a block/if/try or otherwise lacks a concrete single-value type, the “push parent into each arm” model stops being clean and worthwhile.

## Why a temporary heap cache is necessary

During those speculative parent evaluations, Binaryen uses a temporary `HeapValues` cache.

This is one of the most important correctness details in the entire pass.

If speculative evaluation of a parent+arm combination were allowed to update the global heap cache, then a later normal evaluation might incorrectly reuse information from a path that only existed inside speculation.

The shipped `precompute-propagate-partial.wast` documents a concrete trap-sensitive example:

- speculative partial evaluation may avoid a trap that the real expression would still hit
- if that speculative result polluted the global heap cache, a later ordinary pass step could incorrectly erase the real trap

So the temporary cache is not an optimization detail.
It is a semantic isolation rule.

## Part 4: GC identity is not the same as GC contents

## Why the pass tracks `GCData`

For GC references, the pass cares about identity-sensitive operations such as `ref.eq`.

If it only remembered field contents, then these two could be confused:

```wat
(ref.eq
  (struct.new $empty)
  (struct.new $empty))
```

Even though the fields match, the two allocations are different runtime objects, so the result is `0`.

The pass solves this by tracking canonical `GCData` identities for heap allocations.

### Positive identity family

```wat
(local.tee $x
  (struct.new $empty))
(ref.eq
  (local.get $x)
  (local.get $x))
```

This can become `1` because the same identity flows to both sides.

### Negative identity family

```wat
(ref.eq
  (struct.new $empty)
  (struct.new $empty))
```

This becomes `0`, not `1`, because the allocations are distinct.

### Merge/loop uncertainty family

If a merge or loop means that a ref may refer to more than one incoming allocation, the pass stops claiming one precise identity.

That is why the GC loop tests distinguish:

- loops where the same allocation definitely survives
- loops where each iteration may create a different allocation

## Part 5: emitability is an equally important boundary

Binaryen may know the result of an expression, but still be unable to replace the original code if that result cannot be emitted as a legal constant expression.

In `version_129`, the pass can directly emit:

- numbers
- null refs
- function refs
- valid UTF-16 string constants

It cannot directly emit arbitrary non-null GC refs.

That explains a surprising but correct family:

- the pass may prove an immutable nested `struct.get` reaches a known object
- but if the result is a non-null GC reference that is not a function or string constant, the pass may still decline to replace the expression directly

This is why some tests say, in effect:

- “we know more than we can re-emit”

That distinction is central to understanding the pass.

## Part 6: the three tricky ideas work together

These three surfaces are not independent.

A real `precompute-propagate` run can combine all of them:

1. main walk proves some local-set fallthroughs are constant
2. propagation gives specific `local.get`s concrete values
3. that new knowledge makes a parent stack around a `select` partially precomputable
4. GC identity caching makes ref comparisons or immutable nested-field reads safe during that work
5. emitability still decides whether the final replacement is legal

That is why the pass is much richer than a simple arithmetic folder.

## Bottom line

The safest mental model for Binaryen `precompute` is:

- **main semantic evaluation**
- **plus optional local-flow propagation**
- **plus optional upward partial precompute through `select`**
- **all constrained by heap identity, trap safety, and what values can actually be emitted back into IR**

If a future Starshine port loses any one of those boundaries, it will end up either too weak or unsound.
