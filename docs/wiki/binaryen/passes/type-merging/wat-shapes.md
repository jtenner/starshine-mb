---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md
  - ../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-merging.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./dfa-partitions-casts-and-refinalization.md
  - ./starshine-strategy.md
---

# `type-merging` WAT and module shapes

This page is the beginner-friendly shape catalog for Binaryen `type-merging`.
It is anchored to the 2026-04-24 primary-source manifest in [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md) and cross-links the current Starshine status page in [`./starshine-strategy.md`](./starshine-strategy.md).

The pass is module-shaped, so many of the most important "shapes" are really **type-graph patterns**, not tiny one-expression peepholes.

## Reading rule

When the examples say a type "merges", Binaryen means:

- all module references to that type are rewritten to a chosen target type
- the redundant private declaration identity disappears into the target
- expression typing may be refinalized afterwards

## Positive family 1: direct subtype adds nothing new

```wat
(type $A (sub (struct (field i32))))
(type $B (sub $A (struct (field i32))))
```

Typical outcome:

- `$B` can merge into `$A`

Why:

- same top-level shape
- no extra field
- no refined field type/nullability
- no cast barrier
- private candidate

## Positive family 2: multi-level chain collapse

```wat
(type $A (sub (struct (field i32))))
(type $B (sub $A (struct (field i32))))
(type $C (sub $B (struct (field i32))))
```

Typical outcome:

- `$B -> $A`
- `$C -> $A`

Why:

- repeated safe supertype merges collapse the whole chain

## Positive family 3: child convergence unlocks parent merge

```wat
(type $X (sub (struct)))
(type $Y (sub $X (struct)))
(type $A (sub (struct (field (ref null $X)))))
(type $B (sub $A (struct (field (ref null $Y)))))
```

Typical outcome:

- `$Y` can merge into `$X`
- then `$B` can merge into `$A`

Why:

- the field refinement stops mattering once the child type distinction disappears too

This is the classic family that requires graph reasoning instead of shallow comparison.

## Positive family 4: recursive subtype chain

```wat
(type $A (sub (struct (field (ref null $A)))))
(type $B (sub $A (struct (field (ref null $B)))))
```

Typical outcome:

- `$B` can merge into `$A`

Why:

- the recursive child position stays equivalent under the graph model

## Positive family 5: mutually recursive paired chains

```wat
(rec
  (type $A (sub (struct (field (ref null $X)) (field i32))))
  (type $B (sub $A (struct (field (ref null $Y)) (field i32))))
  (type $X (sub (struct (field (ref null $A)) (field f32))))
  (type $Y (sub $X (struct (field (ref null $B)) (field f32))))
)
```

Typical outcome:

- `$B -> $A`
- `$Y -> $X`

Why:

- the two recursive chains are equivalent as pairs

## Positive family 6: sibling merge after earlier parent merge

```wat
(rec
  (type $A (sub (struct anyref)))
  (type $B (sub $A (struct anyref)))
  (type $C (sub $A (struct anyref)))
  (type $D (sub $B (struct eqref)))
  (type $E (sub $C (struct eqref)))
)
```

Typical outcome:

- `$B` and `$C` merge into `$A`
- then `$D` and `$E` become siblings and can merge too

Why:

- repeated sibling rounds are needed to expose later equivalences

## Positive family 7: arrays participate too

```wat
(type $intarray (sub (array (mut i32))))
(type $sub-intarray (sub $intarray (array (mut i32))))
```

Typical outcome:

- `$sub-intarray -> $intarray`

Why:

- same element type and mutability
- no extra observable distinction

## Positive family 8: function heap types participate too

```wat
(type $func (sub (func (param eqref))))
(type $sub-func (sub $func (func (param eqref))))
```

Typical outcome:

- `$sub-func -> $func`

Why:

- same param/result shape
- no extra observable distinction

## Positive family 9: private subtype below public parent

```wat
(type $A (sub (func)))      ;; public
(type $B (sub $A (func)))   ;; public
(type $C (sub $B (func)))   ;; private
```

Typical outcome:

- `$C -> $B`
- `$A` and `$B` stay

Why:

- public types are preserved as identities
- private descendants may still merge into them

## Bailout family 1: subtype adds a field

```wat
(type $A (sub (struct (field anyref))))
(type $C (sub $A (struct (field anyref) (field f64))))
```

Typical outcome:

- keep `$C`

Why:

- added field is an observable shape change

## Bailout family 2: field nullability refines

```wat
(type $A (sub (struct (field (ref null $X)))))
(type $C (sub $A (struct (field (ref $X)))))
```

Typical outcome:

- keep `$C`

Why:

- non-null field is a stronger contract than nullable field

## Bailout family 3: field heap type refines

```wat
(type $X (sub (struct anyref)))
(type $Y (sub $X (struct eqref)))
```

Typical outcome:

- keep `$Y`

Why:

- field heap type refinement remains observable

## Bailout family 4: final/open-state mismatch

```wat
(type $A (sub (struct (field anyref))))
(type $G (sub final $A (struct (field anyref))))
```

Typical outcome:

- keep `$G`

Why:

- final/open state is part of the top-level shape

## Bailout family 5: cast barrier

```wat
(drop
  (ref.cast (ref null $F)
    (local.get $a)
  )
)
```

Typical outcome:

- keep `$F` distinct

Why:

- a cast site still observes `$F` as a meaningful identity

## Bailout family 6: `ref.test` barrier

```wat
(ref.test (ref $B)
  (local.get $a)
)
```

Typical outcome:

- keep `$B` distinct

Why:

- `ref.test` is an explicit runtime type observation

## Bailout family 7: `br_on_cast` barrier

```wat
(br_on_cast $label (ref $A) (ref $B)
  (local.get $a)
)
```

Typical outcome:

- keep `$B` distinct

Why:

- the branch-on-cast still distinguishes the subtype

## Bailout family 8: `call_indirect` barrier

```wat
(call_indirect (type $B)
  (i32.const 0)
)
```

Typical outcome:

- keep `$B` distinct

Why:

- indirect-call type identity still matters unless traps-never-happen mode removes that distinction

## Bailout family 9: public type identity

```wat
(export "foo" (func $foo))
```

Typical outcome:

- the exported/public type stays even if a private cousin is structurally equal

Why:

- public visibility is a hard preserve boundary

## Known-limitation family: private-under-public opportunity left on table

The official lit file includes a TODO case where a private subtype under a public type could, in principle, merge, but Binaryen currently does not find the merge because public-state successors are not encoded deeply enough in the DFA.

Beginner summary:

- not every apparently-safe merge is implemented
- this one is a documented upstream limitation, not a mystery

## Refinalization family: exact result gets sharper after merging

```wat
(drop
  (select (result (ref $super))
    (struct.new_default $subA)
    (struct.new_default $subB)
    (i32.const 0)
  )
)
```

Typical outcome after `$subA` and `$subB` both merge to the same target:

- the result type can sharpen to an exact reference type
- Binaryen refinalizes the IR accordingly

Why this matters:

- it proves the pass is not just changing declarations
- expression types can become more precise too

## Best short prediction rule

A type is a good merge candidate only if all of these feel true:

- it is private
- it does not add a real shape difference that still matters
- no cast/test/indirect-call site distinguishes it
- its child references either already match or will also converge under the graph solver
- merging direction stays ancestor-safe

If any of those fail, Binaryen usually preserves the type.

## Sources

- [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md)
- [`../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md`](../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md`](../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-merging.wast>
