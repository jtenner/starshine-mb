---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./merge-shapes-and-canonical-slots.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `ssa-nomerge` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `ssa-nomerge` pass.

## Read this page with one mental model

Binaryen `ssa-nomerge` is trying to prove:

- every read that matters for this write comes from exactly one source

If it can prove that, it can give the write a fresh local slot.
If it cannot, it leaves the merge on the canonical original slot.

## Quick glossary

- **canonical slot**: the original local index from the input function
- **fresh slot**: a new local Binaryen creates for one specific write
- **entry value**: the parameter value or zero-init/default local value
- **merge get**: a `local.get` with more than one reaching source in LocalGraph

## Positive family 1: straight-line untangling

Before:

```wat
(local $x i32)
(local.set $x (i32.const 1))
(drop (local.get $x))
(local.set $x (i32.const 2))
(drop (local.get $x))
```

After, conceptually:

```wat
(local $x i32)      ;; original slot may remain declared
(local $x.1 i32)
(local $x.2 i32)
(local.set $x.1 (i32.const 1))
(drop (local.get $x.1))
(local.set $x.2 (i32.const 2))
(drop (local.get $x.2))
```

Why this works:

- each nearby get is single-source
- no later merge get needs those sets on the canonical slot

## Positive family 2: repeated gets after one set stay on the same fresh slot

Before:

```wat
(local $x i32)
(local.set $x (i32.const 3))
(call $use (local.get $x) (local.get $x))
```

After, conceptually:

```wat
(local $x.1 i32)
(local.set $x.1 (i32.const 3))
(call $use (local.get $x.1) (local.get $x.1))
```

Why this matters:

- “single-source” does not mean “single-use”
- one set can feed many gets and still be eligible

## Positive family 3: dead param overwrite gets a fresh slot

Before:

```wat
(func (param $p i64) (result i32)
  (i64.const 756)
  (local.set $p)
  (i32.const 700))
```

After, conceptually:

```wat
(func (param $p i64) (result i32)
  (local $p.dead i64)
  (i64.const 756)
  (local.set $p.dead)
  (i32.const 700))
```

Why this works:

- the overwritten param value is not used later
- so Binaryen does not need to keep the canonical param slot alive for that write

## Positive family 4: dead param tee also gets a fresh slot

Before:

```wat
(func (param $p f64) (result f32)
  (f64.const 17)
  (local.tee $p)
  (drop)
  (f32.const 92))
```

After, conceptually:

```wat
(local $p.dead f64)
(f64.const 17)
(local.tee $p.dead)
(drop)
(f32.const 92)
```

Why this matters:

- the same no-merge rule applies to tee-style writes too
- the key question is still later source multiplicity, not syntax

## Positive family 5: default local reads become explicit zeros

Before:

```wat
(local $x i32)
(drop (local.get $x))
```

After:

```wat
(drop (i32.const 0))
```

The dedicated official `ssa-nomerge` golden file also shows analogous rewrites for:

- `f32` -> `f32.const 0`
- `i64` -> `i64.const 0`
- `f64` -> `f64.const 0`
- `v128` -> an explicit zero splat

Why this works:

- LocalGraph proves the only source is the entry/default value
- the pass is allowed to materialize that value directly when the type is defaultable

## Positive family 6: some writes inside one original local still get fresh slots while later merge writes do not

Before, conceptually:

```wat
(local $x i32)
(local.set $x (i32.const 1))
(call $use (local.get $x) (local.get $x))
(local.set $x (i32.const 2))
(call $use (local.get $x) (local.get $x))
(local.set $x (i32.const 3))
;; later control flow merges and reads $x
```

After, conceptually:

```wat
(local $x i32)
(local $x.1 i32)
(local $x.2 i32)
(local.set $x.1 (i32.const 1))
(call $use (local.get $x.1) (local.get $x.1))
(local.set $x.2 (i32.const 2))
(call $use (local.get $x.2) (local.get $x.2))
(local.set $x (i32.const 3))
;; merge region stays canonical
```

Why this matters:

- `ssa-nomerge` decisions are per set, not per original local

## Positive family 7: overwritten write inside a merge arm can still untangle

Before:

```wat
(if
  (i32.const 1)
  (then
    (local.set $x (i32.const 6)))
  (else
    (block
      (local.set $x (i32.const 7))
      (local.set $x (i32.const 8)))))
(drop (local.get $x))
```

After, conceptually:

- the write of `7` can use a fresh slot if it never feeds the final merged read
- the final `8` write stays on canonical `$x`
- the `then` write of `6` also stays on canonical `$x`

