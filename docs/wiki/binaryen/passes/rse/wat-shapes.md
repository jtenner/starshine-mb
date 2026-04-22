---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
  - ../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0114-2026-04-20-rse-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cfg-and-value-tracking.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `rse` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `rse` pass.
The upstream provenance for the shapes here was rechecked against the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-rse-primary-sources.md`](../../../raw/binaryen/2026-04-22-rse-primary-sources.md) on 2026-04-22.

## Read this page with one mental model

Binaryen is asking two linked questions:

1. what value does this local definitely hold right now?
2. does any future read still need this `local.set`, or can those reads be rewritten directly?

If the pass can answer:

- “the local already has that value,” or
- “the future reads can be rewritten and no later block depends on this stored state,”

then it may delete the set.

## Quick glossary

- **current value**: the exact value Binaryen thinks a local currently holds
- **influencing set**: a `local.set` whose stored value still matters to some future read or fallthrough
- **merged values**: several predecessor values where Binaryen knows the alternatives but not one exact replacement expression
- **same-block read rewrite**: replacing a `local.get` directly so the earlier set becomes unnecessary
- **refined expression**: a more precise GC expression like `ref.cast` or `ref.as_non_null`

## Shape 1: a plain overwritten set disappears

Before:

```wat
(local.set $x
  (i32.const 1))
(local.set $x
  (i32.const 2))
```

After, conceptually:

```wat
(i32.const 1) ;; kept only if its RHS work matters
(local.set $x
  (i32.const 2))
```

Why it folds:

- the second write overwrites the first
- no needed read survives between them
- the earlier store no longer matters

This is the simplest family and the one the README summary hints at.

## Shape 2: storing the same value again is redundant

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

- Binaryen already knows `$x` holds that exact value
- the second store changes nothing
- the assignment vanishes, but the RHS is still preserved if needed

## Shape 3: a redundant `local.tee` becomes just the value

Before:

```wat
(drop
  (local.tee $x
    (i32.const 1)))
```

Conceptual after when `$x` already holds `1`:

```wat
(drop
  (i32.const 1))
```

Why it matters:

- `local.tee` returns a value, so Binaryen cannot just erase it the way it erases a plain `local.set`
- it removes the store part while preserving the produced value

## Shape 4: copied locals do not always need a separate store

Before:

```wat
(local.set $y
  (i32.const 42))
(local.set $x
  (local.get $y))
(local.get $y)
```

Conceptual after:

```wat
(local.set $y
  (i32.const 42))
;; no meaningful separate store to $x needed
(local.get $y)
```

Why it folds:

- Binaryen tracks `$x` as inheriting `$y`'s current value and history
- if nothing later truly needs `$x` as its own stored slot, the copied store is redundant

This is one place where the pass is wider than an adjacent-overwrite peephole.

## Shape 5: same-block reads can be rewritten, so the earlier set can still die

Before:

```wat
(local.set $x
  (i32.const 7))
(drop
  (local.get $x))
(local.set $x
  (i32.const 9))
```

Conceptual after:

```wat
(drop
  (i32.const 7))
(local.set $x
  (i32.const 9))
```

Why it folds:

- the only intervening read was in the same block
- Binaryen can rewrite that read directly to the current expression
- after that rewrite, the first set is no longer needed before the later overwrite

This is the single easiest `rse` behavior to miss.

## Shape 6: merge points with unanimous predecessors can still fold

Before, conceptually:

```wat
(if
  (then
    (local.set $x (i32.const 1)))
  (else
    (local.set $x (i32.const 1))))
(local.get $x)
```

After, conceptually:

```wat
(if
  (then)
  (else))
(i32.const 1)
```

Why it folds:

- both predecessors agree on the same exact current value
- Binaryen keeps exact knowledge through that merge
- the later `local.get` can be replaced

The `if2` / `many-merges` families in the shipped tests are the best concrete examples.

## Shape 7: merge points with different predecessor values do **not** fold exactly

Before, conceptually:

```wat
(if
  (then
    (local.set $x (i32.const 1)))
  (else
    (local.set $x (i32.const 2))))
(local.get $x)
```

Before and after stay the same in the important part.

Why Binaryen keeps it:

- predecessors disagree on the current value
- the pass records `MergedValues`
- that is useful for bookkeeping, but not enough to materialize one exact replacement expression

This is the right beginner mental model for “merged values are not real phi reconstruction.”

## Shape 8: non-linear control flow is a barrier

Conceptual shape:

```wat
(local.set $x
  (i32.const 1))
