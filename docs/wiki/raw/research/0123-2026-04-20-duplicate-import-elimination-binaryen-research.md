# 0123 - `duplicate-import-elimination` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what `duplicate-import-elimination` actually does, which helpers it depends on, which import and user shapes it rewrites, and which exact source-level caveats a future Starshine port must preserve.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` now suggests `duplicate-import-elimination` as the highest-value remaining next dossier.
- The pass still had wiki status `none` in the tracker when this thread began and is still only a boundary-only placeholder in `src/passes/optimize.mbt`.
- The canonical Binaryen no-DWARF `-O` / `-Os` path runs it in the late post-pass cluster:
  - after the second `duplicate-function-elimination`
  - before `simplify-globals-optimizing`
  - before the final `remove-unused-module-elements`
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - slot `51`
- The saved Binaryen debug log shows it as a very small late cleanup:
  - `2.133e-05` seconds in the captured generated-artifact run
- This pass is easy to misdescribe as either:
  - “remove unused imports”, or
  - “just merge duplicate imported functions”
- The real source contract is narrower and more structural:
  - it merges only certain imported declaration kinds
  - it keys identity on exact import metadata helpers, not on reachability or effects
  - it rewrites many more user sites than just direct calls
  - it deletes the redundant import declarations immediately after retargeting users

That combination makes it a good dossier target even though the implementation file itself is much smaller than big planners like `inlining-optimizing` or `simplify-globals-optimizing`.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/DuplicateImportElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateImportElimination.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/ir/import-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.h>
- `src/ir/import-utils.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/wasm.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- `test/lit/passes/duplicate-import-elimination.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-import-elimination.wast>

## Fast answer

Binaryen’s `duplicate-import-elimination` pass is a late **module-level alias cleanup**.

It does not ask whether an import is unused.
It does not run dataflow.
It does not compare effects.
It does not look for profitability.
It does not rerun nested cleanup passes.

Instead it does this:

1. scan imported functions, globals, tables, and memories in module order
2. compute a structural identity key for each import
3. keep the first import seen for each exact key
4. retarget all later duplicate users to that first canonical import
5. delete the redundant import declarations

The important durable facts are:

- The pass is a **boundary/module** pass, not a function-local optimization.
- It only handles these imported kinds in `version_129`:
  - functions
  - globals
  - tables
  - memories
- It does **not** handle imported tags, even though the helper import metadata structs already know how to describe tag imports.
- Identity is keyed by:
  - import kind
  - import module string
  - import field/base string
  - kind-specific import type metadata
- “Kind-specific import type metadata” is more exact than just the visible WAT name, but it is not identical across all kinds:
  - functions compare the full stored function `Type`
  - globals compare value type plus mutability
  - memories compare limits, sharedness, address type, and page size
  - tables compare heap type, limits, and address type, with an important caveat below about nullability/exactness
- User rewrites are broader than many first guesses:
  - function direct calls
  - `ref.func`
  - start function name
  - exports
  - `global.get` / `global.set`
  - many table instructions
  - many memory instructions
  - some module-level init expressions through `runOnModuleCode(...)`
- The pass itself removes the redundant imports immediately after retargeting users.
- A future Starshine port must preserve the exact aliasing contract, not replace it with unused-import pruning or a weaker “same module/base only” heuristic.

## Where it appears in the scheduler

## Top-level no-DWARF path

Binaryen `version_129` `pass.cpp` schedules `duplicate-import-elimination` inside `addDefaultGlobalOptimizationPostPasses()` when:

- `optimizeLevel >= 2`, or
- `shrinkLevel >= 2`

In the canonical no-DWARF `-O` / `-Os` pipeline tracked in this repo, the pass appears:

- after `duplicate-function-elimination`
- before `simplify-globals-optimizing`
- before `remove-unused-module-elements`
- before `string-gathering`
- before `reorder-globals`
- before `directize`

The practical scheduler meaning is simple and important:

