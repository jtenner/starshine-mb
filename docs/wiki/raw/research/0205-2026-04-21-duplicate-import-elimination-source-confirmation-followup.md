# 0205 - `duplicate-import-elimination` source-confirmation follow-up

## Status

- Date: 2026-04-21
- Type: Source-confirmation follow-up
- Scope: correct the existing `duplicate-import-elimination` dossier against the real Binaryen `version_129` source, identify the exact owner files and shipped tests, and record the major correction that this pass is function-import-only in `version_129`, not a broad all-import alias cleaner.

## Why this follow-up was needed

The existing living dossier for `duplicate-import-elimination` already had useful scheduler context, but it still taught a much broader contract than Binaryen `version_129` actually implements.

The earlier dossier said, in effect:

- imported functions, globals, tables, and memories are all deduplicated,
- `ImportInfo` is the real equality key,
- `OptUtils` rewrites broad per-kind user surfaces for all of those kinds,
- and the main remaining nuance is a tag/table caveat.

After re-reading the real upstream sources, that is not the current pass.

The real Binaryen `version_129` pass is much smaller:

- it scans only imported **functions**,
- it keys duplicates only by `(module, base)` and then checks exact function type equality against the first-seen import for that pair,
- it rewrites only function-name users through `OptUtils::replaceFunctions(...)`,
- and it ships one small dedicated test that covers only the function surface.

So this follow-up exists to replace the folder's earlier broad "all handled import kinds" story with the real source-confirmed owner map.

## Inputs consulted

### Repo-local inputs

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- existing folder `docs/wiki/binaryen/passes/duplicate-import-elimination/`
- earlier raw note `docs/wiki/raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md`

`agent-todo.md` **does** have a dedicated slice for this pass:

- `#### DIE - Duplicate Import Elimination`
- `[DIE]001 - Import Identity and Merge Safety`
- `[DIE]002 - Index Rewrite and Artifact Validation`

That backlog wording currently overstates the rewrite surface (`function/table/global/memory import users`) relative to Binaryen `version_129`, so future implementation work should treat this follow-up as the more accurate upstream oracle.

### Official Binaryen sources used

- `src/passes/DuplicateImportElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateImportElimination.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/import-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.h>
- `test/passes/duplicate-import-elimination.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.wast>
- `test/passes/duplicate-import-elimination.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.txt>

I also checked current Binaryen `main` for drift in `DuplicateImportElimination.cpp`; the file is unchanged relative to `version_129` on the reviewed surface.

## Fast correction

## What the pass really is

Binaryen `version_129` `duplicate-import-elimination` is a tiny late module pass that:

1. scans imported **functions** in module order,
2. groups them by the pair `(import.module, import.base)`,
3. keeps the first import seen for that pair,
4. merges later imports only if their `Function::type` matches that first import,
5. rewrites direct function-name users to the first import name,
6. removes the later duplicate function imports.

## What it is **not**

It is **not**, in `version_129`:

- a generic all-import deduplicator,
- a pass over globals, tables, memories, and tags,
- an `ImportInfo`-keyed structural merge over all import kinds,
- or a broad per-kind rewrite pass over table/global/memory instructions.

Those broader ideas are easy to infer from nearby helpers like `ImportInfo`, but they are not what `DuplicateImportElimination.cpp` currently does.

## Main source-confirmed findings

## 1. The owner file is tiny and function-only

`src/passes/DuplicateImportElimination.cpp` is the real owner file.

Its opening comment says:

- `// Removes duplicate imports.`
- `// TODO: non-function imports too`

That TODO is the clearest single-line correction to the older dossier.

The implementation then iterates only:

- `for (auto* func : imports.importedFunctions)`

There are no parallel loops for:

- `importedGlobals`
- `importedTables`
- `importedMemories`
- `importedTags`

So the pass's real current scope is explicitly narrower than the nearby `ImportInfo` helper surface.

## 2. `ImportInfo` is used only as a convenience collector here

`DuplicateImportElimination.cpp` constructs:

- `ImportInfo imports(*module);`

But that does **not** mean the pass uses a polymorphic `ImportInfo` equality key.

Instead, the pass builds:

- `std::map<std::pair<Name, Name>, Name> seen;`

That key is just:

- `(func->module, func->base)`

Then, only when the pair has been seen before, it fetches the previous canonical function and checks:

- `previousFunc->type == func->type`

So the real equality story is two-step:

1. same import module/base pair,
2. same function type as the first import already recorded for that pair.

That is narrower and more concrete than the earlier dossier's `ImportInfo(kind,module,base,type)` story.

## 3. Canonicalization is first-import-wins, but only within a module/base bucket

The pass stores the first function name seen for each `(module, base)` pair in `seen`.

For a later function import with the same pair:

- if its type matches the first one, it becomes a duplicate alias,
- otherwise Binaryen preserves it and does **not** replace `seen[pair]`.

That means one pair can legally keep multiple imported functions when types differ, and later same-pair imports are always compared against the original first-seen representative, not against some evolving best match.

Practical implication:

- `(module, base)` picks the bucket,
- exact function type decides merge eligibility,
- the earliest matching import remains canonical.

## 4. The rewrite surface is exactly `OptUtils::replaceFunctions(...)`

When duplicates were found, the pass does this exact sequence:

1. `module->updateMaps();`
2. `OptUtils::replaceFunctions(getPassRunner(), *module, replacements);`
3. remove each duplicate function name with `module->removeFunction(name);`

`replaceFunctions(...)` in `opt-utils.h` is also much smaller than the earlier dossier implied.

