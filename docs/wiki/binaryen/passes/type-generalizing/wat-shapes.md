---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-flow-type-floor-and-boundaries.md
  - ./starshine-strategy.md
supersedes:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
---

# `type-generalizing` WAT and IR shape catalog

## How to read this page

These are beginner-friendly shape sketches for the corrected Binaryen `version_129` pass.
They show the important transformed or preserved families without pretending to be exact printer output.

The durable point is:

- `type-generalizing` is about local-flow type cleanup and defaultable expression retagging,
- not about closed-world GC field/call/cast rewrites.

## Family 1: ordinary expression type retagging

### Before

```wat
(block (result (ref null $broad))
  ... expression whose local-flow users only need a compatible narrower type ...)
```

Local-flow fact:

- local assignment evidence lets Binaryen compute a compatible type using subtype/LUB reasoning.

### After

```wat
(block (result (ref null $compatible))
  ... same expression, retagged to the compatible type ...)
```

### Why it changes

The pass can mutate the expression's visible type when the candidate is defaultable and the computed type is subtype-compatible with the original expression and local-flow uses.

## Family 2: `local.get` cannot be retagged directly

### Before

```wat
(local.get $x) ;; declaration type belongs to $x
```

Local-flow fact:

- the surrounding expression would be better typed as a compatible defaultable type that is not the local declaration type.

### After

```wat
(block (result $compatible)
  (drop (local.get $x))
  ;; default/zero value of $compatible
  (ref.null $compatible))
```

### Why it changes

A `local.get` result type is tied to the local declaration.
Binaryen preserves evaluation of the original get through a `drop`, then produces a default/zero value of the chosen type.

Use `ref.null` here as a reference-type sketch; the exact zero/default form depends on the chosen Binaryen `Type`.

## Family 3: local-set evidence collection

### Before

```wat
(local.set $x
  (some-value))
```

### After

```wat
(local.set $x
  (some-value))
```

### Why it usually stays printed the same

`local.set` is usually evidence for nearby retagging, not necessarily the visible rewrite target.
It records that a value of a certain type flows into local `$x`.

## Family 4: local-tee evidence collection

### Before

```wat
(local.tee $x
  (some-value))
```

### After

```wat
(local.tee $x
  (some-value))
```

### Why it usually stays printed the same

Like `local.set`, `local.tee` contributes type evidence for the local index.
Its own printed shape may remain unchanged even when that evidence lets the pass retag a surrounding expression.

## Family 5: weak evidence bailout

### Before

```wat
(block (result (ref null $broad))
  ... expression ...)
```

Local-flow fact:

- the observed local evidence does not yield a compatible type that is safe to use.

### After

```wat
(block (result (ref null $broad))
  ... expression ...)
```

### Why it stays

The pass is conservative.
If subtype/LUB reasoning does not produce a safe target type, the original expression stays unchanged.

## Family 6: nondefaultable bailout

### Before

```wat
(local.get $x) ;; candidate would require a nondefaultable replacement type
```

### After

```wat
(local.get $x)
```

### Why it stays

The `local.get` fallback may need to create a default/zero value.
If no valid default exists for the chosen type, the pass must not rewrite.

## Family 7: concrete or unreachable barrier

### Before

```wat
;; concrete typed expression, or an expression already typed unreachable
...
```

### After

```wat
;; unchanged by this pass
...
```

### Why it stays

The owner file treats these cases as no-op/barrier families for this pass.
They are not the target of local-flow type generalization.

## Family 8: `struct.get` is not transformed here

### Before

```wat
(struct.get $t 0
  (local.get $obj))
```

### After

```wat
(struct.get $t 0
  (local.get $obj))
```

### Why it stays

The earlier dossier claimed `struct.get` result narrowing, but the reviewed `TypeGeneralizing.cpp` file has no `struct.get` visitor.
If a future source adds such behavior, it should be filed as new provenance, not assumed from this pass name.

## Family 9: `struct.set` is not transformed here

### Before

```wat
(struct.set $t 0
  (local.get $obj)
  (local.get $value))
```

### After

```wat
(struct.set $t 0
  (local.get $obj)
  (local.get $value))
```

### Why it stays

The corrected pass does not retarget struct field declarations or field operands.

## Family 10: `call_ref` is not transformed here

### Before

```wat
(call_ref (type $sig)
  (local.get $arg)
  (local.get $target))
```

### After

```wat
(call_ref (type $sig)
  (local.get $arg)
  (local.get $target))
```

### Why it stays

The previous one-signature `call_ref` story is stale for this pass.
The reviewed owner file has no `call_ref` visitor and no impossible-target-to-`unreachable` rewrite.

## Family 11: `ref.cast` is not transformed here

### Before

```wat
(ref.cast (ref $parent)
  (local.get $x))
```

### After

```wat
(ref.cast (ref $parent)
  (local.get $x))
```

### Why it stays

No optimizing-casts sibling was found in the reviewed `version_129` source.
This pass does not tighten existing casts and does not insert new casts.

## Positive versus negative cheat sheet

| Shape | Corrected result |
| --- | --- |
| defaultable expression with compatible local-flow evidence | may retag expression type |
| `local.get` that would need a different compatible type | drop original get, then emit default/zero of chosen type |
| `local.set` / `local.tee` | evidence source; often printed unchanged |
| weak subtype/LUB proof | preserved |
| nondefaultable target type | preserved |
| concrete or unreachable candidate | preserved/barrier |
| `struct.get`, `struct.set`, `call_ref`, `ref.cast` | not directly transformed by reviewed `version_129` pass |

## What beginners should remember most

If you only keep four shape rules in your head, keep these:

1. The pass is local-flow type cleanup, not a GC oracle.
2. `local.set` and `local.tee` feed the type evidence.
3. `local.get` retagging becomes drop-plus-zero.
4. The old `struct.get` / `call_ref` / cast story is stale for this pass.
