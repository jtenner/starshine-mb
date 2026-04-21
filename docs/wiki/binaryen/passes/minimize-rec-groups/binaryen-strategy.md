---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./permutations-brands-and-public-conflicts.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `minimize-rec-groups` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/MinimizeRecGroups.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies visible in the implementation:

- `ModuleUtils::collectHeapTypeInfo(...)`
- `SCCs` / `TypeSCCs`
- `TopologicalOrders`
- `DisjointSets`
- `RecGroupShape` and `ComparableRecGroupShape`
- `BrandTypeIterator`
- `GlobalTypeRewriter::mapTypes(...)`
- `GlobalTypeRewriter::mapTypeNamesAndIndices(...)`

The shipped lit surface is also part of the contract:

- `test/lit/passes/minimize-rec-groups.wast`
- `test/lit/passes/minimize-rec-groups-brands.wast`
- `test/lit/passes/minimize-rec-groups-desc.wast`
- `test/lit/passes/minimize-rec-groups-exact.wast`
- `test/lit/passes/minimize-rec-groups-ignore-exact.wast`

## High-level intent

Binaryen uses `minimize-rec-groups` to emit the smallest private recursion groups that validation actually requires.

That sounds like a plain SCC pass, but the real contract has a second half.

1. First, split private types into minimal SCCs.
2. Then, make sure those new SCC-based rec groups stay **distinct** from one another and from public groups even when two groups have the same shape.
3. Prefer valid permutations of isomorphic groups before adding extra brand types.
4. Only add a brand when permutations are impossible or exhausted.

That is why this is a module pass even though there is no runtime dataflow story here.
The hard part is type identity, not execution behavior.

## Where the pass runs

In `pass.cpp`, Binaryen registers the pass under the CLI name:

- `minimize-rec-groups`

### Open-world no-DWARF path relevant to this repo

For the canonical MoonBit debug-artifact path, `minimize-rec-groups` is **absent**.

The open-world page still ends its GC prepass cluster at:

- `... -> global-refining -> remove-unused-module-elements -> gsi`

So the repo's main no-DWARF orientation page should continue to omit `minimize-rec-groups`.

### Closed-world Binaryen path

The reviewed `version_129` default closed-world GC/type cluster still does **not** auto-insert `minimize-rec-groups`.

That means the important scheduler fact is negative:

- this pass is registered upstream as an explicit CLI pass
- but it is not part of the reviewed default optimize presets

So a future Starshine port should not assume upstream already treats it as a preset slot.

## Phase 0: hard GC gate

`MinimizeRecGroups::run(Module* module)` begins by recording `module->features` and returning immediately when:

- `!features.hasGC()`

This is one of the most important differences from the just-documented closed-world GC/type passes.
The pass is GC-only, but it does **not** require closed world.

## Phase 1: collect heap types and visibility

The pass uses:

- `ModuleUtils::collectHeapTypeInfo(*module, TypeInclusion::AllTypes, VisibilityHandling::FindVisibility)`

That gives the pass a full heap-type inventory plus public/private classification.

### Private types

Private types go into:

- `types`

These are the only types the pass is allowed to rewrite.

### Public groups

Public types are not rewritten.
Instead the pass collects each distinct public rec group and records its shape in `groupShapeIndices` using a sentinel index:

- `PublicGroupIndex`

That one detail explains a lot of later behavior:

- private output groups must stay distinct from public groups too
- public groups are immutable collision targets

## Phase 2: compute SCCs of the private type graph

The pass defines a tiny `TypeSCCs` helper on top of Binaryen's generic SCC utility.

Its rule is:

- inspect each private type's referenced heap types
- only follow an edge when the referenced type is also in the private set

So public edges do not keep private types in the same SCC.
That is why the pass really does minimize **private** recursion groups.

This is the first half of the algorithm and the source-backed reason the pass can split oversized source rec groups.

## Phase 3: repair a valid order inside each SCC

An SCC is not automatically in a valid emitted order.
So for each SCC the pass builds a local dependency graph with:

- edges from supertype -> subtype
- edges from described type -> descriptor

Then it asks `TopologicalOrders` for a valid topological order and uses the first one.

That means the candidate group is valid before Binaryen even starts worrying about shape collisions.

### Why those edges matter

Two beginner-visible rules come directly from `createTypeOrderGraph(...)`:

- supertypes must be emitted before their subtypes
- described types must be emitted before their descriptors

So some groups that are isomorphic in the abstract do **not** have every permutation available.
The ordering constraints are real.

## Phase 4: try to insert the new group shape

Each candidate group becomes a `RecGroupInfo` in `groups`.
Then `updateShape(...)` tries to insert:

- `RecGroupShape(groups[group].group, features)`

into:

- `groupShapeIndices`

If insertion succeeds, the shape is unique and the group is finished.

If insertion fails, there is a collision.
That collision can be with:

- a public group
- a previous permutation of the same class
- a group in a different class
- a group not yet part of any nontrivial class

The pass uses:

- `DisjointSets equivalenceClasses`
- `GroupClassInfo`
- `shapesToUpdate`

for this conflict-resolution loop.

## Phase 5: canonicalize lazily, not eagerly

The long source comment is important here.
Binaryen rejects both simple extremes.

### Bad extreme 1: eagerly canonicalize every group

That would avoid wasted permutation search, but it would also waste work in the common case where no collision ever happens.

### Bad extreme 2: never canonicalize

That would delay work until needed, but highly symmetric groups can have many duplicate-shape permutations, so Binaryen would waste time generating permutations that cannot help.

### Chosen design

Binaryen does a hybrid:

- detect shape conflicts lazily
- but once a nontrivial equivalence class exists, canonicalize that class so future permutations are not wasted

That is the core strategy choice of the whole pass.

