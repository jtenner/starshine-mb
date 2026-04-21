---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0142-2026-04-20-reorder-locals-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./names-roundtrip-and-porting.md
  - ./parity.md
  - ./multivalue-call-scope.md
---

# `reorder-locals` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `reorder-locals` pass.

## Read this page with one mental model

Binaryen `reorder-locals` asks a very small question:

- which body locals are used most, which are used at all, and which were never touched?

Then it does three things:

- keep parameters fixed
- move the hotter live body locals earlier
- drop the untouched body-local tail

## Quick glossary

- **param**: a function parameter; never moved by this pass
- **body local**: a non-parameter local declaration; these are the only locals the pass reorders or drops
- **count**: how many `local.get` / `local.set` uses Binaryen saw for that local
- **first use**: the first time a live body local was seen; used as the tiebreak among equally hot live body locals

## Positive family 1: hotter body locals move earlier

Before:

```wat
(func (param i32)
  (local $x i32) ;; 1 use
  (local $y i32) ;; 2 uses
  (local $z i32) ;; 3 uses
  (local.set $x (local.get $x))
  (local.set $y (local.get $y))
  (local.set $y (local.get $y))
  (local.set $z (local.get $z))
  (local.set $z (local.get $z))
  (local.set $z (local.get $z)))
```

After, conceptually:

```wat
(func (param i32)
  (local $z i32)
  (local $y i32)
  (local $x i32)
  ...same accesses rewritten to the new indices...)
```

Why this works:

- all three body locals are live
- `z` has the highest count, then `y`, then `x`

## Positive family 2: first observed access breaks live ties

Before:

```wat
(func
  (local $a i32)
  (local $b i64)
  ;; each local is used twice, but $a is seen first
  (drop (local.get $a))
  (drop (local.get $b))
  (drop (local.get $a))
  (drop (local.get $b)))
```

After:

- `$a` stays before `$b`

Why:

- both locals have the same nonzero count
- so Binaryen uses first-seen rank as the tiebreak

## Positive family 3: write-only locals survive

Before:

```wat
(func
  (local $deadread i32)
  (local $writeonly i64)
  (i64.const 11)
  (local.set $writeonly)
  (i32.const 7))
```

After, conceptually:

```wat
(func
  (local $writeonly i64)
  (i64.const 11)
  (local.set 0)
  (i32.const 7))
```

Why this works:

- the pass counts writes as accesses
- it does not ask whether the stored value is semantically dead

This is one of the most important beginner corrections.

## Positive family 4: tee-only locals also survive

In Binaryen IR, `local.tee` is represented as `LocalSet` with tee state.
So a tee-only local is still counted as used.

Conceptual raw-wasm example:

```wat
(func
  (local $x i32)
  (local $unused i64)
  (i32.const 5)
  (local.tee $x)
  (drop)
  (i32.const 7))
```

After:

- `$x` survives
- `$unused` disappears

## Positive family 5: unused trailing body locals disappear

Before:

```wat
(func
  (local $used i32)
  (local $unused i64)
  (i32.const 5)
  (local.set $used)
  (local.get $used))
```

After:

```wat
(func
  (local $used i32)
  (i32.const 5)
  (local.set 0)
  (local.get 0))
```

Why this works:

- after sorting, the used local comes first
- the zero-count suffix begins at `$unused`
- Binaryen truncates the body-local list there

## Positive family 6: all body locals can disappear

The dedicated upstream test includes a function that uses none of its body locals at all.
Conceptually:

```wat
(func
  (local $a i32)
  (local $b i32)
  (nop))
```

After:

```wat
(func
  (nop))
```

That is legal and intended.

## Positive family 7: parameters never move, even when hotter than body locals

Before:

```wat
(func (param $p0 i32) (param $p1 i32)
  (local $x i32)
  (local.set $p1 (local.get $p1))
  (local.set $p1 (local.get $p1))
  (local.set $p1 (local.get $p1))
  (local.set $x (local.get $x)))
```

