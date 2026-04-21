---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0114-2026-04-20-rse-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
---

# `rse` CFG And Value Tracking

This page focuses on the easiest part of Binaryen `rse` to misunderstand:

- what exactly the pass thinks it knows about a local at any point
- how that knowledge merges across blocks
- why same-block reads often do **not** keep a set alive
- why loops stay conservative today

## The beginner mental model

Pretend every local has a sticky note attached to it.

The sticky note can say one of three things:

- **I know exactly what value is in this local**
- **I know several predecessor values might be here, but not one exact expression**
- **I do not trust any exact current value here**

Binaryen calls those states:

- `Value`
- `MergedValues`
- `Unseen`

That tiny lattice drives the whole pass.

## The `LocalInfo` record

For each local index, `rse` tracks:

| Field | Meaning |
| --- | --- |
| `curr` | current value state: `Unseen`, exact value, or merged-values set |
| `setses` | which `local.set`s or entry/self values still influence that current value |

So Binaryen is always keeping two related stories at once:

1. the **value story**
2. the **why-that-value-is-still-live story**

The first story enables substitution.

The second story enables dead-set elimination.

## Exact values vs merged values

### Exact value

If all known paths into the current point agree on one value number, `curr` is exact.

That means a later `local.get` may be replaceable.

### Merged values

If predecessors disagree, Binaryen stores a set of possible incoming values instead.

That still helps with influence bookkeeping, but it is no longer enough to materialize one exact replacement expression.

This is the key rule:

- merged knowledge is usually good enough for liveness bookkeeping
- merged knowledge is usually **not** good enough for exact `local.get` substitution

### Unseen

If the pass crossed a barrier or never learned a trustworthy exact value, it records `Unseen`.

Then it stops pretending it knows the current local contents precisely.

## Parameters start as “self” values

At function entry, parameters are not treated as mysterious unknowns.

Each parameter gets:

- its own unique value number
- a `Self` influence marker

That is why Binaryen can propagate parameter-derived locals the same way it propagates locals defined by earlier sets.

## Copied locals inherit history, not just syntax

Suppose the code does:

```wat
(local.set $y
  (local.get $x))
```

Binaryen does **not** merely remember:

- “`$y` was assigned the expression `local.get $x`”

It instead remembers:

- whatever exact current value `$x` had
- plus the same set-influence history that made `$x`'s current value live

That means later reads of `$y` behave as if `$y` were another view of `$x`'s current value.

This is a big reason the pass can remove copied-local traffic late in the pipeline.

## Block-entry merge examples

## Example 1: both predecessors agree

Conceptual shape:

```wat
(if
  (local.set $x (i32.const 1))
  (local.set $x (i32.const 1)))
(local.get $x)
```

Both incoming paths say `$x == 1`.

So Binaryen can keep exact current knowledge and may replace the later `local.get`.

## Example 2: predecessors disagree

Conceptual shape:

```wat
(if
  (local.set $x (i32.const 1))
  (local.set $x (i32.const 2)))
(local.get $x)
```

Now Binaryen only knows:

- `$x` is either `1` or `2`

That becomes `MergedValues`, not one exact current value.

The later `local.get` usually stays.

## Example 3: copied predecessor values still help

Conceptual shape:

```wat
(if
  (local.set $y (local.get $x))
  (local.set $y (local.get $x)))
(local.get $y)
```

Even though `$y` is not the original source local, Binaryen can still keep exact knowledge because both predecessors copied the same current value history into `$y`.

## Why same-block reads do not automatically keep a set alive

This is the most important mental shift.

A naive dead-store pass would think:

- “if I see a later `local.get`, then the earlier `local.set` must stay”

Binaryen's `rse` is smarter than that.

If all future reads of that value are in the **same basic block**, and Binaryen can replace those reads directly with the current expression, then the set itself does not need to survive.

That is why the pass tracks both:

- current values
- set->get influence edges

The get may still exist in the source program, but it no longer needs the local storage slot after substitution.

## Fallthrough matters

One more subtlety:

- a set may feed only same-block gets
- but if the set also influences the block's fallthrough value into later CFG successors,
- then the set still matters beyond the current block

So Binaryen consults block fallthrough information before deciding the set is truly dead.

That is why `Properties::getFallthrough(...)` matters to this pass.

## Non-linear barriers wipe the current-value sticky notes

Whenever Binaryen hits non-linear control flow, it clears the exact current-value cache.

The source uses this barrier around things like:

- branches
- control-flow structures

Beginner takeaway:

- `rse` reasons aggressively in straight-line code
- it becomes conservative at non-linear boundaries

This is not a weakness so much as the main correctness guardrail.

## Why loops stay conservative today

The source comment says the block-input model is not right in loops yet, so there is no point trying to optimize them here.

The easiest beginner summary is:

- ordinary predecessor merges are easy enough
- loop backedges behave more like a tiny dataflow fixpoint problem
- `rse` does not solve that problem in `version_129`

So upstream deliberately leaves those cases alone.

This is a real part of the contract, not a temporary accident the wiki should hide.

## GC refined values are still “current values” when types line up

The `rse-gc.wast` tests show that the “current expression” may be a refined GC expression such as:

- `ref.cast`
- `ref.as_non_null`

Binaryen may use that refined expression as the current replacement only when the expression's static type fits the `local.get` site.

That is why some GC tests are positive and others are negative:

- same semantic runtime value is not enough
- the replacement expression also has to be assignable to the use type

## Why `MergedValues` is not “mini CSE for all paths”

It is tempting to think of `MergedValues` as a little phi node that could still be reconstructed later.

That is not how this pass uses it.

`MergedValues` is mostly a conservative bookkeeping state.

It says:

- “I still know something about which values and sets might matter here”

not:

- “I can synthesize one exact replacement expression from those alternatives”

That distinction explains many of the preserved negative cases.

## The most important porting lesson from this page

If Starshine ports `rse`, it should first preserve this exact attitude:

- be precise in straight-line code
- merge only when predecessor agreement is real
- let same-block read substitution unlock dead-set elimination
- forget exact knowledge at non-linear barriers
- stay conservative on loops until a stronger proof exists

That is the real Binaryen flavor of the pass.

## Sources

- [`../../../raw/research/0114-2026-04-20-rse-binaryen-research.md`](../../../raw/research/0114-2026-04-20-rse-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- Binaryen `version_129` local graph helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- Binaryen `version_129` liveness helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/liveness.h>
- Binaryen `version_129` value numbering helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- Binaryen `version_129` properties helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- Binaryen `version_129` pass tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- Binaryen `version_129` GC lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