Its actual function-name rewrite surface is:

- `Call.target`
- `RefFunc.func`
- function uses found by `runOnModuleCode(...)` through the same `visitCall` / `visitRefFunc` walker
- `module.start`
- function exports

There are no sibling helpers used here for:

- `GlobalGet` / `GlobalSet`
- table instructions
- memory instructions
- global exports
- table exports
- memory exports

So the older dossier's global/table/memory rewrite map was imported from nearby helper intuition, not from this pass's real implementation.

## 5. `runOnModuleCode(...)` matters, but only for function references

Because the walker only overrides:

- `visitCall(Call*)`
- `visitRefFunc(RefFunc*)`

its module-code walk is only relevant where module-level expression trees can contain function references.

The practical positive example is:

- element segment payload expressions containing `ref.func`

The shipped test proves a related effect through table element contents.

What this does **not** mean:

- Binaryen is not walking module code here to rewrite globals, tables, or memories by name.

It is still only performing function-name rewrites.

## 6. The pass comment about "does not alter function contents" needs careful reading

The pass overrides:

- `bool requiresNonNullableLocalFixups() override { return false; }`

with the comment:

- `// This pass does not alter function contents.`

Taken literally, that comment is a little misleading, because `replaceFunctions(...)` absolutely can rewrite `call` and `ref.func` inside function bodies.

The source-backed practical meaning is narrower:

- it does not change local declarations or expression result types in a way that needs nonnullable-local repair.

That nuance is worth keeping explicit so future documentation does not repeat the comment too literally.

## 7. The shipped test surface is one small function-only file

The dedicated test files are:

- `test/passes/duplicate-import-elimination.wast`
- `test/passes/duplicate-import-elimination.txt`

The input test covers:

- two duplicate imported nullary functions `$foo` and `$bar`,
- one same-module/base imported function `$wrong` with a different signature that must be preserved,
- table element contents using both `$foo` and `$bar`,
- `start $bar`,
- direct `call $foo`,
- direct `call $bar`,
- direct `call $wrong`.

The checked output proves:

- `$bar` is removed,
- the element segment now uses `$foo $foo`,
- `start` is rewritten to `$foo`,
- both direct calls target `$foo`,
- `$wrong` survives unchanged.

There are no dedicated positive tests here for:

- imported globals,
- imported tables,
- imported memories,
- imported tags.

That test scope matches the real implementation scope.

## 8. Scheduler placement is real, but the pass remains tiny

`pass.cpp` confirms:

- registration name: `duplicate-import-elimination`
- help text: `removes duplicate imports`
- default global post-pass placement immediately after the second `duplicate-function-elimination`

inside `addDefaultGlobalOptimizationPostPasses()`.

So the pass is still a real late post-pass in the canonical no-DWARF path, but its actual work is the small function-import alias cleanup described above.

## File-by-file role map

## `src/passes/DuplicateImportElimination.cpp`

Owns the whole public algorithm:

- import scan
- bucket key
- type check
- replacement map build
- user rewrites through `replaceFunctions`
- duplicate imported-function removal

## `src/passes/opt-utils.h`

Owns the exact rewrite surface actually used by this pass:

- `Call.target`
- `RefFunc.func`
- module-code `call` / `ref.func`
- start
- function exports

## `src/ir/import-utils.h`

Only supplies the convenient imported-function list here.

It does prove that Binaryen has nearby helper awareness of imported globals/tables/memories/tags, but that broader helper availability should **not** be mistaken for actual `duplicate-import-elimination` behavior.

## `src/passes/pass.cpp`

Owns pass registration and the late global post-pass scheduler slot.

## `test/passes/duplicate-import-elimination.wast` and `.txt`

Own the compact executable contract for the pass's actual function-only surface.

## Corrected beginner summary

A better beginner explanation for `version_129` is:

- If a module imports the same host **function** more than once under different internal names,
- and those imports have the same function type,
- Binaryen keeps the first import name,
- rewrites later direct calls, `ref.func`s, start, exports, and module-level function references to that first name,
- then removes the later imported function declarations.

That is the real source-backed contract.

## Explicit corrections to the previous dossier

The following earlier claims should now be treated as superseded for Binaryen `version_129`:

- `duplicate-import-elimination` handles imported globals, tables, and memories.
- `ImportInfo(kind,module,base,type)` is the actual duplicate key used by the pass.
- the main rewrite surface includes `global.get` / `global.set`, bulk table ops, bulk memory ops, memory exports, table exports, and similar non-function users.
- the main subtle caveat is tag support or table-type-key precision.

The more accurate correction is:

- none of those non-function surfaces are in the current pass at all.

## Practical implications for Starshine

If Starshine wants Binaryen `version_129` parity first, the faithful port target is a small late boundary/module pass that only handles duplicate imported functions.

If Starshine later wants a broader all-import deduplicator, that should be documented as one of:

- a deliberate divergence from `version_129`,
- a forward-port from future upstream work if Binaryen expands the pass,
- or a separate local optimization.

But it should not be attributed to current Binaryen `version_129`.

## Durable conclusions

- The existing folder needed a real source-confirmation correction, not just a missing implementation-map page.
- Binaryen `version_129` `duplicate-import-elimination` is function-import-only today.
- The real duplicate key is `(module, base)` plus exact function-type equality against the first-seen import for that pair.
- The real rewrite surface is only the function-name surface in `OptUtils::replaceFunctions(...)`.
- The shipped test coverage is correspondingly small and function-only.
- Current Binaryen `main` matches `version_129` on the reviewed implementation file, so this corrected description is not just tag-specific historical trivia.