(br_if $l (local.get $cond))
(local.get $x)
```

Why Binaryen becomes conservative:

- the branch makes control flow non-linear
- the pass clears its exact current-value cache around that barrier
- the later `local.get` is much less likely to fold

Beginner takeaway:

- `rse` is aggressive in straight-line code
- it gets cautious once branching enters the picture

## Shape 9: loops are intentionally conservative today

Conceptual shape:

```wat
(loop $loop
  (local.set $x
    (i32.const 1))
  ...
  (br $loop)
  (local.get $x))
```

Why Binaryen does **not** promise a fold here:

- loop backedges require stronger block-input reasoning
- the upstream source explicitly says the current model is not right in loops
- `rse` therefore leaves loop precision on the table

The shipped `loop-target-preserved` GC test protects this conservative choice.

## Shape 10: refined GC expressions can replace later local gets

Before, conceptually:

```wat
(local.set $refined
  (ref.cast ... (local.get $arg)))
(local.set $x
  (local.get $refined))
(local.get $x)
```

After, conceptually:

```wat
(ref.cast ... (local.get $arg))
```

Why it folds:

- Binaryen knows the current value of `$x` is the refined expression
- that refined expression is assignable to the later `local.get` type
- using the refined expression directly makes the stored local traffic redundant

This is the positive GC family from `rse-gc.wast`.

## Shape 11: a more refined expression is **not** always a valid replacement

Before and after stay the same in the important part when the type story is wrong.

Why Binaryen keeps it:

- same semantic runtime value is not enough
- the replacement expression must also fit the `local.get`'s static type
- some GC tests explicitly protect the nullable-vs-non-null distinction here

Beginner takeaway:

- `rse` is not just proving value equality
- it is also proving type-legal substitution

## Shape 12: different refined predecessor choices stay as a real local get

Conceptual shape from the `different-choices` GC test:

```wat
(if
  (then
    (local.set $x (local.get $choice1)))
  (else
    (local.set $x (local.get $choice2))))
(local.get $x)
```

Why Binaryen keeps the get:

- the two choices are different current values
- the merge is not single-valued enough for exact substitution
- preserving the real `local.get` is safer than picking one branch's representative

## Shape 13: this pass does **not** eliminate `global.set` / memory stores / `struct.set`

Before and after stay the same for the relevant operation families:

```wat
(global.set $g
  (i32.const 1))
(i32.store
  (i32.const 0)
  (i32.const 1))
(struct.set $S 0
  (local.get $obj)
  (i32.const 1))
```

Why it matters:

- the pass name is broad
- the implementation is not
- `RedundantSetElimination.cpp` only implements local traffic cleanup in `version_129`

## What nearby passes do with the new shape

`rse` is deliberately almost the last local cleanup pass.

### Unlock family 1: final `vacuum`

After `rse` turns redundant stores into `drop(value)` or raw values, final `vacuum` removes tiny leftovers.

### Unlock family 2: earlier local cleanup passes expose `rse` candidates

Earlier passes such as:

- `coalesce-locals`
- `local-cse`
- `simplify-locals`
- late `precompute`
- late `optimize-instructions`
- late `heap-store-optimization`

make it easier for `rse` to see repeated current values and dead copied locals.

### Unlock family 3: nested optimizing reruns matter too

Because `dae-optimizing` and `inlining-optimizing` rerun the default function cleanup pipeline, `rse` is also a post-change cleanup tool in those nested lanes, not just in the top-level late slot.

## A simple rule of thumb

When you look at a possible `rse` candidate, ask these questions in order:

1. Is this really local traffic, or am I accidentally asking `rse` to optimize some other instruction family?
2. Does Binaryen know one exact current value for the local here?
3. If not, did predecessor disagreement already collapse us to merged values?
4. If a later `local.get` exists, can it be rewritten directly?
5. Does the current expression still fit the use site's static type?
6. Did control flow hit a non-linear barrier or a loop precision boundary?

If the answer to `2`, `4`, `5`, or `6` is wrong for the transformation, expect Binaryen to keep the local traffic.

## Source strength note

- The positive and negative shapes above come directly from Binaryen's shipped `rse` tests plus the `version_129` implementation.
- The scheduler-interaction notes are derived from the official `pass.cpp` order and the nested rerun helper in `opt-utils.h`.

## Sources

- [`../../../raw/binaryen/2026-04-22-rse-primary-sources.md`](../../../raw/binaryen/2026-04-22-rse-primary-sources.md)
- [`../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md`](../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0114-2026-04-20-rse-binaryen-research.md`](../../../raw/research/0114-2026-04-20-rse-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- Binaryen `version_129` pass tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- Binaryen `version_129` pass output: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt>
- Binaryen `version_129` GC lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
