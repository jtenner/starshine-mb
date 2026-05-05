---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-merge-locals-current-main-recheck.md
  - ../../../raw/research/0485-2026-05-05-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../coalesce-locals/index.md
---

# `merge-locals`: LocalGraph and copy influences

## Why this page exists

The easiest way to misread `merge-locals` is to choose one wrong extreme:

- too small: “just delete adjacent `local.set` / `local.get` pairs”
- too large: “do full `coalesce-locals` style slot coloring”
- stale overread: “treat it as one-set-local merging with a fresh-temp fallback”

The reviewed Binaryen implementation is in between.
It starts from a concrete copy-shaped local traffic pair, uses `LocalGraph` set influences to decide which side should own the influenced gets, and then verifies the rewrite against a post-graph snapshot.
The 2026-05-05 freshness layer keeps that reading current without changing the contract.

## The central question

Ask:

- “after exposing this copy as a trivial tee, should the influenced gets live on the source local or on the destination local?”

Do **not** ask:

- “are these locals globally equivalent?”
- “can these locals share a slot?”
- “is this a one-set local that should be rewritten from scratch?”

Those are different pass families or stale documentation claims.

## What `LocalGraph` contributes

`MergeLocals.cpp` uses `LocalGraph` set influences to compare the original copy local and the synthetic tee local.
That gives the pass a narrow proof surface:

- which influenced gets can move toward the copy destination?
- which influenced gets can move toward the copy source?
- do the affected gets still have one proven set after the rewrite?

### Set influences

Set influences let the pass ask whether a candidate's influenced gets still trace to the intended source of truth.
The candidate dies if the graph no longer supports that orientation.

That is the real proof surface: a copy-oriented single-set story, not generic local equivalence.

## Why eager graph construction matters

The reviewed source constructs the graph eagerly so it can compare against the original state while mutating the function.
The pass then performs a post-graph check to catch candidates that looked good before rewrite but no longer hold afterward.

For readers, the takeaway is simple:

- Binaryen pays for a fuller graph because this pass is meant to make a local copy relationship explicit, choose an orientation, and then verify that the choice still holds.

## How this is wider than a peephole

A copy can be separated from its uses by control structure or by later local traffic.
The pass therefore reasons over graph facts instead of only over an adjacent pair.

So a future Starshine port should not be implemented as only:

```wat
(local.set $x (local.get $y))
```

The source-backed pass is graph-guided and orientation-sensitive.

## How this is narrower than `coalesce-locals`

[`../coalesce-locals/index.md`](../coalesce-locals/index.md) is about broader slot sharing under liveness/interference constraints.
`merge-locals` is not.

`merge-locals` does not try to answer:

- can two unrelated locals occupy the same slot?
- can compatible typed locals be recolored?
- can a later declaration order be improved?

It answers only a much smaller question:

- can this copy-shaped pair be rewritten so one side owns the influenced gets, with post-graph verification keeping the result honest?

## Direct source-to-destination retargeting

If the synthetic tee side is safe, Binaryen can retarget influenced gets toward the original copy destination.

Conceptually:

```wat
(local.set $x (local.get $y))
(drop (local.get $y))
```

becomes a shape where the later gets live on `$x` instead.

The graph proof matters because the pass must know the later uses are still fed by one set.

## Destination-to-source retargeting

If the original copy side is the better target, Binaryen can retarget influenced gets toward the source local instead.

Conceptually:

```wat
(local.set $x (local.get $y))
(drop (local.get $x))
```

can become a shape where the later gets live on `$y` instead.

The pass does not claim those two locals are identical; it chooses the side that still has a clean graph story.

## What to remember

`merge-locals` is a **copy-oriented `LocalGraph` rewrite**:

- the copy is made explicit with a trivial tee
- `LocalGraph` decides whether the source or destination side should own the influenced gets
- the pass verifies the rewrite with a post-graph snapshot
- broader slot sharing belongs to `coalesce-locals`
- the older one-set-local / fresh-temp model is stale for the reviewed source
