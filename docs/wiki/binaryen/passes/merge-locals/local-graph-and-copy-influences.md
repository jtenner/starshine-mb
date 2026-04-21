---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0128-2026-04-20-merge-locals-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../coalesce-locals/index.md
---

# `merge-locals`: LocalGraph and copy influences

## Why this page exists

The easiest way to misunderstand `merge-locals` is to imagine one of two wrong extremes:

- a tiny peephole that only spots adjacent `local.set` / `local.get` pairs
- a broad allocator-style pass like `coalesce-locals`

The real Binaryen pass is in between.

This page focuses on the part that makes that possible:

- `LocalGraph`
- set influences
- the single-set provenance rule
- the direct-reuse vs fresh-temp split

## The central question

Ask this question, not the pass name:

- “do these locals all come from one sufficiently simple set story?”

If the answer is yes, Binaryen can normalize them.
If the answer is no, Binaryen bails out.

That is the whole personality of the pass.

## What `LocalGraph` contributes

`src/ir/local-graph.h` defines the helper surface the pass depends on.
The most important APIs are:

- `getSetses(index)`
- `getGetses(index)`
- `computeSetInfluences()`
- `getInfluences(set)`
- `postWalkFunction(...)`

The key comment in `local-graph.h` says `computeSetInfluences()` works when:

- a local has only one setting location
- that set influences all gets of the local
- and the relation can be computed transitively through local-to-local setting chains

That single comment explains most of the test suite.

## Why this is wider than a peephole

Because the influence relation can be transitive, Binaryen can see shapes like:

```wat
(local.set $a (i32.const 1))
(local.set $b (local.get $a))
(local.set $c (local.get $b))
(drop (local.get $c))
```

as one source story instead of three unrelated locals.

A pure adjacency peephole would have to rediscover that locally over and over.
The graph helper lets Binaryen reason about the whole alias family.

That is why the official test families include:

- `transitive1`
- `transitive2`
- `update working get with influences`
- `merge in a DAG`

## Why this is narrower than `coalesce-locals`

`coalesce-locals` asks something like:

- “can two locals share a storage slot without live-range/value conflict?”

`merge-locals` asks something simpler and stricter:

- “is this entire local group really just one simple source set seen through aliases?”

So `merge-locals` is **not** doing:

- liveness coloring
- interference analysis
- exact-type compatibility search
- global best-fit slot sharing

It is doing provenance normalization.

## The single-set rule is the pass’s biggest limiter

The pass rejects a candidate unless:

- `graph.getSetses(i).size() == 1`

That is the biggest thing to remember.

It means Binaryen does **not** attempt this optimization on locals with:

- one set in each branch of an `if`
- a loop-carried value written in several different places
- multiple stores that later happen to look equal
- any other “I think these probably mean the same thing” story

If the graph does not say “one set,” Binaryen stops.

## Influences are filtered again on purpose

Even after `getInfluences(set)` returns a get set, Binaryen still deletes any get whose recorded influencing set is not the exact candidate set.

Why that extra filter exists:

- a local might still have a confusing wider graph neighborhood
- some gets might not really belong to the one-set story we want
- the pass wants one trustworthy provenance story before it rewrites by local index

So the real rule is not just:

- one set exists

It is:

- one set exists **and the actual uses we want to rewrite still agree about that set**

## `FunctionUtils::isSimple(...)` is the other half of safety

A one-set local is still not enough.
The set’s value must pass `FunctionUtils::isSimple(...)`.

`pass-utils.h` shows that helper is effect-aware.
The source value must be reorderable and must not have unremovable side effects.

That is why the pass is willing to normalize groups built from:

- pure constants
- pure local-fed expressions
- direct copy chains

but not from clearly more structured or effect-heavy producers.

The `keepSimple1` and `keepSimple2` tests exist to lock in that boundary.

## Two canonical-slot strategies

Once Binaryen trusts the source story, it must decide **where** that story should live.
There are two strategies.

## Strategy A: reuse an existing source local

When the candidate set is literally:

```wat
(local.set $b
  (local.get $a))
```

and the source local `$a` itself has a tiny clean graph surface, Binaryen can just say:

- use `$a` as the canonical slot
- make the alias group read `$a`
- remove the redundant copy traffic

This is the “copy chain collapse” case.

Good beginner wording:

- do not invent a new temp when an existing tiny source local is already the right answer

## Strategy B: create one fresh canonical temp

When the candidate source is simple but not that trivial direct-copy case, Binaryen allocates one new temp local.

This is the “shared simple source” case.

Good beginner wording:

- there is one good source story here,
- but it is not just “use that old local directly,”
- so create one canonical temp and redirect the alias group to it

That is an important correction to a common misconception:

- `merge-locals` can create a new local as part of simplifying the group

## Conceptual example: direct reuse

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

Why:

- `$b` has one set
- the set is a direct `local.get $a`
- the uses of `$b` all belong to that one source story
- Binaryen can reuse `$a` directly

## Conceptual example: fresh temp

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

Why:

- the source value is still simple enough
- but it is not the trivial “just reuse one tiny source local” case
- one fresh canonical temp is the clean shared slot

## Why order-sensitive tests exist

The test names:

- `order gets it right`
- `reorder it right`
- `transitive1`
- `transitive2`

show that the pass is not merely checking one local in isolation.

A local that looks optimizable may depend on another local also being recognized as part of the same source story.
`LocalGraph` influences give Binaryen that larger view.

So if a future port only scans one local at a time without preserving that influence model, it will likely:

- miss valid transitive opportunities, or
- get the rewrite order wrong and strand a half-collapsed alias chain

## Why the DAG test matters

The `merge in a DAG` family is a strong clue that Binaryen is willing to normalize one source story even when it fans out through several locals instead of one simple line.

That is another reason to avoid describing the pass as “just adjacent copy removal.”

## Why the loop-backedge test matters

The `loop-backedge` family shows the source story can survive across loop structure when the graph still proves a single simple provenance.

Again, this is broader than a straight-line peephole, but still narrower than a general loop dataflow optimizer.

## Why the unreachable test matters

The `between-unreachable` case teaches a different lesson:

- even when the surrounding control surface is awkward,
- the pass must stay conservative and valid,
- not over-merge because a local story looks simple in one region only

That makes it a good regression family for any future Starshine port.

## The local-name bailout changes the meaning of “eligible”

Most optimizer descriptions talk only about IR shape.
This pass also has a metadata-level eligibility rule:

- if local names exist, skip the function

That means two otherwise identical functions can differ in pass eligibility depending on whether local-name metadata is present.

A future port has to make an explicit choice there too:

- either keep the same bailout
- or replace it with a consciously designed metadata-preservation policy

## The easiest wrong summary

The easiest wrong summary is:

- “merge-locals removes redundant local copies”

That is too shallow.

A better summary is:

- `merge-locals` uses `LocalGraph` influence facts to prove that a group of locals really comes from one simple single-set source story, then rewrites the whole group to one canonical slot while staying conservative about complexity, multi-source provenance, unreachable/control weirdness, and local-name metadata.

## Bottom line

If you remember one thing from this page, remember this:

- `merge-locals` is a **provenance pass**

It is not just about “copies exist,” and it is not about “locals interfere.”
It is about whether `LocalGraph` can prove one simple set story across a whole alias group.
