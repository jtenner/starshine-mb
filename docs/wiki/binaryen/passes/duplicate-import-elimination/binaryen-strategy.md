---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-duplicate-import-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md
  - ../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md
  - ../../../raw/research/0205-2026-04-21-duplicate-import-elimination-source-confirmation-followup.md
  - ../../../raw/research/0269-2026-04-23-duplicate-import-elimination-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ../simplify-globals-optimizing/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `duplicate-import-elimination` strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The reviewed official Binaryen GitHub `version_129` release page was rechecked on **2026-04-23** through [`../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md), and GitHub showed the release publish date as **2026-04-01**.
- The core implementation is `src/passes/DuplicateImportElimination.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp`.
- The actual rewrite surface used by this pass comes from `src/passes/opt-utils.h`, specifically `OptUtils::replaceFunctions(...)`.
- `src/ir/import-utils.h` matters only because it supplies `ImportInfo.importedFunctions`.
- The shipped behavior examples come from:
  - `test/passes/duplicate-import-elimination.wast`
  - `test/passes/duplicate-import-elimination.txt`

Primary source URLs captured on 2026-04-23 and rechecked against current `main` on 2026-04-25:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateImportElimination.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.txt>

A narrow 2026-04-25 spot check of current Binaryen `main`, captured in [`../../../raw/binaryen/2026-04-25-duplicate-import-elimination-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-duplicate-import-elimination-current-main-recheck.md), did not surface teaching-relevant drift on the reviewed implementation, helper, registration, or dedicated-test surfaces.

## Main correction

The most important source-confirmed fact is simple:

- Binaryen `version_129` `duplicate-import-elimination` is a **function-import-only** pass.

The implementation file says:

- `// TODO: non-function imports too`

and the pass body iterates only:

- `imports.importedFunctions`

So do **not** teach the current pass as deduplicating imported globals, tables, memories, or tags.

## High-level intent

Binaryen uses `duplicate-import-elimination` to collapse multiple internal aliases of the same imported **function**.

The actual implementation is a very small late module planner with three stages:

| Stage | What Binaryen does | Why it exists |
| --- | --- | --- |
| Scan imported functions | Group imported functions by `(module, base)` and compare their function types | Detect which later imported functions are really duplicate aliases |
| Retarget users | Rewrite later direct function-name users to the first canonical import | Preserve behavior while collapsing aliases |
| Remove duplicates | Delete the redundant imported function declarations | Leave the late pipeline with one canonical imported function per matching alias class |

That means the pass is not:

- dead-import elimination
- unused-import elimination
- all-import deduplication
- effect analysis
- a nested cleanup wrapper

## Pass family and scheduler placement

`pass.cpp` exposes one production pass name here:

- `duplicate-import-elimination`

The default global optimization post-pass cluster uses it after the second `duplicate-function-elimination`.

In the canonical no-DWARF `-O` / `-Os` path documented in this repo, the pass appears:

- after `duplicate-function-elimination`
- before `simplify-globals-optimizing`
- before `remove-unused-module-elements`
- before `string-gathering`
- before `reorder-globals`
- before `directize`

A practical scheduler inference is:

- later late-module passes see fewer imported-function aliases and fewer function names referring to the same host binding.

## Saved `-O4z` local evidence

The saved generated-artifact audit and debug log add two useful local facts:

- the pass is a real top-level skipped slot in the saved `-O4z` path:
  - slot `51`
- the pass is tiny in the captured Binaryen run:
  - `2.133e-05` seconds

So the implementation challenge is exactness, not scale.

## Real algorithm

## 1. Gather imported functions

The pass constructs:

- `ImportInfo imports(*module);`

but then only iterates:

- `imports.importedFunctions`

This is the first place the older broad dossier went wrong: the helper knows about many import kinds, but the pass chooses only imported functions.

## 2. Bucket by `(module, base)`

The pass keeps:

