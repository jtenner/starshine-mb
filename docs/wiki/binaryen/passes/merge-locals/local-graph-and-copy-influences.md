---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
---

# `merge-locals`: LocalGraph and copy influences

## Why this page exists

The easiest way to misread `merge-locals` is to choose one wrong extreme:

- too small: “just delete adjacent local copies”
- too large: “do coalesce-locals style slot coloring”
- stale repo overread: “use `EquivalentCopies` plus `LocalStructuralDominance` to collapse wrapper families onto one existing winner”

The reviewed Binaryen implementation is in between.
It uses `LocalGraph` influence facts to prove a one-set local can be merged, but it stays far narrower than general local allocation.

## The central question

Ask:

- “does this local have exactly one simple set, and do all influenced gets still trace to that same set?”

Do **not** ask:

- “are these locals broadly equivalent?”
- “can these locals share storage?”
- “is there an equivalent-copy wrapper family under structural dominance?”

Those are different pass families or stale documentation claims.

## What `LocalGraph` contributes

`MergeLocals.cpp` creates a `LocalGraph` and computes two things:

- ordinary influences
- set influences

### Ordinary influences

Ordinary influences let the pass see which gets and local uses are fed by which sets.
This is why the pass can reason through more than a single adjacent `local.set` / `local.get` pair.

### Set influences

Set influences let the pass ask whether a local's uses all come from one set.
The candidate dies if any influenced get traces to a different set.

That is the real proof surface: a clean one-set influence story.

## Why eager graph construction matters

The reviewed source constructs the graph in non-lazy mode.
The source comment says lazy mode missed opportunities and was slower in Binaryen benchmarking.

For readers, the takeaway is simple:

- Binaryen pays for a fuller graph because this pass is meant to catch non-adjacent copy/influence patterns.

## How this is wider than a peephole

A local copy can be separated from its uses by control structure, ordering, or other simple local traffic.
The official test file includes branch, DAG-like, and loop-shaped families.

So a future Starshine port should not be implemented as only:

```wat
(local.set $x (local.get $y))
(local.get $x)
```

The source-backed pass is graph-guided.

## How this is narrower than `coalesce-locals`

[`../coalesce-locals/index.md`](../coalesce-locals/index.md) is about broader slot sharing under liveness/interference constraints.
`merge-locals` is not.

`merge-locals` does not try to answer:

- can two unrelated locals occupy the same slot?
- can compatible typed locals be recolored?
- can a later declaration order be improved?

It answers only a much smaller question:

- can this local's one simple set be replaced by an existing source local or by one fresh temp for all influenced gets?

## Direct source-local reuse

If the single set's value is a `local.get` from a small enough source-local chain, Binaryen can retarget gets to that source local.

Conceptually:

```wat
(local.set $tmp (local.get $src))
(drop (local.get $tmp))
```

becomes:

```wat
(drop (local.get $src))
```

The graph proof matters because the pass must know the uses of `$tmp` are really fed by that one set.

## Fresh-temp materialization

If the single set's value is simple but not a small reusable local-get chain, Binaryen can materialize the value once in a fresh temp and retarget gets to that temp.

Conceptually:

```wat
(local.set $a (i32.const 10))
(local.set $b (i32.const 10))
(drop (i32.add (local.get $a) (local.get $b)))
```

can become a shape like:

```wat
(local.set $fresh (i32.const 10))
(drop (i32.add (local.get $fresh) (local.get $fresh)))
```

Exact printed output depends on surrounding cleanup passes.

## Why extra sets break the proof

If the candidate local has two sets, or if an influenced get is graph-fed by a different set, the rewrite is no longer safe.
The pass does not try to merge “probably equivalent” locals.

That conservative rule protects cases where control flow or ordering can change which value a get observes.

## Why complex values stay put

Even a clean one-set influence story is not enough if the set value is not simple.
Calls, large expressions, and trap/effect-sensitive operations cannot be moved or shared by this pass without changing behavior.

## What to remember

`merge-locals` is a **one-set local influence rewrite**:

- `LocalGraph` proves the candidate's uses are all fed by one set
- the set's value must be simple
- Binaryen either reuses a small source-local chain or creates a fresh temp
- broader slot sharing belongs to `coalesce-locals`
- `LocalStructuralDominance` and `EquivalentCopies` are not part of the reviewed `merge-locals` implementation
