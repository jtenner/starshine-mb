# 0149 - Binaryen `remove-unused-types` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the refreshed `simplify-locals` dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is now fully dossier-covered and the campaign prompt excludes the passes already deepened there, expand into a nearby upstream-only Binaryen pass that still has no dedicated living dossier.
- Create a new beginner-friendly but source-backed dossier for `remove-unused-types`.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/remove-unused-types/`
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

- the tracker no longer had any pass with wiki status `none` in the main no-DWARF / saved-`-O4z` queue
- the implemented-landing queue was already closed
- the major-gap fallbacks named by recent tracker notes were already closed
- the campaign prompt explicitly excluded the already-dossiered parity-queue passes that older threads had just refreshed
- `agent-todo.md` had **no dedicated `remove-unused-types` slice yet**, so there was no local backlog page to reuse as a substitute for a living pass dossier

So this run needed an explicit queue-expansion pick instead of another parity-queue pick.

I picked `remove-unused-types` for five source-backed reasons:

- It is already named in the local Starshine boundary-only registry in `src/passes/optimize.mbt`, so this is not an invented upstream tangent.
- The current living `global-refining` and `global-struct-inference` docs both already mention `remove-unused-types` as a real neighbor in Binaryen's **closed-world GC/type cleanup cluster**.
- The pass still had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- The implementation is deceptively small: `RemoveUnusedTypes.cpp` looks tiny, but most of the real contract lives in helper surfaces such as `ModuleUtils::CodeScanner`, `ModuleUtils::getPublicHeapTypes`, and `GlobalTypeRewriter` in `type-updating.h`.
- That hidden helper structure creates a real beginner-teaching gap: the pass sounds like a trivial mark-and-sweep cleanup, but the official `version_129` contract is actually a closed-world GC/type-section rewrite with public/private visibility rules, rec-group preservation, and full-module heap-type remapping.

So this thread is not a tracker-status promotion of an old parity item.
It is the first explicit dossier for an upstream-only local-registry pass that sits right beside the repo's existing GC/type module-pass docs.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
- pass registration and scheduler placement:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- helper surfaces that carry most of the real behavior:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
- representative official test surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>

Narrow freshness check on current `main`:

- core pass file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedTypes.cpp>
- pass registration:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- dedicated test file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-types.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-`main` check on the most important surfaces while researching the living pages.

Durable result:

- the checked `RemoveUnusedTypes.cpp` logic on `main` still matches the tagged `version_129` pass on the important surfaces reviewed here:
  - same `optimizeLevel >= 2` gate
  - same `closedWorld` gate
  - same `hasGC()` gate
  - same `publicTypes` / `usedTypes` split
  - same private-rec-group builder loop
  - same handoff to `GlobalTypeRewriter(...).update()`
- the checked `pass.cpp` registration still exposes `remove-unused-types`
- the checked dedicated `remove-unused-types.wast` file still matches on the reviewed surfaces

That is intentionally a **narrow** freshness statement, not a whole-repo equivalence proof.
The durable wiki rule should be:

- use `version_129` as the normative algorithm oracle
- record later upstream drift explicitly if it matters
- do not invent a semantic drift story when the checked current surfaces still match the tag

## Repo-local sources used for context

Starshine-side files that mattered while choosing and framing this dossier:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

Important local context conclusion:

- the current open-world no-DWARF page does **not** run `remove-unused-types`
- but the local docs already record it as a real **closed-world** Binaryen neighbor around `global-refining` and `gsi`
- the local registry already tracks it as a boundary-only pass name
- the living pass map and tracker had not yet given it a dedicated dossier home

## High-level conclusion

Binaryen `remove-unused-types` is not a generic dead-code pass and not a second copy of `remove-unused-module-elements`.

The real `version_129` contract is:

1. only run in **closed-world**, GC-enabled, optimizing module contexts
2. keep all externally visible heap types (`publicTypes`) stable
3. scan module code and declaration-level type uses to find heap types that are actually referenced (`usedTypes`)
4. subtract the public set so only **used private types** remain as rewrite candidates
5. copy the rec groups of those used private types into a new type builder in original order
6. ask `GlobalTypeRewriter` to rebuild the module's heap-type graph and rewrite every remaining use to the new type indices / groups

So the pass is best described as:

- **closed-world private heap-type GC plus full-module type-section rewriting**

The two biggest beginner corrections are:

- it does **not** run on the repo's main open-world no-DWARF optimize path
- it does **not** delete one heap type at a time; rec groups and public-type visibility rules dominate the real behavior

## Phase-by-phase reading of the official implementation

## Phase 0: very strict gates

`RemoveUnusedTypes::run(Module* module)` begins with three early no-op gates:

- `optimizeLevel < 2` -> return immediately
- `!module->closedWorld` -> return immediately
- `!module->features.hasGC()` -> return immediately

That already teaches three important things:

- the pass is considered an optimization pass, not just a canonical cleanup
- the pass depends on closed-world reasoning
- the pass is specifically about the GC/type-section world, not old MVP-only modules

This is why the pass does not appear on the repo's open-world no-DWARF orientation page.

## Phase 1: Binaryen keeps public heap types first

The next important line is:

- `auto publicTypes = ModuleUtils::getPublicHeapTypes(*module);`

This is the pass's first real semantic move.

Before looking for removable types, Binaryen asks:

- which heap types are externally visible and therefore not safe to disappear or be silently made more specific?

`module-utils.h` shows that `getPublicHeapTypes` is built on `collectHeapTypeInfo(...)` and returns the heap types whose visibility is marked `public_`.

That means the pass is intentionally **visibility-aware**.
It is not just scanning for internal references.

Beginner-friendly translation:

- if outside code could still name or observe a type, Binaryen keeps that type stable first and only then cleans up private leftovers

## Phase 2: `usedTypes` is discovered by scanning module code and declaration-level types

`RemoveUnusedTypes.cpp` then constructs a small scanner:

- `struct UsedTypeScanner : public ModuleUtils::CodeScanner`

Its only special behavior is:

- whenever it sees a `Type` that is a ref type, it inserts `type.getHeapType()` into `usedTypes`

Then Binaryen runs:

- `ModuleUtils::iterModuleCode(*module, scanner);`

The important detail is not the tiny override.
The important detail is what `ModuleUtils::CodeScanner` already visits for it.

`module-utils.h` shows that the shared scanner walks things such as:

- function signatures
- global declaration types and init expressions
- tag types
- table types, addresses, and tuple entries
- element segment items and offsets
- expression result types while walking code
- field types inside heap types

So `usedTypes` is broader than:

- "types mentioned directly by instructions in function bodies"

It includes declaration-level and initializer-level type uses that matter for the module's remaining meaning.

## Phase 3: public types stay; only private used types get rebuilt

After scanning, the pass does:

- `usedTypes.erase(publicTypes.begin(), publicTypes.end());`

This is a very small line with a very large meaning.

After this point, `usedTypes` no longer means:

- every used type in the module

It means:

- every **used private** type in the module

Public types still matter, but they are tracked separately because they are already guaranteed to survive.

That split is the real heart of the pass.

## Phase 4: used private types keep their whole rec groups

The next block builds a fresh type builder:

- `Builder newTypeBuilder(*module);`
- `std::unordered_set<HeapType> seen;`

Then for each `type` in the module's original type order:

- if the type is not in `usedTypes`, skip it
- if that type was already copied through an earlier group member, skip it
- otherwise iterate its `type.getRecGroup()` and copy **every member of that old rec group** into `newTypeBuilder`

This means a used private type does **not** keep only itself.
It keeps the whole private recursive group that defines its meaning.

That is why the pass is not a simple per-node delete pass.

The smallest correct beginner rule is:

- a live private member keeps its entire rec group alive

## Phase 5: `GlobalTypeRewriter` does the real rewrite work

The last line of the pass body is:

- `GlobalTypeRewriter(*module, usedTypes, std::move(newTypeBuilder), publicTypes).update();`

That is where most of the real behavior lives.

`RemoveUnusedTypes.cpp` is mostly an orchestrator.
`GlobalTypeRewriter` in `type-updating.h` carries the hard contract.

### What `GlobalTypeRewriter` is told

The constructor receives four critical inputs:

- the original module
- `usedTypes` = used private types only
- `builder` = freshly copied rec groups for those private types
- `publicTypes` = externally visible types that must stay stable

### What `update()` then does

The helper walks the old type section in original order and rebuilds a new mapping from old heap types to new heap types.

Important rules visible in the source:

- public types are kept in place as the anchor of the current rewritten group
- used private groups are inserted only when needed
- if the current old group contains public types, rewritten private types are merged around that live public group carefully rather than arbitrarily reordered
- if a private group is unused, it is simply not copied into the new builder
- the helper then rewrites module references to the new heap-type mapping and replaces the module's type section

This is why the pass is safe to describe as a **type-section rewriter**, not merely a type filter.

## Phase 6: the helper has a subtle public/private group rule

The most educational comment in `type-updating.h` is inside `update()`:

- public types must retain their original group structure
- when a rewritten private type is a subtype of a public type, the helper tries to place it into the current public group if that is the right rewritten group
- but it avoids copying unrelated private groups into a live public group unnecessarily

In beginner terms:

- Binaryen keeps public group identity stable first
- then threads needed private rewritten groups around that public structure as narrowly as possible

That is a much more constrained algorithm than:

- "delete unused private groups and renumber everything densely"

## Phase 7: why the pass is closed-world only

`GlobalTypeRewriter` contains comments that make the closed-world dependency explicit.

The helper says, in effect:

- in open world, Binaryen cannot assume more-specific public subtype relations are safe to expose externally
- current public-type handling is intentionally conservative and partial
- the long-term story would need better public/private subtype-group reasoning than this helper currently implements

That source-backed limitation explains the hard `!module->closedWorld` early exit in `RemoveUnusedTypes.cpp`.

So the correct beginner summary is:

- this pass needs closed world not because Binaryen forgot to generalize it, but because public type identity and subtype exposure are part of the correctness boundary

## Phase 8: no dedicated `ReFinalize` step is needed here

Unlike many AST-walking hot passes, `remove-unused-types` does **not** call `ReFinalize`.

That is not an omission.
It reflects the fact that the pass works at the module type-section layer through `GlobalTypeRewriter`, which directly updates heap-type references throughout the module as part of the rewrite.

So the postcondition is maintained by the helper itself, not by a separate later function-body repair pass.

## Scheduler meaning

`pass.cpp` registers the pass summary as:

- `remove unused types`

The more important source fact is its placement.

In the closed-world default-optimization pipeline around the repo's existing GC/type dossiers, Binaryen runs a broader cluster such as:

- before `global-refining`:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
- after `global-refining`:
  - optional `global-type-optimization`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

That placement matters.

`remove-unused-types` is not a random late cleanup.
It is part of a **closed-world GC/type tightening cluster** where earlier passes simplify and shrink global/type structure, then `remove-unused-types` trims now-dead private heap types, then later passes like `gsi` and post-GSI type cleanups operate on the leaner type graph.

## What the pass sounds like versus what it actually does

What it sounds like:

- drop heap types that are never referenced

What it actually is in `version_129`:

- a closed-world, GC-only module pass that:
  - preserves public heap types first
  - scans module code and declaration-level type uses
  - identifies used **private** heap types
  - keeps whole rec groups for those private types
  - rewrites the module's heap-type graph with `GlobalTypeRewriter`
  - updates every surviving type use consistently

That is a much more teachable and much more precise contract.

## Biggest beginner corrections

### 1. `remove-unused-types` is not `remove-unused-module-elements`

`remove-unused-module-elements` removes dead module declarations such as functions, globals, tags, memories, tables, elem segments, and data segments.

`remove-unused-types` works one layer lower:

- it rewrites the **type section** and heap-type graph after the declaration set has already changed

### 2. The pass is not about open-world `-O` / `-Os`

The repo's main no-DWARF page is open-world.
This pass is not there.

So a future Starshine port should not silently smuggle `remove-unused-types` into that open-world story.

### 3. It does not keep or drop one type at a time

The real unit is often the **rec group**, not an individual type.

### 4. Public visibility is not the same as actual in-module use

A public type may stay even when no remaining local code mentions it, because the external boundary still matters.

### 5. The tiny pass file is not the whole algorithm

The hard logic lives in helpers:

- `ModuleUtils::CodeScanner`
- `ModuleUtils::getPublicHeapTypes`
- `GlobalTypeRewriter`

Any future port that ignores those helpers will misunderstand the pass.

## Porting implications for Starshine

A future Starshine implementation would need at least:

- a real notion of public versus private heap-type visibility
- a module-wide scanner that sees declaration-level and code-level heap-type uses, not just function-body instructions
- rec-group-aware type retention
- a whole-module heap-type rewrite helper comparable to `GlobalTypeRewriter`
- an explicit closed-world gate

The pass is therefore a **boundary-only type-system pass**, not a straightforward HOT pass.
That matches the current local registry categorization.

## Living-page deltas filed from this note

This research should land as:

- a new `docs/wiki/binaryen/passes/remove-unused-types/` folder with:
  - landing page
  - Binaryen strategy page
  - implementation/test map
  - focused public/private + rec-group page
  - WAT-shape catalog
- tracker/index/log updates that make `remove-unused-types` a first-class campaign target instead of a name only mentioned in neighboring dossiers

## Sources

Official Binaryen sources:

- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedTypes.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-types.wast>

Repo-local sources:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`
