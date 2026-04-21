---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-visibility-and-rec-group-rewrite.md
  - ./wat-shapes.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
---

# Binaryen `remove-unused-types` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass.

Primary files:

- `src/passes/RemoveUnusedTypes.cpp`
- `src/passes/pass.cpp`
- `src/ir/type-updating.h`
- `src/ir/module-utils.h`
- `test/lit/passes/remove-unused-types.wast`

I also did a narrow current-`main` check on the same surfaces.
Durable result:

- the checked `main` pass file still matches the reviewed `version_129` logic on the important gates and rewrite structure
- the checked dedicated lit file still matches on the reviewed surfaces

So this dossier treats `version_129` as the normative algorithm oracle.

## High-level intent

Binaryen uses `remove-unused-types` to shrink the heap-type graph of a **closed-world GC module** after earlier module cleanup and refinement passes have made some private types unnecessary.

That is more precise than either of these summaries:

- remove dead types
- type-section DCE

The real pass is closer to:

- **keep public heap types stable, keep used private rec groups, then rewrite the whole module to the new type graph**

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Gate on mode/features | Require `optimizeLevel >= 2`, `closedWorld`, and GC | Open-world ABI visibility and non-GC modules are outside the pass contract |
| Seed public types | `ModuleUtils::getPublicHeapTypes(*module)` | Externally visible heap types must not disappear or be silently tightened away |
| Scan uses | `ModuleUtils::iterModuleCode(*module, scanner)` | Find heap types still referenced by declarations, initializers, and code |
| Separate public from private | `usedTypes.erase(publicTypes...)` | Only private used types need to be copied into the new private builder |
| Build live private groups | Copy each used private type's whole old rec group once | Rec groups are the real retention unit, not isolated heap types |
| Rewrite module | `GlobalTypeRewriter(...).update()` | Rebuild the type section and rewrite every remaining heap-type use consistently |

## Phase 0: strict gatekeeping is part of the meaning

`RemoveUnusedTypes::run(Module* module)` returns immediately when any of these are true:

- `optimizeLevel < 2`
- `!module->closedWorld`
- `!module->features.hasGC()`

Those early exits are not incidental.
They tell us the intended scope:

- this is an optimization pass, not always-on canonical cleanup
- it is fundamentally a **closed-world** pass
- it only matters for modules with GC heap types

That is why the repo's main open-world no-DWARF page does not include it.

## Phase 1: Binaryen protects public heap types first

The first substantive line is:

- `auto publicTypes = ModuleUtils::getPublicHeapTypes(*module);`

`module-utils.h` shows that `getPublicHeapTypes` is built on `collectHeapTypeInfo(...)` and returns the heap types whose visibility is `public_`.

The key beginner point is:

- `remove-unused-types` does not begin by asking what is unused
- it begins by asking what must remain externally stable

That means public visibility is a **correctness boundary**, not just a profitability hint.

## Phase 2: `ModuleUtils::CodeScanner` makes the use scan broader than it first appears

The pass defines a tiny scanner:

- `struct UsedTypeScanner : public ModuleUtils::CodeScanner`

The override is small:

- when a `Type` is a ref type, insert `type.getHeapType()` into `usedTypes`

The important thing is what the inherited scanner already visits.
`module-utils.h` shows that `CodeScanner` covers things such as:

- function signatures
- global declaration types and global init expressions
- tag types
- table types, addresses, and tuple entries
- element segment items and offsets
- expression result types while walking code
- field types inside heap-type definitions

So `usedTypes` means more than:

- heap types mentioned by instructions in function bodies

It also includes declaration-level and initializer-level type uses that still matter to the module.

## Phase 3: public types are removed from the private worklist

After scanning, the pass does:

- `usedTypes.erase(publicTypes.begin(), publicTypes.end());`

That one line is easy to skim past, but it is central.

After it runs:

- `publicTypes` = externally visible heap types that stay because of visibility
- `usedTypes` = heap types that are still used **and private**

So the pass is not trying to rebuild every used type.
It is trying to rebuild only the used **private** portion of the heap-type graph while preserving public types separately.

## Phase 4: used private types keep whole rec groups

The next block constructs:

- `Builder newTypeBuilder(*module);`
- `std::unordered_set<HeapType> seen;`

Then Binaryen iterates the old module type order.
For each old heap type:

- if it is not in `usedTypes`, skip it
- if it is already in `seen`, skip it
- otherwise iterate `type.getRecGroup()` and copy every member of that old rec group into `newTypeBuilder`

This is the pass's most important structural rule.

A live private type does **not** keep only itself.
It keeps its whole recursive group.

That is why the pass is rec-group-aware type GC, not isolated node deletion.

## Phase 5: `GlobalTypeRewriter` carries the real rewrite contract

The final line of the pass body is:

- `GlobalTypeRewriter(*module, usedTypes, std::move(newTypeBuilder), publicTypes).update();`

That is where most of the real work lives.

### What the helper receives

`GlobalTypeRewriter` gets:

- the original module
- the set of used private types
- the builder containing the copied live private rec groups
- the set of public types

### What `update()` then does

Reading `type-updating.h`, the helper:

1. walks the old type section in original order
2. preserves public groups as anchors
3. injects rewritten private groups only when they are actually needed
4. avoids copying unrelated private groups into live public groups unnecessarily
5. builds the old-to-new heap-type mapping
6. rewrites heap-type uses throughout the module to the new mapping
7. installs the rewritten type section

So the pass is accurately described as a **whole-module type-section rewrite**.

## Phase 6: public-group handling is deliberately conservative

The key source comment in `type-updating.h` says, in effect:

- if the current old group is public, keep that public structure intact
- if the current rewritten private type belongs in that public group, add it there
- otherwise do not drag extra private groups into the public group for no reason

This explains why the pass stays closed-world-only.

A beginner-friendly summary is:

- Binaryen will tighten the private type graph around public groups,
- but it will not freely reshape public group structure just because some internal types disappeared

## Phase 7: the closed-world requirement is explained by the helper comments too

`GlobalTypeRewriter` contains TODO comments about public type handling that are very revealing.
The helper explicitly warns that in open world:

- it cannot assume that making public subtype relations more specific is okay
- public/private subtype-group placement has to respect external visibility guarantees

So the `!module->closedWorld` early exit is not arbitrary.
It is the honest boundary of the current correctness proof.

## Scheduler placement explains why this pass exists

The repo's main no-DWARF page is open-world, so it does not mention `remove-unused-types`.

But neighboring living docs already record the closed-world cluster where it belongs.
In the closed-world Binaryen module pipeline around the repo's existing GC/type dossiers, Binaryen can run a neighborhood like:

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

That placement makes sense once the pass is understood correctly.
It is not generic late cleanup.
It is part of a **closed-world GC/type tightening cluster**.

## What the pass sounds like versus what it actually is

What it sounds like:

- a tiny dead-type sweep

What it actually is:

- a closed-world, GC-aware module rewrite with:
  - public/private heap-type visibility handling
  - declaration-level and code-level use scanning
  - rec-group retention rules
  - full-module heap-type remapping

That is the behavior a future Starshine port would need to preserve.

## Bottom line

Binaryen `remove-unused-types` in `version_129` is a small file wrapped around a larger helper contract:

- keep public types
- find used private types
- keep their rec groups
- rewrite the module's remaining heap-type graph consistently

The name makes it sound smaller and flatter than it really is.
The source says otherwise.

## Sources

- [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-types.wast>
