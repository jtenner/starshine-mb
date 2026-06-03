---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md
  - ../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./parity.md
---

# `global-struct-inference`: closed-world analysis and un-nesting

This page covers the half of Binaryen `gsi` that is easiest to misunderstand. The raw source manifest is [`../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md`](../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md), with a 2026-05-06 current-main recheck in [`../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md); owner-file and test locations are mapped in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

This page covers:

- what closed world actually adds
- how subtype reasoning works
- when Binaryen emits a `select`
- when it gives up
- and how non-constant nested values still become optimizable through fresh globals

## Read this page with one mental model

Binaryen is trying to prove something very small:

- “this read can only come from one or two immutable global instances I understand well enough to substitute.”

If it cannot prove that cheaply, it leaves the read alone.

## Closed world does not mean "optimize everything"

Closed world adds a data structure:

- `typeGlobals`

That map says, roughly:

- for this struct heap type, these immutable globals are the only top-level creators Binaryen trusts

But the pass still prunes heavily.
Closed world does **not** mean:

- every struct type is trusted
- every read of a parent type is safe
- every many-global family is worth rewriting

## How a type becomes unoptimizable

Binaryen poisons a type when it sees creation patterns that break the simple immutable-global-origin story.

### Poison source 1: a `struct.new` in a function body

If a function allocates a value of type `$T`, then reads of `$T` can no longer be explained only by immutable globals.
So `$T` becomes unoptimizable.

### Poison source 2: a nested `struct.new` inside a global initializer

If a global contains a top-level `struct.new $Outer` but also nests a `struct.new $Inner` inside one of its operands, then `$Inner` is poisoned.

Why?
Because Binaryen is only trusting top-level immutable global creators here.
A nested creator means there is more internal structure and more possible origins than the simple type-to-global model wants to assume.

### Poison source 3: mutable globals

Mutable globals are excluded because the global instance itself is not a stable single immutable source of truth.

### Poison source 4: declared global type not comparable enough for `ref.eq`

If the global is declared too broadly, like `anyref`, Binaryen cannot safely use it in the one-compare `ref.eq` strategy that distinguishes candidate globals.

That is why the lit file has:

- `eqref` positives
- `anyref` negatives

## Why poison spreads upward to supertypes

A parent-typed read can observe child instances.
So if subtype `$Child` is poisoned, then reads of `$Parent` must assume `$Child` values might appear too.

That is why Binaryen propagates unoptimizability upward through declared supertypes.

### Beginner-safe rule

If one child type can be created somewhere outside the trusted immutable-global set, then a parent-typed read is no longer simple enough for `gsi` to explain.

## Why candidate globals also spread upward

The opposite direction matters too.

If child type `$Child` has a trusted immutable global `$gChild`, then a read of parent type `$Parent` might also see `$gChild`.
So Binaryen propagates candidate global names upward.

This is how it can optimize shapes like:

- `(param (ref null $Parent))`
- where the actual runtime value must be one of two child-type globals

without requiring the read itself to be typed as the exact child type.

## One global vs one value

These are not the same thing.

### One global

If there is exactly one candidate global for the read, Binaryen rewrites the **reference** to that global after preserving the null trap.

That is useful even when the field value is not constant, because later passes now see the exact origin.

### One value

If there are many candidate globals but they all yield the same field value, Binaryen can skip the origin distinction entirely and just return that value after preserving the null trap.

So the pass's logic is really about **possible values**, not just counts of possible globals.

## When Binaryen emits a `select`

Binaryen groups candidate globals by the value read from the requested field.
Then it asks a narrow question:

- can a single `ref.eq` pick between exactly two unique values?

That requires:

1. there are at most two unique values
2. if there are two, one value-group has exactly one global in it

### Positive case

If values look like:

- `$g1` -> `42`
- `$g2` -> `1337`
- `$g3` -> `1337`

then Binaryen can compare against `$g1` and emit:

- `select(42, 1337, ref.eq(ref, global.get $g1))`

### Negative case

If values look like:

- `$g1` -> `42`
- `$g2` -> `42`
- `$g3` -> `1337`
- `$g4` -> `1337`

then neither value-group is singleton.
A single compare is not enough, so Binaryen bails out.

## Why non-constant equal-looking expressions still fail

Binaryen only groups values aggressively when they are recognized as constant by `PossibleConstantValues`.

That includes:

- literal constant expressions
- immutable `global.get`s

But it does **not** mean arbitrary expression equivalence.

So two separate non-constant expressions like:

- `(i32.add (i32.const 41) (i32.const 1))`
- `(i32.add (i32.const 41) (i32.const 1))`

are not treated as the same grouped constant here.

That is why the test file says two identical-looking non-constant values do not help the multi-global select story by themselves.

## What un-nesting is really doing

The un-nesting mechanism is the pass's escape hatch for non-constant field operands.

Imagine this global:

```wat
(global $g (ref $S)
  (struct.new $S
    (i32.add (i32.const 41) (i32.const 1))))
```

The field value is not a constant literal or immutable-global name.
So Binaryen cannot materialize it directly as a grouped constant.

Instead it can split the nested operand out into a fresh immutable global:

```wat
(global $g.unnested.0 i32
  (i32.add (i32.const 41) (i32.const 1)))
(global $g (ref $S)
  (struct.new $S
    (global.get $g.unnested.0)))
```

Now the field value is a stable immutable `global.get`, which the rest of the machinery can use.

## Why un-nesting happens after the parallel walk

Binaryen optimizes functions in parallel, but adding globals mutates module structure.
So during the parallel phase it only records:

- which global to split
- which operand index or descriptor to split
- which placeholder `global.get` should later target the new global

Only after the parallel work is done does it:

- add the new globals
- retarget the placeholders
- rerun `reorder-globals-always`

That keeps the parallel walk simple and deterministic.

## Why `reorder-globals-always` is part of the contract

Fresh globals added during un-nesting must appear before uses in module order.
So Binaryen runs nested:

- `reorder-globals-always`

when any fresh globals were added.

This is not optional cleanup fluff.
It is what makes the transformed module valid and deterministic.

## Descriptor and cast surfaces nearby

Two related surfaces sit next to the main field-read story.

### `ref.get_desc`

Plain `gsi` already routes descriptor reads through the same optimizer.
So the pass is not just about ordinary fields.

### `gsi-desc-cast`

The sibling `gsi-desc-cast` mode can replace some `ref.cast` checks with descriptor-equality casts, but only when:

- the target type has a descriptor type
- there are no relevant strict subtypes unless the target is exact already
- the descriptor type maps to exactly one candidate global

This is useful context because it shows how much of the pass infrastructure is really about trusted global-origin descriptors, not only scalar field constants.

## Easy misunderstandings to avoid

### Misunderstanding 1: "Closed world means parent reads always optimize"

No.
Parent reads still fail when poisoned child allocations exist or when the value grouping would need more than one comparison.

### Misunderstanding 2: "Many globals always block optimization"

No.
Many globals are fine if they collapse to one unique value.
What matters is unique values and singleton testability, not raw count alone.

### Misunderstanding 3: "Non-constant fields are impossible for `gsi`"

No.
Non-constant fields can still optimize if Binaryen can un-nest them into fresh immutable globals.

### Misunderstanding 4: "Any struct-typed global can be used in `ref.eq`"

No.
The **declared global type** must be comparable enough for the `ref.eq`-based select strategy.
That is why `eqref` works and `anyref` does not.

## What a future Starshine port must preserve

A future parity-focused port must keep all of these rules explicit:

- function-local and nested-global allocations poison the relevant type families
- poisoning spreads upward to supertypes
- candidate globals also propagate upward to supertypes
- one global and one value are different optimization cases
- selects are only for at most two unique values with one singleton-tested group
- non-constant fields can still participate through un-nesting
- new globals created by un-nesting must be reordered before uses
- nearby descriptor/cast surfaces reuse the same trusted-global infrastructure

If local code intentionally keeps a smaller subset, the wiki should continue calling that out as a local limitation, not as the Binaryen contract. After the 2026-06-03 O4z audit and follow-up facts slices, that local subset is the open-world direct-global folder plus an analysis-only subtype-aware closed-world candidate/poison table described in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md), not the full `typeGlobals` rewrite, local/param rewrite, value grouping, select, or un-nesting engine described here.
