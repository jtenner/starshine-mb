# Binaryen `reorder-functions` primary-source and Starshine follow-up

_Date:_ 2026-04-24  
_Status:_ absorbed into living wiki pages  
_Main pages:_ `docs/wiki/binaryen/passes/reorder-functions/`

## Question

The `reorder-functions` dossier already had a landing page, Binaryen strategy page, implementation/test map, count-surface page, and module-shape catalog, but it still lacked two things required by the current pass-wiki quality bar:

1. an immutable raw primary-source manifest for the reviewed upstream sources, and
2. a dedicated Starshine strategy/status page that tells readers exactly where the current repository implements or rejects the pass.

This follow-up closes that gap without changing the underlying source-confirmed `version_129` interpretation from the earlier 2026-04-21 notes.

## Local overlap check

Before writing, I re-read or inspected:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/raw/research/`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/reorder-functions/`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/lib/types.mbt`
- `src/passes/duplicate_function_elimination.mbt`
- `agent-todo.md`

The overlap check showed that updating the existing `reorder-functions` folder was better than creating a new page family. The pass already had a good source-confirmed explanation; the missing durable pieces were provenance and the Starshine bridge.

## Primary sources captured

Added:

- `docs/wiki/raw/binaryen/2026-04-24-reorder-functions-primary-sources.md`

The captured official sources are:

- Binaryen GitHub release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen releases index: <https://github.com/WebAssembly/binaryen/releases>
- `version_129` `src/passes/ReorderFunctions.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp>
- current `main` `src/passes/ReorderFunctions.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>
- `version_129` `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- current `main` `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `version_129` `test/lit/passes/reorder-functions-by-name.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast>
- current `main` `test/lit/passes/reorder-functions-by-name.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-functions-by-name.wast>
- `version_129` pass-test directory listing: <https://api.github.com/repos/WebAssembly/binaryen/contents/test/lit/passes?ref=version_129>
- current `main` pass-test directory listing: <https://api.github.com/repos/WebAssembly/binaryen/contents/test/lit/passes?ref=main>

## Source-backed findings retained

The follow-up preserves the existing contract rather than inventing a larger pass:

- `ReorderFunctions.cpp` owns both `reorder-functions` and `reorder-functions-by-name`.
- `reorder-functions` is a static function-declaration orderer, not a body optimizer and not a profile-guided hotness pass.
- Counted surfaces in the reviewed `version_129` source are direct `call`, start function, function export, and element-segment function names.
- `ref.func`, declaration-section mentions, `call_ref`, and `call_indirect` target inference are not counted by the reviewed source. The `ref.func` and declaration omissions are explicit upstream TODOs, so they should not be smoothed over.
- The sort rule is descending count, then descending function name.
- The sibling `reorder-functions-by-name` sorts ascending by name and has the direct dedicated lit file.
- The reviewed official release page showed `version_129` publish date **2026-04-01 14:31** on 2026-04-24.
- A narrow current-`main` spot check did not surface teaching-relevant drift for the reviewed owner, registration, sibling-test, or dedicated-test-list surfaces.

## Starshine status added

Added:

- `docs/wiki/binaryen/passes/reorder-functions/starshine-strategy.md`

Current local status recorded there:

- `src/passes/optimize.mbt` registers `reorder-functions` as a boundary-only name.
- `src/passes/optimize.mbt` also registers the sibling `reorder-functions-by-name` as boundary-only.
- `src/passes/pass_manager.mbt` has no module-pass dispatch case for `reorder-functions`.
- The public `optimize` and `shrink` preset arrays do not include `reorder-functions`.
- `agent-todo.md` has no dedicated active implementation slice for `reorder-functions`.
- `src/lib/types.mbt` shows why a future Starshine port is not a pure vector sort: Starshine stores function references as numeric `FuncIdx` values across calls, exports, start, element expressions, globals/tables, annotations, and section pairs such as `FuncSec` / `CodeSec`.
- `src/passes/duplicate_function_elimination.mbt` already contains the closest in-tree function-index remap machinery, but a future `reorder-functions` port would need a permutation-preserving module layout pass rather than DFE's canonical-survivor merge/remap.

## Uncertainties and boundaries

- The GitHub directory listing only supports the narrow claim that no dedicated plain `reorder-functions.wast` file appeared in the reviewed `test/lit/passes` directory listing. It does not prove the whole Binaryen repository has no indirect coverage for the pass.
- The Binaryen source works with named function references inside Binaryen IR, so source-level function bodies do not need rewriting. Starshine's current lowered module model uses numeric function indices, so a local implementation would need to rewrite references when changing declaration/index order. The new Starshine page makes this local-only adaptation explicit.
- This follow-up did not implement the pass. It only files the provenance and planning/status bridge.

## Living pages updated

- `docs/wiki/binaryen/passes/reorder-functions/index.md`
- `docs/wiki/binaryen/passes/reorder-functions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-functions/count-surfaces-ordering-and-omissions.md`
- `docs/wiki/binaryen/passes/reorder-functions/module-shapes.md`
- `docs/wiki/binaryen/passes/reorder-functions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Durable conclusion

`reorder-functions` is now a complete living wiki dossier by the current pass-wiki standard: overview, transformed module shapes, Binaryen strategy, implementation/test map, focused count-surface page, raw primary-source manifest, and a dedicated Starshine status/port-strategy page with exact local code pointers.
