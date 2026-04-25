# Binaryen `untee` current-main recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable freshness and hygiene source manifest for `docs/wiki/binaryen/passes/untee/`

## Scope

This capture refreshes the `untee` dossier without replacing the earlier 2026-04-23 primary-source manifest.
It exists because the living `untee` pages still mixed a 2026-04-23 review date with one stale “2026-04-21 drift check” sentence, and future readers need one clear current-main bridge.

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/untee/index.md`
- `docs/wiki/binaryen/passes/untee/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/untee/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/untee/flattening-code-pushing-and-tee-boundaries.md`
- `docs/wiki/binaryen/passes/untee/wat-shapes.md`
- `docs/wiki/binaryen/passes/untee/starshine-strategy.md`

## Primary sources rechecked

### Official Binaryen release and source

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Earlier observed by this dossier as the tagged release anchor with publish date **2026-04-01**.
- `Untee.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Untee.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Untee.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `SimplifyLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>

### Official Binaryen tests

- `untee.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/untee.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/untee.wast>

## Source locations that matter

- `Untee` declares a function-parallel `PostWalker` and owns the whole transform in `visitLocalSet(...)`.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Untee.cpp#L21-L48>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Untee.cpp#L21-L48>
- The reachable case builds a `local.get` using the function's declared local type, wraps the original node in a sequence, and then turns the original tee into a set.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Untee.cpp#L38-L45>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Untee.cpp#L38-L45>
- The unreachable fast path replaces the tee shell with the unreachable child instead of emitting an impossible get-after-unreachable wrapper.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Untee.cpp#L33-L37>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Untee.cpp#L33-L37>
- `pass.cpp` still registers the public pass name `untee` and its set/get description.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L3317-L3321>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L3317-L3321>
- `passes.h` still declares `createUnteePass()` among normal public pass constructors.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h#L1022-L1026>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h#L1022-L1026>
- The default function optimization roster around `addDefaultFunctionOptimizationPasses()` still does not schedule `untee`; the absence preserves the earlier dossier's non-default teaching.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L3396-L3511>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L3396-L3511>
- The dedicated `untee.wast` file still contains the same proof families: dropped scalar tee, non-integer scalar tee, tee feeding another set, nested tee chain, and unreachable tee deletion.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/untee.wast#L370-L475>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/untee.wast#L370-L475>

## Current-main result

The 2026-04-25 recheck found **no teaching-relevant drift** from the already documented `version_129` contract:

- `untee` remains a tiny `LocalSet` / `local.tee` postwalk pass.
- Reachable tees still expand to explicit `local.set` plus `local.get` form.
- The synthetic get still uses the declared function-local type.
- Unreachable tees still delete the tee shell and preserve the unreachable child.
- The public registration name and description are unchanged.
- The constructor declaration remains present in the normal pass roster.
- The dedicated lit file remains the same small oracle for the main positive and bailout families.
- The pass still does not appear in the reviewed default no-DWARF function optimization roster.

## Hygiene correction recorded by this capture

The previous living pages were materially correct, but one freshness sentence in `binaryen-strategy.md` and `implementation-structure-and-tests.md` still said “2026-04-21 drift check.”
The surrounding folder had already been refreshed on 2026-04-23, so the date mismatch could confuse future readers.
The living pages should now cite this 2026-04-25 recheck when discussing current-main freshness.

## Starshine status source locations

The local status remains unchanged by this source recheck:

- `src/passes/optimize.mbt` still tracks `untee` as a removed pass name.
- `src/passes/optimize.mbt` still rejects removed pass requests before any hot-pipeline execution.
- `src/passes/simplify_locals.mbt` remains only a neighboring locals-rewrite implementation surface, not an `untee` owner.
- `src/passes/pass_manager_wbtest.mbt` still has adjacent-tee-oriented simplify-locals coverage rather than a pass-specific `untee` test lane.
- `agent-todo.md` still has no dedicated `untee` implementation slice.

## Consumability rule

Prefer this capture for current-main freshness claims, and keep citing the 2026-04-23 manifest for the original broad source-provenance capture.
Do not treat the no-drift result as implementation progress in Starshine; it only strengthens the upstream oracle and repairs stale freshness wording.
