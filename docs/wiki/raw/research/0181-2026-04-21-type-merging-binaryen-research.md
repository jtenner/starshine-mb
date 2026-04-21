# Binaryen `type-merging` research

Date: 2026-04-21
Author: Codex recursive wiki campaign thread
Status: source-backed upstream-only dossier input

## Scope and candidate selection

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

The original no-DWARF / saved-`-O4z` queue is already dossier-covered.
The first widened upstream-only queue is dossier-covered too.
So this thread needed to justify a **new** eligible tracker expansion rather than picking an old `none` entry.

I chose the local boundary-only registry pass name **`type-merging`**.
That expansion is justified because:

- it is still explicitly named in `src/passes/optimize.mbt`
- it is a real public Binaryen pass registered in upstream `pass.cpp`
- it has a substantial `version_129` implementation file (`TypeMerging.cpp`)
- it sits directly beside already-documented GC/type neighbors like `type-refining`, `signature-*`, `global-type-optimization`, `remove-unused-types`, `abstract-type-refining`, and `unsubtyping`
- its name is easy to over-teach as “delete duplicate types”, while the real contract is a closed-world, cast-aware, partition-refinement merge pass over the private heap-type graph
- it is relevant to future size-focused and late-GC cleanup work even though it is not in the repo's current canonical no-DWARF `-O` / `-Os` path
- `agent-todo.md` currently has **no dedicated `type-merging` slice**

I explicitly did **not** pick forbidden passes from the campaign instructions.
I also did not pick a pass that already had a deep dedicated folder.

## Main source set reviewed

### Core implementation

- Binaryen `version_129` `src/passes/TypeMerging.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/wasm-type-ordering.h`
- Binaryen `version_129` `src/support/dfa_minimization.h`
- Binaryen `version_129` `src/ir/module-utils.h`
- Binaryen `version_129` `src/ir/type-updating.h`

### Representative shipped test surface

- Binaryen `version_129` `test/lit/passes/type-merging.wast`

### Freshness / drift spot check

- Binaryen current `main` `src/passes/TypeMerging.cpp`
- Binaryen current `main` `src/passes/pass.cpp`
- Binaryen current `main` `test/lit/passes/type-merging.wast`

## Freshness check

I did a narrow current-`main` spot check.

Durable result:

- `pass.cpp` still registers `type-merging`
- the dedicated lit file still exists with the same leading run line
- the reviewed `TypeMerging.cpp` drift from `version_129` to current `main` is only a spelling/comment fix (`differentiatable` -> `differentiable`) on the checked diff

So `version_129` is a safe behavioral oracle for the dossier.

## High-level conclusion

Binaryen `type-merging` is a **closed-world GC type-graph compaction pass**.
It does **not** delete unused types in the `remove-unused-types` sense.
Instead it looks for **private heap types that are still used, but are not observably distinguishable from some supertype or sibling**, and then merges them.

The most important real contract points are:

1. only run with **GC enabled**
2. only run with **`--closed-world`**
3. only consider **private** original heap types mergeable
4. refuse merges that would be observable through **casts**, **exact casts**, `br_on_cast`, `ref.test`, or `call_indirect`
5. treat descriptor chains as linked units
6. do one pass of **merge-into-identical-supertype**
7. then iterate **merge-identical-siblings** until fixed point or `MAX_ITERATIONS = 20`
8. rewrite all affected heap-type references with `TypeMapper`
9. `ReFinalize` afterwards if sibling or exact-LUB-sensitive merging happened

So the pass is best taught as:

- **late private heap-type equivalence merging**
- not dead-type deletion
- not generic type inference
- not a simple syntactic deduplicator

## What the pass is trying to optimize

The source comment explains the real goal:

- some used subtype declarations are redundant for validation and have no detectable runtime effect
- merging them can shrink the type graph and open later size opportunities

The same comment also records the counterweight:

- redundant types can still help earlier optimizations
- so `type-merging` should happen late, after type-sensitive optimization has already benefited from the richer graph
- but not *too* late, because merging types may unlock later opportunities such as function merging

The source gives a concrete example sequence:

- `--type-ssa -Os --type-merging -Os`

That is a very important teaching correction.
The pass belongs to a **late cleanup / shrink** phase, not to the early inference cluster.

## What the pass does **not** do

The reviewed source is especially useful because it shows several tempting wrong assumptions.

`type-merging` does **not** in `version_129`:

