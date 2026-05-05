---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md
  - ../../../raw/research/0462-2026-05-05-type-merging-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md
  - ../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/dfa_minimization.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./dfa-partitions-casts-and-refinalization.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy for `type-merging`

This page is now anchored to the immutable 2026-04-24 primary-source manifest in [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md) and the 2026-05-05 current-main bridge in [`../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md).
That manifest pair records the official `version_129` release page, owner source, helper headers, dedicated lit file, and the narrow current-`main` spot check used for this dossier.

## What the pass really is

The reviewed implementation is a **closed-world GC heap-type compaction pass**.
It does not remove dead types and it does not infer sharper types.

The pass starts from the set of **private heap types** that still exist in the module, asks which of them are no longer observably distinct from some safe target, proves equivalence with a partition-refinement algorithm over the type graph, rewrites the module to use the merged targets, and then refinalizes if expression result types may have become sharper.

That means the best mental model is:

- **late private type equivalence merging**
- with **cast observability** and **whole-module type repair**

## Public surface and scheduler meaning

`src/passes/pass.cpp` registers `type-merging` as a public pass.
The source comment at the top of `TypeMerging.cpp` gives the scheduler advice that matters more than any preset listing:

- redundant types can help earlier optimization
- so `type-merging` should run late
- but not so late that it misses opportunities it can unlock, like later function merging

The comment's concrete example sequence is:

- `--type-ssa -Os --type-merging -Os`

So a future port should treat `type-merging` as a **late cleanup / shrink neighbor of other type and size passes**, not as an early inference stage.

## Hard entry gates

`TypeMerging::run` has two hard gates before it does anything meaningful:

- `module->features.hasGC()` must be true
- `getPassOptions().closedWorld` must be true

If closed-world mode is absent, the pass aborts.

This makes sense because the pass relies on a closed-world claim about observability:

- if the outside world can manufacture or distinguish heap-type identities freely, then private-type merging is not safe to reason about the same way

## Core data the pass tracks

### `privateTypes` and `mergeable`

The initial candidate pool is `ModuleUtils::getPrivateHeapTypes(*module)`.

That gives two important invariants:

- the pass never picks a public type as a merge *candidate*
- public types can still participate as **distinguishing graph structure**

### `castTypes` and `exactCastTypes`

The pass also computes two observability sets:

- heap types that appear in cast-like sites at all
- heap types that appear as exact cast targets

These are the key negative guards that stop unsafe merges.

### `merges`

This stores the transitive merge map from original types to chosen targets.
The helper `getMerged(...)` repeatedly chases through that map so later phases can see already-collapsed targets.

## Main algorithmic phases

## Phase 1: scan cast-like observability

`findCastTypes()` is one of the central safety phases.
It runs a parallel function analysis and also scans module-scope code for future-proofing.

The nested `CastFinder` records heap types reached through:

- `ref.cast` unless traps-never-happen mode says success is guaranteed
- `ref.test`
- `br_on_cast` / `br_on_cast_fail`
- `call_indirect` unless traps-never-happen mode says success is guaranteed

The important nuance is that Binaryen is not treating all these instructions as the same.

### Why TNH matters

If traps never happen, then:

- `ref.cast` cannot fail
- `call_indirect` cannot trap on type mismatch

So those instructions stop distinguishing types for this pass.

But `ref.test` still matters because it observes type identity without needing a trap.

That nuance is easy to lose in a shallow summary.

## Phase 2: seed the candidate graph in supertype order

The helper `mergeableSupertypesFirst(...)` uses `HeapTypeOrdering::supertypesFirst(...)`.

This ordering matters because:

- target choice must always be supertype-safe
- descriptor chains need the supertype chain considered before the subtype chain
- later partition splitting and target choice rely on stable ancestor-first reasoning

A future port that iterates in arbitrary set order could easily choose a wrong target direction.

## Phase 3: build coarse initial partitions

The pass has two explicit merge modes:

- `Supertypes`
- `Siblings`

The implementation constructs **initial partitions** differently for the two modes.

### Supertype mode

A type can join its supertype's partition only if:

- it has a declared supertype
- it is private
- neither it nor its descriptor-chain members are blocked by cast observability
- its top-level shape matches its supertype under `shapeEq`
- the relevant supertype edge is not blocked by an exact-cast hazard

Otherwise it starts its own singleton partition.

### Sibling mode

A type is grouped by:

- merged supertype identity
- top-level shape

So sibling merging happens only after earlier supertype merges may have collapsed parents enough to make siblings comparable.

## Phase 4: treat the type graph as a partitioned DFA

This is the pass's defining algorithmic idea.

Each relevant heap type is turned into a DFA state whose ordered successors are heap-type children.
Then Binaryen asks the DFA minimizer to refine coarse maybe-equivalent partitions into true equivalence classes.

### Why this is needed

A local parent/field comparison is not enough because types can differ only through child types that themselves later merge.

Example mental model:

- parent A mentions child X
- parent B mentions child Y
- A and B look different now
- but if X and Y are themselves equivalent and later merged, A and B become equivalent too

The DFA formulation is how Binaryen captures that recursively.

## Phase 5: descriptor chains are single logical units

The pass goes out of its way to avoid treating descriptor-chain members independently.

Important implementation choices:

- descriptor types are skipped as independent partition roots
- the base described type represents the chain in the DFA
- `shapeEq(HeapType, HeapType)` walks the full descriptor chain
- child references are normalized to the base described type of the successor chain
- when merges are applied, replacements are expanded positionally across both chains

So the true unit of equivalence is not “one heap type declaration node” but often “one base type plus its descriptor chain.”

## Phase 6: refine partitions with DFA minimization

After seeding partitions, the pass moves them into a vector and calls:

- `DFA::refinePartitions(...)`

from `support/dfa_minimization.h`.

The minimizer splits initial partitions until states in the same partition have equivalent successor structure.

This is the central proof step that turns “maybe mergeable” into “actually equivalent under the graph model.”

## Phase 7: post-split supertype partitions manually

After DFA refinement, Binaryen performs an extra correction in `Supertypes` mode:

- `splitSupertypePartition(...)`

Why?

Because DFA refinement can still leave a partition containing unrelated roots after an ancestor split.
That may be okay for later sibling merging, but it is not okay when the semantic promise is “merge only into supertypes.”

So Binaryen walks the refined partition in ancestor-first order and splits it into connected supertype-rooted subpartitions.

This is a subtle correctness repair, not incidental cleanup.

## Phase 8: choose one safe target per refined partition

For each final refined partition, the target type is:

- the first element in `mergeableSupertypesFirst(partition)`

That effectively means:

- pick the earliest safe ancestor-ordered representative

This is why the pass avoids historical bugs like merging the ancestor into the descendant instead of the other way around.

## Phase 9: do one supertype pass, then repeated sibling passes

`run(...)` performs:

- one `merge(Supertypes)`
- then up to `MAX_ITERATIONS = 20` of `merge(Siblings)`

The source comment explains the asymmetry:

- supertype merging can unlock sibling merging
- sibling merging cannot unlock new supertype merging

That is also why the repeated loop exists at all: one horizontal merge can expose more horizontal equivalences in later rounds.

## Phase 10: rewrite the whole module with `TypeMapper`

`applyMerges()` is where the abstract merge map becomes real module IR changes.

The pass first:

- flattens transitive merge trees
- expands each original-to-target merge across corresponding descriptor-chain members

Then it uses:

- `TypeMapper(*module, replacements).map()`

That is the real whole-module rewrite surface.
It updates every static heap-type reference that the mapper knows how to touch.

## Phase 11: refinalize when needed

If merges happened in a way that can change exact result types or LUBs, Binaryen runs:

- `ReFinalize().run(getPassRunner(), module)`

The source comment gives the best intuition:

- if two formerly distinct subtypes are both merged into the same parent, a `select` that used to return their common supertype may now be able to return an exact result

So refinalization is part of the semantic contract, not optional cleanup.

## Helper dependencies that really matter

### `HeapTypeOrdering::supertypesFirst`

This gives stable ancestor-first traversal for both initial partitioning and safe target choice.

### `DFA::refinePartitions`

This is the actual equivalence engine. Without it, the pass would miss recursive and child-driven equivalences or make unsafe local guesses.

### `ModuleUtils::getPrivateHeapTypes`

This defines the visibility boundary of what is allowed to merge.

### `TypeMapper`

This performs the actual module-wide type rewrite after the merge plan is known.

### `ReFinalize`

This repairs exact result types and expression typing after merges that change the graph's effective LUB structure.

## How the pass models "same shape"

The pass uses `shapeEq` / `shapeHash` across several layers:

- heap type kind
- open/final state through `isOpen()`
- shared-ness through `isShared()`
- struct fields, array element, function params/results, continuation payloads
- field mutability and packedness
- reference nullability and exactness
- tuple arity and members
- descriptor-chain index position

What it intentionally does **not** compare directly at the top level is:

- declared supertype identity

That omission is deliberate because the pass wants to allow “same shape as supertype” merges.
Child heap-type differences are deferred into DFA successor refinement instead of being fully treated as direct inequality up front.

## Important pass interactions

## 1. `type-ssa`

The source comment names this explicitly.
`type-ssa` can create distinctions that help earlier optimization.
`type-merging` intentionally comes later to remove the distinctions that are no longer worth keeping.

## 2. `remove-unused-types`

These passes solve different problems.

- `remove-unused-types` deletes private dead declarations
- `type-merging` collapses **live** private declarations into other live declarations

A future port should keep them separate conceptually and in scheduler design.

## 3. `merge-similar-functions`

The top comment explicitly mentions that type merging can unlock later function-merging opportunities.
That gives a concrete late-size interaction worth preserving.

## 4. `unsubtyping`

`unsubtyping` prunes unnecessary subtype relations while preserving observable correctness.
`type-merging` can go further by merging nodes entirely when they are no longer observably distinct.
So they are related, but not substitutes.

## Beginner-facing summary of the real contract

If you want the shortest accurate rule, it is this:

- take the private heap-type graph
- mark the types that casts and exactness still make observable
- group only maybe-equivalent types together
- refine those groups by child-type graph structure
- merge safe groups into supertype-safe representatives
- rewrite every type reference consistently
- refinalize if exact typing sharpened

That is the real Binaryen strategy for `type-merging`.

## Sources

- [`../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md)
- [`../../../raw/research/0462-2026-05-05-type-merging-current-main-recheck.md`](../../../raw/research/0462-2026-05-05-type-merging-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md)
- [`../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md`](../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md`](../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/dfa_minimization.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
