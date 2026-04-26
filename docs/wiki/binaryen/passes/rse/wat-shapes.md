---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cfg-and-value-tracking.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../no-dwarf-default-optimize-path.md
---

# `rse` WAT Shapes

This is the beginner-friendly shape catalog for the corrected Binaryen `version_129` `rse` contract.
Use it with the source correction in [`../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md`](../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md).

## Read this page with one mental model

Binaryen asks:

> At this point in the CFG, does this local already have the value number this `local.set` or `local.tee` is about to write?

If yes, the write shell is redundant.
If no, Binaryen records the new value number.
At `local.get`, Binaryen may also ask whether another local with the same value has a stricter type and can be read instead.

## Shape 1: repeated same-value `local.set`

Before:

```wat
(local.set $x
  (i32.const 1))
(local.set $x
  (i32.const 1))
```

Conceptual after `rse`:

```wat
(local.set $x
  (i32.const 1))
(drop
  (i32.const 1))
```

Why it folds:

- the second RHS value-numbers the same as the current value for `$x`;
- the write changes no local state;
- the RHS evaluation is still preserved.

A later `vacuum` can erase the `drop` if the RHS is pure and unused.

## Shape 2: repeated same-value `local.tee`

Before:

```wat
(local.set $x
  (i32.const 1))
(drop
  (local.tee $x
    (i32.const 1)))
```

Conceptual after `rse`:

```wat
(local.set $x
  (i32.const 1))
(drop
  (i32.const 1))
```

Why it folds:

- the tee's store is redundant;
- the tee's result value is still needed by its parent `drop`;
- replacing the tee with the RHS preserves stack behavior.

## Shape 3: same value through a branch join

Before:

```wat
(if
  (local.get $cond)
  (then
    (local.set $x (i32.const 7)))
  (else
    (local.set $x (i32.const 7))))
(local.set $x (i32.const 7))
```

Conceptual after `rse`:

```wat
(if
  (local.get $cond)
  (then
    (local.set $x (i32.const 7)))
  (else
    (local.set $x (i32.const 7))))
(drop (i32.const 7))
```

Why this belongs to `rse`:

- Binaryen computes block start values through the CFG;
- both predecessors agree on `$x`'s value number;
- the post-join set writes the same value again.

This shape is the key correction to the stale straight-line-only teaching.

## Shape 4: different branch values do not fold

Before:

```wat
(if
  (local.get $cond)
  (then
    (local.set $x (i32.const 1)))
  (else
    (local.set $x (i32.const 2))))
(local.set $x (i32.const 1))
```

Important behavior:

```wat
(if
  (local.get $cond)
  (then
    (local.set $x (i32.const 1)))
  (else
    (local.set $x (i32.const 2))))
(local.set $x (i32.const 1))
```

Why it does **not** fold:

- the post-join block does not know `$x` definitely already holds `1`;
- predecessor disagreement becomes a merge/unknown value, not one chosen predecessor;
- `rse` does not prove old different-value writes dead.

## Shape 5: different overwritten values are not an `rse` deletion

Before:

```wat
(local.set $x
  (i32.const 1))
(local.set $x
  (i32.const 2))
```

Important behavior:

```wat
(local.set $x
  (i32.const 1))
(local.set $x
  (i32.const 2))
```

Why it does **not** fold in this pass:

- the second RHS has a different value number;
- `rse` is not proving that the first write is dead;
- no liveness-backed arbitrary overwritten-write deletion runs here.

## Shape 6: RHS side effects or traps stay

Before:

```wat
(local.set $x
  (i32.const 0))
(local.set $x
  (i32.div_s
    (i32.const 1)
    (local.get $maybe_zero)))
```

This can only fold if the RHS value number equals the current value for `$x`.
Even then, the RHS evaluation cannot disappear just because the local write is redundant.

Practical porting rule:

- remove the write shell, never an observable RHS effect or trap.

## Shape 7: copied-local refined get

Conceptual before:

```wat
(local.set $narrow
  (ref.as_non_null
    (local.get $maybe)))
(local.set $wide
  (local.get $narrow))
(local.get $wide)
```

Conceptual after:

```wat
(local.set $narrow
  (ref.as_non_null
    (local.get $maybe)))
(local.set $wide
  (local.get $narrow))
(local.get $narrow)
```

Why it folds:

- `$wide` and `$narrow` carry the same value number;
- `$narrow` has a stricter reference type than `$wide`;
- reading `$narrow` validates where `$wide` was read.

The exact WAT type spelling depends on the surrounding GC type declarations.
The durable point is that Binaryen retargets the local index; it does not copy the original expression tree into the get.

## Shape 8: loops require convergence

Before, conceptually:

```wat
(loop $l
  (local.set $x (i32.const 1))
  (br_if $l (local.get $cond)))
(local.set $x (i32.const 1))
```

The pass must reach a fixed point before deciding whether the post-loop set is redundant.
A Starshine port should not treat loops as a one-pass straight-line scan; it must either implement the Binaryen-style fixed point or conservatively skip loop-carried facts until that proof exists.

## Shape 9: globals, memory stores, and field stores are non-goals

These are outside `version_129` `rse`:

```wat
(global.set $g (i32.const 1))
(i32.store (i32.const 0) (i32.const 1))
(struct.set $T 0 (local.get $obj) (i32.const 1))
(array.set $A (local.get $arr) (i32.const 0) (i32.const 1))
```

Do not expect this pass to remove them.
If future Starshine work handles those shapes, document it as a Starshine-local extension or a different Binaryen-pass port.

## Shape 10: `rse -> vacuum` handoff

Before `vacuum`:

```wat
(local.set $x (i32.const 1))
(drop (i32.const 1))
```

After a later `vacuum`-style cleanup:

```wat
(local.set $x (i32.const 1))
```

This is why direct `--rse` comparisons and late-tail `--rse --vacuum` comparisons can show different final neatness while both are source-consistent.