- run in open world
- run without GC features
- merge public/export-visible types just because they are structurally equal
- ignore casts or exactness
- fold unused declarations away by itself
- operate only on structs; arrays, function heap types, tuples in signatures, and continuations all participate in the shape logic
- merge descriptor-chain members independently one-by-one
- perform only one naive linear sweep
- preserve IR validity without later type repair when exact-LUB-sensitive merges happened

It is therefore unsafe to summarize the pass as “merge duplicate types” without the visibility, cast, and refinalization conditions.

## Public surface and scheduler facts

Upstream `pass.cpp` registers:

- `type-merging` — `merge types to their supertypes where possible`

Nearby public registrations include:

- `type-finalizing`
- `type-ssa`
- `type-unfinalizing`
- `unsubtyping`
- `untee`

So `type-merging` is a first-class public pass, not an internal helper.
But it is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` page.
This dossier is therefore a justified tracker expansion for a real registry pass outside the default parity queue.

## Core implementation structure

## 1. Hard entry gates

`TypeMerging::run` returns immediately unless:

- `module->features.hasGC()` is true
- `getPassOptions().closedWorld` is true

The closed-world gate is fatal, not advisory.
The pass throws if closed-world mode is absent.

That means any future Starshine port must keep this as a **module/boundary pass with hard global preconditions**, not as a permissive hot-function cleanup.

## 2. Private-type candidate pool

The pass seeds `mergeable` with:

- `ModuleUtils::getPrivateHeapTypes(*module)`

and mirrors that into a `privateTypes` set.

This is the visibility rule:

- only original private heap types can be merged
- public types still matter in the DFA as distinguishing terminals, but they are not merge candidates

The lit file explicitly checks this with public exported function types.
Public `A` and `B` stay, while private `C` can merge into `B`.

## 3. Cast sensitivity: observable types must stay distinct

The pass first computes two sets:

- `castTypes`
- `exactCastTypes`

via a parallel function walk plus a module-scope walk.

`CastFinder` records heap types mentioned in:

- `ref.cast` unless traps-never-happen mode disables that distinction
- `ref.test`
- `br_on_cast` and `br_on_cast_fail`
- `call_indirect` unless traps-never-happen mode disables that distinction

The exact-cast set is stricter:

- if a cast target is exact, then subtypes of that target must also remain distinguishable from it

This is one of the biggest beginner traps.
A subtype can be “structurally redundant” and still be unmergeable because the module tests for it.

The lit file covers:

- plain `ref.cast`
- `ref.test`
- `br_on_cast`
- `call_indirect`

and the pass implementation matches those surfaces exactly.

## 4. The pass models the type graph as a partitioned DFA

The central algorithmic idea is not an ad hoc nested loop.
The file explicitly models heap types as DFA states whose transitions are their child heap-type references.

The rough pipeline is:

1. form coarse initial partitions of maybe-equivalent types
2. encode each type as a DFA state with successor states
3. run DFA partition refinement (`support/dfa_minimization.h`)
4. post-split unsafe supertype partitions when needed
5. merge each refined partition into a chosen target type

This is the real reason the file is substantial.
The pass is doing **graph equivalence refinement**, not just local parent checks.

## 5. Descriptor chains are treated as single units

Descriptor chains are a non-obvious but very important part of the implementation.

Key rules from the source:

- descriptor types are skipped as independent roots during partition seeding
- only the base described type is used as the DFA state representative
- the shape logic iterates across the whole descriptor chain
- when merges are applied, the replacement map is expanded across corresponding positions in both descriptor chains

So a future port must not independently merge one descriptor-chain node without the rest of the chain.
The algorithm treats the chain as one coupled object.

## 6. Two distinct merge kinds

The source makes the split explicit:

- `Supertypes`
- `Siblings`

This is not just implementation detail.
It is a correctness boundary.

### Supertype merging

A type may be grouped with its supertype only if:

- it has a declared supertype
- the top-level shapes match under `shapeEq`
- the relevant supertype is not blocked by an exact-cast boundary

### Sibling merging

After the supertype phase, structurally identical siblings can be grouped by:

- merged supertype (if any)
- top-level shape

The source comment explicitly says doing both kinds at once would be unsound, because a type could merge into a parent's sibling without first merging into the parent.
The lit suite includes a regression for exactly that kind of unsoundness.

## 7. One supertype pass, then iterative sibling passes

`run(...)` performs:

- one `merge(Supertypes)`
- then up to `MAX_ITERATIONS = 20` of `merge(Siblings)` until no further change

Why the asymmetry?

- merging supertypes can unlock sibling merges
- sibling merges cannot unlock new supertype merges
- repeated sibling passes are needed because one horizontal merge can create more horizontal equivalences higher or lower in the graph

The lit file has a dedicated multi-iteration test where successive waves unlock more merging.

## 8. Partition refinement is shape-aware but not purely structural

The pass defines `shapeEq` and `shapeHash` for:

- heap types
- structs
- arrays
- signatures
- continuations
- fields
- ordinary types and tuple types

Critical subtleties:

- supertype identity is intentionally ignored in the top-level shape, because the pass wants to permit parent merges
- nullability, exactness, mutability, packedness, tuple arity, and descriptor-chain position all matter
- non-basic heap-type children are abstracted into DFA successors rather than fully compared up front
- basic heap types still matter directly in shape hashing/equality

This is why the pass can recognize “these two types only differ in which child type they mention, and those children may themselves later merge” without prematurely rejecting the parent merge.

## 9. Public children are terminal differentiators

`makeDFAState` includes both private and public child heap types as possible successors, but public types are effectively treated as terminal states.

The comment explains why:

- public types are already singleton partitions, so they distinguish reaching states without needing their own successors explored further

That design is also the reason for one still-open limitation documented in the lit file TODO:

- a private subtype under a public type may fail to merge because the DFA does not encode successors of public states deeply enough

The test names issue `#7120` in the upstream comment.
For this dossier I treat that as **explicit upstream limitation**, not a local uncertainty.

