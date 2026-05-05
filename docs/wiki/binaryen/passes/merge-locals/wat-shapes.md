---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
---

# `merge-locals` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen `merge-locals`.
Examples are intentionally small and conceptual; exact final WAT can differ after the later cleanup passes that run around it.

## Correct mental model

Binaryen starts from a copy-shaped local traffic pair and asks whether the influenced gets should live on the source local or on the destination local after graph checking.
It does not ask whether arbitrary locals can share storage.
That is [`../coalesce-locals/index.md`](../coalesce-locals/index.md).

## Shape 1: source-side ownership

Before:

```wat
(local $src i32)
(local $dst i32)
(local.set $dst (local.get $src))
(drop (local.get $src))
```

After, conceptually:

```wat
(local $src i32)
(local $dst i32)
(local.set $dst (local.tee $src (local.get $src)))
(drop (local.get $dst))
```

Why it rewrites:

- the candidate is a copy-shaped `local.set` / `local.get`
- the pass can choose to let `$dst` own the influenced gets
- the graph still proves the single-set story after the rewrite

## Shape 2: destination-side ownership

Before:

```wat
(local $src i32)
(local $dst i32)
(local.set $dst (local.get $src))
(drop (local.get $dst))
```

After, conceptually:

```wat
(local $src i32)
(local $dst i32)
(local.set $dst (local.tee $src (local.get $src)))
(drop (local.get $src))
```

Why it rewrites:

- the pass can instead let `$src` own the influenced gets
- this is the opposite orientation from Shape 1
- the graph and type checks still have to agree

## Shape 3: the pass is graph-guided, not adjacent-only

Before, conceptually:

```wat
(local.set $dst (local.get $src))
(if (local.get $cond)
  (then (drop (local.get $src)))
  (else (drop (local.get $dst))))
```

After, conceptually, either ownership direction may survive depending on the graph:

```wat
(local.set $dst (local.tee $src (local.get $src)))
(if (local.get $cond)
  (then (drop (local.get $dst)))
  (else (drop (local.get $dst))))
```

or

```wat
(local.set $dst (local.tee $src (local.get $src)))
(if (local.get $cond)
  (then (drop (local.get $src)))
  (else (drop (local.get $src))))
```

Why it can rewrite:

- control structure alone is not a bailout
- the pass checks set influence, not just adjacency

## Shape 4: type mismatch blocks the candidate

Before and after stay the same in the important part:

```wat
(local.set $dst (local.get $src))
(drop (local.get $dst))
```

Why Binaryen keeps it:

- the influenced gets must keep matching local types
- a mismatched type makes the orientation unsafe

## Shape 5: post-graph rollback keeps the pass honest

Before and after can stay the same around a candidate that looked good initially:

```wat
(local.set $dst (local.get $src))
(drop (local.get $src))
```

Why this matters:

- the pass can accept a candidate pre-rewrite and still reject it after the postGraph check
- the visible result is conservative, not maximal

## Shape 6: unreachable-adjacent ambiguity is conservative

Before:

```wat
(local.set $dst (local.get $src))
unreachable
(drop (local.get $dst))
```

Why this matters:

- the reviewed lit surface still keeps a `between-unreachable` regression around
- do not assume unreachable code always unlocks a more aggressive copy rewrite

## One-sentence summary for each family

- **source-side ownership:** positive when the graph says the destination-side gets can move
- **destination-side ownership:** positive when the graph says the source-side gets can move
- **graph-guided control-flow shape:** positive when the copy relation survives across control structure
- **type mismatch:** negative
- **post-graph rollback:** conservative safety net
- **unreachable-adjacent ambiguity:** conservative

## Bottom line

`merge-locals` rewrites copy-shaped local traffic, not arbitrary locals.
The shapes to remember are the two ownership directions, the graph-guided control-flow positive, the type-mismatch negative, and the conservative unreachable-boundary regression.
