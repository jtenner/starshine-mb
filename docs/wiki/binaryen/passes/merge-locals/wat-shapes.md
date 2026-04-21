---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0128-2026-04-20-merge-locals-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./local-graph-and-copy-influences.md
  - ../coalesce-locals/index.md
---

# `merge-locals` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen’s `merge-locals` pass.

## Read this page with one mental model

Binaryen is not asking:

- “can I delete this one copy instruction?”

It is asking:

- “do these locals all belong to one simple single-set source story?”

That means four questions matter most:

1. does the candidate local have exactly **one set**?
2. does that set have a real **value**?
3. is that value **simple / reorderable** enough under `FunctionUtils::isSimple(...)`?
4. do the uses Binaryen wants to rewrite still trace back to that **same exact set**?

## Important note about the examples

The `after` snippets below are often **conceptual**.

In real Binaryen output:

- the chosen temp index may differ
- some old locals may still appear in declarations before later passes clean them up
- exact printed structure depends on neighboring cleanup passes

So read the shapes as “what family rewrites or stays put,” not “the exact final pretty-printed indices in every case.”

## Quick glossary

- **candidate local**: the local Binaryen is currently checking for the one-set-simple-source rule
- **influenced gets**: the gets `LocalGraph` says are fed by that candidate’s set story
- **canonical slot**: the local index all proven aliases will read after the rewrite
- **direct reuse**: Binaryen reuses an existing source local as the canonical slot
- **fresh temp**: Binaryen creates one new local to be the canonical slot

## Shape 1: simple copy chain collapses back to the original source local

Before:

```wat
(local.set $a (i32.const 10))
(local.set $b (local.get $a))
(drop (local.get $b))
```

After, conceptually:

```wat
(local.set $a (i32.const 10))
(drop (local.get $a))
```

Why it rewrites:

- `$b` has exactly one set
- that set is a direct `local.get $a`
- the uses of `$b` all still belong to that one source story
- Binaryen can reuse `$a` directly as the canonical slot

This is the cleanest positive case.

## Shape 2: transitive copy chain also collapses

Before:

```wat
(local.set $a (i32.const 10))
(local.set $b (local.get $a))
(local.set $c (local.get $b))
(drop (local.get $c))
```

After, conceptually:

```wat
(local.set $a (i32.const 10))
(drop (local.get $a))
```

Why it rewrites:

- `LocalGraph` can compute influences transitively through the chain
- the whole group still has one simple source story

This is why the official tests include transitive-order families.

## Shape 3: one simple computed value can become one fresh canonical temp

Before:

```wat
(local.set $a
  (i32.add
    (local.get $x)
    (i32.const 1)))
(local.set $b (local.get $a))
(drop (local.get $b))
```

After, conceptually:

```wat
(local.set $canon
  (i32.add
    (local.get $x)
    (i32.const 1)))
(drop (local.get $canon))
```

Why it rewrites:

- the value is still simple / reorderable enough
- but it is not the trivial “just reuse one existing source local” case
- Binaryen therefore creates one fresh canonical temp

This is the easiest shape for beginners to miss because the pass name sounds like it should only delete locals.

## Shape 4: DAG fanout can still normalize to one slot

Before, conceptually:

```wat
(local.set $a (i32.const 1))
(local.set $b (local.get $a))
(local.set $c (local.get $a))
(drop (local.get $b))
(drop (local.get $c))
```

After, conceptually:

```wat
(local.set $a (i32.const 1))
(drop (local.get $a))
(drop (local.get $a))
```

Why it rewrites:

- the graph still says both branches of alias traffic come from the same set story
- Binaryen is not limited to one linear chain

This is the `merge in a DAG` lesson.

## Shape 5: loop-backedge alias traffic is still a real positive case

Before, conceptually:

```wat
(loop $L
  (local.set $next (local.get $curr))
  (drop (local.get $next))
  (br $L)
)
```

After, conceptually:

```wat
(loop $L
  (drop (local.get $curr))
  (br $L)
)
```

Why it rewrites:

- the official `loop-backedge` test says Binaryen wants this family
- the graph still proves one simple source story for the alias local

The exact printed result can vary, but the important fact is:

- loops do not automatically disqualify the pass

## Shape 6: multiple sets to the same local do **not** qualify

Before and after stay the same in the important part:

```wat
(if (local.get $cond)
  (then (local.set $x (i32.const 1)))
  (else (local.set $x (i32.const 2))))
(drop (local.get $x))
```

