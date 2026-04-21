---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./two-phase-dataflow.md
  - ../heap2local/index.md
---

# `optimize-casts` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `optimize-casts` pass.

## Read this page with one mental model

Binaryen is not asking:

- “where are there casts?”

It is asking two narrower questions:

1. **can I safely make the best cast available earlier?**
2. **can later uses reuse a casted value that already exists?**

That is why many shapes below come in pairs.

## Quick glossary

- **wide local**: the original local with a less refined reference type
- **narrow local**: the fresh local Binaryen creates to hold a more refined casted value
- **earlier-motion phase**: the part of the pass that duplicates a cast to an earlier `local.get`
- **later-reuse phase**: the part that stores a cast in a fresh local and redirects later gets to that local
- **linear window**: the straight-line execution region `LinearExecutionWalker` is willing to treat as one chunk
- **barrier**: an instruction or control-flow boundary that forces Binaryen to stop carrying cast facts across it

## Shape 1: a later `local.get` can reuse an already-computed `ref.cast`

Before:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
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
```

Why it rewrites:

- the cast already exists
- the later get reads the same local value
- using the refined local is better than going back to the wider one

Important nuance:

- the original cast site stays where it was
- Binaryen adds a fresh local and reuses that

## Shape 2: a better cast may be duplicated to the earliest safe get

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
    (local.get $x)))
```

Why it rewrites:

- the later cast is the best known cast for `$x`
- there is an earlier get of `$x` in the same strict linear window
- no barrier makes earlier motion unsafe

Important nuance:

- the pass often leaves the original later cast in place for later cleanup
- it is optimizing availability first, not minimizing syntax immediately

## Shape 3: Binaryen prefers the most refined subtype

Before:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
(drop
  (ref.cast (ref $B)
    (local.get $x)))
(drop
  (local.get $x))
```

Assume `$B <: $A`.

After, conceptually, the last use prefers `$B`.

Why it rewrites that way:

- the pass always tries to keep the narrowest known compatible cast
- a later `ref.cast (ref $B)` beats an earlier `ref.cast (ref $A)` for reuse

This is one of the main ways the pass helps later GC/local optimization work.

## Shape 4: `ref.as_non_null` is in scope when the local is nullable

Before:

```wat
(drop
  (local.get $x))
(drop
  (ref.as_non_null
    (local.get $x)))
```

After, conceptually:

```wat
(local $tmp (ref struct))
(drop
  (local.tee $tmp
    (ref.as_non_null
      (local.get $x))))
```

Why it rewrites:

- the original local is nullable
- the `ref.as_non_null` really carries a better fact
- a non-null local is worth reusing later

## Shape 5: `ref.as_non_null` is ignored when the target is already non-nullable

Before and after stay the same in the important part:

```wat
(drop
  (local.get $x))
(drop
  (ref.as_non_null
    (local.get $x)))
```

where `$x` already has a non-nullable type.

Why Binaryen keeps it:

- duplicating `ref.as_non_null` to another non-nullable use would add no useful information

This is an easy place to overestimate the pass.

## Shape 6: a same-index `local.set` is a hard barrier

Before and after stay the same in the important part:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
(local.set $x
  (call $new_value))
(drop
  (local.get $x))
```

Why Binaryen stops:

- after the `local.set`, `$x` no longer means the same value
- the old refinement fact is dead

This is one of the most important bailout shapes for a future port.

## Shape 7: a side effect can block earlier motion without blocking later reuse

Before:

```wat
(drop
  (local.get $x))
(global.set $g
  (i32.const 1))
(drop
  (ref.cast (ref $A)
    (local.get $x)))
```

Why Binaryen does **not** move the cast earlier:

- the cast can trap
- `global.set` is a visible side effect
- moving the cast earlier could change whether the side effect happens before the trap

But this different shape can still reuse later:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
(global.set $g
  (i32.const 1))
(drop
  (local.get $x))
```

Why later reuse is still OK:

- the cast itself stays where it was
- the pass is only redirecting the later get to a new narrow local

This asymmetry is the heart of the pass.

## Shape 8: calls block earlier motion, but later reuse may still cross them

Before:

```wat
(drop
  (local.get $x))
(call $maybe_exits)
(drop
  (ref.cast (ref $A)
    (local.get $x)))
