---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ../optimize-added-constants/index.md
---

# `optimize-added-constants-propagate` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `optimize-added-constants-propagate` pass.

## Read this page with one mental model

Binaryen is not asking:

- “can I simplify this arithmetic tree?”

It is asking a smaller and more concrete question:

- “can I move this small added constant into a load/store offset, and if the address was cached in a local, can I still do that safely?”

## Important note about the examples

The `after` snippets are **conceptual**.
Real Binaryen output may keep helper locals, `nop`s, or surrounding wrapper structure.
What matters here is the address-shape contract.

## Quick glossary

- **base**: the nonconstant pointer expression that should remain as the actual pointer operand
- **small constant**: a nonnegative constant below `LowMemoryBound` (`1024` in reviewed `version_129`)
- **direct fold**: rewriting `load/store(base + c)` into `offset=c`
- **propagated fold**: doing the same rewrite when `base + c` first flowed through a local
- **helper local**: a new local Binaryen inserts when the old base cannot be safely reused directly

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

- this is the core direct-address family
- the added constant is small enough to become an offset

## Shape 2: commuted direct load fold

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

- the pass normalizes commuted add forms too
- this is another reason the pass should not be taught as generic arithmetic rewriting

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

- the new small constant is added to the existing offset
- the pointer operand becomes simpler

## Shape 4: direct constant-pointer cleanup

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

- Binaryen prefers the whole constant address in one place when overflow is impossible
- this is for clarity/compressibility, not because the meaning changed

## Shape 5: propagate through a dead address local

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

After, conceptually:

```wat
(nop)
(drop
  (i32.load offset=1
    (local.get $y)))
```

Why it rewrites:

- the local only carried the address shape
- all influenced uses were still load/store parents
- propagation removes the old address-carrier job

## Shape 6: propagate with SSA reuse

Before:

```wat
(local.set $y (local.get $z))
(local.set $x
  (i32.add
    (i32.const 1)
    (local.get $y)))
(drop
  (i32.load
    (local.get $x)))
```

After, conceptually:

```wat
(local.set $y (local.get $z))
(nop)
(drop
  (i32.load offset=1
    (local.get $y)))
```

Why it rewrites cleanly:

- the base local is still safely reusable
- Binaryen does not need a helper local here

## Shape 7: propagate with helper-local insertion

Before:

```wat
(local.set $y (local.get $z))
(local.set $x
  (i32.add
    (i32.const 1)
    (local.get $y)))
(local.set $y (i32.const -2))
(drop
  (i32.load
    (local.get $x)))
```

After, conceptually:

```wat
(block
  (local.set $tmp
    (local.get $y))
  (nop))
(local.set $y (i32.const -2))
(drop
  (i32.load offset=1
    (local.get $tmp)))
```

Why it needs help:

- the original base local may change before the load
- Binaryen snapshots the old base in a helper local

## Shape 8: realistic repeated stack-pointer offsets

Before, conceptually:

```wat
(local.set $x (i32.add (local.get $ptr) (i32.const 8)))
(local.set $y (i32.add (local.get $ptr) (i32.const 16)))
(local.set $z (i32.add (local.get $ptr) (i32.const 24)))
(call $f (i32.load (local.get $x)))
(call $f (i32.load (local.get $y)))
(i32.store (local.get $z)
  (i32.add (i32.load (local.get $z)) (i32.const 1)))
```

After, conceptually:

```wat
(call $f (i32.load offset=8 (local.get $ptr)))
(call $f (i32.load offset=16 (local.get $ptr)))
(i32.store offset=24
  (local.get $ptr)
  (i32.add (i32.load offset=24 (local.get $ptr)) (i32.const 1)))
```

Why it matters:

- this is the most intuitive real-world win
- the pass is good at collapsing stack/frame-pointer-style address locals into direct offseted memory ops

## Shape 9: extra non-memory use blocks propagation

Before:

```wat
(local.set $buf
  (i32.add
    (local.get $sp)
    (i32.const 16)))
(drop (local.get $buf))
(i32.store offset=4
  (local.get $buf)
  (i32.const 1))
```

After, conceptually:

```wat
;; preserved or only partially simplified
```

Why it stays:

- the address local has an extra use outside load/store parent positions
- propagating would not eliminate the old add cleanly enough

## Shape 10: too-large offsets stay as adds

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
- the pass keeps only offsets strictly below that bound

## Shape 11: negative constants stay put

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

- the pass wants safe low-memory offsets, not arbitrary signed pointer math

## Shape 12: no-memory modules are untouched

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

- there are no loads or stores to optimize here

## Shape 13: memory64 overflow-sensitive constant-pointer cases

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

- folding the offset into the constant would overflow
- Binaryen preserves the original split form

## Positive summary

The pass is strongest on:

- direct `load/store(base + small_const)` shapes,
- commuted add forms,
- existing-offset accumulation,
- stack-pointer/frame-pointer address locals,
- and dead address-carrier locals used only by memory accesses.

## Negative summary

The pass is deliberately weak or absent on:

- arbitrary arithmetic expressions,
- negative or too-large constants,
- non-memory uses of the address local,
- no-memory modules,
- and overflow-sensitive constant-pointer normalization.

## Beginner rule of thumb

If the rewrite needs you to say:

- “this small constant only exists to describe where a load/store happens”

then it is a good candidate for this pass.

If you instead need to say:

- “this integer add anywhere in the program should fold”

you are almost certainly talking about some other optimization family.