After, conceptually:

- params stay at indices `0` and `1`
- `$x` remains a body local after them

Why this matters:

- parameter heat never lets a body local cross the param boundary
- parameter order is an invariant, not just a likely side effect

## Positive family 8: nested local users are rewritten uniformly

A local can appear inside nested control flow and still participate normally.
For example:

```wat
(func (param i32)
  (local $a i32)
  (local $b i64)
  (block
    (loop
      (drop (local.get $a))
      (if (i32.const 1)
        (then
          (local.set $b (i64.const 7)))
        (else
          (drop (local.tee $a (local.get $a))))))))
```

After:

- the declaration order may change
- every `local.get`, `local.set`, and `local.tee` is rewritten to the new index
- the control-flow structure itself is otherwise unchanged

This is a good reminder that `reorder-locals` is not a control-flow optimizer.

## Positive family 9: declaration order can change even when types differ

The print-roundtrip tests show a simple but important case:

```wat
(func
  (local $x i32)
  (local $y f64)
  (drop (local.get $x))
  (drop (local.get $y))
  (drop (local.get $y)))
```

After:

```wat
(func
  (local $y f64)
  (local $x i32)
  ...)
```

Why this matters:

- the pass does **not** sort by type or keep like-typed locals together
- counts and first-use order decide the declaration order

## Negative family 1: no body locals means true no-op

Before:

```wat
(func (param i32 i64) (result i32)
  (local.get 0))
```

After:

- no change

Why:

- `getNumVars() == 0` returns early

## Negative family 2: this is not dead-store elimination

Before:

```wat
(func
  (local $x i32)
  (i32.const 9)
  (local.set $x)
  (nop))
```

A beginner might expect `$x` to vanish because the stored value is never read.
That does **not** happen here.

Why:

- the pass only asks whether the local was accessed at all
- the `local.set` itself counts as an access

Removing semantically dead stores is another pass's job.

## Negative family 3: this is not local coalescing

Before:

```wat
(func
  (local $a i32)
  (local $b i32)
  ...)
```

If `$a` and `$b` never overlap in useful ways, `reorder-locals` still will not merge them.

Why:

- there is no liveness or interference analysis here
- the pass only reorders and drops zero-count body locals

## Negative family 4: zero-count locals are not stably kept around for names or type grouping

If a body local has count `0` after the scan:

- it does not receive a better place in the order
- it does not stay around just because its type would be convenient
- it does not stay around just because it previously had a name

It is part of the dropped suffix.

## Negative family 5: params do not join the body-local sort competition

Even if a parameter is the hottest local in the function and some body locals are barely used:

- Binaryen does not sort all locals globally by count

The real rule is always:

- params fixed first
- then body locals sorted among themselves

## Negative family 6: multivalue call local growth is not a pass rewrite family

If a tiny multivalue call witness grows more locals on Binaryen roundtrip:

- that is not a `reorder-locals` shape in the narrow sense
- it is a writer / tuple-packaging boundary phenomenon

That boundary is documented separately on:

- [`./multivalue-call-scope.md`](./multivalue-call-scope.md)
- [`./names-roundtrip-and-porting.md`](./names-roundtrip-and-porting.md)

## Practical rules a future port must preserve

A future parity port should keep these exact shape-level rules honest:

- params never move
- body locals move only relative to other body locals
- writes and tees count as accesses
- nonzero-count tie = first use
- zero-count tie = original order
- the zero-count body-local suffix disappears entirely
- nested local users must all be rewritten consistently
- local type differences do not override count-based ordering

## Bottom line

`reorder-locals` is shape-driven, but in a very literal way.

It does not care about deep control-flow meaning.
It cares about:

- how often a local was touched
- when a live body local was first seen
- and whether a body local was ever touched at all

That is the right mental model to keep when comparing it to the much heavier local-analysis passes nearby in the Binaryen pipeline.