```

Why Binaryen does **not** move the cast earlier:

- the call might prevent the later cast from executing at all
- moving the cast earlier could therefore introduce a new earlier trap

But this shape can still reuse later:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
(call $maybe_exits)
(drop
  (local.get $x))
```

Why Binaryen may still rewrite the last get:

- the cast stays at its old location
- if the call exits, the later get does not run either
- if the later get does run, the cast has already executed

## Shape 9: unnamed blocks and `local.tee` can still participate

Before:

```wat
(drop
  (ref.cast (ref $A)
    (block (result (ref struct))
      (local.get $x))))
(drop
  (local.get $x))
```

Why it can rewrite:

- `Properties::getFallthrough` can see through the unnamed block’s falling-through value

And this shape is also meaningful:

```wat
(drop
  (ref.cast (ref $A)
    (local.tee $y
      (local.get $x))))
(drop
  (local.get $y))
```

Why it can rewrite:

- the pass treats the tee carrier as important state, not just the underlying get

## Shape 10: separate local indices are tracked separately

Before:

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

Why Binaryen can still help `$y`:

- the write to `$x` kills facts about `$x`
- it does not kill facts about `$y`

This is why the tests include separate-index cases rather than only one-local examples.

## Shape 11: non-linear control flow resets the window

Before and after stay the same in the important part:

```wat
(drop
  (ref.cast (ref $A)
    (local.get $x)))
(if
  (i32.const 0)
  (then
    (return)))
(drop
  (local.get $x))
```

Why Binaryen keeps it:

- the `if` breaks the simple linear window
- this pass does not use a full CFG / dominance proof here

So a cast in one region and a use in another region are often **not** enough by themselves.

## Shape 12: incompatible types are a bailout, not a challenge

Before and after stay the same in the important part:

```wat
(local.set $a
  (local.get $x))
(drop
  (ref.cast (ref $D)
    (local.get $x)))
```

where `$a` is typed as some incompatible or wider unrelated reference.

Why Binaryen refuses to move the cast earlier:

- the earlier target must remain type-correct
- the pass only moves casts when the cast type is safely related as a subtype of the target get’s type

This is an important soundness guard.

## Shape 13: the pass name is broader than the actual rewrite surface

Before and after stay the same for these families:

```wat
(ref.test (ref $A)
  (local.get $x))
```

```wat
(br_on_cast $l
  (ref $A)
  (local.get $x))
```

```wat
(any.convert_extern
  (local.get $x))
```

Why Binaryen keeps them:

- `optimize-casts` in `version_129` does not rewrite those forms
- extern conversions are explicitly excluded from cast-style fallthrough handling
- the actual implementation only visits `RefCast` and `RefAs`

This is the single easiest way to misdescribe the pass if you only read its name.

## What later passes tend to do with the new shape

`optimize-casts` often creates temporary local traffic on purpose.

### Unlock family 1: `local-subtyping`

Because more uses now already point at narrower locals, later local-type narrowing has cleaner facts to work with.

### Unlock family 2: `coalesce-locals`

Some of the extra carrier locals can later be merged if their lifetimes and types permit it.

### Unlock family 3: `simplify-locals`

Once the refined value is available in the right places, later local cleanup can remove or simplify some of the carrier traffic.

### Unlock family 4: `local-cse` and `rse`

Those later passes can profit from the cleaner, more explicit refined-value flow even though they are not doing the same job themselves.

## A simple rule of thumb

When you look at a possible `optimize-casts` candidate, ask these questions in order:

1. Is this really a `ref.cast` or `ref.as_non_null` family?
2. Is the pass trying to move the cast earlier, or only reuse it later?
3. Are we still inside the linear window Binaryen is willing to reason about?
4. Has the same local index been written in between?
5. Would moving the cast earlier change trap timing across a side effect or call?
6. Is the refined type actually a subtype of the target get’s current type?

If any answer is “no,” expect Binaryen to keep the original shape.

## Source strength note

- The positive and negative shapes above come directly from Binaryen's shipped `optimize-casts` lit tests plus the current `version_129` implementation comments and helper contracts.
- The unlock examples are derived explanations of why the pass sits where it does in the GC/local cleanup cluster.

## Sources

- [`../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md`](../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md)
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>