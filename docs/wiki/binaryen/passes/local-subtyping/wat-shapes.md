---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./lubs-and-dominance.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
---

# `local-subtyping` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `local-subtyping` pass.

## Read this page with one corrected mental model

After the 2026-04-22 source correction, the right beginner model is:

- Binaryen looks at the local's declaration and the concrete values written into it,
- computes one common narrower reference type,
- keeps that narrowing only when helper support and dominance permit it,
- then retags the declaration plus the matching `local.get` / `local.tee` expression types.

So the pass is **smaller** than the earlier local summary had implied.
It is not a broad use-and-def local inference pass.

## Important note about the examples

The `after` snippets below are **conceptual**.
They show the important declaration and expression-type changes, not the exact printer output of every surrounding expression.

## Quick glossary

- **wide local**: the original local declaration type is broader than the values written into it
- **narrow local**: the tighter type Binaryen wants after collecting definition facts
- **LUB**: the least upper bound of the declaration and the written-value facts
- **dominance-safe non-nullability**: the case where Binaryen can prove the non-null local state reaches all relevant gets

## Shape 1: all concrete writes already agree on one narrower type

Before:

```wat
(local $x anyref)
(local.set $x
  (struct.new $A ...))
(drop
  (local.get $x))
```

After, conceptually:

```wat
(local $x (ref null $A))
(local.set $x
  (struct.new $A ...))
(drop
  (local.get $x))
```

Why it rewrites:

- the declaration is wider than the concrete values written into the local
- the written values all agree on the same narrower reference type
- helper support allows the local type change

This is the simplest positive family.

## Shape 2: sibling subtype writes narrow only to the common parent

Before:

```wat
(local $x anyref)
(if
  (then
    (local.set $x
      (struct.new $Left ...)))
  (else
    (local.set $x
      (struct.new $Right ...))))
(drop
  (local.get $x))
```

After, conceptually:

```wat
(local $x (ref null $Parent))
```

Why it rewrites that way:

- Binaryen computes a LUB, not the narrowest individual leaf type
- both child structs fit under `$Parent`
- the declaration can still get narrower than `anyref`, just not all the way to either child leaf

This is the most important “LUB, not smallest leaf” shape.

## Shape 3: `local.tee` participates through its result type

Before:

```wat
(local $x anyref)
(drop
  (local.tee $x
    (struct.new $A ...)))
```

After, conceptually:

```wat
(local $x (ref null $A))
(drop
  (local.tee $x
    (struct.new $A ...)))
```

Why it matters:

- Binaryen records the tee's result type when collecting definition facts
- that means tee-written locals can narrow the same way as plain sets
- the tee expression type can then be retagged to match the narrower declaration

## Shape 4: non-nullability needs dominance, not just a non-null write

Before, conceptually:

```wat
(local $x (ref null $A))
(local.set $x
  (struct.new $A ...))
(drop
  (local.get $x))
```

Possible after, when every relevant get is dominated by non-null writes:

```wat
(local $x (ref $A))
(local.set $x
  (struct.new $A ...))
(drop
  (local.get $x))
```

Why it rewrites:

- the only improvement may be nullability
- Binaryen requires `LocalStructuralDominance` to prove the non-null state reaches the gets safely
- only then does it keep the non-null declaration

## Shape 5: an undominated get keeps the local nullable

Before, conceptually:

```wat
(local $x (ref null $A))
(drop
  (local.get $x)) ;; can happen before the non-null write is guaranteed
(local.set $x
  (struct.new $A ...))
```

After, conceptually:

```wat
(local $x (ref null $A))
```

Why Binaryen can keep it nullable:

- some get can still observe the older nullable state
- the dominance proof for non-nullability fails
- Binaryen therefore refuses to keep the stronger non-null declaration

This is the core dominance-gated negative family.

## Shape 6: gets alone do not narrow the declaration

Before and after stay the same in the important part:

```wat
(local $x anyref)
(call $needs_a
  (local.get $x))
```

Why Binaryen can keep it wide:

- the reviewed pass does not use gets as new evidence for narrowing
- definition-side facts drive the LUB, not consumer-side wishes

This is one of the biggest corrections in the refreshed dossier.

## Shape 7: `ref.as_non_null` alone is not a direct positive shape here

Before and after stay the same in the important part:

```wat
(local $x (ref null $A))
(drop
  (ref.as_non_null
    (local.get $x)))
```

Why Binaryen may keep it unchanged:

- the reviewed `version_129` pass does not collect evidence from `ref.as_non_null`
- that earlier local claim was an overread of the upstream source
- if this family becomes more optimizable, the enabling work belongs to other passes or a future deliberate scope expansion

## Shape 8: params are intentionally unchanged

Before and after stay the same in the important part:

```wat
(func $f (param $p anyref)
  (drop
    (local.get $p)))
```

Why Binaryen keeps it:

- the pass only handles non-parameter locals in `version_129`
- a faithful port should preserve that conservatism first

## Shape 9: tuple locals are intentionally unchanged

Before and after stay the same in the important part:

```wat
(local $pair (tuple i32 i64))
```

Why Binaryen keeps it:

- `TypeUpdating::canHandleAsLocal(...)` rejects tuple types here
- this pass only updates helper-supported locals

## What a future Starshine port must preserve

If Starshine ports `local-subtyping`, these are the shape truths worth preserving first:

1. narrow only non-parameter reference locals
2. skip tuple locals unless helper support grows
3. use declaration-seeded, def-fed LUB narrowing rather than aggressive leaf picking
4. treat `local.tee` as part of the definition surface
5. require dominance before keeping a non-nullability improvement
6. do not pretend `local.get` or `ref.as_non_null` are direct positive shapes in the reviewed upstream oracle
7. keep the `optimize-casts -> local-subtyping -> coalesce-locals` neighborhood explicit
