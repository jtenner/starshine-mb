---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md
  - ../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./normal-vs-gufa-and-fixups.md
  - ./starshine-strategy.md
---

# `type-refining` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen `type-refining`.

## Read this page with one mental model

Binaryen is usually trying to do one of four things here:

1. infer a narrower field type from writes
2. preserve nullability and subtype legality
3. avoid touching public types
4. repair reads and writes that the narrower field type would otherwise break

So the pass is not just a declaration rewrite.
It is a declaration rewrite **plus code repair**.

## Important note about the examples

These examples are conceptual.
Real Binaryen output may:

- renumber type indices
- add `ref.cast`
- insert `drop` + `unreachable` wrappers
- refine surrounding control-flow result types after `ReFinalize`

So read the shapes as semantic before/after families, not exact pretty-print templates.
For current Starshine implementation status and local fixture caveats, see [`./starshine-strategy.md`](./starshine-strategy.md).

## Shape 1: direct subtype write refines a private field

Before, conceptually:

```wat
(module
  (type $S (struct (field (mut anyref))))
  (func (param $s (ref $S))
    (struct.set $S 0
      (local.get $s)
      (ref.i31 (i32.const 0)))))
```

After, conceptually:

```wat
(module
  (type $S (struct (field (mut i31ref))))
  (func (param $s (ref $S))
    (struct.set $S 0
      (local.get $s)
      (ref.i31 (i32.const 0)))))
```

Why:

- the field is private
- the only relevant writes are `i31ref`
- no public-boundary rule blocks the refinement

This is the most basic positive family.

## Shape 2: default construction keeps a field nullable

Before, conceptually:

```wat
(module
  (type $S (struct (field (mut anyref))))
  (func (param $s (ref $S))
    (drop (struct.new_default $S))
    (struct.set $S 0
      (local.get $s)
      (ref.i31 (i32.const 0)))))
```

After, conceptually:

```wat
(module
  (type $S (struct (field (mut i31ref))))
  ...)
```

If the field's declared type is nullable, the durable rule is:

- default values preserve **nullability**
- but they do not automatically keep a wide heap type like `anyref`

That is why Binaryen can still refine the heap type part while keeping the field nullable when needed.

## Shape 3: explicit null plus precise non-null writes often becomes `ref null T`

Before, conceptually:

```wat
(module
  (type $S (struct (field (mut (ref null struct)))))
  (type $C (sub $S (struct)))
  (func (param $s (ref $S)) (param $c (ref $C))
    (struct.set $S 0 (local.get $s) (local.get $c))
    (struct.set $S 0 (local.get $s) (ref.null none))))
```

After, conceptually:

```wat
(module
  (type $S (struct (field (mut (ref null $C)))))
  ...)
```

Why:

- Binaryen tracks that null is possible
- but the non-null values are still always `$C`
- so the field can become “nullable `$C`” instead of “nullable anything struct-like”

## Shape 4: a same-field copy does not block refinement

Before, conceptually:

```wat
(module
  (type $S (struct (field (mut structref))))
  (func (param $s (ref $S))
    (struct.set $S 0
      (local.get $s)
      (local.get $s))
    (struct.set $S 0
      (local.get $s)
      (struct.get $S 0 (local.get $s)))))
```

After, conceptually:

```wat
(module
  (type $S (struct (field (mut (ref $S)))))
  ...)
```

Why:

- the second write is just copying the same field back into itself
- `noteCopy(...)` treats that as adding no new requirement

This is one of the most useful beginner corrections.
Not every self-copy keeps the old wide type alive.

## Shape 5: child writes can force parent refinement

Before, conceptually:

```wat
(module
  (rec
    (type $A (struct (field (ref $X))))
    (type $B (sub $A (struct (field (ref $X)))))
    (type $Y (sub $X (struct))))
  (func
    (drop
      (struct.new $B
        (struct.new_default $Y)))))
```

After, conceptually:

```wat
(module
  (rec
    (type $A (struct (field (ref (exact $Y)))))
    (type $B (sub $A (struct (field (ref (exact $Y)))))))
  ...)
```

Why:

- `struct.new` facts propagate upward to supertypes
- the parent field has no competing writes
- so Binaryen can refine both the child and the parent-compatible field

