---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
  - ../../../raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cfg-and-value-tracking.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `rse` WAT Shapes

This is the beginner-friendly shape catalog for the corrected Binaryen `version_129` `rse` contract.
Use it with the source correction in [`../../../raw/binaryen/2026-04-25-rse-source-correction.md`](../../../raw/binaryen/2026-04-25-rse-source-correction.md).

## Read this page with one mental model

Binaryen asks:

> Does this local already hold the same value number that this `local.set` or `local.tee` is about to write?

If yes, the write shell is redundant.
If no, Binaryen remembers the new value number and moves on.
If control/effects make the fact unsafe, Binaryen forgets it.

## Shape 1: repeated same-value `local.set`

Before:

```wat
(local.set $x
  (i32.const 1))
(local.set $x
  (i32.const 1))
```

Conceptual after:

```wat
(local.set $x
  (i32.const 1))
(drop
  (i32.const 1))
```

Why it folds:

- the second RHS value-numbers the same as the remembered value for `$x`;
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

Conceptual after:

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

## Shape 3: RHS side effects or traps stay

Before:

```wat
(local.set $x
  (call $may_trap_or_side_effect))
(local.set $x
  (call $may_trap_or_side_effect))
```

This folds only if Binaryen's value-numbering and barrier rules still prove the same value for the second RHS.
Even then, the call/evaluation cannot disappear just because the local write is redundant.
The set shell can go away; the observable RHS behavior cannot.

Practical porting rule:

- remove the write, never the RHS effect.

## Shape 4: different overwritten values are not an `rse` deletion

Before:

```wat
(local.set $x
  (i32.const 1))
(local.set $x
  (i32.const 2))
```

Important after:

```wat
(local.set $x
  (i32.const 1))
(local.set $x
  (i32.const 2))
```

Why it does **not** fold in this pass:

- the second RHS has a different value number;
- `rse` is not proving that the first write is dead;
- no liveness or predecessor use analysis runs here.

A different pass may remove dead overwritten writes in some contexts.
Do not attribute that behavior to Binaryen `version_129` `rse`.

## Shape 5: barrier clearing blocks a later fold

Before, conceptually:

```wat
(local.set $x
  (i32.const 1))
(call $unknown)
(local.set $x
  (i32.const 1))
```

Expected important behavior:

```wat
(local.set $x
  (i32.const 1))
(call $unknown)
(local.set $x
  (i32.const 1))
```

Why it does not fold:

- the call is a conservative barrier;
- Binaryen forgets the remembered value for locals;
- the later set must stand because the pass no longer trusts that `$x` still holds `1`.

## Shape 6: branch joins are not merged facts

Before, conceptually:

```wat
(if
  (then
    (local.set $x (i32.const 1)))
  (else
    (local.set $x (i32.const 1))))
(local.set $x (i32.const 1))
```

A dataflow pass could prove both arms agree.
`version_129` `rse` does not depend on that proof.
It uses conservative invalidation around non-linear control instead of exact predecessor merging.

## Shape 7: local-get refinement for GC/reference values

Conceptual before:

```wat
(local.set $x
  (ref.as_non_null
    (local.get $maybe)))
(local.get $x)
```

The important output is not necessarily a visible syntactic rewrite.
The pass can refine the value-numbering fact for `local.get $x` when the remembered expression has a subtype of the get's declared type.

Why it matters:

- later value-number comparisons can be more precise;
- GC/ref-type validation stays sound;
- this is why Binaryen has a dedicated `rse-gc.wast` test surface.

## Shape 8: globals, memory stores, and field stores are non-goals

These are outside `version_129` `rse`:

```wat
(global.set $g (i32.const 1))
(i32.store (i32.const 0) (i32.const 1))
(struct.set $T 0 (local.get $obj) (i32.const 1))
(array.set $A (local.get $arr) (i32.const 0) (i32.const 1))
```

Do not expect this pass to remove them.
If future Starshine work handles those shapes, document it as a Starshine-local extension or a different Binaryen-pass port.

## Shape 9: `rse -> vacuum` handoff

Before `vacuum`:

```wat
(local.set $x (i32.const 1))
(drop (i32.const 1))
```

After a later cleanup, conceptually:

```wat
(local.set $x (i32.const 1))
```

Why this matters:

- `rse` may intentionally leave `drop` wrappers;
- the late pipeline expects `vacuum` to clean unused pure results;
- direct `--rse` output and `--rse --vacuum` output can differ.

## Porting checklist from the shapes

A faithful Starshine shape suite should include:

- same-value `local.set` positive;
- same-value `local.tee` positive;
- RHS trap/effect preservation;
- different-value overwritten-write negative;
- call/control barrier negative;
- GC/refinement local-get coverage;
- late `rse -> vacuum` debris cleanup proof.
