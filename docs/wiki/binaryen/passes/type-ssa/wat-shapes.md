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
  - ./created-exact-types-control-values-and-signature-rewrites.md
---

# `type-ssa` WAT and IR shape catalog

## How to read this page

These are beginner-friendly shape sketches.
They summarize the durable rewrite families implied by the Binaryen `version_129` source and its direct lit test.

The point is not exact printer output.
The point is to show:

- what gets remembered as a created exact type,
- where that precision survives,
- where it becomes visible again,
- and where the pass intentionally bails out.

## Family 1: fresh constructor -> local.set -> local.get

### Before

```wat
(local.set $x
  (struct.new $A
    ...))
(drop
  (local.get $x)) ;; broad declared ref type
```

### After, conceptually

```wat
(local.set $x
  (struct.new $A
    ...))
(drop
  (local.get $x)) ;; same node shape, narrower exact $A-flavored type
```

### Why it changes

The constructor seeds a created exact type.
The set remembers it.
The later get is retagged to that more precise heap type.

## Family 2: fresh array creation through a local

### Before

```wat
(local.set $arr
  (array.new_fixed $B
    ...))
(call $use
  (local.get $arr))
```

### After, conceptually

```wat
(local.set $arr
  (array.new_fixed $B
    ...))
(call $use
  (local.get $arr)) ;; operand type sharpened to the created exact array type when subtype-safe
```

### Why it changes

The pass does not stop at the get.
If the call parameter accepts the narrower type, the operand itself can stay sharp there too.

## Family 3: `ref.as_non_null` creates a useful exact value

### Before

```wat
(local.set $x
  (ref.as_non_null
    (local.get $maybe-a)))
(drop
  (local.get $x))
```

### After, conceptually

```wat
(local.set $x
  (ref.as_non_null
    (local.get $maybe-a)))
(drop
  (local.get $x)) ;; retagged with the created exact/non-null precision
```

### Why it changes

`ref.as_non_null` is one of the tiny seed instructions.
So it can start a created-type flow just like a constructor can.

## Family 4: `ref.cast` as a seed

### Before

```wat
(local.set $x
  (ref.cast (ref $A)
    (local.get $v)))
(return
  (local.get $x))
```

### After, conceptually

```wat
(local.set $x
  (ref.cast (ref $A)
    (local.get $v)))
(return
  (local.get $x)) ;; returned expression type sharpened when the function result accepts it
```

### Why it changes

`ref.cast` also seeds a created exact type.
That exactness can survive to the return boundary.

## Family 5: matching `if` arms preserve precision

### Before

```wat
(local.set $x
  (if (result (ref null $Parent))
    (then (struct.new $A ...))
    (else (struct.new $A ...))))
(drop (local.get $x))
```

### After, conceptually

```wat
(local.set $x
  (if (result (ref null $Parent))
    (then (struct.new $A ...))
    (else (struct.new $A ...))))
(drop (local.get $x)) ;; can still reflect the common created exact $A type
```

### Why it changes

The `if` helper only forwards the value when both arms agree on the same created type.
Here they do.

## Family 6: mismatched `if` arms bail out

### Before

```wat
(local.set $x
  (if (result (ref null $Parent))
    (then (struct.new $A ...))
    (else (struct.new $B ...))))
(drop (local.get $x))
```

### After

```wat
;; preserved broad type
```

### Why it stays

The two arms do not agree on one created exact type.
So Binaryen keeps the broader original type.

## Family 7: `try` result can carry precision when the flows agree

### Before

```wat
(local.set $x
  (try (result (ref null $Parent))
    (do (struct.new $A ...))
    (catch_all
      (struct.new $A ...))))
(drop (local.get $x))
```

### After, conceptually

```wat
(local.set $x
  (try (result (ref null $Parent))
    (do (struct.new $A ...))
    (catch_all
      (struct.new $A ...))))
(drop (local.get $x)) ;; precision can survive because the carried values agree
```

### Why it changes

The `try` helper can forward a created type when it sees one stable carried value shape.

## Family 8: loop values are a deliberate no-op boundary

### Before

```wat
(local.set $x
  (loop (result (ref null $Parent))
    ...
    (struct.new $A ...)))
(drop (local.get $x))
```

### After

```wat
;; preserved broad type
```

### Why it stays

The reviewed helper does not treat `loop` as a value-propagation source.
That is a real pass boundary.

## Family 9: global forwarding

### Before

```wat
(global.set $g
  (struct.new $A ...))
(drop
  (global.get $g))
```

### After, conceptually

```wat
(global.set $g
  (struct.new $A ...))
(drop
  (global.get $g)) ;; retagged to the remembered created type when subtype-safe
```

### Why it changes

Globals participate in the same created-type forwarding story as locals.

## Family 10: direct call operands sharpen

### Before

```wat
(call $takes-parent
  (struct.new $A ...))
```

### After, conceptually

```wat
(call $takes-parent
  (struct.new $A ...)) ;; operand type can stay visibly exact-$A when that is a subtype of the parameter type
```

### Why it changes

`type-ssa` explicitly visits direct call operands, not just local/global gets.

## Family 11: return values sharpen

### Before

```wat
(func (result (ref null $Parent))
  (return
    (struct.new $A ...)))
```

### After, conceptually

```wat
(func (result (ref null $Parent))
  (return
    (struct.new $A ...))) ;; returned expression type can be sharpened to the created subtype
```

### Why it changes

The pass tracks return values too, which helps preserve the exact created type until the function boundary.

## Family 12: abstract references are not a seed surface

### Before

```wat
(local.set $x
  (ref.null any))
(drop (local.get $x))
```

### After

```wat
;; preserved
```

### Why it stays

The helper that creates target types rejects broad abstract refs like `anyref`, `eqref`, `i31ref`, and `none`.

## Positive summary

`type-ssa` is strongest on:

- fresh struct and array creations,
- `ref.as_non_null` and `ref.cast` seed values,
- local/global forwarding,
- matching `if` and some `try` value families,
- direct call operands,
- return values.

## Negative summary

It is deliberately weak or absent on:

- loops,
- mismatched branch-created types,
- broad abstract refs,
- values that were never seeded as created exact types,
- and anything that would require a broader whole-program analysis.

## Beginner rule of thumb

If the useful sentence about a value is:

- “this was just created as exactly this concrete heap type, and that fact survives to a later use”

then `type-ssa` is the right pass family to think about.

If the useful sentence is instead:

- “the whole program suggests this value could only be one of these contents”

then you are probably thinking about a different GC/type pass.
