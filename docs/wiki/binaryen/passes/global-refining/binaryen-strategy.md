---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
related:
  - ./index.md
  - ./exports-public-types-and-retagging.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `global-refining` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/GlobalRefining.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies visible in the implementation:

- `ModuleUtils::ParallelFunctionAnalysis`
- `FindAll<GlobalSet>`
- `LUBFinder`
- `ExportUtils::getExportedGlobals(...)`
- `PublicTypeValidator`
- `ReFinalize`
- `WalkerPass<PostWalker<...>>`
- `runOnModuleCode(...)` from `pass.h`

The shipped lit surface is also part of the contract:

- `test/lit/passes/global-refining.wast`

## High-level intent

Binaryen uses `global-refining` to tighten the declared types of globals when the module's own writes prove a narrower type is always enough.

But the real contract is narrower than the pass name sounds.

The pass only stays correct because it preserves all of these at once:

1. the global is a defined ref-typed global that the pass is allowed to edit
2. the new type is the least upper bound of the initializer and every observed assigned value
3. the new type is a subtype of the old declaration type
4. exported-boundary rules are respected in open and closed world
5. every cached `global.get` result type is updated afterward
6. changed code is refinalized so outer expression types stay correct

That is why this is a module pass even though the core analysis is very small.

## Where the pass runs

In `pass.cpp`, the default no-DWARF global-prepass builder inserts `global-refining` only when:

- `wasm->features.hasGC()`
- and `options.optimizeLevel >= 2`

### Open-world no-DWARF path relevant to this repo

For the canonical MoonBit debug-artifact path, the meaningful neighborhood is:

- `... -> once-reduction -> global-refining -> remove-unused-module-elements -> gsi -> ...`

