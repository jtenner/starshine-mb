---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md
  - ../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/dfa_minimization.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-merging.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `type-merging`: DFA partitions, cast barriers, and refinalization

This is the hardest part of `type-merging` to teach clearly.
The 2026-04-24 primary-source manifest in [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md) is the current immutable source anchor for the Binaryen algorithm described here.

If you remember only one thing, remember this:

- Binaryen is **not** just comparing two type declarations and deleting one.
- It is solving a **graph equivalence** problem under **observability constraints**.

## Why a DFA shows up at all

Suppose two parent types differ only in which child heap type they mention:

- parent A points at child X
- parent B points at child Y

A shallow structural comparison says:

- A and B differ, so stop

But Binaryen wants the smarter answer:

- if X and Y also turn out to be equivalent and mergeable,
- then A and B may also become equivalent

That is why the pass models heap types as DFA states with transitions to child heap types.
Partition refinement can then discover equivalence classes in the whole graph, not just one declaration at a time.

## What goes into a state

A state represents one base heap type.
Its successors are the non-basic heap-type children that appear inside its shape.

Important detail:

- descriptor chains are treated as one logical unit
- public child types still appear as terminal distinguishing states
- private child types can recursively participate in more refinement

So the algorithm captures:

- parent structure
- child references
- descriptor-chain position
- public-vs-private visibility

all together.

## Why initial partitions are only "maybe" equivalence

The pass does not start by saying “all same-looking types are equal.”
It starts by saying:

- these types are similar enough that refinement should look deeper

Then partition refinement splits those groups when their successor structure proves they are actually different.

This matters because some differences are:

- immediately visible at the top level
- while others are visible only through child types or cast sites

## Why casts are such a big deal

A private subtype can still matter if the module tests for it.

That is the point of `castTypes` and `exactCastTypes`.
They encode the rule:

- if code can still distinguish this type at runtime, do not merge it away

The reviewed Binaryen implementation treats these surfaces as type-distinguishing:

- `ref.cast`
- exact `ref.cast`
- `ref.test`
- `br_on_cast`
- `call_indirect`

with one important nuance:

- in traps-never-happen mode, `ref.cast` and `call_indirect` stop distinguishing types because they are assumed to succeed
- `ref.test` still distinguishes because it observes identity without trapping

## Why exact casts are stricter than ordinary casts

An ordinary cast says something like:

- this value must be at least compatible with target type T

An exact cast says something stronger:

- this value must match exactly enough that keeping subtypes distinct still matters

That is why the implementation has a separate `exactCastTypes` set and why a supertype edge can be blocked even when ordinary shape equality looks fine.

## Why the pass has separate supertype and sibling phases

This is a real correctness rule.

If Binaryen merged supertypes and siblings in one big step, it could choose a target that is only *shape-equal* but not actually a legal ancestor in the current graph.
That can break subtype structure.

So the algorithm is deliberately staged:

1. merge into structurally identical supertypes
2. only after that, merge structurally identical siblings
3. repeat sibling merging as new opportunities appear

The official lit regressions include a case that used to fail when those phases were not separated cleanly enough.

## Why Binaryen manually splits refined partitions afterwards

Even after DFA refinement, a partition can still contain multiple disconnected roots in the supertype-only phase.
That is too broad for “merge only into supertypes.”

So Binaryen post-processes refined partitions with `splitSupertypePartition(...)`.

That step says, in effect:

- refinement told us these states are equivalent enough to share a partition
- but supertype-only legality still requires each final merge cluster to be connected through ancestor links

This is an easy rule to miss if you only read the file top comment.

## Why refinalization is part of semantics, not cleanup

Merging types can sharpen exactness and LUB results.
A famous example from the source comment is a `select` that used to have to return a common supertype because its arms had two different subtypes.
After both subtypes merge into one target, the result can become exact.

That change is semantically relevant to Binaryen's typed IR.
So after certain merges the pass must refinalize.

A good beginner summary is:

- the pass changes the type graph
- changing the type graph changes the right answer for some expression result types
- `ReFinalize` repairs those answers

## Common wrong mental models

### Wrong model: "If two types print the same, just merge them"

Not safe.
You must also respect:

- visibility
- casts
- exactness
- child-type graph structure
- target direction
- descriptor chains

### Wrong model: "Refinalization is just for pretty printing"

Not safe.
Without it, expression result types can be stale or invalid after merges.

### Wrong model: "Public types are irrelevant because we never merge them"

Also wrong.
Public types still matter as **distinguishing terminals** in the DFA.

## Porting rule of thumb

If a future Starshine pass cannot yet model:

- graph-based child equivalence
- cast observability
- descriptor-chain coupling
- refinalization after graph rewrites

then it does not yet implement Binaryen `type-merging` honestly.

## Sources

- [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md)
- [`../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md`](../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md`](../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/dfa_minimization.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-merging.wast>
