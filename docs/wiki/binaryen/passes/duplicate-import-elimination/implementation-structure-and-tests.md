---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md
  - ../../../raw/research/0205-2026-04-21-duplicate-import-elimination-source-confirmation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# `duplicate-import-elimination`: implementation structure and tests

This page is the compact source-confirmed map for how Binaryen `version_129` actually implements `duplicate-import-elimination` and where the shipped tests pin that behavior down.

## Why this page exists

The folder already had a useful dossier, but it still missed one compact page answering four recurring questions in one place:

- which official file really owns the pass,
- what the exact algorithmic phases are,
- which helpers are actually used,
- and which shipped tests prove the contract.

That gap mattered because the earlier folder also overgeneralized the pass into a broad all-import deduplicator.
The real `version_129` implementation is much smaller.

## Official owner files

## `src/passes/DuplicateImportElimination.cpp`

This is the real owner file.
It contains essentially the whole pass contract:

- imported-function scan,
- `(module, base)` bucket detection,
- exact function-type equality check,
- first-import-wins replacement planning,
- function-user rewrites through `OptUtils::replaceFunctions(...)`,
- duplicate imported-function removal.

The file's own top comment includes the most important scope correction:

- `TODO: non-function imports too`

That is the clearest source-backed proof that current `version_129` is function-import-only here.

## `src/passes/opt-utils.h`

This file owns the rewrite surface the pass actually uses.

For this pass, the relevant helper is only:

- `OptUtils::replaceFunctions(...)`

That helper rewrites:

- `Call.target`
- `RefFunc.func`
- function uses found in module-code expression trees through `runOnModuleCode(...)`
- `module.start`
- function exports

This is why the real pass rewrites function names only, not global/table/memory users.

## `src/ir/import-utils.h`

This file matters here only because `ImportInfo` provides the imported-function list:

- `imports.importedFunctions`

It is useful context, but it does **not** mean the pass uses the full helper's broader cross-kind import metadata as its equality key.

## `src/passes/pass.cpp`

This file proves:

- the public pass name is `duplicate-import-elimination`,
- the help text is `removes duplicate imports`,
- the pass appears in the late default global post-pass cluster right after the second `duplicate-function-elimination`.

## Real implementation phases in `DuplicateImportElimination.cpp`

## Phase 0: collect imported functions with `ImportInfo`

The pass starts with:

- `ImportInfo imports(*module);`

and then iterates only:

- `imports.importedFunctions`

There are no sibling loops over:

- imported globals,
- imported tables,
- imported memories,
- imported tags.

Beginner takeaway:

- the current pass is not "all imports" despite the broad public name.

## Phase 1: bucket by `(module, base)`

The pass keeps:

- `std::map<std::pair<Name, Name>, Name> seen;`

Each bucket key is just:

- the import module string,
- the import base/field string.

That is the first half of duplicate detection.

## Phase 2: require exact function-type equality

When a `(module, base)` pair has been seen before, the pass fetches the first function recorded for that pair and checks:

- `previousFunc->type == func->type`

Only then does it treat the later import as a duplicate alias.

So the real duplicate rule is:

- same module/base pair,
- same function type as the first-seen import in that pair bucket.

## Phase 3: build the replacement and removal sets

For each duplicate imported function, the pass records:

- `replacements[func->name] = previousName`
- `toRemove.push_back(func->name)`

The canonical representative is therefore:

- not a synthetic import,
- not a lexicographically chosen one,
- simply the first imported function seen for the bucket.

## Phase 4: update maps and rewrite users

If the replacement map is non-empty, the pass performs this exact sequence:

1. `module->updateMaps()`
2. `OptUtils::replaceFunctions(getPassRunner(), *module, replacements)`
3. `module->removeFunction(name)` for each duplicate

That exact order is part of the practical implementation story.

## Phase 5: remove duplicate imported functions

The pass then removes only the later duplicate imported function declarations.

It does not:

- delay removal to `remove-unused-module-elements`,
- keep aliases around as dead declarations,
- or perform a second cleanup pass.

## Important negative facts

These are just as important as the positive phases.

The pass does **not** use:

- `EffectAnalyzer`
- CFG or dominance reasoning
- any fixpoint loop
- `ReFinalize`
- type-updating helpers
- global/table/memory replacement helpers
- nested reruns like `optimizeAfterInlining(...)`

That means a faithful Starshine port should stay small and structural.

## Nonnullable-local-fixup note

The pass overrides:

- `requiresNonNullableLocalFixups() -> false`

with the comment that it does not alter function contents.

Strictly speaking, it can rewrite `call` and `ref.func` names inside function bodies.
But the source-backed practical point is narrower:

- it does not alter local declarations or expression typing in a way that needs nonnullable-local repair.

So future docs should not read that comment as "the AST never changes at all."

## Shipped tests and what they prove

## `test/passes/duplicate-import-elimination.wast`

This is the dedicated input test.
It covers exactly the function-only surface the implementation supports:

- duplicate imported nullary functions `$foo` and `$bar`,
- same module/base but different-signature imported function `$wrong`,
- an element segment using both `$foo` and `$bar`,
- `start $bar`,
- direct calls to `$foo`, `$bar`, and `$wrong`.

## `test/passes/duplicate-import-elimination.txt`

This is the checked output.
It proves that Binaryen:

- removes `$bar`,
- preserves `$wrong`,
- rewrites the element contents to `$foo $foo`,
- rewrites `start` to `$foo`,
- rewrites both direct calls to `$foo`,
- leaves the differing-signature call to `$wrong` alone.

## What the shipped tests do **not** prove

The dedicated test surface does not cover positive duplicates for:

- globals,
- tables as imported declarations,
- memories as imported declarations,
- tags.

That absence matches the real implementation.
It is another reason the earlier broad dossier needed correction.

## Exact file/test ownership summary

| File | What it proves |
| --- | --- |
| `src/passes/DuplicateImportElimination.cpp` | The whole real algorithm: imported-function-only scan, `(module, base)` buckets, exact function-type check, first-import-wins replacement map, and duplicate imported-function removal |
| `src/passes/opt-utils.h` | The exact function-only rewrite surface: `call`, `ref.func`, module-code `call/ref.func`, start, and function exports |
| `src/ir/import-utils.h` | Only the imported-function collection surface actually used here |
| `src/passes/pass.cpp` | Public pass registration and late post-pass scheduler placement |
| `test/passes/duplicate-import-elimination.wast` | Function-only positive and negative input shapes |
| `test/passes/duplicate-import-elimination.txt` | The expected canonicalized output for those shapes |

## Current-main drift check

A spot check against current Binaryen `main` found no reviewed drift in `DuplicateImportElimination.cpp` relative to `version_129`.

So the corrected story on this page is not just tag-specific historical trivia.
It still describes the current upstream implementation on the reviewed surface.