## 10. Manual partition splitting after supertype refinement

After DFA refinement in the supertype phase, Binaryen does another manual step:

- `splitSupertypePartition`

The reason is subtle and important:

- DFA refinement can leave unrelated types grouped together after an ancestor lands in a different refined partition
- that would be okay for sibling merging, but not for “merge only into supertypes” mode

So Binaryen walks the refined partition in supertype order and splits disconnected roots into separate partitions.

This is a real correctness patch, not optimization polish.

## 11. Merge target choice is deliberately ordered

For each final refined partition, the chosen target is:

- `mergeableSupertypesFirst(partition).front()`

In plain language:

- pick the earliest supertype-ordered member, not an arbitrary equal-shape member

That matters because merging into a subtype would be wrong and can corrupt the declared-super graph.
The lit file includes a regression for a historical bug where the wrong direction was chosen.

## 12. Applying merges is a module-wide heap-type rewrite

Once the merge map is known, `applyMerges()`:

- flattens transitive merge chains
- expands replacements across descriptor chains
- invokes `TypeMapper(*module, replacements).map()`

This is the visible whole-module rewrite step.
It updates type references across:

- function signatures
- locals
- globals
- struct and array definitions
- instructions whose static types mention heap types

The lit file's “real-world patterns” section exists mainly to prove this rewrite stays consistent.

## 13. Refinalization is part of the semantic contract

Binaryen tracks whether merging may require refinalization.
The source comment gives the key motivating example:

- if sibling merges make two previously distinct subtype values become the exact same type, then a `select` LUB can sharpen to an exact result

So after merges, Binaryen may run:

- `ReFinalize().run(getPassRunner(), module)`

The lit file includes dedicated refinalization regressions.
This is not optional cleanup.
A future port that rewrites type declarations without later expression-type repair will be wrong.

## Important positive rewrite shapes

The official lit file is rich and gives a beginner-friendly catalog.
The most important positive families are:

### 1. Direct subtype-to-supertype merges

If a subtype adds no fields, refines nothing, changes no exactness/nullability/mutability/finality, and is not distinguished by casts, it can merge into its declared supertype.

### 2. Multi-level chain collapse

If `C -> B -> A` are all effectively identical, repeated supertype merging collapses the whole chain into `A`.

### 3. Sibling merging after parent merging

Two types that are not initially siblings may become siblings after earlier parent merges, then merge in a later sibling iteration.

### 4. Field-child convergence

A child-type refinement can stop mattering if the referenced child types also merge.
The pass can therefore merge a struct subtype whose field mentions `$Y` into one mentioning `$X` after `$Y` merges into `$X`.

### 5. Recursive and mutually recursive graph merges

The pass handles recursive and mutually referential subtype chains by treating child references as DFA successors and iterating to fixed point.

### 6. Root-type variety

The lit suite proves the pass is not structs-only.
It handles:

- arrays
- function heap types
- structs
- tuples inside signatures
- continuation-bearing type shapes via the generic shape logic

### 7. Real-world full-module rewrite

The longer mid-file regression proves the rewrite updates:

- globals
- constructor instructions
- array constructors
- function signatures
- nested field references

while preserving a valid, merged type graph.

## Important bailout and preservation shapes

### 1. Field refinement that remains semantically visible

A subtype cannot merge when it really refines a field in a way that stays observable:

