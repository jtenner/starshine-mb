---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./ordering-cost-model-and-boundaries.md
  - ./wat-shapes.md
  - ../reorder-globals/index.md
  - ../remove-unused-types/index.md
  - ../minimize-rec-groups/index.md
---

# `reorder-types`: Binaryen strategy

## Scheduler placement and activation

Source-confirmed scheduler facts:

- `pass.cpp` registers a public `reorder-types` pass.
- It also registers a hidden `reorder-types-for-testing` sibling.
- The pass is absent from the repo's canonical no-DWARF default optimize path.
- `ReorderTypes::run()` returns immediately without GC.
- `ReorderTypes::run()` fatally requires `--closed-world`.

So the durable scheduler conclusion is:

- treat `reorder-types` as an **explicit upstream module pass**,
- not as a current default-preset parity requirement.

## Real purpose

The pass comment in `ReorderTypes.cpp` states the goal directly:

- reorder private types within a single large recursion group to minimize cumulative type-index size throughout the module.

That makes the real contract much tighter than the old working guesswork.
The pass is optimizing binary size from heap-type indices, not performing a vague locality cleanup.

## Core algorithm

`reorder-types` is implemented as a `ReorderingTypeRewriter`, a `GlobalTypeRewriter` subclass.
The pass structure is:

### Phase 1: collect candidate types and counts

`GlobalTypeRewriter` gathers heap-type info with:

- `ModuleUtils::TypeInclusion::UsedIRTypes`
- `ModuleUtils::VisibilityHandling::FindVisibility`

This gives each used heap type:

- `useCount`
- `visibility`

Important consequence:

- only **used IR heap types** are counted for this pass
- public types are discovered and then frozen out of the reorderable set

### Phase 2: build the predecessor graph for private types

`getPrivatePredecessors()` creates one graph node per private type and adds predecessor edges for only two legality families:

- declared private supertype
- private described type

This is the exact legality contract the reorder must preserve.

### Phase 3: convert the graph to index form and seed direct counts

`ReorderingTypeRewriter::getSortedTypes(...)` maps each private type to an integer index, builds:

- an index-only successor graph
- a `counts` vector from `typeInfo[type].useCount`

So the sorting logic is over raw private-type indices, but the weights come directly from Binaryen's heap-type-use scanner.

### Phase 4: try 21 successor-weight propagation factors

The pass tries `numFactors = 21` factors from `0.0` through `1.0`.
For each factor it:

1. initializes `weights[i] = counts[i]`
2. walks the graph in successors-first order
3. adds `weights[succ] * factor` into each predecessor weight
4. runs a topological `minSort` that prefers larger weights earlier
5. computes the resulting encoded-index cost
6. keeps the cheapest order

This is the real version of the earlier dossier's vague “maybe successor-aware” story.
It is explicit and small.

### Phase 5: cost the resulting order by type-index byte width

`getCost(...)` models LEB index width by counting usable bits per byte:

- normal pass: `7`
- testing pass: `1`

It then accumulates:

- `numBytes * counts[order[i]]`

as the total layout cost.

So the objective is:

- minimize total bytes paid by all counted heap-type uses.

### Phase 6: rebuild reordered private types through `GlobalTypeRewriter`

`GlobalTypeRewriter::rebuildTypes(...)` does the heavy lifting:

- assigns new indices to the chosen private-type order
- grows a `TypeBuilder`
- places all rebuilt private output types into **one single large recursion group**
- copies and remaps each original private type into the builder
- preserves declared supertype relationships via remapped supertypes
- ensures the resulting rebuilt group is distinct from preserved public groups

This is one of the dossier's most important corrected facts:

- the pass sorts individual private types,
- but it rebuilds them inside one fresh private rec group.

## What helper files matter

### Core pass logic

- `src/passes/ReorderTypes.cpp`
  - pass gate, weight search, cost model, and best-order selection

### Pass registration

- `src/passes/pass.cpp`
  - public registration for `reorder-types`
  - hidden registration for `reorder-types-for-testing`

### Rebuild and remap engine

- `src/ir/type-updating.h`
- `src/ir/type-updating.cpp`
  - `GlobalTypeRewriter`
  - private/public split
  - predecessor construction
  - full-module remapping
  - name/index metadata repair

### Heap-type counting and visibility

- `src/ir/module-utils.h`
- `src/ir/module-utils.cpp`
  - `HeapTypeInfo`
  - `collectHeapTypeInfo(...)`
  - `UsedIRTypes` versus broader binary-type collection

### Nearby ordering-helper context

- `src/wasm-type-ordering.h`
  - not called directly by `ReorderTypes.cpp`, but useful context for neighboring type-order passes

## Real rewrite surface

After rebuilding types, `GlobalTypeRewriter::mapTypes(...)` updates:

- function signatures
- local variable types
- expression result types
- expression heap-type fields
- table types
- element segment types
- global types
- tag types

Then `mapTypeNamesAndIndices(...)` repairs:

- type names
- preserved type-index metadata

So a future port must not stop at reordering declarations.
The contract is module-wide remapping.

## Important pass interactions

### `remove-unused-types`

That pass determines which private types still exist.
`reorder-types` then decides how to lay out the surviving private types.

### `minimize-rec-groups`

That pass is about recursion-group structure.
`reorder-types` is about private-type index layout and rebuild order.
Do not merge their semantics.

### `reorder-globals`

This is the closest intuition pump:

- both are layout passes
- both optimize encoded index costs
- both must respect dependency constraints

But `reorder-types` is stricter because its dependency edges come from the heap-type graph and described-type relations.

## What is easy to misunderstand

### 1. The pass does not touch all types

Public types are intentionally frozen.
Only private types move.

### 2. The pass is not just count-sorting

It uses direct counts plus successor-propagated weights and then evaluates actual encoded-index cost.

### 3. The pass does not preserve old private rec-group structure

It rebuilds reordered private types into one large new private group.

### 4. The pass is not safe to run open-world

`--closed-world` is mandatory.

### 5. The pass is not a no-op metadata tweak

It rewrites code, declarations, locals, and type metadata across the whole module.

## Future Starshine port rules

- Keep the pass module-scoped.
- Gate it on GC, just like upstream.
- Preserve the hard `--closed-world` requirement unless the contract is deliberately widened and re-proven.
- Freeze public types.
- Build legality edges only from the same two upstream families unless a new upstream drift review shows otherwise:
  - private supertypes
  - private described types
- Implement the actual factor search and encoded-index cost model, not a naive count sort.
- Preserve the whole-module remap surface, including locals and type metadata.
- Do not silently treat this as `minimize-rec-groups` or `remove-unused-types`.

## Sources

- [`../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md`](../../../raw/research/0199-2026-04-21-reorder-types-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderTypes.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
