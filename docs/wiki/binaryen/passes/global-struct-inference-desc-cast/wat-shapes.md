---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md
  - ../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md
  - ../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md
  - ../../../raw/binaryen/2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
  - ../../../raw/research/0488-2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-singleton-gate-and-dedicated-tests.md
  - ./starshine-strategy.md
  - ../global-struct-inference/wat-shapes.md
---

# `global-struct-inference-desc-cast` WAT / IR shape catalog

This page teaches the **shape families** that matter for `gsi-desc-cast`.
It is intentionally beginner-friendly.
A 2026-05-05 current-main recheck found no shape-level drift on the reviewed surfaces.

The crucial corrected mental model is:

- plain `gsi` optimizes trusted reads from struct-valued globals
- `gsi-desc-cast` adds a much narrower cast rewrite based on the **target type's descriptor singleton global**

So the important shapes are mostly about the **cast target type**, not about a rich provenance proof on the cast input.

## First mental model

Think of the pass like this:

- plain `gsi` asks: "Can I replace this trusted field or descriptor read with a known value, a known global, or a tiny conditional?"
- `gsi-desc-cast` asks: "Does this cast target have a descriptor type with exactly one known global instance, and is descriptor equality precise enough here?"

That is a safer model than the older "trusted cast-input origin" explanation.

## Positive shape 1: leaf target type with one descriptor global

### Before

```wat
(rec
  (type $A (sub (descriptor $A.desc) (struct)))
  (type $A.desc (sub (describes $A) (struct))))

(global $A.desc (ref $A.desc)
  (struct.new $A.desc))

(func (param $x anyref)
  (drop
    (ref.cast (ref $A)
      (local.get $x))))
```

### After under `--gsi-desc-cast`

```wat
(func (param $x anyref)
  (drop
    (ref.cast_desc_eq (ref $A)
      (local.get $x)
      (global.get $A.desc))))
```

### Why this works

- `$A` has a descriptor type `$A.desc`
- there is exactly one descriptor global for `$A.desc`
- `$A` has no strict subtypes, so descriptor equality is precise enough

## Positive shape 2: exact cast where the inexact cast would bail out

### Before

```wat
(rec
  (type $A (sub (descriptor $A.desc) (struct)))
  (type $A.desc (sub (describes $A) (struct)))
  (type $B (sub $A (descriptor $B.desc) (struct)))
  (type $B.desc (sub $A.desc (describes $B) (struct))))

(func (param $x anyref)
  (drop (ref.cast (ref $A) (local.get $x)))
  (drop (ref.cast (ref (exact $B)) (local.get $x))))
```

### Why the shapes differ

- non-exact `(ref $A)` still has relevant strict subtypes, so it stays an ordinary cast
- exact `(ref (exact $B))` can still become `ref.cast_desc_eq`

### Beginner note

Exactness matters because the legality question is about whether descriptor equality still preserves the original cast contract.

## Positive shape 3: two independent descriptor families can both optimize

### Before

```wat
(rec
  (type $A (sub (descriptor $A.desc) (struct)))
  (type $A.desc (sub (describes $A) (struct)))
  (type $B (sub (descriptor $B.desc) (struct)))
  (type $B.desc (sub (describes $B) (struct))))

(global $A.desc (ref $A.desc) (struct.new $A.desc))
(global $B.desc (ref $B.desc) (struct.new $B.desc))

(func (param $x anyref)
  (drop (ref.cast (ref $A) (local.get $x)))
  (drop (ref.cast (ref $B) (local.get $x))))
```

### Why this works

Each target type has its own singleton descriptor global and no strict-subtype ambiguity.
So both casts can become `ref.cast_desc_eq`.

## Positive shape 4: nullable target cast

### Before

```wat
(func (param $x anyref)
  (drop
    (ref.cast (ref null $A)
      (local.get $x))))
```

### Why this still works