## Shape 6: unused child types may still need updated fields

Before, conceptually:

```wat
(module
  (rec
    (type $A (struct (field (ref $X))))
    (type $B (sub $A (struct (field (ref $X)))))
    (type $C (sub $A (struct (field (ref $X))))))
  (func
    (local $unused (ref null $C))
    (drop (struct.new $B (struct.new_default $Y)))))
```

After, conceptually:

```wat
(module
  (rec
    (type $A (struct (field (ref (exact $Y)))))
    (type $B (sub $A (struct (field (ref (exact $Y))))))
    (type $C (sub $A (struct (field (ref (exact $Y)))))))
  ...)
```

Why:

- `$C` was never directly written
- but it still must remain a valid subtype of the refined parent field
- so Binaryen updates it too

This is why the pass is not just "look at used types with writes".
Hierarchy legality matters even for quiet descendants.

## Shape 7: mutable children cannot specialize relative to a refined super

Before, conceptually:

```wat
(module
  (rec
    (type $A (struct (field (mut anyref))))
    (type $B (sub $A (struct (field (mut anyref))))))
  (export "global" (global $g))
  ...)
```

After, conceptually:

```wat
(module
  ;; unchanged or only minimally changed
  ...)
```

Why:

- public ancestors are frozen
- mutable child fields must match their super fields exactly
- so even apparently refinable private children can be forced to stay wide

This is one of the main negative families in the public-type tests.

## Shape 8: immutable private children may still refine under a public ancestor

Before, conceptually:

```wat
(module
  (type $A (struct (field anyref)))
  (type $B (sub $A (struct (field anyref)))) ;; public
  (type $C (sub $A (struct (field anyref)))) ;; private
  ...)
```

After, conceptually:

```wat
(module
  (type $A (struct (field anyref)))
  (type $B (sub $A (struct (field anyref))))
  (type $C (sub $A (struct (field (ref any)))))
  ...)
```

Why:

- `$A` and `$B` stay frozen because of public visibility
- but an immutable private child can still become more specific as long as it remains a legal subtype of the frozen parent field

Important lesson:

- public freeze is real
- but it does not automatically forbid every private descendant improvement

## Shape 9: tee fallthrough can block a refinement that an `if` can still allow

### Tee family

Before, conceptually:

```wat
(struct.set $A 0
  (local.get $a)
  (local.tee $tmp
    (struct.get $A 0 (local.get $a))))
```

Typical result:

- Binaryen may keep the field wider than you expected

Why:

- the normal pass deliberately ignores tee/`br_if` fallthrough copies here

### `if` family

Before, conceptually:

```wat
(struct.set $A 0
  (local.get $a)
  (if (result (ref null $A))
    (cond)
    (then (struct.get $A 0 (local.get $a)))
    (else unreachable)))
```

Typical result:

- Binaryen can still refine the field
- and later refinalize the `if` to the narrower type

This is a major source-backed difference between what the pass refuses to see during inference and what it can still legalize afterward.

## Shape 10: a now-invalid `struct.get` becomes `drop + unreachable`

Before, conceptually:

```wat
(module
  (type $Wrap (struct (field (mut structref))))
  (func (result anyref)
    (struct.get $Wrap 0
      (block (result nullref)
        (ref.null none)))))
```

After, conceptually:

```wat
(module
  (type $Wrap (struct (field (mut (ref $Wrap)))))
  (func (result anyref)
    (block
      (drop
        (block (result nullref)
          (ref.null none)))
      (unreachable))))
```

Why:

- after refinement the read is no longer valid or inhabitable
- Binaryen cannot emit an “unreachable struct.get” node directly
- so it emits trap-equivalent code instead

This is one of the most important read-repair shapes.

## Shape 11: declaration refinement can force new `ref.cast`s at writes

Before, conceptually:

```wat
(module
  (type $A (struct (field (ref struct))))
  (type $B (struct))
  (func (result (ref $A))
    (struct.new $A
      (ref.cast (ref struct)
        (struct.get $A 0
          (struct.new $A (struct.new_default $B)))))))
```

After, conceptually:

