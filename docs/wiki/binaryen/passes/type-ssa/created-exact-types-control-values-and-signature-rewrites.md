---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0217-2026-04-21-type-ssa-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# `type-ssa`: created exact types, control values, and signature rewrites

This page covers the easiest part of `type-ssa` to misread.
The pass name sounds broad, but the real `version_129` contract is mostly three small ideas:

1. decide which values count as **created exact types**,
2. decide when control wrappers carry one of those values unchanged,
3. push that precision into later locals, globals, calls, and returns.

## 1. What counts as a created exact type?

The answer is narrower than many readers expect.

The helper `getTargetType(...)` rejects:

- non-reference types,
- `anyref`,
- `eqref`,
- `i31ref`,
- `none`.

If a type survives that filter:

- an already-exact reference stays exact,
- a nonexact concrete reference becomes the same heap type but **exact + non-null**.

So the pass starts from a very specific invariant:

- “this value was just created as a concrete exact heap-typed reference.”

## 2. Where do those created exact types come from?

The seed surface is tiny.
Binaryen records created exact types for:

- `struct.new`
- `array.new`
- `array.new_fixed`
- `ref.as_non_null`
- `ref.cast`

That is why `type-ssa` feels smaller than its name.
It is not discovering precision everywhere.
It is protecting precision that was already made obvious by constructor-like or cast-like instructions.

## 3. How do control wrappers carry the precision?

The helper `getValue(...)` is the real control-flow rulebook.

### `block`

A `block` value comes from its last child.
So if the last child carries a created exact type, the block can carry it too.

### `if`

An `if` only forwards the precision when both arms produce values with the **same** created type.
If the arms disagree, Binaryen keeps the broader original type.

This is a very important beginner correction.
The pass is not doing arbitrary join inference.
It wants exact agreement.

### `try`

The same idea applies to `try` results.
The `do` body or catch bodies can carry a created type upward only when the reviewed helper finds one stable carried value.

### `loop`

`loop` is the cleanest explicit non-goal.
The helper returns no carried value for loops.
So `type-ssa` does not try to forward created exact types through loop values.

## 4. How does local/global propagation work?

Once a carried value has a remembered created type:

- `local.set` records that type for the set,
- `global.set` does the same.

Later:

- `local.get` can be retagged to that type,
- `global.get` can be retagged too.

The get keeps its original nullability.
So the main win is usually:

- more specific heap type,
- often exactness,
- without blindly forcing a different nullable/nonnullable story than the use site already had.

## 5. Why are call operands and returns part of the pass?

This is another place the pass is easy to undersell.
The precision does not stop at local or global loads.

The pass also looks at:

- direct call operands,
- return values.

If a remembered created type is a subtype of the expected parameter or result type, Binaryen rewrites the expression type there too.

That matters because later optimizations can only benefit if the sharper type is visible at the program edges where other passes read it.

## 6. What the pass refuses to do

It is just as important to remember the refusals.

The reviewed `version_129` pass does **not**:

- build general SSA form,
- reason about loops as value carriers,
- infer new exactness for abstract refs like `anyref` or `eqref`,
- merge different branch-created types into one new invented exact type,
- or consume a whole-program content oracle.

Those non-goals keep the pass small and predictable.

## A compact mental checklist

If you want to predict whether `type-ssa` helps on a shape, ask these questions in order:

1. Was the value freshly created by one of the tiny seed instructions?
2. Is the type concrete enough to survive `getTargetType(...)`?
3. If it flows through control, do the carried-value rules still see one stable exact type?
4. If it reaches a local/global get, call argument, or return, is the narrower type subtype-safe there?

If all four answers are yes, `type-ssa` is likely to rewrite the visible type.
If any answer is no, Binaryen usually preserves the broader original type.

## Why this matters next to `type-merging`

This page also clarifies the comment already cited in the `type-merging` dossier.
`type-ssa` creates distinctions because it keeps exact created types visible longer.
Later, `type-merging` may remove declaration-level distinctions that no longer matter.

So the two passes are not competitors.
They act at different times and on different layers:

- `type-ssa` sharpens **uses**,
- `type-merging` compacts **declarations**.