## Phase 6: canonicalization with DFS-root shape classes

`getCanonicalPermutation(...)` is the deepest part of the implementation.

The pass:

1. runs a DFS order from each type in the SCC
2. turns each DFS order into a `ComparableRecGroupShape`
3. groups root types whose DFS orders have the same shape into equivalence classes
4. picks the least shape class as the canonical base
5. builds a final canonical order by striping across those root classes

### Why striping matters

The pass comment proves a useful graph fact:

- in a strongly connected recursion group, all cycles in an automorphism have the same size
- therefore a nontrivial automorphism cannot keep one element fixed
- therefore two distinct permutations with the same first element cannot have the same shape

That lets Binaryen use the topological-order generator efficiently:

- keep the first element fixed as long as possible
- that maximizes the number of distinct-shape permutations before duplicate automorphisms appear

## Phase 7: use valid permutations before brands

Each nontrivial equivalence class tracks:

- a canonical type-order graph
- the current optional brand
- a `TopologicalOrders` generator

That generator enumerates only orders that still respect:

- supertype-before-subtype
- described-before-descriptor

Binaryen tries those valid permutations first because they keep output smaller than immediately adding brands.

This is the real reason some same-shape SCC families in the lit tests stay brand-free:

- they still have multiple valid topological orders that produce distinct rec-group shapes

## Phase 8: add a brand when permutations stop helping

When valid permutations are exhausted, or when the constraints admit only one order, the class advances its brand.

`BrandTypeIterator` provides an infinite deterministic sequence of candidate brand types.
Important facts from the helper:

- it prioritizes compact encodings
- it starts with tiny one-element array or struct-style shapes
- it grows only when smaller choices are exhausted
- for singleton groups it explicitly skips any brand whose shape would still match the real singleton type

That explains the brand-heavy lit output:

- Binaryen is deliberately paying the smallest known synthetic-type cost that preserves distinctness

## Phase 9: handle the seven conflict families

The source comment in `updateShape(...)` lists seven concrete conflict families.
The most important way to understand them is by grouping them into four questions.

### 9A. Did we collide with a public group?

If yes, the private group must change.
If the group already belongs to a nontrivial class, Binaryen advances that class.
Otherwise it creates a new class so it has enough machinery to advance.

### 9B. Did we collide with a previous permutation of our own class?

If yes, more permutations with that brand are useless.
Binaryen jumps straight to the next brand.

### 9C. Did we collide with a group from some other class?

If one side is already in a nontrivial class and the other is not, Binaryen brings the unaffiliated group into that class.
If both are already in branded nontrivial classes, the pass treats the collision as a special cross-brand conflict and advances the current group rather than merging the classes.

### 9D. Did two unaffiliated groups collide for the first time?

If yes, Binaryen creates a new nontrivial equivalence class, canonicalizes the shared shape, makes one group the representative, and reinserts both groups through the class machinery.

You do not need to memorize the case numbers, but you do need to understand this principle:

- every collision either teaches Binaryen that two groups are really the same isomorphism class, or teaches it that the current class needs a fresh valid permutation or brand.

## Phase 10: rebuild and rewrite the module

After all groups are finalized, `rewriteTypes(Module& wasm)` takes over.

### Build new rec groups

The pass creates one `TypeBuilder` rec group for each finalized `RecGroupInfo` and copies each type while remapping intra-group references.

### Skip synthetic brands in the old->new map

Brand types do not correspond to original module types, so they are skipped when Binaryen builds `oldToNew`.

### Rewrite module uses and metadata

The pass then calls:

- `GlobalTypeRewriter rewriter(wasm)`
- `rewriter.mapTypes(oldToNew)`
- `rewriter.mapTypeNamesAndIndices(oldToNew)`

So the pass repairs:

- expression types
- globals, tags, and signatures
- type-name metadata
- recorded type indices

That is why this is a real module rewrite, not just a pretty-printer change.

## Feature-sensitive shape comparison

This is one of the easiest details to miss.

`RecGroupShape` ultimately compares types through:

- `type.asWrittenGivenFeatures(features)`

That means the pass compares groups based on what the type section would actually emit under the active features.

The exactness tests prove why that matters:

- with exactness-relevant features on, exact and inexact refs can keep two groups distinct
- with custom descriptors disabled, exactness can disappear from the written shape, making those same groups collide and forcing a brand

So the pass is feature-sensitive by design.

## What the pass does **not** do

Binaryen `minimize-rec-groups` in `version_129` does **not** do any of these:

- it does not run without GC
- it does not require closed world
- it does not run in the default no-DWARF optimize presets
- it does not optimize public groups
- it does not simply remove dead types
- it does not behave like `reorder-types`
- it does not guarantee fewer total types, because brands may be added
- it does not allow arbitrary SCC member reordering that violates subtype or descriptor order

Those boundaries are just as important as the positive rewrites.

## What the pass sounds like versus what it actually is

What it sounds like:

- a simple SCC splitter for type sections

What it actually is in `version_129`:

- a GC-only explicit module pass that performs SCC splitting, valid-order repair, feature-sensitive shape comparison, lazy equivalence-class canonicalization, permutation-based disambiguation, brand-based fallback, and finally whole-module type plus metadata rewriting.

That is the behavior a future Starshine port would need to preserve.

## Bottom line

Binaryen `minimize-rec-groups` is really:

- **minimal-SCC partitioning plus a carefully engineered anti-accidental-merge algorithm**

The public one-line summary in `pass.cpp` hides almost all of that story.

## Sources

- [`../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md`](../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinimizeRecGroups.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/strongly_connected_components.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/topological_sort.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/disjoint_sets.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-shape.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm/wasm-type-shape.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-brands.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-ignore-exact.wast>
