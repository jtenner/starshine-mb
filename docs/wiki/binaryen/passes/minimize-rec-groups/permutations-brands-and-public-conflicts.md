---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md
  - ../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `minimize-rec-groups`: permutations, brands, and public conflicts

This page is the focused guide to the hardest half of `minimize-rec-groups`.
It should be read with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md`](../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md) and the Starshine status map in [`./starshine-strategy.md`](./starshine-strategy.md).

If you only remember one thing from this dossier, remember this:

- **splitting rec groups by SCC is not enough**

The pass must also make sure distinct old types remain distinguishable after the split.
That is where permutations, brands, and public-group conflicts come in.

## Why SCC splitting alone is wrong

Suppose two private types live in different SCCs after minimization, but the two emitted SCC-based groups have the same shape.

Under Binaryen's isorecursive type model, that would make them effectively the same type shape.
Then operations like casts could stop distinguishing between values that used to have different type identities.

So the pass has a second correctness goal:

- every new private output group must have a shape distinct from every other private output group and every public output group

That is the real reason the pass is more than Tarjan's algorithm.

## Public groups are immutable collisions

Public groups are never rewritten.
But the pass still records their shapes before it rewrites any private types.

That means a later private group can collide with:

- a previous private group
- or a public group

If the collision is with a public group, the pass has only one option:

- change the private group instead

This is why public visibility matters here even though public types are not optimized.

## The conflict-resolution mindset

The source comment in `updateShape(...)` lists seven explicit conflict cases.
You do not need to memorize the case labels, but you do need to understand the four recurring questions.

### Question 1: is this the first time we've seen this isomorphic class?

If two unaffiliated groups collide for the first time, Binaryen forms a new nontrivial equivalence class and canonicalizes that class.

### Question 2: does this group already belong to a class?

If yes, the class already knows:

- the canonical order
- the valid topological-order generator
- the current brand, if any

So Binaryen can just advance the class to the next usable shape.

### Question 3: did we collide with a previous shape from the same class?

If yes, more permutations under the same brand will not help.
The pass jumps straight to a new brand.

### Question 4: did we collide with a public group?

If yes, the public group stays fixed and the private group must advance.

These are the core mental checkpoints behind the seven concrete source cases.

## Lazy equivalence classes

Binaryen deliberately avoids eager canonicalization.

### Why not canonicalize everything up front?

Because in the common case there may be no shape conflicts at all.
Eager canonicalization would waste work.

### Why not just keep trying new permutations forever?

Because highly symmetric SCCs can have many permutations with the same shape.
Without canonicalization, Binaryen would waste time exploring duplicates.

### Chosen design

Binaryen therefore uses a hybrid:

- do nothing extra until a real collision happens
- once a collision proves a nontrivial isomorphism class exists, canonicalize that class so future permutation search is efficient

That is the core algorithmic tradeoff of the pass.

## Canonicalization: what `getCanonicalPermutation(...)` is really doing

This helper is the densest part of the source.
A beginner-friendly reading is:

1. pretend each type in the SCC could be the “first” type
2. run a deterministic DFS order from each possible first type
3. compare the resulting whole-group shapes
4. group roots whose DFS-based orders produce the same shape
5. pick the least such class as the canonical base
6. interleave those root classes so the eventual permutation generator gets as many distinct first elements as possible before duplicate-shape automorphisms show up

## The automorphism theorem matters

The long theorem comment is not fluff.
It proves a very practical fact.

### The source-backed conclusion

For a strongly connected recursion group:

- a nontrivial automorphism cannot keep one vertex fixed

Binaryen uses that to conclude:

- two distinct permutations with the same first element cannot have the same shape

### Why that helps

`TopologicalOrders` keeps the first element fixed as long as possible before moving it.
So Binaryen can get many distinct shapes cheaply by choosing a canonical order that spreads equivalent roots early.

That is why the canonical order is striped across root equivalence classes instead of taking one whole class and then the next.

## Valid permutations are not arbitrary permutations

This is another easy misunderstanding.

Binaryen does **not** say:

- “any permutation of the SCC is fair game”

It only allows permutations that remain valid according to:

- supertype-before-subtype order
- described-before-descriptor order

That is why `GroupClassInfo` stores a type-order graph and uses `TopologicalOrders` over that graph instead of over a free permutation space.

### Practical consequence

Some groups have many distinct valid permutations.
Others have only one.
That is why some same-shape SCCs can avoid brands while other very similar ones cannot.

## When permutations are enough

Permutations are enough when both of these are true:

1. there is more than one valid topological order
2. at least one of those other orders has a distinct rec-group shape

The main lit file's “now we can disambiguate by permuting without a brand” family exists to prove exactly that.

## When brands become necessary

Binaryen falls back to a brand in four common situations.

### 1. Singleton or near-singleton shape conflicts

If a group has no meaningful alternative order, there is nothing to permute.
A brand is the only option.

### 2. Automorphism-heavy SCCs

Some SCCs look like they have multiple orders, but those orders are shape-equivalent because of graph automorphisms.
Again, a brand is needed.

### 3. Subtyping or descriptor ordering leaves only one valid order

A group may have multiple members, yet only one order is legal.
Then permutations cannot help and a brand is needed.

### 4. The class has exhausted its distinct-shape permutations

Even when the first few groups in a class can be distinguished by permutation, later groups may run out of fresh distinct shapes and need a brand anyway.

## The brand iterator is a real size tradeoff

`BrandTypeIterator` is worth reading because it explains the odd-looking test output.

Important facts:

- it is an infinite deterministic generator
- it prioritizes the most compact encodings first
- it starts with tiny array and one-field struct-like shapes
- it only grows to more fields after exhausting smaller options
- when the equivalence class contains a singleton real type, it skips any brand whose shape would still match that singleton

So a brand is not just “some random extra type.”
It is Binaryen's cheapest available proof that two groups are different.

## Public conflicts versus private conflicts

### Private/private conflict

Binaryen may:

- create a new class
- merge an unaffiliated group into an existing class
- advance the current class to a new permutation
- jump straight to the next brand

### Private/public conflict

Binaryen may only:

- advance the private side

The public side is frozen.

That is why the public-conflict tests are important even though public groups never get rewritten.

## A rare but real class-vs-class corner case

The source has a special case where two already-nontrivial branded classes collide.

The comment explains the reason:

- this can happen when the chosen brand in one class matches the unbranded base shape of another class, and vice versa

In that situation Binaryen does **not** merge the classes.
It simply advances the current class again.

This is a good example of the pass doing just enough work to restore distinctness without overreacting.

## Exactness is feature-sensitive, not absolute

The exactness tests make sense only when paired with `wasm-type-shape.cpp`.
That helper compares:

- `type.asWrittenGivenFeatures(features)`

So exactness matters only when the active features would still write it into the type section.

### Practical outcome

- with custom descriptors enabled, exact and inexact groups can stay distinct
- with custom descriptors disabled, exactness may vanish from the written shape and the same groups can now collide

That is why `minimize-rec-groups-ignore-exact.wast` exists.
It proves the collision logic is based on emitted shape, not raw IR decoration.

## Descriptor ordering is both a grouping and a permutation constraint

The descriptor lit file teaches two separate rules.

### Rule 1: described and descriptor types stay together

They belong to the same SCC / emitted rec group.

### Rule 2: their order is constrained

The described type must come before the descriptor.

Together, those two rules mean descriptor-bearing groups often have fewer legal permutations than plain structural SCCs.
That is why some descriptor families need brands earlier than a plain-struct reader might expect.

## Reading rule of thumb

When you see a surprising `minimize-rec-groups` output, ask these five questions in order:

1. What is the minimal private SCC boundary here?
2. Is the current candidate group colliding with another private group or a public group?
3. Are there multiple **valid** orders once subtype and descriptor constraints are enforced?
4. Are those valid orders actually shape-distinct under the active feature set?
5. If not, which compact brand does Binaryen pick next?

Those five questions explain most of the visible output.

## Bottom line

The real hard part of `minimize-rec-groups` is not finding SCCs.
It is:

- **keeping split groups distinct with the cheapest correct combination of canonicalization, valid permutations, and brand insertion while never colliding with public output shapes**.

## Sources

- [`../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md`](../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md)
- [`../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md`](../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md`](../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinimizeRecGroups.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/topological_sort.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/disjoint_sets.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-shape.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm/wasm-type-shape.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-brands.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-ignore-exact.wast>