- later late-module passes see **fewer alias names** for the same imported object
- later global/string/layout cleanup does not need to preserve duplicate imported declarations that say the same thing

That second sentence is partly an inference from placement, but it is the obvious practical consequence of the source order.

## Saved generated-artifact `-O4z` audit

The saved generated-artifact ordered replay records a real skipped top-level slot:

- slot `51`: `duplicate-import-elimination`

The saved Binaryen debug log also shows the pass is tiny in that run:

- `2.133e-05` seconds

That does **not** mean the pass is trivial to port incorrectly. It means the pass is structurally small and late, so the value is in getting the exact rename surface right rather than in reproducing some giant analysis.

## Actual implementation structure

## 1. One pass, one sweep, no nested reruns

`pass.cpp` registers a single pass name:

- `duplicate-import-elimination`

`DuplicateImportElimination.cpp` implements one module pass with no optimize-vs-non-optimize variant and no nested `PassRunner` behavior.

This pass is therefore unlike:

- `dae-optimizing`
- `inlining-optimizing`
- `simplify-globals-optimizing`

Those late neighbors contain rerun contracts. `duplicate-import-elimination` does not.

## 2. The real core data structure is `ImportInfo`

The source does not compare raw imports ad hoc.
It uses `ImportInfo` from `src/ir/import-utils.h` and `src/ir/import-utils.cpp`.

That helper packages four things into one identity key:

- `kind`
- `module`
- `base`
- `type`

Where `type` is a variant over:

- function type
- global type
- table type
- memory type
- tag type

So the pass is not merely comparing the visible `(import "env" "foo" ...)` strings. It combines those strings with kind-specific type metadata.

## 3. It scans imported items kind by kind

The pass body keeps:

- `std::map<ImportInfo, Name> existing`
- `std::set<Name> importsToRemove`
- separate replacement maps for:
  - functions
  - globals
  - tables
  - memories

It then iterates imported declarations in this order:

1. imported functions
2. imported globals
3. imported tables
4. imported memories

For each imported item:

- compute `ImportInfo`
- if it has been seen before:
  - remember a replacement from the current import name to the first-seen name
  - mark the current import for removal
- otherwise:
  - record the current import name as the canonical first-seen representative

The beginner-friendly rule is:

- **first import wins**
- later duplicates become aliases to that first one

## 4. “First import wins” is deterministic and source-visible

Because the pass only writes `existing[info] = name` on the first encounter, the canonical import is the earliest imported declaration of that identity class in module iteration order.

That is important because the pass does **not** invent a fresh merged import.
It preserves one of the existing names and redirects later aliases to it.

So a future Starshine port should preserve:

- stable canonical choice
- predictable export/start/user rewrites to the earliest import

not a more complicated canonicalization rule.

## 5. There is no fixpoint or profitability loop

The pass makes one structural sweep, then one rewrite phase, then one removal phase.

There is no:

- repeat-until-stable loop
- scoring heuristic
- branch or CFG analysis
- effect invalidation machinery
- refinalization pass
- secondary cleanup rerun

This is a valuable negative fact because larger Binaryen passes often do have those things. This one does not.

## Import identity: what actually counts as “duplicate”

## Function imports

Functions use the full stored `Function::type` through `ImportInfo::FunctionType`.

That means Binaryen requires more than just:

- same module string
- same field string

It also requires the exact function type object used by the import metadata helper.

In practice, the shipped test shows the intended beginner case:

- same module/base + same signature => merge
- same module/base + different signature => do not merge

Important nuance from `src/wasm.h`:

- `Function::type` is a non-nullable reference type over the signature
- `wasm.h` still has a TODO saying imported functions should probably be inexact in the future

So for `version_129`, function-import identity is tied to Binaryen’s current stored function-type representation, not just a handwritten params/results comparison.

## Global imports

Globals use `Type(curr.type, curr.mutable_)` through `ImportInfo::GlobalType`.

