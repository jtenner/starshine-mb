# 0199 - Binaryen `reorder-types` source-confirmation follow-up

## Scope

- Continue the recursive Binaryen pass wiki-ing campaign after the `precompute-propagate` and `i64-to-i32-lowering` follow-ups.
- Re-read `docs/README.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`, and `agent-todo.md` before picking a pass.
- Pick exactly one eligible pass different from the excluded recent dossiers.
- Close a real remaining documentation gap using official Binaryen `version_129` sources.
- File the result back into the living `reorder-types` dossier and shared indexes.

## Candidate selection

I re-checked the required repo docs first.

At selection time:

- the main no-DWARF / saved-`-O4z` queue still had no `none` entry
- `reorder-types` was already dossier-covered, so it was only eligible if there was a real major gap
- the existing `reorder-types` folder was still explicitly marked as a **working contract** with unresolved upstream-source questions
- `agent-todo.md` still had **no dedicated `reorder-types` slice**

So this was an allowed major-gap fallback rather than a first-dossier expansion.
The specific gap was source-backed confirmation:

- the old folder still guessed at the ordering unit, profitability rule, legality edges, and helper files
- it still told future threads to do a later web-enabled confirmation pass
- it lacked a dedicated implementation/test-map page

That made `reorder-types` a legitimate target even though it already had a landing dossier.

## Sources consulted

Official Binaryen `version_129` sources:

- `src/passes/ReorderTypes.cpp`
- `src/passes/pass.cpp`
- `src/ir/type-updating.h`
- `src/ir/type-updating.cpp`
- `src/ir/module-utils.h`
- `src/ir/module-utils.cpp`
- `test/lit/passes/reorder-types.wast`
- `src/wasm-type-ordering.h` for nearby ordering-helper context

Repo-local context:

- `docs/wiki/binaryen/passes/reorder-types/`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

## What the official sources changed or confirmed

### 1. The pass is much smaller and more specific than the old working-contract dossier implied

The old dossier described `reorder-types` as a broad constrained type-layout pass with several unresolved possibilities.
The official source shows a much tighter contract:

- it only runs when `module->features.hasGC()` is true
- it hard-requires `--closed-world`
- it only reorders **private** types
- it does so through a `GlobalTypeRewriter` subclass
- it minimizes cumulative encoded type-index cost using ordinary type-use counts plus successor-propagated weights

So the real pass is not a vague general layout optimizer.
It is a small closed-world GC-only private-type reorderer.

### 2. The pass does not reorder public groups at all

`GlobalTypeRewriter` collects heap-type info with:

- `ModuleUtils::TypeInclusion::UsedIRTypes`
- `ModuleUtils::VisibilityHandling::FindVisibility`

It then treats publicly observable types as frozen.
Only private types are candidates for the predecessor graph and reorder.
That resolves one of the old dossier's biggest open questions.

### 3. The legality graph is exact and small

The predecessor graph is built only from private types, and each private type can depend on:

- its declared private supertype
- its private described type

That means the pass's legality story is not an arbitrary rec-group or whole-graph constraint soup.
It is a topological-order problem over two explicit edge families:

- supertype-before-subtype
- described-before-descriptor

### 4. The optimization unit is an individual private heap type, but rewriting happens by rebuilding all reordered private types into one new rec group

The old dossier left open whether the ordering unit was a rec group or individual types.
The source clarifies the split:

- the sort order is over individual private heap types
- the rebuild step then places all new reordered private types into **one single large recursion group**

That detail is important for a future port.
The pass is not preserving old private rec-group boundaries.
It relies on `GlobalTypeRewriter` to rebuild the reordered private types safely inside one fresh big group.

### 5. The cost model is concrete

`ReorderTypes.cpp` tries 21 factors from `0.0` through `1.0`.
For each factor it:

