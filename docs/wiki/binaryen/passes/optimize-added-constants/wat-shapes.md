---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md
  - ../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md
  - ../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./low-memory-threshold-overflow-and-offset-merge-rules.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-added-constants-propagate/index.md
---

# `optimize-added-constants` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's plain `optimize-added-constants` pass.
For the source manifest, current-main recheck, Starshine port map, and implementation-readiness ladder, see [`../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md`](../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md), [`../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md), [`./starshine-strategy.md`](./starshine-strategy.md), and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Read this page with one mental model

Binaryen is not asking:

- “can I simplify this add expression in general?”

It is asking a smaller question:

- “can I turn this small added constant in a memory address into an explicit load/store offset?”

## Important note about the examples

The `after` snippets are **conceptual**.
Real Binaryen output may preserve surrounding wrapper structure.
What matters here is the direct memory-address contract.

## Quick glossary

- **base**: the nonconstant pointer expression that should stay as the pointer operand
- **small constant**: a nonnegative constant below `LowMemoryBound` (`1024` in reviewed `version_129`)
- **direct fold**: rewriting `load/store(base + c)` into `offset=c`
- **constant-pointer normalization**: merging `offset + const` into one constant pointer when overflow is impossible

## Shape 1: direct load fold

Before:

```wat
(drop
  (i32.load
    (i32.add
      (local.get $x)
      (i32.const 8))))
```

After, conceptually:

```wat
(drop
  (i32.load offset=8
    (local.get $x)))
```

Why it rewrites:

- the add only exists to describe the address
- the constant is small enough to become an offset

## Shape 2: commuted direct fold

Before:

```wat
(drop
  (i32.load
    (i32.add
      (i32.const 4)
      (local.get $x))))
```

After, conceptually:

```wat
(drop
  (i32.load offset=4
    (local.get $x)))
```

Why it matters:

- commuted add forms are still fair game

## Shape 3: existing offset accumulation

Before:

```wat
(i32.store offset=2
  (i32.add
    (local.get $x)
    (i32.const 5))
  (local.get $v))
```

After, conceptually:

```wat
(i32.store offset=7
  (local.get $x)
  (local.get $v))
```

Why it rewrites:

- the added constant is merged into the already-present offset

## Shape 4: constant-pointer cleanup

Before:

```wat
(drop
  (i32.load offset=10
    (i32.const 0)))
```

After, conceptually:

```wat
(drop
  (i32.load
    (i32.const 10)))
```

Why it rewrites:

- Binaryen prefers a single constant address when that is obviously safe

## Shape 5: direct constant-plus-constant address

Before:

```wat
(drop
  (i32.load offset=2
    (i32.add
      (i32.const 2)
      (i32.const 4))))
```

After, conceptually:

```wat
(drop
  (i32.load
    (i32.const 8)))
```

Why it rewrites:

- the pass can absorb the add into the memory address surface itself

## Shape 6: too-large offsets stay as adds

Before:

```wat
(drop
  (i32.load
    (i32.add
      (local.get $x)
      (i32.const 1024))))
```

After, conceptually:

```wat
(drop
  (i32.load
    (i32.add
      (local.get $x)
      (i32.const 1024))))
```

Why it stays:

- `1024` is at the reviewed `LowMemoryBound` cutoff

## Shape 7: negative constants stay put

Before:

```wat
(i32.store offset=2
  (i32.add
    (local.get $x)
    (i32.const -13))
  (local.get $v))
```

After, conceptually:

```wat
(i32.store offset=2
  (i32.add
    (local.get $x)
    (i32.const -13))
  (local.get $v))
```

Why it stays:

- the pass is not trying to encode arbitrary signed pointer math as offsets

## Shape 8: no-memory modules are untouched

Before:

```wat
(module
  (func (param $x i32) (result i32)
    (i32.add (local.get $x) (i32.const 42))))
```

After, conceptually:

```wat
(module
  (func (param $x i32) (result i32)
    (i32.add (local.get $x) (i32.const 42))))
```

Why it stays:

- there are no loads or stores to optimize

## Shape 9: memory64 overflow-sensitive constant-pointer cases

Before:

```wat
(i64.load offset=32
  (i64.const 0xfffffffffffffff0))
```

After, conceptually:

```wat
(i64.load offset=32
  (i64.const 0xfffffffffffffff0))
```

Why it stays:

- merging the offset into the constant would overflow

## Shape 10: local-pair propagation is not plain mode

Before:

```wat
(local.set $x
  (i32.add
    (local.get $y)
    (i32.const 1)))
(drop
  (i32.load
    (local.get $x)))
```

After, conceptually in **plain mode**:

```wat
(local.set $x
  (i32.add
    (local.get $y)
    (i32.const 1)))
(drop
  (i32.load
    (local.get $x)))
```

Why it stays:

- following address locals is the propagate sibling's job, not the plain pass's job

## Positive summary

The plain pass is strongest on:

- direct `load/store(base + small_const)` shapes,
- commuted add forms,
- existing offset accumulation,
- and constant-pointer cleanup.

## Negative summary

The plain pass is deliberately weak or absent on:

- arbitrary arithmetic,
- negative or too-large constants,
- no-memory modules,
- overflow-sensitive constant-pointer cases,
- and local-pair propagation.

## Beginner rule of thumb

If the rewrite needs you to say:

- “the memory address itself has a small added constant right here”

then the plain pass may own it.

If you instead need to say:

- “the address got stored in a local first, but we should still chase it”

then you are probably talking about `optimize-added-constants-propagate`, not plain `optimize-added-constants`.

## Starshine reading note

Current Starshine has no local rewrite for any shape on this page. Treat the examples as future-port targets, and read [`./starshine-strategy.md`](./starshine-strategy.md) for the exact removed-registry status plus the HOT `Load` / `Store` and `MemArg` code surfaces a future implementation would use.