So duplicate imported globals must agree on both:

- value/reference type
- mutability

The shipped test demonstrates the simple visible version of this:

- `i32` + `i32` duplicate => merge
- `i32` + `i64` => do not merge

## Memory imports

Memories use `ImportInfo::MemoryType` with these fields:

- `initial`
- `max`
- `shared`
- `addressType`
- `pageSize`

That is more exact than many casual descriptions like “same min/max limits.”

So a future port must preserve memory import equality across:

- ordinary 32-bit vs 64-bit memory addressing
- shared vs unshared
- custom page size metadata
- limit differences

The shipped test only illustrates differing limits/sharedness in a simple way, but the helper source shows the real key is broader.

## Table imports

Tables use `ImportInfo::TableType` with these fields:

- `initial`
- `max`
- `addressType`
- `type: HeapType`

This is where the source becomes more subtle than the shorthand “same table type.”

The helper stores:

- heap type

but **not** the full Binaryen `Type` object for the table element type.

That means the helper source we inspected does **not** explicitly record table element nullability or exactness here.

I did not find a shipped `duplicate-import-elimination` test that distinguishes nullable versus non-nullable table imports, so this is best recorded as a source-level caveat:

- the helper is at least slightly looser than full `Type` equality for tables
- future research should verify whether that matters in practice for `version_129`

This is an implementation reading, not a fully test-backed semantic conclusion.

## Tag imports are described by helpers, but the pass does not use them

`ImportInfo` already has:

- `TagType`

and `getImportInfo(...)` can compute tag import identity.

But `DuplicateImportElimination.cpp` never iterates imported tags and never builds a tag replacement map.

So the real `version_129` pass scope is **not** “all import kinds.”
It is only:

- functions
- globals
- tables
- memories

That is one of the most useful “what the pass sounds like vs what it actually does” takeaways.

## What the pass actually rewrites

The pass delegates user rewrites to `OptUtils` helpers.
Those helpers are the real answer to “what breaks if Starshine forgets one edge?”

## Function import rewrite surface

`OptUtils::replaceFunctions(...)` rewrites:

- direct `Call.target`
- `RefFunc.func`
- exports of kind `Function`
- module start name
- module-code expression trees through `runOnModuleCode(...)`

Practical consequences:

- direct calls to the duplicate imported function retarget to the canonical import
- `ref.func $dup` retargets to `ref.func $canonical`
- exported aliases keep their export names but now point at the canonical import
- a duplicate imported start function is canonicalized too
- module-level `ref.func` users such as element-segment payload expressions can be updated

## Global import rewrite surface

`OptUtils::replaceGlobals(...)` rewrites:

- `GlobalGet.name`
- `GlobalSet.name`
- exports of kind `Global`
- module-code expressions through `runOnModuleCode(...)`

Practical consequences:

- function bodies are updated
- global initializer expressions are updated
- segment offset expressions are updated if they use `global.get`
- exported aliases keep their export names but point at the canonical imported global

## Table import rewrite surface

`OptUtils::replaceTables(...)` rewrites:

- `TableGet.table`
- `TableSet.table`
- `TableSize.table`
- `TableGrow.table`
- `TableFill.table`
- `TableCopy.destTable`
- `TableCopy.sourceTable`
- `TableInit.table`
- exports of kind `Table`
- module-code expression trees through `runOnModuleCode(...)`

This is wider than a beginner might expect. The pass is not just about `table.get` or table exports; it also has to retarget bulk-table ops.

## Memory import rewrite surface

`OptUtils::replaceMemories(...)` rewrites:

- `Load.memory`
- `Store.memory`
- `AtomicRMW.memory`
- `AtomicCmpxchg.memory`
- `AtomicWait.memory`
- `AtomicNotify.memory`
- `SIMDLoad.memory`
- `SIMDLoadStoreLane.memory`
- `MemorySize.memory`
- `MemoryGrow.memory`
- `MemoryInit.memory`
- `MemoryCopy.destMemory`
- `MemoryCopy.sourceMemory`
- `MemoryFill.memory`
- `ArrayNewData.memory`
- `ArrayInitData.memory`
- exports of kind `Memory`
- module-code expression trees through `runOnModuleCode(...)`

