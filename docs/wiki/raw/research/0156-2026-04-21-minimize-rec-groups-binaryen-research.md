# 0156 - Binaryen `minimize-rec-groups` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `abstract-type-refining` upstream-only registry dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is fully dossier-covered and the prompt excludes the already-deepened parity passes plus the newer closed-world GC/type dossiers, expand into another nearby upstream-only Binaryen pass that still has no dedicated living dossier.
- Create a new beginner-friendly but source-backed dossier for `minimize-rec-groups`.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/minimize-rec-groups/`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. re-checked `agent-todo.md`

At that point:

- the main no-DWARF / saved-`-O4z` queue still had no pass with wiki status `none`
- the implemented-landing queue was already closed
- the prompt still excluded the refreshed parity dossiers plus the newer upstream-only dossiers for `remove-unused-types`, `type-refining`, `signature-pruning`, `signature-refining`, `global-type-optimization`, `abstract-type-refining`, and `unsubtyping`
- the tracker's clearest still-`none` upstream-only candidates were `minimize-rec-groups` and `reorder-types`
- `agent-todo.md` still had **no dedicated `minimize-rec-groups` slice**, so there was no local backlog page already teaching the Binaryen contract

So this run needed another explicit queue-expansion pick from the tracker's upstream-only registry table.

I picked `minimize-rec-groups` for seven source-backed reasons:

- It was still listed as `none` in the tracker's additional upstream-only registry table.
- It is already tracked in the local boundary-only registry in `src/passes/optimize.mbt`, so this is a real Starshine-facing pass name and not just an upstream tangent.
- Unlike the just-completed closed-world GC/type-cluster dossiers, this pass is a different kind of type rewrite: it is **not** about tightening field or signature types, but about rewriting recursion-group boundaries while preserving nominal distinctness under Binaryen's isorecursive type model.
- It had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- The official implementation is subtle enough to deserve a real dossier: the pass is not merely “split SCCs,” because SCC splitting alone would accidentally merge distinct private types whenever two emitted rec groups had the same shape.
- The implementation hides several beginner traps worth making explicit:
  - the pass is **GC-gated** but not closed-world-gated
  - it is **not** part of Binaryen's default `-O` / `-Os` optimize schedule in `version_129`
  - it only rewrites **private** types, but it must also avoid colliding with **public** rec-group shapes
  - it uses **feature-sensitive** rec-group comparison, so exactness matters only when the type would still be written with exactness
  - it prefers **permutations** of isomorphic SCCs before falling back to inserting brand types
  - it can **increase** the number of emitted types by adding brands, even though its overall goal is rec-group minimization
  - it must keep supertypes before subtypes and described types before descriptors when reordering inside a rewritten group
- The shipped lit surface is broad and teachable: the main file covers independent types, acyclic chains, true cycles, brand introduction, permutation exhaustion, automorphism limits, subtype-order constraints, and public conflicts; the descriptor file proves descriptor/described ordering and reordering limits; the exactness files prove feature-sensitive shape comparison; and the dedicated brands file stress-tests the compact brand iterator.

So this thread is not reopening an old parity item.
It is the first explicit living dossier for the upstream-only `minimize-rec-groups` pass that the tracker still marked `none`.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinimizeRecGroups.cpp>
- pass registration and scheduler surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- helper surfaces that carry much of the real behavior:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/strongly_connected_components.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/topological_sort.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/disjoint_sets.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-shape.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm/wasm-type-shape.cpp>
- representative official test surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-brands.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-ignore-exact.wast>

Narrow freshness check on current `main`:

- core pass file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MinimizeRecGroups.cpp>
- pass registration:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- dedicated lit files checked on the reviewed surfaces:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-brands.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-ignore-exact.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-`main` check on the most important reviewed surfaces while drafting the living pages.

Durable result:

- the checked `MinimizeRecGroups.cpp` file on `main` is identical to the tagged `version_129` file
- the checked dedicated lit files above were unchanged
- the reviewed `pass.cpp` surfaces did not change the `minimize-rec-groups` registration, and the pass is still only registered as an explicit pass rather than being inserted into the default optimize presets on the reviewed `main` surface

That is intentionally a **narrow** freshness statement, not a whole-repo equivalence proof.
The durable rule for the living wiki should be:

- use `version_129` as the normative algorithm oracle
- record later upstream drift explicitly if it matters
- do not invent a semantic drift story when the checked current surfaces still match the reviewed tag behavior

## Repo-local sources used for context

Starshine-side files that mattered while choosing and framing this dossier:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

Important local context conclusions:

- the current open-world no-DWARF page does **not** run `minimize-rec-groups`
- the local registry tracks the pass only as the full boundary-only name `minimize-rec-groups`
- the current living late-pass docs already record it as an upstream-only pass name visible in public Binaryen release-note surfaces and package-derived terminology checks
- `agent-todo.md` has **no dedicated `minimize-rec-groups` slice today**, so this note must say that explicitly rather than pretending a backlog slice already exists

## High-level conclusion

Binaryen `minimize-rec-groups` is not generic “type cleanup,” and it is not just “split recursion groups by SCC.”

The real `version_129` contract is narrower and more concrete:

1. require GC features, otherwise do nothing
2. collect all heap types and their visibility
3. optimize only **private** types, while recording **public** rec-group shapes as immutable collision sentinels
4. compute the strongly connected components of the private type reference graph, considering only edges to other private types
5. topologically order each SCC so supertypes precede subtypes and described types precede descriptors
6. treat each emitted private SCC as a candidate rec group whose shape must be unique against all prior private groups **and** all public groups
7. when a shape collision appears, lazily organize isomorphic groups into an equivalence class, canonicalize their shape only when needed, and try valid topological permutations first
8. when valid permutations are exhausted or impossible, insert compact **brand types** to keep distinct old types distinct
9. rebuild the private type graph and rewrite all module type uses, names, and indices accordingly

A better short summary is:

- **Binaryen `minimize-rec-groups` is a GC-only explicit module pass that splits private heap types into minimal valid SCC-based recursion groups, then preserves nominal distinctness under isorecursive typing by using feature-sensitive shape comparison, valid permutations, and finally compact brand types when needed.**

The biggest beginner corrections are:

- SCC splitting is only the **first** half of the algorithm
- the pass can **add** brand types, so it does not monotonically reduce type count
- it is **not** a default optimize-pipeline pass in `version_129`
- it is **not** closed-world-only
- the pass compares rec-group shapes as they will be **written given the feature set**, which is why exactness can matter in one run and disappear in another
- the public ABI is kept fixed, but public groups still constrain private-group rewriting because private groups must not collide with their shapes

## Upstream naming and scheduler surface

`pass.cpp` registers the pass with the public CLI name:

- `minimize-rec-groups`

and the summary:

- `Split types into minimal recursion groups`

That summary is directionally right, but too small.
It hides several central details:

- the pass is a **module pass**, not a local peephole
- it only runs when GC features are enabled
- it is **explicit-only** in the reviewed `version_129` scheduler surface
- it rewrites only **private** types but must still avoid matching **public** group shapes
- minimizing SCC size alone is not enough; the pass must also preserve **type identity** under Binaryen's isorecursive type model
- the fallback to **brands** is part of the mainline algorithm, not a weird corner case

### Relation to nearby passes

The most useful distinction is:

- `remove-unused-types` deletes dead private types and whole dead private rec groups
- `reorder-types` sorts types for layout/frequency reasons
- `minimize-rec-groups` changes where rec-group boundaries are drawn, and may also reorder types inside a group or even add brand types to preserve distinctness

So this is not dead-type cleanup and not frequency sorting.
It is **rec-group partitioning plus identity preservation**.

### Scheduler placement

The key scheduler fact is actually an absence.

In the reviewed `version_129` `pass.cpp` surface:

- `minimize-rec-groups` is **registered** as a CLI pass
- but it is **not** inserted into the default no-DWARF `-O` / `-Os` path
- and it is **not** inserted into the reviewed closed-world GC/type cluster either

That teaches three durable things:

- `minimize-rec-groups` is an upstream explicit pass name, not a preset slot the repo must already mirror
- the repo's current no-DWARF parity documents are right to omit it
- a future Starshine port should treat scheduler placement as a policy question instead of assuming upstream `version_129` already runs it by default

## Core algorithm and phases

The key implementation idea is two-stage:

- first, split private types into the **smallest validation-required SCCs**
- then, make sure those new groups still stay **nominally distinct** even when their shapes coincide

That sounds simple until the shape-conflict logic appears.

### Phase 0: hard GC gate

`MinimizeRecGroups::run(Module* module)` begins by reading `module->features` and returning immediately when:

- `!features.hasGC()`

So this is a GC-only pass.
It does **not** require closed world.

### Phase 1: collect private types and public-group sentinels

The pass uses:

- `ModuleUtils::collectHeapTypeInfo(*module, TypeInclusion::AllTypes, VisibilityHandling::FindVisibility)`

That gives two essential facts for every heap type:

- the type exists in the module's type universe
- it is public or private

The pass then does two different things with that information.

#### Private types

Private types go into:

- `types`

These are the only types the pass is allowed to rewrite.

#### Public types

Public groups are **not** rewritten.
Instead the pass inserts each distinct public rec group shape into `groupShapeIndices` with a sentinel value:

- `PublicGroupIndex`

That means public groups act like fixed collision targets.
New private groups must not accidentally end up with the same shape.

This is one of the most important beginner corrections:

- the pass does not optimize public groups, but public groups still actively constrain the rewrite.

### Phase 2: compute SCCs of the private type graph

The pass defines a tiny `TypeSCCs` helper on top of Binaryen's generic Tarjan-based SCC utility.

Its rule is:

- walk each private type's referenced heap types
- follow an edge only if the referenced type is also in the private set

So edges to public types are deliberately ignored for SCC partitioning.
That gives the minimal sets of mutually recursive **private** types that must stay in the same emitted rec group for validation.

This is the first half of the pass name.
It is what really minimizes the rec-group boundary.

### Phase 3: repair order inside each SCC

An SCC is not automatically in a valid emitted order.
So for each SCC, the pass builds a local dependency graph with:

- edges from supertype -> subtype
- edges from described type -> descriptor

Then it asks `TopologicalOrders` for a valid topological order and uses the first one.

That means:

- supertypes are forced before subtypes
- described types are forced before descriptors

So even before shape-dedup logic starts, the pass has already turned “unordered SCC members” into “a valid candidate rec group.”

### Phase 4: enforce rec-group shape uniqueness

Now the pass enters the hard half.

For each candidate group, it computes a `RecGroupShape` and tries to insert it into:

- `groupShapeIndices`

If insertion succeeds, the shape is unique and the pass is done with that group.

If insertion fails, there is a shape conflict.
That conflict could be with:

- a public group
- a previous permutation of the same equivalence class
- a group in another equivalence class
- a group not yet part of any nontrivial equivalence class

The pass handles all of that through:

- `DisjointSets equivalenceClasses`
- `RecGroupInfo`
- `GroupClassInfo`
- an explicit `shapesToUpdate` work stack

That last stack matters because the pass resolves conflicts iteratively rather than recursing deeply through repeated updates.

### Phase 5: lazily canonicalize only after the first real conflict

The pass comments are unusually rich here.
They explain that there are two bad extremes:

- eagerly canonicalize every group, which wastes work in the common no-conflict case
- never canonicalize, which can waste huge amounts of time generating duplicate-shape permutations in highly symmetric groups

Binaryen chooses a hybrid:

- do **not** canonicalize eagerly
- but once a shape conflict proves a nontrivial equivalence class exists, canonicalize that class so future permutation search avoids useless work

That is why `getCanonicalPermutation(...)` is only used when a class becomes nontrivial.

### Phase 6: canonicalization by DFS-root shape classes

`getCanonicalPermutation(...)` is the deepest part of the implementation.

Its core idea is:

1. run a DFS order starting from each type in the SCC
2. treat each resulting order as one way to linearize the same strongly connected graph
3. compare the resulting rec-group shapes with `ComparableRecGroupShape`
4. group roots whose DFS orders have the same shape into equivalence classes
5. choose the lexicographically least shape class as the base
6. build a final canonical order by **striping** across those root equivalence classes so the earliest permutations differ as much as possible in their first element

The pass comment proves why this works with a graph-theory lemma:

- in a strongly connected recursion group, all cycles in an automorphism have the same size
- therefore a nontrivial automorphism cannot keep one element fixed
- therefore two distinct permutations with the same first element cannot have the same shape

That proof is what makes the topological-order generator useful: keeping the first element fixed as long as possible maximizes the number of distinct shapes found before duplicate-shape automorphisms appear.

### Phase 7: use valid permutations before adding brands

Each nontrivial equivalence class tracks:

- the canonical intra-group dependency graph
- the current optional brand
- a `TopologicalOrders` generator over that graph

Binaryen tries to disambiguate isomorphic groups by taking a fresh valid topological order first.

This is important because it keeps output smaller than immediately adding brands.

It also explains why some lit cases with the same underlying SCC size need no brand at all:

- if subtype/descriptor constraints still allow multiple distinct valid orders, those orders are enough to make the shapes different

### Phase 8: add compact brand types when permutations fail or run out

When valid permutations are exhausted, or when the constraints admit only one order, the pass falls back to a brand.

Brand generation is handled by `BrandTypeIterator` from `wasm-type-shape.h`.

Important facts:

- the iterator is infinite
- it is biased toward **compact encodings**
- it starts with tiny one-element array and struct shapes
- it grows to more fields only when smaller shapes are exhausted
- for singleton groups, it explicitly skips any brand whose shape would still match the real singleton type

That is why the official tests show brands such as:

- `(array (mut i8))`
- `(array i8)`
- tiny structs

appearing before bigger brands.

This is another big beginner correction:

- `minimize-rec-groups` can add synthetic types on purpose to keep old types distinct.

### Phase 9: rebuild and rewrite the module

After the groups are finalized, `rewriteTypes(Module& wasm)` does three things.

#### 9A. Build a new type graph

The pass creates a `TypeBuilder`, emits one rec group per finalized output group, and copies each type while remapping intra-group references.

#### 9B. Skip synthetic brands in the old->new map

Brand types do not correspond to original module types, so the pass deliberately skips them when building the `oldToNew` map.

#### 9C. Rewrite all module type uses and metadata

Finally it uses `GlobalTypeRewriter` helper entry points:

- `mapTypes(oldToNew)`
- `mapTypeNamesAndIndices(oldToNew)`

So the rewrite is not just about the type section itself.
It also updates remaining module references, type names, and recorded indices.

## Important helper dependencies

The pass file looks dense because it delegates to helpers.
The most important ones are:

- `ModuleUtils::collectHeapTypeInfo`
  - defines the private/public boundary
- `SCCs` / `TypeSCCs`
  - finds minimal private recursion components
- `TopologicalOrders`
  - enumerates valid type orders that respect subtype and descriptor constraints
- `DisjointSets`
  - tracks equivalence classes of isomorphic groups
- `RecGroupShape` and `ComparableRecGroupShape`
  - define what “same shape” means under the active feature set
- `BrandTypeIterator`
  - supplies compact synthetic types when permutations stop being enough
- `GlobalTypeRewriter::mapTypes` and `mapTypeNamesAndIndices`
  - apply the finished rewrite across the module and repair metadata

## What the pass does **not** do

Binaryen `minimize-rec-groups` in `version_129` does **not** do any of these:

- it does not run without GC
- it does not require closed world
- it does not run automatically in the default no-DWARF `-O` / `-Os` path
- it does not optimize public groups
- it does not merely delete dead types
- it does not sort types by access frequency like `reorder-types`
- it does not guarantee fewer total types after rewriting, because brands may be inserted
- it does not ignore feature lowering; shapes are compared as written under the active features
- it does not allow arbitrary reordering inside an SCC; subtype and descriptor ordering stay mandatory

Those boundaries are just as important as the positive rewrites.

## Important module / WAT shape families

The official tests show seven major shape families.

### 1. Oversized rec groups with independent members

A single `(rec ...)` containing unrelated private types can split into multiple singleton groups.

### 2. Acyclic dependency chains inside one rec group

Even if the source groups several types together, the pass can split them when they only form a chain rather than a cycle.

### 3. True SCCs that must stay grouped

When types are mutually recursive, the pass keeps them together.
The minimization target is the SCC boundary, not “as many singleton groups as possible.”

### 4. Same-shape groups differentiated by permutation

Some isomorphic SCCs can stay brand-free because a different valid order already changes their shape.

### 5. Same-shape groups differentiated by brands

When no valid order is distinct enough, the pass inserts a synthetic brand type.
That happens for singleton conflicts, highly symmetric SCCs, descriptor-locked shapes, and exhausted permutation spaces.

### 6. Descriptor/described families

Described types and descriptors must stay in the same SCC, and their order is constrained.
Sometimes extra reorderable types in the same SCC are enough to avoid a brand; sometimes they are not.

### 7. Feature-sensitive exactness

Shape comparison uses types **as written given the feature set**.
So exactness can distinguish groups when custom descriptors are enabled, but disappear when custom descriptors are disabled.
The dedicated `ignore-exact` test proves that a once-distinct exact/inexact SCC pair can start colliding and require a brand under a different feature set.

## What is easy to misunderstand

### Misunderstanding 1: SCC splitting is the whole pass

Not even close.
SCC splitting finds minimal validation-required groups, but shape collisions would still accidentally merge type identities unless the later permutation/brand logic ran.

### Misunderstanding 2: “minimize” means the type section only gets smaller

No.
The pass minimizes **recursion groups**, not necessarily total type count.
Brand insertion can make the emitted type section larger in exchange for correctness.

### Misunderstanding 3: this is just a variant of `remove-unused-types`

It is not.
`remove-unused-types` removes dead private type material.
`minimize-rec-groups` rewrites the grouping of still-live private types.

### Misunderstanding 4: this is just a variant of `reorder-types`

It is not.
`reorder-types` is about layout or frequency ordering.
`minimize-rec-groups` is about SCC boundaries and isorecursive identity preservation.

### Misunderstanding 5: exactness always matters for shape comparison

Not exactly.
The comparison is based on what the type will actually look like when written under the active features.
So exactness can vanish from the shape when the feature set says it should.

## Future Starshine port invariants

A future Starshine port would need to preserve at least these invariants:

- keep the pass boundary-only / module-wide, not a HOT local peephole
- keep the GC gate
- collect whole-module heap-type visibility so public groups remain fixed collision targets
- compute SCCs over the **private** type-reference graph only
- enforce valid intra-group order for subtype and descriptor dependencies
- compare rec-group shapes in a **feature-sensitive** way based on emitted types
- keep private groups distinct from one another **and** from public groups
- use permutations before brands whenever they are valid and sufficient
- insert brands when permutations are impossible or exhausted
- keep brand selection deterministic and compact-aware
- rewrite all module type uses, names, and indices after rebuilding the private type graph
- treat scheduler placement as an explicit local policy choice, because upstream `version_129` does not schedule this pass by default

If a port only “splits rec groups by SCC” without the identity-preservation machinery, it will not match Binaryen's real behavior.

## Open questions and uncertainty

- `agent-todo.md` has no dedicated `minimize-rec-groups` slice today, so there is no local backlog contract yet beyond this dossier.
- I did **not** exhaustively diff every helper file on current `main`; the freshness note is intentionally limited to the core pass file, `pass.cpp`, and the dedicated lit surfaces above.
- There is one narrow reviewed-source wrinkle worth keeping honest: the comment on `typeIndices` in `MinimizeRecGroups.cpp` says it is a global ordering on all types including public types, but the reviewed `version_129` initialization loop populates it from the private-type scan. The dedicated lit surface did not expose a contradiction here, and the canonicalization examples that matter for this dossier mostly involve private and earlier-SCC references. I am therefore treating that as a small source-level subtlety to watch rather than claiming a hidden semantic bug.

## Bottom line

Binaryen `minimize-rec-groups` is really:

- **a GC-only explicit rec-group partitioning pass whose hard part is not SCC detection but preserving distinct type identities through feature-sensitive shape comparison, valid permutations, and compact brand insertion**

That is much more specific than the tiny pass summary in `pass.cpp` suggests.

## Sources

- Repo context:
  - `docs/README.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
  - `src/passes/optimize.mbt`
  - `agent-todo.md`
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
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MinimizeRecGroups.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-brands.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-ignore-exact.wast>