1. starts with direct use counts
2. propagates successor weight back into predecessors
3. performs a topological min-sort that prefers larger weights earlier
4. computes total index-encoding cost
5. keeps the cheapest resulting order

The cost model counts bytes using type-index LEB width:

- normal pass: `7` usable bits per byte
- test-only pass: `1` usable bit per byte so small tests show visible movement sooner

That means the pass is not just sorting by raw counts.
It is explicitly minimizing cumulative encoded index cost under topological constraints.

### 6. The shipped test file proves three especially important behaviors

`reorder-types.wast` makes three families explicit:

- simple count-driven reordering among unconstrained private struct types
- constraint preservation even when code size would prefer a different order
- successor weighting can break ties or overturn a plain-count intuition

It also contains a regression covering a prior mismatch between the types counted from the binary surface and the used-IR-types set collected by `GlobalTypeRewriter`.
That regression matters because it shows the pass depends on the exact `UsedIRTypes` collection contract, not just on any broader "all binary types" inventory.

### 7. The real rewrite surface is broader than just the type section

`GlobalTypeRewriter::mapTypes` and `mapTypeNamesAndIndices` update:

- function signatures
- local variable types
- expression result types and expression heap-type fields
- local.get / local.tee result typing via updated function locals
- tables
- element segment types
- globals
- tags
- type names
- preserved type indices metadata

So the pass is absolutely not just reordering printed type declarations.
The entire module's type-bearing surface is rewritten.

## Durable conclusions for the living wiki

- `reorder-types` is a **GC-only**, **closed-world-only**, **module pass**.
- It reorders only **private** heap types.
- It keeps legality via a predecessor graph containing only:
  - private declared supertypes
  - private described types
- It tries 21 successor-propagation factors and chooses the cheapest encoded-index order.
- The tested optimization objective is cumulative type-index byte cost, not vague locality.
- It sorts individual private heap types, then rebuilds them into one fresh large private rec group through `GlobalTypeRewriter`.
- Public groups stay fixed and are kept distinct from the new rebuilt private group.
- The real rewrite surface includes code, declarations, locals, type names, and preserved index metadata.
- The dedicated test pass `reorder-types-for-testing` exists specifically to exaggerate the cost model for small lit cases.
- `agent-todo.md` still has **no dedicated `reorder-types` slice**.

## Important beginner-facing corrections

### `reorder-types` is not a generic type-layout mystery anymore

The exact source-backed mental model is:

- collect used IR heap types and their visibility
- freeze public groups
- build predecessor edges for private supertypes and described types
- try several successor-weight propagation strengths
- choose the order with the smallest encoded-index cost
- rebuild and remap every affected type use

### `reorder-types` is not `remove-unused-types`

`remove-unused-types` decides what private types can disappear.
`reorder-types` keeps the surviving private types and changes their flat order.

### `reorder-types` is not `minimize-rec-groups`

`minimize-rec-groups` tries to shrink SCC structure while preserving type identity.
`reorder-types` instead rebuilds reordered private types into one fresh big private rec group.

### The old folder's public/private uncertainty is now closed

The official helper code makes the policy explicit:

- public types are not modified
- private types are the only optimization candidates

## Remaining uncertainties

This follow-up closed the major source-confirmation gap.
What remains is much smaller:

- The dossier now has enough official-source grounding to stop calling the pass a working-contract guess.
- A later thread could still compare `version_129` with current `main` for drift, but the core contract is now clear enough for implementation teaching.

## Files updated by this follow-up

- `docs/wiki/binaryen/passes/reorder-types/index.md`
- `docs/wiki/binaryen/passes/reorder-types/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-types/ordering-cost-model-and-boundaries.md`
- `docs/wiki/binaryen/passes/reorder-types/wat-shapes.md`
- `docs/wiki/binaryen/passes/reorder-types/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source links

- https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderTypes.cpp
- https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
- https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp
- https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
- https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp
- https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
- https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type-ordering.h
- https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-types.wast