Again, this is not merely `memory.size` or a section-level rename.
Binaryen retargets many instruction families.

## `runOnModuleCode(...)` matters, but it is narrower than “all module fields”

`OptUtils::runOnModuleCode(...)` explicitly walks expression subtrees in:

- globals with initializers
- element segments with offset expressions and element payload expressions
- data segments with offset expressions

That means module-level expression users are included.

But the helper does **not** itself promise to rewrite non-expression top-level fields like:

- `ElementSegment.table`
- `DataSegment.memory`

That creates one honest uncertainty in this dossier:

- the helper surfaces I traced clearly rewrite expression trees and exports/start
- I did **not** trace an equally explicit rewrite for the non-expression active-segment target names in this pass’s path

So there are two possibilities:

1. Binaryen handles those target-name rewrites elsewhere in code not traced here, or
2. this pass’s current tested surface simply does not cover those cases directly

I do not want to overclaim which is true from the inspected files alone.
Record this as an open implementation-reading caveat for future follow-up.

## Removal phase

After the replacement maps are applied, the pass removes the redundant import declarations by name using `importsToRemove`.

The key practical point is:

- Binaryen does not leave dead duplicate imports behind for later cleanup
- the pass is a complete alias-collapse step for the imports it decides to merge

## What the shipped test teaches

The shipped lit test `duplicate-import-elimination.wast` is compact but very instructive.

It demonstrates all of these positive cases:

