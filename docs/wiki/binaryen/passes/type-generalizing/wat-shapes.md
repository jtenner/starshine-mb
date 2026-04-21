---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./call-ref-casts-and-boundaries.md
---

# `type-generalizing` WAT and IR shape catalog

## How to read this page

These are beginner-friendly shape sketches.
They summarize the durable rewrite families the Binaryen `version_129` sources and lit tests imply.

The point is not exact printer output.
The point is to show:

- what shapes are in scope
- what becomes narrower
- what stays unchanged
- where the pass bails out

## Family 1: narrower `struct.get` result type

### Before

```wat
(struct.get $parent 0
  (local.get $x)) ;; static result type is a broad nullable ref
```

Closed-world fact:

- `$x` can only contain values from a narrower child heap type

### After

```wat
(struct.get $child 0
  (local.get $x)) ;; same nullability, narrower heap type
```

### Why it changes

The pass asks the oracle for possible contents of the receiver, computes a LUB heap type, and rewrites the result type when that heap type is a subtype of the current one.

## Family 2: preserved `struct.get` when the proof is weak

### Before

```wat
(struct.get $parent 0
  (local.get $x))
```

Closed-world fact:

- `$x` may contain values from multiple unrelated or insufficiently precise receiver types

### After

```wat
(struct.get $parent 0
  (local.get $x))
```

### Why it stays

No single safe narrower heap type is available, so the pass keeps the original broader type.

## Family 3: narrower `struct.set` field type

### Before

```wat
(struct.set $parent 0
  (local.get $obj)
  (local.get $value))
```

Closed-world fact:

- `$obj` always belongs to a narrower child heap type whose field `0` is also narrower

### After

```wat
(struct.set $child 0
  (local.get $obj)
  (local.get $value))
```

### Why it changes

The pass refines the field type named by the write when the actual receiver type is provably narrower.

## Family 4: `call_ref` with one possible signature

### Before

```wat
(call_ref (result eqref)
  (local.get $f)
  (local.get $arg))
```

Closed-world fact:

- `$f` can only contain one callable signature, say `(func (param eqref) (result (ref null $child)))`

### After

```wat
(call_ref (result (ref null $child))
  (local.get $f) ;; target type is now that exact non-nullable function signature
  (local.get $arg))
```

### Why it changes

The pass only narrows `call_ref` when the possible target signature set has exactly one member.
Then it can sharpen both:

- the target expression type
- the call result type

## Family 5: impossible `call_ref`

### Before

```wat
(call_ref (result eqref)
  (local.get $f)
  (local.get $arg))
```

Closed-world fact:

- `$f` has no possible callable contents

### After

```wat
(call_ref (result eqref)
  unreachable
  (local.get $arg))
```

### Why it changes

The pass treats an impossible target set as a real semantic impossibility, not just as a no-op case.
So it rewrites the target to `unreachable`.

## Family 6: mixed-signature `call_ref` bailout

### Before

```wat
(call_ref (result eqref)
  (local.get $f)
  (local.get $arg))
```

Closed-world fact:

- `$f` may contain two different function signatures

### After

```wat
(call_ref (result eqref)
  (local.get $f)
  (local.get $arg))
```

### Why it stays

The family does **not** try to join or synthesize a common callable wrapper.
Its rule is simple:

- one signature → narrow
- more than one → bail

## Family 7: existing-cast tightening in the optimizing-casts sibling

### Before

```wat
(ref.cast (ref $parent)
  (local.get $x))
```

Closed-world fact:

- `$x` is always within a narrower child heap-type cone

### After

```wat
(ref.cast (ref $child)
  (local.get $x))
```

### Why it changes

This only happens in `experimental-type-generalizing-with-optimizing-casts`.
The plain sibling leaves `ref.cast` alone.

## Family 8: no new casts are inserted

### Before

```wat
(local.get $x) ;; broad static type, narrower proven runtime contents
```

### After

```wat
(local.get $x)
```

### Why it stays

This family does not insert arbitrary new `ref.cast` scaffolding.
That is a good place to remember the split from `gufa-cast-all`.

## Family 9: unsupported expression kinds are preserved

### Before

Any GC/type-sensitive expression outside:

- `struct.get`
- `struct.set`
- `call_ref`
- `ref.cast`

### After

Unchanged.

### Why it stays

The family's visitor surface is tiny by design.
That narrowness is part of the real contract.

## Family 10: refinalization-visible parent cleanup

### Before

A parent expression was typed according to the old broader child type.

### After

The child is narrower, and Binaryen refinalizes the function so parent types remain valid.

### Why it matters

This is not a directly printed WAT family so much as a correctness family:
without refinalization, many visible type changes here would be incomplete.

## Positive versus negative cheat sheet

| Shape | Result |
| --- | --- |
| receiver contents collapse to one narrower field hierarchy | `struct.get` / `struct.set` can narrow |
| `call_ref` target contents collapse to one signature | target and maybe result narrow |
| `call_ref` target contents are impossible | target becomes `unreachable` |
| existing `ref.cast` is provably over-broad and sibling enables cast optimization | cast target narrows |
| mixed-signature `call_ref` | preserved |
| no useful oracle LUB | preserved |
| missing cast-optimizing sibling flag | `ref.cast` preserved |
| desire for brand-new inserted casts | not this pass |

## What beginners should remember most

If you only keep four shape rules in your head, keep these:

1. `struct.get` and `struct.set` can both become more precise.
2. `call_ref` narrows only when one signature remains.
3. impossible `call_ref` targets become `unreachable`.
4. the second sibling tightens existing casts; it does not insert new ones.
