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
  - ./local-graph-and-copy-influences.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
---

# `merge-locals` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `merge-locals` pass.

## Read this page with one mental model

Binaryen is not asking:

- “does this local have exactly one set?”
- “should I invent one fresh canonical temp?”

The reviewed source points to a different mental model:

- “is there one simple root set, and are these other locals only equivalent copy wrappers around it?”

That means four questions matter most:

1. is the root `local.set` value simple enough?
2. do the other locals form equivalent copy wrappers around that root story?
3. are the relevant gets structurally dominated so the retargeting stays valid?
4. which existing local is the best winner for the merged family?

## Important note about the examples

The `after` snippets below are often **conceptual**.
In real Binaryen output:

- the chosen winner local can differ
- some declarations may remain until later cleanup passes run
- exact printed structure depends on neighboring passes

So read the shapes as “what family rewrites or stays put,” not “the exact final pretty-printed text in every case.”

## Quick glossary

- **root set**: the simple value-producing `local.set` Binaryen treats as the source story
- **equivalent copy wrapper**: a local whose copy set is structurally equivalent to a wrapper around the root story
- **winner local**: the existing local Binaryen chooses as the final target for the family
- **dominated get**: a use site that can safely retarget to the winner under the structural-dominance proof

## Shape 1: one root plus direct equivalent copy wrappers collapse to one existing local

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
- `$b` and `$c` are only equivalent copy wrappers
- the rewritten gets remain valid under the structural proof

## Shape 2: transitive copy chains can still collapse

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

- `LocalGraph` can still recover the connected value story
- the wrapper copies still behave like the same root-based alias family

This is why the official tests include transitive and ordering-sensitive cases.

## Shape 3: loops do not automatically disqualify the pass

Before, conceptually:

```wat
(loop $L
  (local.set $tmp (local.get $root))
  (drop (local.get $tmp))
  (br $L)
)
```

After, conceptually:

```wat
(loop $L
  (drop (local.get $root))
  (br $L)
)
```

Why it can still rewrite:

- the relevant family can remain structurally dominated even across loop structure
- the pass is broader than a straight-line peephole

## Shape 4: a non-simple root producer stays put

Before and after stay the same in the important part:

```wat
(local.set $x
  (call $impure))
(local.set $y (local.get $x))
(drop (local.get $y))
```

Why Binaryen keeps it:

- the root set value is not simple enough under `FunctionUtils::isSimple(...)`
- the pass is intentionally conservative about effectful or otherwise non-simple producers

## Shape 5: one extra competing set breaks the equivalent-wrapper proof

Before and after stay the same in the important part:

```wat
(local.set $x (i32.const 1))
(if (local.get $cond)
  (then (local.set $x (i32.const 2))))
(local.set $y (local.get $x))
(drop (local.get $y))
```

Why Binaryen keeps it:

- the local family no longer has one clean root-plus-equivalent-wrapper story
- the extra set breaks the proof surface the pass relies on

## Shape 6: structurally different wrappers do not count as equivalent copies

Before and after stay the same in the important part, conceptually:

```wat
(local.set $root (i32.const 1))
(local.set $a (local.get $root))
(local.set $b (select (local.get $root) (local.get $root) (local.get $cond)))
(drop (local.get $a))
(drop (local.get $b))
```

Why Binaryen keeps the nontrivial side:

- `$a` is a plain copy wrapper
- `$b` is not the same kind of wrapper story
- the pass wants equivalent wrappers, not just vaguely related locals

## Shape 7: this is not a fresh-temp canonicalization pass

A useful negative shape is conceptual rather than syntactic.
The older dossier taught a family like:

```wat
(local.set $a
  (i32.add (local.get $x) (i32.const 1)))
(local.set $b (local.get $a))
(drop (local.get $b))
```

as if Binaryen would typically rewrite to one new canonical temp.
The reviewed `version_129` source does **not** justify that teaching surface.

The better expectation is:

- choose one existing winner local if the equivalent-wrapper proof succeeds
- otherwise bail out

So future read-alongs should not teach `merge-locals` as a new-temp creator.

## Shape 8: this is not `coalesce-locals`

Before and after stay the same in the important part, conceptually:

```wat
(local.set $a (i32.const 1))
... many unrelated live-range uses ...
(local.set $b (i32.const 2))
```

Why this example matters:

- even if a later slot-sharing pass might recycle storage here,
- `merge-locals` is not trying to solve that problem

The pass only cares about root-plus-equivalent-copy families.

## Important interaction families

### Interaction 1: `heap2local` creates more local alias traffic

Why scheduler placement matters:

- `heap2local` can turn heap traffic into local traffic
- stronger optimize/shrink modes then run `merge-locals`
- so the pass gets richer alias-local families to clean up

### Interaction 2: `optimize-casts` and `local-subtyping` see the cleaned local surface

Why placement matters:

- under stronger settings, `merge-locals` runs immediately before those passes
- they therefore reason about a less copy-wrapper-heavy local surface

### Interaction 3: `coalesce-locals` is a different later cleanup layer

Why the distinction matters:

- `merge-locals` handles rooted equivalent-copy families first
- `coalesce-locals` later handles broader slot-sharing logic

So if you see both passes in the same neighborhood, do not collapse them into one concept.

## One-sentence summary for each family

- **direct equivalent copy wrappers**: positive, collapse onto one existing winner local
- **transitive copy chain**: positive, if the root story and wrapper equivalence stay provable
- **loop case**: still positive when structural dominance is preserved
- **non-simple root**: negative, simple-value gate fails
- **extra set**: negative, root-plus-wrapper proof breaks
- **structurally different wrapper**: negative, equivalence fails
- **fresh-temp expectation**: stale teaching pattern, not the reviewed `version_129` contract
- **slot-sharing / coloring story**: belongs to `coalesce-locals`, not here

## Bottom line

The most important shape question is not “is there a copy?” or “does this local have one set?”
It is:

- “is there one simple root set with structurally equivalent copy wrappers that Binaryen can safely collapse onto one existing local?”

If yes, `merge-locals` can rewrite it.
If no, the pass is supposed to stay small and conservative.
