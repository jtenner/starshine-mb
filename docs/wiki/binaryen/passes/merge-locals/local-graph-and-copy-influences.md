---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
  - ../../../raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
---

# `merge-locals`: LocalGraph, copy influences, and structural dominance

## Why this page exists

The easiest way to misunderstand `merge-locals` is to imagine one of two wrong extremes:

- a tiny peephole that only deletes adjacent `local.set` / `local.get` pairs
- a broad allocator-style pass like `coalesce-locals`

The reviewed Binaryen pass is in between.
This page focuses on the part that makes that possible:

- `LocalGraph`
- ordinary influences versus set influences
- `EquivalentCopies`
- `LocalStructuralDominance`

## The central question

Ask this question, not the pass name:

- “which locals are only structurally equivalent copy wrappers around one simple root set?”

If the answer is yes, Binaryen can collapse them.
If the answer is no, Binaryen bails out.

That is the real personality of the pass.

## What `LocalGraph` contributes

The pass source depends on a `LocalGraph` and calls both:

- `computeInfluences()`
- `computeSetInfluences()`

Those are different kinds of facts.

### Ordinary influences

These explain which gets and local uses are fed by earlier sets.
They let the pass see more than one adjacent copy.

### Set influences

These let the pass iterate from actual root sets rather than treating every local as an equally interesting candidate.
That is one of the main corrections from the older dossier.

A better summary is:

- Binaryen starts from simple root sets and reasons outward

not:

- Binaryen scans every local for an exact-one-set property and then normalizes that local directly.

## Why this is wider than a peephole

Because the graph tracks influence relationships, Binaryen can reason about shapes like:

```wat
(local.set $a (i32.const 1))
(local.set $b (local.get $a))
(local.set $c (local.get $b))
(drop (local.get $c))
```

as one connected value story instead of three unrelated locals.

That is why the official tests include transitive and ordering-sensitive families.

## Why this is narrower than `coalesce-locals`

`coalesce-locals` asks something like:

- “can these locals share storage without liveness or interference trouble?”

`merge-locals` asks something sharper:

- “are these locals only equivalent copy wrappers around one simple root set?”

So `merge-locals` is **not** doing:

- liveness coloring
- interference analysis
- exact-type compatibility search across arbitrary locals
- global best-fit slot sharing

It is doing source-story collapse.

## `EquivalentCopies` is the key missing concept from the older dossier

The reviewed source uses an `EquivalentCopies` notion to compare wrapper copy sets.
That is what keeps the pass from being either:

- too small to handle transitive alias families, or
- too large to rewrite arbitrary local groups

Good beginner wording:

- Binaryen looks for locals whose copy wrappers are the same kind of wrapper around the same root story

That is stronger than “they both copy something once” and narrower than “they look similar.”

## `LocalStructuralDominance` explains why the rewritten gets stay safe

Even if two locals are equivalent copy wrappers, Binaryen still needs proof that the gets it rewrites are in the right structural region.
That is where `LocalStructuralDominance` comes in.

The durable mental model is:

- `LocalGraph` tells Binaryen which values and copy wrappers are connected
- `LocalStructuralDominance` tells Binaryen whether the rewrite stays valid at the actual use sites

That is why the pass is not just a graph rewrite and not just a dominance rewrite.
It needs both.

## Conceptual example: positive equivalent copy family

Before:

```wat
(local.set $root (i32.const 10))
(local.set $b (local.get $root))
(local.set $c (local.get $root))
(drop (local.get $b))
(drop (local.get $c))
```

After, conceptually:

```wat
(local.set $root (i32.const 10))
(drop (local.get $root))
(drop (local.get $root))
```

Why it rewrites:

- the root set is simple
- `$b` and `$c` are just equivalent copy wrappers around that root
- the rewritten gets stay structurally dominated by the relevant value story

## Conceptual example: transitive copy family

Before:

```wat
(local.set $root (i32.const 10))
(local.set $b (local.get $root))
(local.set $c (local.get $b))
(drop (local.get $c))
```

After, conceptually:

```wat
(local.set $root (i32.const 10))
(drop (local.get $root))
```

Why it rewrites:

- `LocalGraph` can still see the connected influence story
- the wrapper copies remain structurally equivalent enough to collapse

## Important correction: no fresh-temp canonicalization story

The older dossier taught a direct-reuse versus fresh-temp split.
The reviewed `version_129` pass source does **not** support that explanation.

A better summary is:

- Binaryen chooses one existing target local among the equivalent family
- then collapses the other equivalent wrappers into it

That is why the current page talks about a **winner local**, not a synthetic temp local.

## Why extra sets break the proof

If a local stops being a pure equivalent-copy wrapper because another set interferes, the equivalence story breaks.
That is a core negative case.

So the pass is not trying to answer:

- “can these two locals probably mean the same thing?”

It is trying to answer:

- “can I still prove one structurally equivalent copy-wrapper story here?”

If not, it bails out.

## Why non-simple roots break the proof

Even a perfectly connected copy family is not enough if the root set value is not simple under `FunctionUtils::isSimple(...)`.
That keeps the pass from floating into effectful or control-heavy rewrite territory.

So two things must be true together:

- the copy-wrapper family is equivalent
- the root producer is simple enough

## The easiest wrong summary

The easiest wrong summary is:

- “merge-locals removes redundant local copies”

That is too shallow.
A better summary is:

- `merge-locals` uses `LocalGraph` plus `LocalStructuralDominance` to prove that some locals are only equivalent copy wrappers around one simple root set, then rewrites that family onto one existing local.

## Bottom line

If you remember one thing from this page, remember this:

- `merge-locals` is a **rooted equivalent-copy proof**, not just a copy peephole and not a general local-slot merger.