Why this matters:

- merge regions are not all-or-nothing per arm
- overwritten dead intermediate writes can still untangle

## Negative family 1: one-arm `if` merging with default local value

Before:

```wat
(local $x i32)
(if
  (i32.const 1)
  (then
    (local.set $x (i32.const 1))))
(drop (local.get $x))
```

After:

- the get stays on canonical `$x`
- the set stays on canonical `$x`

Why this blocks untangling:

- the post-`if` get can see either the explicit set or the entry zero value
- that is a merge, even though there is only one explicit set

## Negative family 2: one-arm `if` merging with the entry param value

Before:

```wat
(func (param $p i32)
  (if
    (i32.const 1)
    (then
      (local.set $p (i32.const 1))))
  (drop (local.get $p)))
```

After:

- the param overwrite stays on canonical `$p`
- the get stays on canonical `$p`

Why this blocks untangling:

- the get can see either the overwritten value or the original parameter value

## Negative family 3: both-arm write merge

Before:

```wat
(local $x i32)
(if
  (i32.const 1)
  (then (local.set $x (i32.const 4)))
  (else (local.set $x (i32.const 5))))
(drop (local.get $x))
```

After:

- no fresh merge slot is created in `ssa-nomerge`
- the sets and the get stay on canonical `$x`

Why this blocks untangling:

- the read is explicitly multi-source
- full `--ssa` would materialize a merge local here, but `ssa-nomerge` will not

## Negative family 4: loop/backedge merge regions stay canonical

Source-backed inference from `SSAify.cpp` plus LocalGraph:

```wat
(local $x i32)
(local.set $x (i32.const 1))
(loop
  ...
  (local.set $x (i32.const 2))
  (br_if 0 ...))
(drop (local.get $x))
```

Expected no-merge behavior:

- reads that may see both the entry/carried value and the backedge value are merge reads
- the participating carried slot stays canonical

Why this is an inference:

- the dedicated official `ssa-nomerge` golden file does not include a loop-specific case
- but the source rule is the same: if a get has multiple reaching sets, no merge local is created in no-merge mode

## Negative family 5: nondefaultable locals keep their entry reads

Before, conceptually:

```wat
(local $x (ref $NonNullableType))
(local.get $x)
```

If the type has no valid zero/default literal:

- the pass leaves the get alone

Why this matters:

- default-value materialization is conditional on the type being defaultable
- `ssa-nomerge` is not allowed to invent impossible values just to remove a get

## Negative family 6: unreachable-code provenance is intentionally loose

If a get sits in unreachable code, LocalGraph may still conservatively include the entry/default value.

Why this matters:

- you should not read `ssa-nomerge` as a precise unreachable-code debugger tool
- the helper comments explicitly say this tradeoff is acceptable because unreachable code should be removed later

## Shared-SSAify families that are relevant but not dedicated no-merge goldens

The shared `test/lit/passes/ssa.wast` file locks helper behavior in the same `SSAify.cpp` source that still matters here.

Useful examples from that shared surface:

- non-nullable param overwrite can force fresh locals
- default tuple reads can materialize explicit tuple zeros
- default ref reads can materialize null and require refinalization

These are relevant to the shared helper surface, but keep the distinction explicit:

- they are not dedicated `ssa-nomerge` golden cases
- they are shared `SSAify.cpp` behavior that the no-merge variant can also reach in the appropriate source-backed situations

## Full-`ssa`-only family: merge locals, tees, and function-entry prepends

This family is worth calling out as a deliberate non-goal of `ssa-nomerge`.

Conceptually, full `--ssa` may turn a merge like this:

```wat
(if
  ...
  (then (local.set $x ...))
  (else (local.set $x ...)))
(local.get $x)
```

into:

```wat
(if
  ...
  (then
    (local.tee $merge ...)
    ...)
  (else
    (local.tee $merge ...)
    ...))
(local.get $merge)
```

and may also prepend entry copies when a parameter is one of the incoming values.

That is **not** `ssa-nomerge` behavior.

## Scheduler interaction to remember

In the canonical no-DWARF path, `ssa-nomerge` runs before the first big cleanup wave.
That is not accidental.

The intended handoff is:

- `ssa-nomerge` simplifies obvious single-source local traffic
- later passes such as `dce`, `remove-unused-*`, `vacuum`, and `coalesce-locals` clean up the residue and recover some of the extra fresh locals

So the pass is best viewed as early preparation, not a final local-form normalizer.