- `std::map<std::pair<Name, Name>, Name> seen;`

where the key is:

- the import module string,
- the import base/field string.

So the first step of duplicate detection is not a rich cross-kind type object. It is just a string pair.

## 3. Check exact function-type equality

When a later imported function hits an existing `(module, base)` bucket, the pass fetches the first-seen function for that bucket and checks:

- `previousFunc->type == func->type`

That is the merge gate.

Beginner translation:

- same host module + same host field + same function type => merge
- same host module + same host field + different function type => keep both

## 4. Keep the first import seen

If the function matches, Binaryen records:

- replacement from later function name to first function name
- later function name in `toRemove`

So the canonical representative is just the first imported function seen for the bucket.

This is deterministic and worth preserving in Starshine's active implementation.

## 5. Rewrite function-name users via `replaceFunctions(...)`

If any duplicates were found, the pass does:

- `module->updateMaps()`
- `OptUtils::replaceFunctions(...)`

That helper rewrites only the function-name surface:

- `call`
- `ref.func`
- module-code `call` / `ref.func`
- `start`
- function exports

This is the second main place the older dossier over-attributed behavior from nearby helpers.
Current `version_129` does **not** use sibling replace helpers for globals, tables, or memories here.

## 6. Remove duplicate imported functions immediately

After rewrites, the pass removes the later imported function declarations directly with:

- `module->removeFunction(name)`

So alias collapse is completed inside the pass itself.
It is not deferred to `remove-unused-module-elements`.

## What the pass does not use

This pass is notable for what it avoids.

It does **not** use:

- `EffectAnalyzer`
- CFG or dominance reasoning
- liveness
- refinalization
- fixpoint iteration
- broad import-type variant equality
- non-function replacement helpers
- nested reruns

A faithful implementation should stay correspondingly small.

## Shipped test contract

The dedicated test pair proves exactly the function-only surface.

The input test covers:

- duplicate imported functions `$foo` and `$bar`
- same module/base but different-signature imported function `$wrong`
- element contents using both duplicate names
- `start $bar`
- direct calls to `$foo`, `$bar`, and `$wrong`

The checked output proves:

- `$bar` is removed
- `$wrong` is preserved
- element contents become `$foo $foo`
- `start` becomes `$foo`
- direct calls to `$bar` become calls to `$foo`

There are no dedicated positive tests here for imported globals, tables, or memories because the current pass does not implement those families.

## Easy-to-misunderstand points

## 1. Nearby helper breadth is not pass breadth

`ImportInfo` knows about imported globals, tables, memories, and tags.
That does **not** mean `DuplicateImportElimination.cpp` uses all of them.

## 2. The duplicate key is not the older dossier's broad `ImportInfo(kind,module,base,type)` story

The real pass uses:

- `(module, base)` bucket key
- exact function-type equality only when the bucket collides

## 3. The rewrite surface is only function names

Because the pass uses only `replaceFunctions(...)`, the real rewrite surface is far narrower than the older folder claimed.

## 4. The public name is broader than the current implementation

`duplicate-import-elimination` sounds like it handles every import kind.
The source-confirmed reality in `version_129` is smaller.

## Starshine parity checklist

Starshine now has an active module-pass implementation, so read this as the ongoing parity/maintenance checklist rather than future-port scaffolding.

- Keep this a late module pass.
- Keep duplicate imported-function elimination as the Binaryen `version_129` parity scope.
- Bucket candidates by `(module, base)`.
- Require exact function-type equality before merging.
- Preserve first-import-wins canonicalization.
- Rewrite only the function-name surface Binaryen actually rewrites:
  - `call`
  - `ref.func`
  - module-code `call` / `ref.func`
  - start
  - function exports
- Remove duplicate imported functions immediately.
- If Starshine later widens the pass to globals/tables/memories, document that as a deliberate divergence or future-upstream drift, not as current `version_129` behavior.