- duplicate imported functions with the same module/base/signature merge
- direct `call` sites retarget
- `ref.func` users retarget
- the start function retargets
- function exports retarget
- duplicate imported globals with the same type/mutability merge
- `global.get` and `global.set` retarget
- global exports retarget
- duplicate imported tables with matching metadata merge
- `table.get`, `table.size`, `table.set`, `table.copy`, `table.fill`, and `table.init` retarget
- table exports retarget
- duplicate imported memories with matching metadata merge
- `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, and `memory.init` retarget
- memory exports retarget

It also demonstrates negative cases that are easy to misunderstand:

- same module/base but different function signature => preserved
- same module/base but different global type => preserved
- same module/base but different table element type/metadata => preserved
- same module/base but different memory limits/metadata => preserved

That test is the best beginner-oriented grounding source for before/after WAT shapes.

## Important non-obvious takeaways

## 1. This is not dead-import elimination

The pass does not care whether the duplicate import is unused.
If two imported declarations are structurally the same and one is heavily used, Binaryen still merges them into a single canonical import and retargets the uses.

So the name is about **duplicate alias declarations**, not dead boundary declarations.

## 2. The pass is structural, not semantic-in-the-large

It does not ask:

- whether two imported functions are observationally equivalent at runtime
- whether a callgraph can prove anything
- whether effects/liveness allow anything

It only asks whether the imported declarations are the same boundary request according to the import metadata helpers.

## 3. Export names are preserved while internal targets collapse

This is easy to miss.
If two exports used to point at two duplicate imported names, Binaryen does not delete the export names.
It rewrites their internal names so the export surface can still contain multiple export names pointing at one canonical imported object.

## 4. The pass is broader than function imports, but narrower than all imports

Broader than many first guesses because it handles:

- globals
- tables
- memories

Narrower than its name sounds because in `version_129` it does **not** handle:

- tag imports

## 5. The helper surface is where most future Starshine bugs would hide

A naive port could easily remember to rewrite:

- `call`

but forget:

- `ref.func`
- start
- exports
- `table.copy`
- `memory.copy`
- module-level init expressions

That would make the port look correct on a shallow example and wrong on real modules.

## 6. Table equality is a subtle source-level caveat

For tables, `ImportInfo::TableType` stores `HeapType`, not the full table `Type` object.
That means the precise equality story is not just “compare full table type exactly.”

This is worth calling out explicitly because the backlog shorthand says “type identity exact,” but the helper source shows the table case deserves a footnote.

## Pass interactions and scheduler implications

## Earlier late neighbors

The pass runs after:

- `dae-optimizing`
- `inlining-optimizing`
- second `duplicate-function-elimination`

That means boundary/callgraph simplifications have already happened before import alias cleanup.

The practical implication is that the late module cleanup cluster sees a more canonical import surface.

## Later late neighbors

The pass runs before:

- `simplify-globals-optimizing`
- `remove-unused-module-elements`
- `string-gathering`
- `reorder-globals`
- `directize`

The most obvious future-port implication is:

- later passes should not need to reason about multiple imported names that request the same external object

and, more narrowly:

- final module cleanup should see the already-collapsed import set, not the pre-merged one

## What analyses it does **not** depend on

This pass does **not** depend on the major analysis families that dominate other dossiers:

- no `EffectAnalyzer`
- no liveness
- no CFG reasoning
- no dominance
- no refinalization
- no branch utilities
- no linear execution walker

Its real dependencies are instead:

- import-metadata extraction
- whole-module imported-item iteration
- per-kind name-rewrite walkers
- final import removal

That negative list is useful because it tells a future implementer not to over-engineer the port.

## Future Starshine port checklist

- Keep this a **module/boundary** pass, not a hot-function pass.
- Preserve the exact top-level placement after the second `duplicate-function-elimination` and before the late global/string/layout cleanup cluster.
- Preserve the **first-import-wins** canonical choice.
- Preserve kind-specific identity keys, not just module/base string equality.
- Preserve rewriting for all currently handled kinds:
  - functions
  - globals
  - tables
  - memories
- Preserve all important user sites:
  - direct calls
  - `ref.func`
  - start
  - exports
  - global ops
  - bulk table ops
  - bulk memory ops
  - module init expressions walked by `runOnModuleCode(...)`
- Do **not** silently widen scope to tags unless deliberately documented; Binaryen `version_129` does not do that here.
- Be careful about the table-identity nuance from `ImportInfo::TableType`.
- Be explicit about any unresolved handling of active segment target-name fields (`ElementSegment.table`, `DataSegment.memory`) if the port chooses to support or defer them.
- Do not turn this into a dead-import or unused-import pass. The contract is alias collapse, not reachability pruning.

## Open questions / uncertainty ledger

1. **Active element/data segment target-name rewrites**
   - I traced `runOnModuleCode(...)` and the per-kind replacers.
   - They clearly rewrite expression trees and exports/start.
   - I did not trace an equally explicit rewrite for non-expression target-name fields like `ElementSegment.table` and `DataSegment.memory`.
   - This is therefore still an open source-reading question, not a settled semantic claim.

2. **Table nullability / exactness sensitivity**
   - `ImportInfo::TableType` stores `HeapType`, limits, and address type.
   - It does not visibly store the full Binaryen `Type` object for the table element type.
   - I did not find a shipped pass test exercising nullable vs non-nullable table import duplicates.
   - So the precise current behavior there should be treated as a caveated implementation reading.

3. **Tag import omission**
   - The omission itself is not uncertain; the pass source simply does not iterate tags.
   - The open question is only whether upstream later intends to widen the pass to tags because the helper metadata already supports them.

## Durable summary

If a beginner remembers only one thing, it should be this:

- `duplicate-import-elimination` is Binaryen’s late pass for collapsing **multiple internal aliases of the same imported boundary object** into one canonical import name.

If an implementer remembers only one thing, it should be this:

- the hard part is not the detection map; it is preserving the **full per-kind user rewrite surface and the exact metadata key**, including the source-level caveats around tables and currently unsupported tags.