The dedicated lit file proves that nullable casts can still optimize.
Null is still handled correctly, so Binaryen can emit `ref.cast_desc_eq (ref null $A) ...`.

## Bailout shape 1: non-exact target with strict subtypes

### Before

```wat
(rec
  (type $A (sub (descriptor $A.desc) (struct)))
  (type $A.desc (sub (describes $A) (struct)))
  (type $B (sub $A (descriptor $B.desc) (struct)))
  (type $B.desc (sub $A.desc (describes $B) (struct))))

(func (param $x anyref)
  (drop
    (ref.cast (ref $A)
      (local.get $x))))
```

### Why Binaryen bails out

`$A` is not exact and still has strict subtypes.
So descriptor equality would be too weak to preserve ordinary cast semantics.

## Bailout shape 2: zero descriptor-instance globals

### Before

```wat
(rec
  (type $A (sub (descriptor $A.desc) (struct)))
  (type $A.desc (sub (describes $A) (struct))))

(func (param $x anyref)
  (drop
    (ref.cast (ref $A)
      (local.get $x))))
```

### Why Binaryen bails out

There is no singleton descriptor global to read.
The dedicated lit file records this as a no-rewrite case.

## Bailout shape 3: multiple descriptor-instance globals

### Before

```wat
(global $A.desc1 (ref $A.desc) (struct.new $A.desc))
(global $A.desc2 (ref $A.desc) (struct.new $A.desc))

(func (param $x anyref)
  (drop
    (ref.cast (ref $A)
      (local.get $x))))
```

### Why Binaryen bails out

The desc-cast-specific logic requires **exactly one** descriptor global.
It does not grow a select-based desc-cast scheme here.

## Bailout shape 4: target type without a descriptor type

### Before

```wat
(type $A (sub (struct)))

(func (param $x anyref)
  (drop
    (ref.cast (ref $A)
      (local.get $x))))
```

### Why Binaryen bails out

No descriptor type means there is no `ref.cast_desc_eq` form to build for this target.

## Bailout shape 5: unreachable cast input

### Before

```wat
(func
  (drop
    (ref.cast (ref $A)
      (unreachable))))
```

### Why Binaryen bails out

The pass explicitly ignores casts whose result type is already `unreachable`.
The dedicated lit file keeps that behavior visible.

## Important non-shape fact: closed world matters for the desc-cast delta

The sibling pass can still run without `--closed-world`, because it shares plain GSI's engine.
But the desc-cast-specific rewrite depends on `typeGlobals`, and `typeGlobals` is filled only in `analyzeClosedWorld(...)`.

So a good beginner rule is:

- ordinary shared GSI wins may still exist without closed world
- the dedicated `ref.cast` -> `ref.cast_desc_eq` wins are effectively closed-world-dependent

## Comparison with plain `gsi`

### Plain `gsi` positive shape

```wat
(ref.get_desc $A
  (global.get $g))
```

### `gsi-desc-cast` positive shape

```wat
(ref.cast (ref $A)
  (local.get $x))
```

### Shared idea

They share the same owner file, closed-world map, and descriptor-oriented support machinery.

### Different deciding proof

- plain `gsi` cares about trusted read sources and small value groups
- `gsi-desc-cast` cares about the target descriptor singleton and subtype legality

That is why the sibling deserves its own corrected dossier.

## What a future Starshine port must preserve

A future port should preserve these shape rules explicitly:

- target descriptor existence is mandatory
- exactly-one-global for the descriptor type is mandatory
- exact targets are easier than non-exact targets
- strict-subtype ambiguity is a bailout
- zero or many descriptor globals are bailouts
- unreachable casts stay untouched
- this pass is not a substitute for `optimize-casts`

## Sources

- [`../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md)
- [`../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md`](../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md`](../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md)
- [`../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md`](../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../global-struct-inference/wat-shapes.md`](../global-struct-inference/wat-shapes.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-to-desc-cast.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-desc.wast>