- extra fields
- stricter nullability
- stricter heap type
- mutable/packed differences

### 2. Finality/open-ness changes

The shape logic checks `isOpen()` and `isShared()`.
The lit file also covers finality differences.
So a type changing final/open status is not mergeable with its parent just because the field list matches.

### 3. Cast-observable types

Any type directly tested by:

- `ref.cast`
- `ref.test`
- `br_on_cast`
- `call_indirect`

is protected from merging in the relevant way.
Exact casts are stricter still.

### 4. Public types

Public/export-visible types are not merge candidates.
Private subtypes below them may still merge into them.

### 5. Upstream TODO boundary with public-state successors

The lit file explicitly documents one current limitation: some private-under-public merge opportunities are left on the table because successors of public DFA states are not encoded.

### 6. Traps-never-happen mode nuance

`ref.cast` and `call_indirect` stop differentiating types when traps never happen, because they are assumed always to succeed.
`ref.test` still differentiates, since it observes type identity without trapping.

That is an easy nuance to lose.

## Pass interactions and pipeline placement

The source comment is unusually explicit here.

Good mental model:

- early type-sharpening passes such as `type-ssa` can create more useful distinctions
- later optimization benefits from those distinctions
- `type-merging` should happen after that benefit is harvested
- but before final size-oriented cleanup opportunities close

Important neighboring relations in this repo's wiki map:

- unlike `remove-unused-types`, this pass keeps used types and rewrites them into fewer equivalent ones
- unlike `type-refining`, it does not make types more specific; it intentionally removes unneeded distinctions
- unlike `unsubtyping`, it is not primarily removing subtype *relationships* while preserving node identities; it can merge nodes together
- unlike `minimize-rec-groups`, it is not about rec-group partition minimization or type-section layout
- it can plausibly unlock later size passes like `merge-similar-functions` by reducing type noise

## What is easy to misunderstand

### Misunderstanding 1: “This is dead-type cleanup.”

No.
That is `remove-unused-types` territory.
`type-merging` works on **still-used** types that can become some other existing type.

### Misunderstanding 2: “It just compares textual type declarations.”

No.
It uses a graph-equivalence algorithm over heap-type children, descriptor chains, and visibility/cast boundaries.

### Misunderstanding 3: “If two types are equal, merge either direction.”

No.
Target choice is directional and must respect supertype order.

### Misunderstanding 4: “Casts only matter for `ref.cast`.”

No.
`ref.test`, `br_on_cast`, exactness, and `call_indirect` all participate.

### Misunderstanding 5: “Refinalization is optional clean-up.”

No.
The pass can change exact LUB results and local/static expression types.
Refinalization is part of correctness.

## Future Starshine port invariants

A future Starshine implementation should preserve at least these invariants:

1. **hard gates**
   - require GC
   - require closed world
2. **visibility rule**
   - only private heap types are merge candidates
3. **observability rule**
   - never merge across cast/exact-cast / `ref.test` / `br_on_cast` / `call_indirect` boundaries unless the same TNH condition holds
4. **descriptor-chain rule**
   - merge descriptor chains positionally as units
5. **two-phase rule**
   - supertype merging before iterative sibling merging
6. **graph-equivalence rule**
   - child-type equivalence must be solved as a graph problem, not only by local parent comparison
7. **direction rule**
   - choose merge targets in supertype-safe order
8. **module rewrite rule**
   - rewrite all heap-type references coherently across the module
9. **type-repair rule**
   - refinalize or otherwise repair all downstream expression/static types after merges
10. **known-limit honesty**
   - if public-successor-state precision is missing, document the lost merge opportunity rather than silently claiming full parity

## Open questions or deliberate non-goals

I did not try to reconstruct a full upstream preset slot for `type-merging` because the reviewed public sources here mainly establish its standalone contract, not a default-preset inclusion.
That is okay: the campaign asked for a deep pass dossier, not preset archaeology for a pass outside the canonical no-DWARF path.

I also did not expand into `type-finalizing`, `type-unfinalizing`, or `experimental-type-generalizing` in this thread.
Those remain possible future tracker expansions if a later thread explicitly justifies them.

## Deliverables filed back into the wiki

This research note feeds the new living folder:

- `docs/wiki/binaryen/passes/type-merging/`

with:

- landing page
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `dfa-partitions-casts-and-refinalization.md`
- `wat-shapes.md`

and also updates:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Sources

- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/dfa_minimization.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-merging.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeMerging.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-merging.wast>
- Local repo context:
  - `docs/README.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `src/passes/optimize.mbt`
  - `agent-todo.md`
