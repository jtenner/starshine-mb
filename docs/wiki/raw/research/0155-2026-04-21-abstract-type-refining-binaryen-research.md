# 0155 - Binaryen `abstract-type-refining` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `unsubtyping` upstream-only registry dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is fully dossier-covered and the prompt excludes the already-deepened parity passes plus the newer closed-world GC/type dossiers, expand into another nearby upstream-only Binaryen pass that still has no dedicated living dossier.
- Create a new beginner-friendly but source-backed dossier for `abstract-type-refining`.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/abstract-type-refining/`
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
- the prompt still excluded the refreshed parity dossiers plus the newer upstream-only dossiers for `remove-unused-types`, `type-refining`, `signature-pruning`, `signature-refining`, `global-type-optimization`, and `unsubtyping`
- the tracker's clearest still-`none` upstream-only candidates were `abstract-type-refining`, `minimize-rec-groups`, and `reorder-types`
- `agent-todo.md` still had **no dedicated `abstract-type-refining` slice**, so there was no local backlog page already teaching the Binaryen contract

So this run needed another explicit queue-expansion pick from the tracker's upstream-only registry table.

I picked `abstract-type-refining` for seven source-backed reasons:

- It was still listed as `none` in the tracker's additional upstream-only registry table.
- It is already tracked in the local boundary-only registry in `src/passes/optimize.mbt`, so this is a real Starshine-facing pass name and not just an upstream tangent.
- It sits directly between `gsi` and `unsubtyping` in Binaryen's late closed-world GC/type cluster, so documenting it now closes the next biggest hole in that already-active wiki neighborhood.
- It had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- The official implementation is small enough to underestimate but subtle enough to deserve a real dossier: it is not a generic type merger, but a conservative closed-world rewrite that relies on “created vs never-created” struct evidence, optional `traps-never-happen` reasoning, and a descriptor/exact-cast preoptimization phase.
- The implementation hides several beginner traps worth making explicit:
  - only **struct** heap types are optimized today
  - only `struct.new*` counts as “created” evidence
  - public types are conservatively treated as created even in closed world
  - refinement to a unique live child only happens in `--traps-never-happen` mode
  - mapping a never-created type to bottom happens even without `--traps-never-happen`
  - subtype-edge cleanup is intentionally **not** done here; that is deferred to later `unsubtyping`
  - exact casts, descriptor casts, `ref.get_desc`, and `struct.new_desc` need preoptimization before shared type rewriting would otherwise reintroduce invalid or behavior-changing shapes
- The official lit surface is broad and teachable: the main file covers cast/test/branch/local families, the descriptor file covers descriptor casts plus `ref.get_desc` and allocation repair, the exact file covers bottomized exact locals, the TNH exact-casts file covers exact-cast impossible-success preservation, and the continuation file proves the type-copy machinery keeps continuation/function links coherent.

So this thread is not reopening an old parity item.
It is the first explicit living dossier for the closed-world-cluster `abstract-type-refining` pass that sits between the already-documented `gsi` and `unsubtyping` neighbors.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/AbstractTypeRefining.cpp>
- pass registration and default scheduler placement:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- helper surfaces that carry much of the real behavior:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/drop.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type.h>
- representative official test surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-cont.wast>

Narrow freshness check on current `main`:

- core pass file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/AbstractTypeRefining.cpp>
- pass registration:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- dedicated lit files checked on the reviewed surfaces:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-cont.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-`main` check on the most important reviewed surfaces while drafting the living pages.

Durable result:

- the checked `AbstractTypeRefining.cpp` file on `main` still matches the tagged `version_129` pass on the reviewed algorithmic surfaces that matter most here:
  - same GC gate
  - same hard `--closed-world` fatal
  - same `StructNew`-only creation scan
  - same public-types-treated-as-created rule
  - same `createdTypesOrSubTypes` upward propagation
  - same TNH-only `computeAbstractTypes(...)` singleton-child logic
  - same struct-only mapping loop
  - same descriptor/exact-cast preoptimization logic
  - same “preserve declared supertypes here; leave that to `unsubtyping`” rule
  - same final `ReFinalize()` tail
- the checked dedicated lit files above were unchanged on the reviewed surfaces
- the reviewed `pass.cpp` surfaces did not change the `abstract-type-refining` registration or its scheduler slot; the visible current-`main` diff hunks in the broader file were unrelated typo fixes elsewhere in the registry

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
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-type-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/unsubtyping/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

Important local context conclusions:

- the current open-world no-DWARF page does **not** run `abstract-type-refining`
- the local registry tracks the pass only as the full boundary-only name `abstract-type-refining`
- the current living `global-refining`, `global-struct-inference`, `global-type-optimization`, and `unsubtyping` docs already treat it as a real closed-world scheduler neighbor
- `agent-todo.md` has **no dedicated `abstract-type-refining` slice today**, so this note must say that explicitly rather than pretending a backlog slice already exists

## High-level conclusion

Binaryen `abstract-type-refining` is not generic “merge similar abstract types.”

The real `version_129` contract is narrower and more concrete:

1. require GC features and reject non-closed-world invocation
2. scan the module for which **struct** heap types are definitely created by `struct.new*`
3. conservatively treat public heap types as created too
4. propagate “some subtype is created” facts upward through the declared subtype tree
5. in `--traps-never-happen` mode only, compute which never-directly-created abstract types can be refined to a single still-relevant child type
6. in all modes, map truly never-created-and-no-live-subtype struct types to their bottom heap type
7. preoptimize exact casts, descriptor casts, `ref.get_desc`, `br_on_cast_desc_eq*`, and `struct.new_desc` so shared type rewriting will not reintroduce invalid or behavior-changing types
8. rewrite remaining type uses with a custom `TypeMapper` while intentionally **preserving declared supertypes**
9. refinalize afterward because the changed heap types can sharpen or invalidate surrounding IR types

A better short summary is:

- **Binaryen `abstract-type-refining` is a closed-world GC module pass that rewrites never-created struct types either to bottom or, in `--traps-never-happen` mode, to a uniquely live child type, while preoptimizing descriptor and exact-cast shapes and leaving declared subtype-edge cleanup to later `unsubtyping`.**

The biggest beginner corrections are:

- the pass is about **creation evidence**, not just declaration shape
- TNH changes only the “refine abstract parent to unique live child” half; it does **not** gate the simpler bottomization of truly never-created types
- only **struct** types participate today
- subtype relations are deliberately not rewritten here even when type uses are rewritten everywhere else
- much of the visible type-section shrink in the official lit files is checked under `--abstract-type-refining --remove-unused-types`, not `--abstract-type-refining` alone

## Upstream naming and scheduler surface

`pass.cpp` registers the pass with the public CLI name:

- `abstract-type-refining`

and the summary:

- `refine and merge abstract (never-created) types`

That summary is directionally right, but too small.
It hides several central details:

- the pass is a **module pass**, not a local peephole
- the current implementation only optimizes **struct** heap types
- the most interesting parent-to-child refinement half is **TNH-only**
- descriptor-bearing casts and allocations need preoptimization before shared type rewriting
- declared subtype edges are intentionally left alone here

### Relation to nearby passes

The most useful cluster model is:

- `type-refining`, `signature-pruning`, and `signature-refining` tighten fields and signatures earlier in the closed-world cluster
- `global-refining` and optional `gto` sharpen globals and struct layouts before `gsi`
- `gsi` can expose more abstract or never-created type traffic after global cleanup
- `abstract-type-refining` then collapses some never-created struct types to bottom, and in TNH mode can further refine abstract parents to a unique live child
- `unsubtyping` comes **afterward** to clean up declared subtype and descriptor edges that this pass intentionally leaves alone
- `remove-unused-types` can erase now-dead heap types when scheduled around this cluster or when explicitly paired in tests

So `abstract-type-refining` is not a first type-tightening step and not a full subtype minimizer.
It is a **late creation-evidence cleanup pass**.

### Scheduler placement

`abstract-type-refining` is not part of the repo's main open-world no-DWARF path.

In upstream `pass.cpp`, the relevant default global-prepass cluster is:

- if `wasm->features.hasGC()` and `options.optimizeLevel >= 2`
- and if `options.closedWorld`
- then run:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
  - `global-refining`
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - `abstract-type-refining`
  - `unsubtyping`

That teaches four durable things:

- `abstract-type-refining` is a **closed-world late GC/type-cluster cleanup**, not an open-world parity pass
- it runs after `gsi`, which means it sees the already-tightened type graph from several earlier neighbors
- the default placement is purely in the global prepass cluster, not in the function-pass loop
- unlike some neighbors, the pass body itself **also** insists on `--closed-world`

## Core algorithm and phases

The key implementation idea is surprisingly small:

- Binaryen asks which struct heap types are ever created,
- uses that to identify impossible or unique-survivor type families,
- rewrites type uses accordingly,
- but preserves declared subtype links for later passes.

That sounds simple until the descriptor and exact-cast repair surface appears.

### Phase 0: hard GC + closed-world gates

`AbstractTypeRefining::run(Module* module)` begins by returning immediately when:

- `!module->features.hasGC()`

and then throwing a fatal error when:

- `!getPassOptions().closedWorld`

So this pass does not merely *tend* to run in closed world.
The body itself requires it.

### Phase 1: collect definitely created struct types

The pass defines a tiny `NewFinder` walker.
Its rule is narrower than many people expect:

- only `visitStructNew(StructNew* curr)` contributes created-type evidence

So today:

- `struct.new*` counts
- arrays do **not** count here
- function/continuation types do **not** count here
- ordinary references, casts, and `ref.func` do **not** count here

The scan runs in two places:

- `walkModuleCode(module)` for globals / element / module code
- `ModuleUtils::ParallelFunctionAnalysis<Types>` over non-imported function bodies

The results are unioned into `createdTypes`.

That is the first big beginner correction:

- “created” means **concrete `struct.new` evidence**, not “mentioned somewhere.”

### Phase 2: public types are conservatively treated as created

Before any refinement logic, the pass inserts every type from:

- `ModuleUtils::getPublicHeapTypes(*module)`

into `createdTypes`.

The source comment is explicit that this is conservative.
Even in closed world, the pass does **not** currently assume it can refine public types just because they are not instantiated inside the module.

So public visibility is a hard practical bailout.

### Phase 3: propagate created-subtype facts upward

The pass constructs:

- `SubTypes subTypes(*module)`

and then computes `createdTypesOrSubTypes`.

This is **not** the same as “directly created.”
The pass starts from `createdTypes` and then walks the subtype tree in subtype-first order:

- if any immediate child of a type is in `createdTypesOrSubTypes`
- mark the parent as in `createdTypesOrSubTypes` too

That produces a more useful late-cluster fact:

- a type is still relevant if it or any descendant can actually show up at runtime

This is why a parent can be abstract in the direct-creation sense while still not being bottomizable.

### Phase 4: TNH-only abstract-parent refinement

Only when:

- `getPassOptions().trapsNeverHappen`

is true, the pass runs `computeAbstractTypes(subTypes)`.

This phase computes a different set:

- `abstractTypes = all collected types - directly created types`

Then, in subtype-first order, it tries to find a unique child target for each abstract type.

There are two cases.

#### 4A. Single immediate subtype

If an abstract type has exactly one immediate subtype, then its casts can refine directly to that child.

#### 4B. Multiple immediate subtypes, but only one relevant one

If there are several immediate children, the pass still accepts refinement when exactly one child is in `createdTypesOrSubTypes`.

That means:

- the hierarchy may look branching on paper
- but if only one branch can actually contain created runtime values
- TNH allows the parent cast to collapse to that single live branch

#### 4C. Chained refinement is propagated

If the chosen child is itself already refinable, the pass replaces the child with the deeper final target.

So chains like:

- `$A :> $B :> $C`

can refine all the way from `$A` to `$C` in TNH mode.

### Phase 5: build the actual rewrite mapping

`optimize(module, subTypes)` builds a `TypeMapper::TypeUpdates mapping`.

This loop is deliberately narrow.
For each collected type:

- if it is **not** a struct type, skip it
- if neither it nor any subtype is created, map it to `type.getBottom()`
- else if TNH computed a child refinement, map it to that child

This implies three crucial boundaries:

- arrays are currently unsupported
- functions are currently unsupported
- bottomization is stronger and more common than TNH child refinement

The source TODO is explicit that arrays/functions are future work, and function support would need extra `configureAll` handling.

### Phase 6: preoptimize descriptor and exact-cast shapes before rewriting types

If the module lacks custom descriptors, the pass skips `preoptimize(...)` entirely.

Otherwise it runs a function-parallel plus module-code `Preoptimizer` walker.

This phase exists because blindly rewriting heap types first would leave several illegal or behavior-changing cases for later refinalization.

#### 6A. Exact casts to optimized types

If a `ref.cast` target type is exact and the heap type is being optimized, the pass rewrites the cast target to the optimized type's bottom while preserving nullability.

Why?

Because otherwise TNH refinement could turn:

- exact cast to never-instantiated `$A`

into:

- exact cast to live child `$B`

which would incorrectly start succeeding.

So exact impossible casts are made **more impossible**, not more specific.

#### 6B. Descriptor casts whose descriptor type goes to bottom

For `ref.cast_desc_eq` and `br_on_cast_desc_eq*`, if the descriptor side is being optimized to bottom, the pass also rewrites the cast/branch to the optimized bottom target.

If the descriptor operand may trap on null and TNH is **not** enabled, the preoptimizer first wraps it in:

- `ref.as_non_null`

Then it uses `ChildLocalizer` to spill side-effectful children into locals so the descriptor operand can be removed without changing evaluation order.

That is why the descriptor lit files grow temporary locals and blocks.

#### 6C. `ref.get_desc`

If the descriptor type being fetched is optimized, `ref.get_desc` needs special repair.

There are two main cases.

- If the query is exact, or the optimized descriptor has no usable subtype path, the operation becomes:
  - drop the ref input
  - then `unreachable`
- Otherwise, when an inexact input might still hold a live refined subtype, the pass inserts a `ref.cast` on the described value so the rewritten `ref.get_desc` still validates and means the right thing

This is one of the easiest parts to misunderstand if you only read the top-level pass summary.

#### 6D. `struct.new_desc`

If the descriptor operand type is optimized, the allocation cannot succeed as written after type rewriting.
So the preoptimizer repairs it before the type rewrite.

- in function context:
  - replace the allocation with dropped children plus `unreachable`
  - preserve side effects with `getDroppedChildrenAndAppend(...)`
- in module/global context:
  - replace the descriptor operand with `ref.null none`
  - because locals and blocks are unavailable there, and only trap behavior matters

This split is a real contract surface, not incidental code style.

### Phase 7: rewrite type uses, but preserve declared supertypes

After preoptimization, the pass rewrites types with a custom subclass of `TypeMapper`.

The central override is:

- `getDeclaredSuperType(...) { return oldType.getDeclaredSuperType(); }`

That one override explains a huge amount of the pass behavior.

Binaryen intentionally does **not** try to repair or minimize declared subtype chains here.
The file comment is explicit that this is nontrivial and is left to:

- `unsubtyping`

So this pass rewrites **uses** of heap types across the module but intentionally keeps the declared subtype graph stable for now.

That is why the correct mental model is:

- use-site refinement now
- subtype-edge cleanup later

### Phase 8: refinalize

Finally, the pass runs:

- `ReFinalize().run(getPassRunner(), module)`

The need is real, not ceremonial.
After type rewriting:

- casts can sharpen or collapse
- block / branch result types can change
- locals and signatures may have new ref types
- descriptor-related shapes may need shared IR repair

So a future port must preserve the final refinalization contract.

## Important helper dependencies

The pass file looks small because it leans on helpers.
The most important ones are:

- `ModuleUtils::ParallelFunctionAnalysis`
  - function-parallel created-type scan
- `ModuleUtils::getPublicHeapTypes(...)`
  - defines the conservative public boundary
- `SubTypes`
  - provides immediate-children queries and subtype-first order
- `TypeMapper`
  - performs the actual module-wide heap-type remap
- `ChildLocalizer`
  - preserves child evaluation order when descriptor operands must be removed
- `getDroppedChildrenAndAppend(...)`
  - preserves side effects when impossible allocations become `unreachable`
- `ReFinalize`
  - repairs surrounding IR types after the rewrite

## What the pass does **not** do

Binaryen `abstract-type-refining` in `version_129` does **not** do any of these:

- it does not run in open world
- it does not optimize without GC
- it does not currently optimize arrays
- it does not currently optimize function or continuation heap types directly
- it does not treat generic type mentions as creation evidence
- it does not rewrite declared subtype links
- it does not replace `unsubtyping`
- it does not require TNH for bottomization of truly never-created struct types
- it does not claim to make all dead types disappear by itself; many visible tests pair it with `remove-unused-types`

Those boundaries are just as important as the positive rewrites.

## Important WAT / IR shapes

The official tests show six major shape families.

### 1. TNH-only abstract-parent-to-child refinement

When a parent type is never directly created but only one still-relevant child branch exists, TNH lets these rewrite:

- `ref.cast`
- `ref.test`
- `br_on_cast`
- local declarations

from the abstract parent type to the unique live child.

### 2. Always-on bottomization of truly never-created families

When neither a type nor any subtype is ever created, the pass maps the heap type to bottom in both TNH and non-TNH modes.
That is why many result, local, and cast types become:

- `ref none`
- `nullref`
- shared bottom equivalents

### 3. Multiple-live-branch bailout

If an abstract parent still has more than one relevant child branch, TNH does **not** refine it to one of them.
The pass must preserve the original parent type.

### 4. Exact-cast impossible-success preservation

Exact casts to uninstantiated types cannot simply retarget to a live child in TNH, because that would create new success cases.
So they become bottom or null-only checks instead.

### 5. Descriptor/cast/allocation repair

Descriptor-aware casts and allocations are where most of the hard local rewrites live:

- nullable descriptor operands may need `ref.as_non_null`
- side-effectful child expressions may need localization into temps
- impossible `struct.new_desc` in functions becomes dropped children plus `unreachable`
- impossible `struct.new_desc` in globals becomes a null descriptor
- `ref.get_desc` can become either trap-only or a refined-cast-then-get shape

### 6. Type-copy robustness beyond plain structs

The continuation test is small but important.
It proves the shared type-rewrite machinery can copy rec groups containing:

- a continuation type referring to a function type
- plus an optimized-away unused struct type

without scrambling the continuation/function link.

## What is easy to misunderstand

### Misunderstanding 1: “abstract” means “no runtime values at all”

Not here.
A type can be abstract in the direct-creation sense and still have live runtime subtypes.
That is why the pass distinguishes:

- `createdTypes`
- `createdTypesOrSubTypes`

### Misunderstanding 2: TNH is required for all optimizations

Not true.
TNH is only required for refining an abstract parent to a specific live child.
The simpler rewrite of a fully never-created family to bottom happens without TNH.

### Misunderstanding 3: the pass rewrites subtype edges too

It explicitly does **not**.
That cleanup is deferred to later `unsubtyping`.

### Misunderstanding 4: exact casts are just stricter ordinary casts

The exact-cast lit files show the opposite teaching point:

- exact impossible casts are dangerous to refine to a live child
- so the pass often makes them bottom/null checks instead

### Misunderstanding 5: `remove-unused-types` is incidental in the tests

It is not.
The main and descriptor lit files often pair:

- `--abstract-type-refining --remove-unused-types`

because the first pass rewrites uses while the second erases newly dead declarations.

## Future Starshine port invariants

A future Starshine port would need to preserve at least these invariants:

- keep the pass boundary-only / module-wide, not a local HOT peephole
- enforce the GC and hard closed-world gates
- scan creation evidence from real `struct.new*` operations, not generic mentions
- conservatively treat public types as created unless the public-boundary contract is redesigned with proof
- distinguish direct creation from “some subtype is created”
- allow parent-to-child refinement only under the same TNH-style safety assumption
- keep the struct-only scope unless arrays/functions are deliberately added with their own proof story
- preoptimize exact casts, descriptor casts, `ref.get_desc`, and `struct.new_desc` before global type rewriting
- preserve side effects and null traps when removing impossible descriptor traffic
- preserve declared subtype edges here and let a later relation-cleanup pass own them
- refinalize after rewriting

If a port implements only “map unused struct types to none” without those invariants, it will miss Binaryen's real behavior.

## Open questions and uncertainty

- The pass file has an explicit TODO for arrays and functions, and mentions `configureAll` for functions. This dossier should therefore describe current support as **struct-only**, not pretend the algorithm is already generic.
- The comments also note that some additional abstract-type cleanup might be possible without TNH if there are no relevant casts. That is an upstream idea, not current `version_129` behavior.
- I did **not** exhaustively diff every helper file on current `main`; the freshness note is intentionally limited to the core pass file, `pass.cpp`, and the dedicated lit surfaces above.

## Bottom line

Binaryen `abstract-type-refining` is really:

- **a late closed-world struct-type cleanup pass driven by creation evidence, with always-on bottomization of impossible families, TNH-only singleton-child refinement, descriptor/exact-cast preoptimization, preserved subtype edges, and final refinalization**

That is much more specific than the tiny pass summary in `pass.cpp` suggests.

## Sources

- Repo context:
  - `docs/README.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
  - `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
  - `docs/wiki/binaryen/passes/global-type-optimization/binaryen-strategy.md`
  - `docs/wiki/binaryen/passes/unsubtyping/binaryen-strategy.md`
  - `src/passes/optimize.mbt`
  - `agent-todo.md`
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/AbstractTypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/drop.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-cont.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/AbstractTypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-cont.wast>