Why Binaryen keeps it:

- `$x` does not have one set story
- the pass’s core precondition fails immediately

This is the most important negative case.

## Shape 7: complex control-heavy source values stay put

Before and after stay the same in the important part:

```wat
(local.set $x
  (block (result i32)
    (loop $L
      (br $L)
    )
    (i32.const 1)))
(drop (local.get $x))
```

Why Binaryen keeps it:

- the source value is not simple enough under `FunctionUtils::isSimple(...)`
- `keepSimple1` and `keepSimple2` exist to lock in this boundary

This is a strong reminder that the pass is not allowed to normalize arbitrary control-heavy producers.

## Shape 8: effectful or trap-sensitive source values should be treated as negative shapes

Before and after stay the same in the important part, conceptually:

```wat
(local.set $x
  (call $impure))
(local.set $y (local.get $x))
(drop (local.get $y))
```

Why Binaryen should keep it:

- the simple-value gate is effect-aware
- an impure or unremovable-side-effect source is outside the intended merge surface

The pass source expresses this through `FunctionUtils::isSimple(...)`, not by listing every forbidden operator family explicitly.

## Shape 9: “looks simple locally, but uses do not all agree on one set” bails out

Before, conceptually:

```wat
(local.set $x (i32.const 1))
(if (local.get $cond)
  (then (local.set $x (i32.const 2))))
(drop (local.get $x))
```

After, conceptually:

```wat
(local.set $x (i32.const 1))
(if (local.get $cond)
  (then (local.set $x (i32.const 2))))
(drop (local.get $x))
```

Why Binaryen keeps it:

- even if one source path looks attractive, the get no longer belongs to one unambiguous set story
- the pass filters influenced gets against the exact candidate set before committing

This is the provenance-agreement bailout.

## Shape 10: local-name metadata can disable the pass for the whole function

This is not a WAT surface shape, but it is still a real eligibility rule.

If the function already has local names, Binaryen returns early and does not run the pass.

Why that matters:

- two structurally identical functions can get different optimization behavior depending on metadata
- a future Starshine port must choose an explicit policy there too

## Shape 11: unreachable/control-edge weirdness is a conservative zone

Before, conceptually:

```wat
(block
  (br_if $out (local.get $cond))
  (unreachable)
)
(local.set $x (i32.const 1))
(drop (local.get $x))
```

After, conceptually:

- Binaryen may still optimize some surrounding alias traffic
- but the important contract is that it stays conservative and valid around the unreachable/control boundary

Why this matters:

- the official `between-unreachable` test exists precisely because this area is easy to get wrong
- a future port should preserve that conservatism, not just the happy-path copy-chain wins

## Important interaction families

## Interaction 1: `heap2local` creates more opportunities

Why scheduler placement matters:

- `heap2local` can turn memory traffic into more local traffic
- stronger optimize/shrink modes then run `merge-locals`
- so the pass gets a richer alias-local surface than it would earlier

## Interaction 2: `optimize-casts` sees the post-merge local surface

Why placement matters:

- under stronger settings, `merge-locals` runs immediately before `optimize-casts`
- that means cast optimization reasons about a cleaner alias surface, not the original copy-heavy one

## Interaction 3: `coalesce-locals` is a different later cleanup layer

Why the distinction matters:

- `merge-locals` handles narrow one-source alias families first
- `coalesce-locals` later handles wider slot-sharing based on different reasoning

So if you see both passes in the same neighborhood, do not collapse them into one concept.

## One-sentence summary for each family

- **simple direct copy chain**: positive, collapse to source local
- **transitive chain**: positive, because `LocalGraph` can follow influences transitively
- **simple computed shared source**: positive, collapse to one fresh temp
- **DAG fanout**: positive, because the source story can fan out but still stay unique
- **loop-backedge alias**: positive, dedicated official test says it matters
- **multi-set local**: negative, core single-set rule fails
- **control-heavy / effectful source**: negative, simple-value rule fails
- **multi-source influenced uses**: negative, provenance-agreement filter fails
- **local names present**: bailout, whole function skipped
- **unreachable/control weirdness**: conservative boundary, keep validity first

## Bottom line

The most important shape question is never “is there a copy?”

It is:

- “is there one simple set story that `LocalGraph` can still prove across this whole alias group?”

If yes, Binaryen can normalize it.
If no, `merge-locals` is supposed to stay small and conservative.
