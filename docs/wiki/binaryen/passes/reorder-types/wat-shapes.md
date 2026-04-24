---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md
  - ../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./ordering-cost-model-and-boundaries.md
  - ./starshine-strategy.md
---

# `reorder-types` WAT / IR shapes

This page records the main source-backed module-shape families a future `reorder-types` port must preserve.
It is anchored by the 2026-04-24 primary-source manifest [`../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md); use [`./starshine-strategy.md`](./starshine-strategy.md) for local code locations.

## Shape 1: unconstrained private types reorder by direct counts

### Before

```wat
(module
  (rec
    (type $A (struct))
    (type $B (struct))
    (type $C (struct)))
  (func $test
    (local (ref $A))
    (local (ref $A))
    (local (ref $A))
    (local (ref $B))
    (local (ref $B))
    (local (ref $C))))
```

### After intuition

- `$A` stays earliest because it has the most direct uses.

### Why it matters

The first lit cases show the pass doing the obvious thing when there are no ordering edges:

- more counted uses
- smaller target indices
- smaller total byte cost

## Shape 2: unconstrained private types can swap by profitability

### Before

```wat
(module
  (rec
    (type $A (struct))
    (type $B (struct))
    (type $C (struct)))
  (func $test
    (local (ref $A))
    (local (ref $A))
    (local (ref $B))
    (local (ref $C))
    (local (ref $C))
    (local (ref $C))))
```

### After intuition

- `$C` can move to the earliest slot because it now carries the largest counted cost.

### Why it matters

The pass is not stable-by-default when a cheaper legal order exists.

## Shape 3: legality beats raw code-size preference

### Before

```wat
(module
  (rec
    (type $A (sub (struct)))
    (type $B (sub $A (struct)))
    (type $C (sub $B (struct))))
  (func $test
    (local (ref $A))
    (local (ref $B))
    (local (ref $B))
    (local (ref $C))
    (local (ref $C))
    (local (ref $C))))
```

### After intuition

- the order remains `$A -> $B -> $C`, even if later types are hotter.

### Why it matters

The lit file explicitly says to respect ordering constraints even when bad for code size.
This is the most important beginner-facing bailout family.

## Shape 4: successor traffic can break ties

### Before

```wat
(module
  (rec
    (type $A (sub (struct)))
    (type $B (sub $A (struct)))
    (type $X (sub (struct)))
    (type $Y (sub $X (struct))))
  (func $test
    (local (ref $A))
    (local (ref $B))
    (local (ref $X))
    (local (ref $Y))
    (local (ref $Y))
    (local (ref $Y))))
```

### After intuition

- `$X` can beat `$A` because successor-heavy `$Y` weight propagates back to it.

### Why it matters

This is the clearest proof that `reorder-types` is not raw direct-use sorting.
Successor propagation is part of the real algorithm.

## Shape 5: a different direct-count balance can outweigh successor pull

### Before

```wat
(module
  (rec
    (type $A (sub (struct)))
    (type $B (sub $A (struct)))
    (type $X (sub (struct)))
    (type $Y (sub $X (struct))))
  (func $test
    (local (ref $A))
    (local (ref $A))
    (local (ref $A))
    (local (ref $A))
    (local (ref $B))
    (local (ref $X))
    (local (ref $Y))
    (local (ref $Y))
    (local (ref $Y))))
```

### After intuition

- `$A` can still stay first because its own branch is hot enough to outweigh the successor pull from `$Y` into `$X`.

### Why it matters

This shows why Binaryen samples multiple factors and computes full cost rather than hardcoding one successor-bias heuristic.

## Shape 6: public types are preserved, not reordered

### Schematic

```wat
(module
  ;; public boundary-visible types
  ;; plus private internal types
)
```

### Working rule

Because `GlobalTypeRewriter` freezes public types, a future port must treat public heap types as:

- present in visibility analysis
- excluded from private reorder candidates

This is a source-backed rule even though the dedicated lit file mostly focuses on private examples.

## Shape 7: no GC means no pass effect

### Before / After

```wat
(module
  ;; no GC heap types
)
```

### Result

- unchanged

### Why it matters

`ReorderTypes::run()` exits immediately without GC.

## Shape 8: open world is a hard bailout

### Result

- the pass does not silently no-op
- it fails with `ReorderTypes requires --closed-world`

### Why it matters

This is a policy boundary, not just an optimization preference.

## Shape 9: type declarations move, but every type use must move with them

### Before

```wat
(module
  (rec
    (type $A (struct))
    (type $B (struct)))
  (func (param (ref $A)) (result (ref $B)) ...)
  (global (mut (ref null $A)) ...)
  (table 1 funcref)
  (tag (param (ref $B))))
```

### After intuition

- if a private type moves, every declaration and expression-level use follows the new mapping.

### Why it matters

The real contract includes locals, expressions, globals, tables, element segments, tags, type names, and preserved type-index metadata.

## Shape 10: regression family around used-IR-type counting

### Before

The dedicated regression in `reorder-types.wast` includes a rec group with a multivalue function type plus struct types, where broader binary-surface counting once disagreed with the `UsedIRTypes` set used by `GlobalTypeRewriter`.

### After intuition

- the pass no longer crashes when standalone function signatures and rec-group-contained binary types disagree.

### Why it matters

A future port must keep the candidate/counting surface aligned with the rewriter's private-type inventory.

## Summary table

| Shape family | Result |
| --- | --- |
| unconstrained hotter private type | move earlier |
| hotter subtype with predecessor edge | predecessor can pin it |
| successor-heavy branch | predecessor weight can rise |
| bigger direct-count branch | can still beat successor-heavy rival |
| public type | preserved / not reordered |
| no GC | no-op |
| open world | hard bailout |
| moved private type | all type-bearing module surfaces remapped |
| used-IR-vs-binary mismatch regression | must stay crash-free |

## Sources

- [`../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md)
- [`../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md`](../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md`](../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderTypes.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