```wat
(module
  (type $A (struct (field (ref (exact $B)))))
  (func (result (ref $A))
    (struct.new $A
      (ref.cast (ref (exact $B))
        (struct.get $A 0
          (struct.new $A (struct.new_default $B)))))))
```

Why:

- the field type became more precise
- the old producer expression is now too broad
- `WriteUpdater` repairs the write with a cast

This is the most common write-fixup family.

## Shape 12: bottom-type repair can become `ref.null bottom` or `unreachable`

Before, conceptually:

```wat
(struct.new $S
  (local.get $maybe-bottom))
```

After, conceptually, one of:

```wat
(block (result nullcontref)
  (drop (local.get $maybe-bottom))
  (ref.null nocont))
```

or

```wat
(block
  (drop (local.get $value))
  (unreachable))
```

Why:

- the refined field type may be an uninhabited or bottom type
- a normal cast is not the right repair
- Binaryen emits the minimal valid bottom-style replacement instead

The continuation tests are especially important here.

## Shape 13: GUFA-only locals/globals/call chains can refine further than normal mode

Before, conceptually:

```wat
(module
  (global $any (mut anyref) ...)
  (func $get_from_global ...)
  (func $work
    (local.set $a (struct.new_default $A))
    (local.set $b (struct.new $B (local.get $a)))
    (local.set $b (struct.new $B (call $get_from_global ...)))
    ...))
```

Normal mode may conclude, conceptually:

```wat
(type $A (struct (field (mut nullref))))
(type $B (struct (field (mut anyref))))
```

GUFA mode may conclude, conceptually:

```wat
(type $A (struct (field (mut nullref))))
(type $B (struct (field (mut (ref null (exact $A))))))
```

Why:

- GUFA sees through the intermediate local/global/call cycle
- the normal pass only saw the direct surface writes

This is the clearest “why GUFA exists” shape.

## Shape 14: exactness may be suppressed when later casts are not legal

Before, conceptually:

```wat
(module
  (type $bar (struct (field (ref null $foo))))
  (global $g (ref $foo) (global.get $exact))
  (func
    (drop (struct.new $bar (global.get $g)))))
```

After, conceptually, with custom descriptors enabled:

```wat
(type $bar (struct (field (ref (exact $foo)))))
(struct.new $bar
  (ref.cast (ref (exact $foo))
    (global.get $g)))
```

After, conceptually, with custom descriptors disabled:

```wat
(type $bar (struct (field (ref $foo))))
(struct.new $bar
  (global.get $g))
```

Why:

- the stronger exact refinement is only legal when the later cast repair is legal too

## Shape 15: continuation fields stay conservative even when other fields optimize

Before, conceptually:

```wat
(module
  (type $cont (cont $func))
  (type $wrap-cont (struct (field (ref $cont))))
  (type $array (array i32))
  (type $wrap-array (struct (field (ref $array))))
  ...)
```

After, conceptually:

- `$wrap-array` may refine to an exact array field
- `$wrap-cont` stays as a continuation field without unsafe exactification

Why:

- continuation cast repair is restricted
- Binaryen refuses to over-refine continuation fields just because there is another optimization opportunity in the same module

## Shape 16: array-adjacent atomic regression cases are mostly no-ops today

The official RMW regression file includes array examples, but the pass source still says arrays are TODO.
So the important lesson is:

- the pass has regression coverage around nearby array/atomic surfaces
- but the actual refinement logic today is still about **struct fields**

## Negative / bailout families

These are just as important as the positive examples.

## Public types are a hard boundary

If a type is public, this pass does not refine its fields.

## Open world is not supported

The pass requires `--closed-world`.
That is not a soft recommendation.
It is a hard pass-body requirement.

## Tee / `br_if` fallthrough is deliberately not treated like a transparent copy

A future port that sees through every tee here will not be matching Binaryen's current tradeoff.

## Arrays are not the main target yet

Do not describe `type-refining` as a generic struct-and-array refiner for `version_129`.
The source itself still says arrays are TODO.

## Bottom line

The best beginner question is not:

- did Binaryen make this type smaller?

It is:

- what writes justified the new private field type, and what reads/writes had to be repaired afterward so that smaller field type stayed valid?

That is the real `type-refining` shape logic.

## Sources

- [`../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md)
- [`../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md`](../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-rmw.wast>