That is the simple open-world shape recorded in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`.

### Closed-world Binaryen path

When Binaryen runs in closed world, the neighborhood grows:

- before `global-refining`:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
- after `global-refining`:
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

That means `global-refining` is an early member of the broader GC/type-tightening cluster, not a late cleanup pass.

## Phase 0: early GC gate

`GlobalRefining::run(Module* module)` begins by returning immediately when:

- `!module->features.hasGC()`

This is a real semantic gate, not just scheduler trivia.
The official implementation does not attempt to reason about global type tightening unless the GC feature surface is enabled.

## Phase 1: collect `global.set` nodes in parallel

Binaryen first defines a tiny per-function summary type:

- `GlobalInfo { std::vector<GlobalSet*> sets; }`

Then it runs:

- `ModuleUtils::ParallelFunctionAnalysis<GlobalInfo>`

over the module.

For each defined function it simply does:

- `FindAll<GlobalSet>(func->body).list`

Important negative fact:

- this is not CFG analysis
- this is not dominance analysis
- this is not effects analysis
- this is not whole-tree use-def analysis

The pass only needs the types of assigned values, so it cheaply collects the `GlobalSet` nodes and stops there.

## Phase 2: build a per-global `LUBFinder`

After the parallel scan, Binaryen folds every discovered assigned value type into:

- `std::unordered_map<Name, LUBFinder> lubs;`

For each collected set it runs:

- `lubs[set->name].note(set->value->type);`

`LUBFinder` itself is extremely small:

- it stores one current type, initialized to `Type::unreachable`
- `note(type)` replaces that with `Type::getLeastUpperBound(current, type)`
- `noted()` just asks whether the type is still `unreachable`

So the main type aggregation story is literally:

- “initializer type plus every write value type, combined through `getLeastUpperBound`.”

## Phase 3: establish which globals are unoptimizable at the boundary

This is the hardest part to remember correctly.

Binaryen collects:

- `exportedGlobalsVec = ExportUtils::getExportedGlobals(*module)`
- a matching `exportedGlobals` set for fast membership checks
- an `unoptimizable` name set

Then for each exported global it inserts the name into `unoptimizable` when:

- `getPassOptions().closedWorld`
- **or** `global->mutable_`

That means:

### Private globals

- eligible for refinement

### Imported globals

- never eligible later in the main loop

### Open-world exported mutable globals

- immediately disqualified

### Open-world exported immutable globals

- still potentially eligible
- but only if the refined type is still public

### Closed-world exported globals

- all currently disqualified in official `version_129`
- even immutable ones

The code comment explicitly says Binaryen could in theory refine closed-world exports to still-public types later, but the current implementation does not.

## Phase 4: for each candidate global, note the initializer too

For each module global not ruled out as imported or unoptimizable, Binaryen looks up the per-global `LUBFinder` and does:

- `lub.note(global->init->type);`

This is a very important contract.
The refined type must cover:

- the initializer
- every later assigned value

If no useful type was ever noted:

- `if (!lub.noted()) continue;`

If the new LUB equals the old declaration type:

- skip as a no-op

## Phase 5: public-type legality for the remaining exported immutable globals

If the global is exported and the candidate refined type is not a valid public type, Binaryen refuses the refinement:

- `if (exportedGlobals.contains(global.get()) && !publicTypeValidator.isValidPublicType(newType)) continue;`

This check only matters for the open-world immutable-export case, because the earlier `unoptimizable` filter already removed:

- all closed-world exports
- all exported mutable globals

`PublicTypeValidator` gives two especially important rules for this pass:

- basic public types are allowed
- exact ref types are not public when custom descriptors are off

That is why an immutable exported `(ref null func)` global can refine to `nullfuncref`, but not to a private exact subtype just because the writes all point at one exact function type.

## Phase 6: rewrite the global declaration

When a candidate passes all checks, Binaryen does the actual declaration change:

- assert `Type::isSubType(newType, oldType)`
- `global->type = newType`
- remember `optimized = true`

That is the whole direct data mutation on the declaration side.

Important negative fact:

- there is no dedicated `global.set` rewrite step here
- there is no constant replacement of `global.get`
- there is no user rewriting beyond cached type repair afterward

## Phase 7: retag `global.get` and refinalize changed code

If no global declaration changed, the pass returns.
Otherwise it launches a nested walker pass named `GetUpdater`.

`GetUpdater`:

- is function-parallel
- also overrides `requiresNonNullableLocalFixups() = false`
- visits `GlobalGet`
- compares the cached node type against the current global declaration type
- rewrites the cached type when they differ
- sets `modified = true`
- refinalizes changed functions in `visitFunction(...)`

Then Binaryen runs it in two ways:

- `updater.run(getPassRunner(), module);`
- `updater.runOnModuleCode(getPassRunner(), module);`

That second call is the big beginner trap.
This pass must not update only function bodies.
It also needs to revisit module code such as other global initializers that contain `global.get`.

## Why `runOnModuleCode(...)` matters so much

The dedicated lit file includes a case where:

- global `$a` refines to a narrower exact function-ref type
- another global `$b` is initialized by `(global.get $a)`

If Binaryen changed `$a`'s declaration without repairing the cached `global.get $a` type in `$b`'s initializer, the module could become invalid.

That is why `global-refining` is not just “change the global declarations and stop.”
The retagging step is part of the pass contract.

## What this pass does **not** do

These non-goals are worth keeping explicit:

- no flow-sensitive reasoning about which writes can reach which reads
- no dominance or path-intersection reasoning
- no effect analysis
- no liveness analysis
- no dead `global.set` elimination
- no `global.get` constant folding
- no field-value inference like `gsi`
- no imported-global refinement
- no exported mutable refinement in open world
- no exported refinement at all in closed world today

## Why the official tests matter so much

The real contract is easiest to understand once you see the lit coverage Binaryen ships.
The dedicated `global-refining.wast` file covers:

- init-only null-ref narrowing
- init-only `ref.func` exact-type narrowing
- null-plus-exact nullable refinement
- non-null exact refinement
- heterogeneous `anyref`-to-`eqref` joins
- dependent global-initializer `global.get` retagging
- open-vs-closed-world exported mutability differences
- public-type-vs-exact-type boundary behavior

That is broader than the current local MoonBit test file.

## Current freshness note

A narrow 2026-04-20 check found no semantic drift here:

- current `main` `GlobalRefining.cpp` is identical to `version_129`
- current `main` `global-refining.wast` is also identical to `version_129`

So the current wiki should continue treating `version_129` as the semantic oracle without an active trunk-drift caveat.

## What a future port or parity pass must preserve

A future strict-parity Starshine port or refactor must keep these Binaryen-backed rules honest:

- the algorithm is initializer-plus-writes LUB aggregation, not control-flow-sensitive global reasoning
- imported globals stay untouched
- open-world exported mutable globals stay untouched
- open-world exported immutable globals only refine when the new type is public
- closed-world exported globals are still conservatively untouched in official `version_129`
- every declaration rewrite must be paired with `global.get` cached-type repair if the IR representation caches expression result types
- changed code must be refinalized after retagging
- this pass does not need generic non-nullable-local fixups in Binaryen's model

If local code intentionally broadens or narrows any of those rules, keep that as an explicit documented divergence.
