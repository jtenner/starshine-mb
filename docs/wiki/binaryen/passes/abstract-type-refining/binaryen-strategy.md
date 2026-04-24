---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md
  - ../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./traps-never-happen-exact-casts-and-descriptors.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `abstract-type-refining` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass, anchored by the immutable 2026-04-24 raw manifest in [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md).

Primary files:

- `src/passes/AbstractTypeRefining.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies visible in the implementation:

- `SubTypes` in `src/ir/subtypes.h`
- `ModuleUtils::ParallelFunctionAnalysis`
- `ModuleUtils::getPublicHeapTypes(...)`
- `TypeMapper`
- `ChildLocalizer`
- `getDroppedChildrenAndAppend(...)`
- `ReFinalize`

The shipped lit surface is also part of the contract:

- `test/lit/passes/abstract-type-refining.wast`
- `test/lit/passes/abstract-type-refining-desc.wast`
- `test/lit/passes/abstract-type-refining-exact.wast`
- `test/lit/passes/abstract-type-refining-tnh-exact-casts.wast`
- `test/lit/passes/abstract-type-refining-cont.wast`

## High-level intent

Binaryen uses `abstract-type-refining` to rewrite some never-created **struct** heap types to something more precise.

That sounds simple, but the real contract has two different refinement modes.

1. In **all** modes, if a struct type and all its subtypes are never created, the pass can rewrite that family to bottom.
2. Only in `--traps-never-happen` mode, if an abstract parent has exactly one still-relevant child branch, the pass can rewrite uses of the parent to that unique child.

Then, before shared type rewriting runs, the pass repairs descriptor and exact-cast shapes that would otherwise become invalid or behavior-changing.

That is why this is a module pass even though much of the visible evidence comes from local WAT shapes.

## Where the pass runs

In `pass.cpp`, Binaryen registers the pass under the CLI name:

- `abstract-type-refining`

### Open-world no-DWARF path relevant to this repo

For the canonical MoonBit debug-artifact path, `abstract-type-refining` is **absent**.

The open-world path still ends its GC prepass cluster at:

- `... -> global-refining -> remove-unused-module-elements -> gsi`

So the repo's main no-DWARF orientation page should continue to omit `abstract-type-refining`.

### Closed-world Binaryen path

When Binaryen runs in closed world, the neighborhood grows:

- before `abstract-type-refining`:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
  - `global-refining`
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
- then:
  - `abstract-type-refining`
- then:
  - `unsubtyping`

That means `abstract-type-refining` is the **late creation-evidence cleanup step in the closed-world GC/type cluster**, not an early type-inference pass.

## Phase 0: hard GC + closed-world gates

`AbstractTypeRefining::run(Module* module)` begins by returning immediately when:

- `!module->features.hasGC()`

and then throws a fatal error when:

- `!getPassOptions().closedWorld`

This is one of the most important differences from the open-world parity path.
The pass body itself insists on closed-world mode.

## Phase 1: collect directly created struct types

The pass uses a tiny `NewFinder` walker.
Its rule is much narrower than the name “created types” might suggest.

### `NewFinder`

The only creation evidence gathered here is:

- `visitStructNew(StructNew* curr)`

So today:

- `struct.new*` counts
- arrays do not count
- function and continuation types do not count
- plain references and casts do not count

### Scan scope

The scan runs in two places:

1. `NewFinder(createdTypes).walkModuleCode(module)`
   - module code such as globals and other module-level expressions
2. `ModuleUtils::ParallelFunctionAnalysis<Types>`
   - non-imported function bodies in parallel

The results are unioned into:

- `createdTypes`

This is the first big beginner correction in the whole pass:

- “created” means **actually allocated by `struct.new*`**, not just mentioned in a type position.

## Phase 2: public types are conservatively treated as created

Before any subtype reasoning, the pass inserts every public heap type from:

- `ModuleUtils::getPublicHeapTypes(*module)`

into `createdTypes`.

The source comment is explicit that this is conservative.
Even in closed world, the pass does not currently try to prove such types are absent externally.

So public visibility is a real optimization fence here.

## Phase 3: compute `createdTypesOrSubTypes`

The pass builds:

- `SubTypes subTypes(*module)`

and then derives:

- `createdTypesOrSubTypes`

by propagating created-type relevance upward through the declared subtype tree.

This means a type is treated as still-runtime-relevant when:

- it is created itself, or
- one of its descendants is created

That difference from `createdTypes` matters a lot.
A parent may be abstract in the direct-creation sense but still not be safe to collapse to bottom.

## Phase 4: TNH-only abstract-parent refinement

If `getPassOptions().trapsNeverHappen` is enabled, the pass runs:

- `computeAbstractTypes(subTypes)`

This phase computes:

- `abstractTypes`
  - all collected types that are **not** directly created

Then, in subtype-first order, it tries to find a unique child target for each abstract type.

### Case 1: exactly one immediate subtype

If an abstract type has one immediate child, the pass can refine it to that child.

### Case 2: several immediate subtypes, but only one relevant child

If there are several immediate children, the pass still accepts refinement when exactly one child is in `createdTypesOrSubTypes`.

That lets Binaryen refine “abstract but branching on paper” parents when only one live branch still matters at runtime.

### Case 3: chained refinement

If the chosen child is itself refinable, the pass propagates that deeper result.
So chains like:

- `$A :> $B :> $C`

can refine all the way from `$A` to `$C` in TNH mode.

### Why TNH matters

Without TNH, Binaryen does **not** assume failing casts and impossible checks can simply disappear or become narrower success-only operations.
So this whole abstract-parent-to-child refinement phase is disabled outside TNH.

## Phase 5: build the actual type mapping

`optimize(module, subTypes)` creates a `TypeMapper::TypeUpdates mapping`.

For each collected type:

- if it is not a struct type, skip it
- if neither it nor any subtype is created, map it to `type.getBottom()`
- otherwise, if TNH found a unique child refinement, map it to that child

This loop encodes three major boundaries.

### Boundary 1: struct-only today

The file has an explicit TODO for arrays and functions.
So the current implementation is deliberately **struct-only**.

### Boundary 2: bottomization is broader than TNH refinement

The pass bottomizes fully never-created families even without TNH.
That is why many official non-TNH examples still end up with:

- `ref none`
- `nullref`
- shared-bottom equivalents

### Boundary 3: use rewriting is broader than cast rewriting

The mapping is later applied to all type uses, not just cast instructions.
That is why locals, results, globals, and continuation-containing rec groups can all change.

## Phase 6: preoptimize custom-descriptor and exact-cast shapes

If the module does not use custom descriptors, the pass skips `preoptimize(...)`.

Otherwise it runs a `Preoptimizer` walker in both:

- function bodies
- module code

This is one of the hardest parts of the pass.
It exists because blindly rewriting types first would leave several shapes invalid or behavior-changing.

### 6A. `visitRefCast(RefCast* curr)`

Two families matter here.

#### Exact casts to optimized types

If the cast target is exact and the heap type is being optimized, the pass rewrites it to the optimized target's bottom while preserving nullability.

The reason is subtle but crucial:

- refining an exact cast from never-instantiated `$A` to live child `$B` could incorrectly make the cast start succeeding

So impossible exact casts become **bottom/null checks**, not more specific live-child checks.

#### Descriptor casts whose descriptor side goes to bottom

If the cast has a descriptor operand and the optimized target goes to bottom, the pass also rewrites to a bottom/null cast.
When the descriptor operand might null-trap and TNH is **not** enabled, it first wraps the descriptor in:

- `ref.as_non_null`

and uses `ChildLocalizer` to preserve evaluation order while removing the descriptor child afterward.

### 6B. `visitRefGetDesc(RefGetDesc* curr)`

If the fetched descriptor type is optimized, the pass cannot just rely on later type rewriting.
It must repair the operation first.

There are two main cases.

#### Exact or impossible descriptor fetch

If the query is exact, or the optimized descriptor has no useful live subtype path, the pass replaces it with:

- drop the input ref
- then `unreachable`

#### Inexact descriptor fetch with a live refined subtype

If an inexact input might still contain a live subtype, the pass inserts a `ref.cast` to the refined described type so the rewritten `ref.get_desc` still validates and only succeeds on the surviving runtime family.

### 6C. `visitBrOn(BrOn* curr)`

For `br_on_cast_desc_eq` and `br_on_cast_desc_eq_fail`, the pass applies the same bottom/null-target rewrite logic as for descriptor casts.

If a descriptor operand must be removed, it again localizes side effects and, when needed outside TNH, inserts `ref.as_non_null` on nullable descriptor operands.

The pass also rewrites:

- `BrOnCastDescEq` -> `BrOnCast`
- `BrOnCastDescEqFail` -> `BrOnCastFail`

when the descriptor operand disappears.

### 6D. `visitStructNew(StructNew* curr)`

If a `struct.new_desc` uses a descriptor type that is being optimized away, the allocation cannot remain as-is.

#### Function context

In a function body, the pass replaces the allocation with:

- dropped children preserving side effects
- then `unreachable`

using `getDroppedChildrenAndAppend(...)`.

#### Module/global context

Outside functions, locals and blocks are unavailable.
So the pass replaces the descriptor operand with:

- `ref.null none`

That preserves the right module-level semantics without introducing illegal structure.

## Phase 7: rewrite types, but preserve declared supertypes

After preoptimization, the pass uses a custom `TypeMapper` subclass.
The critical override is:

- `getDeclaredSuperType(...) { return oldType.getDeclaredSuperType(); }`

That one line is the source-backed reason the pass does **not** do full subtype-graph cleanup.

The file comment is explicit that changing subtype relationships safely is nontrivial and is left for:

- `unsubtyping`

So the right teaching model is:

- rewrite type uses now
- minimize subtype edges later

## Phase 8: refinalization

Finally, the pass runs:

- `ReFinalize()`

This is mandatory, not decorative.
After the rewrite:

- cast result types can change
- locals and function signatures may have new ref types
- branch/block result types may sharpen or collapse
- descriptor-related operations may need shared IR repair

A future port must preserve this step.

## What the pass does **not** do

Binaryen `abstract-type-refining` in `version_129` does **not** do any of these:

- it does not run in open world
- it does not optimize without GC
- it does not currently optimize arrays
- it does not currently optimize function or continuation heap types directly
- it does not rewrite declared subtype edges
- it does not replace `unsubtyping`
- it does not require TNH for bottomization of fully never-created struct families
- it does not make every newly dead type declaration disappear by itself; many visible shrink results rely on pairing with `remove-unused-types`

Those boundaries are just as important as the positive rewrites.

## What the pass sounds like versus what it actually is

What it sounds like:

- a declaration merge pass for abstract types

What it actually is in `version_129`:

- a closed-world struct-only module pass with creation scanning, created-subtype propagation, TNH-only singleton-child refinement, always-on bottomization, descriptor/exact-cast preoptimization, use-site type rewriting that preserves declared supertypes, and final refinalization.

That is the behavior a future Starshine port would need to preserve.

## Bottom line

Binaryen `abstract-type-refining` is really:

- **creation-evidence-based struct-type rewriting with a sharp split between always-on bottomization, TNH-only child refinement, and later separate subtype-edge cleanup**

The public one-line summary in `pass.cpp` hides that entire story.

## Sources

- [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md)
- [`../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md`](../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/AbstractTypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/drop.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-cont.wast>
