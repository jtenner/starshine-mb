# Binaryen `local-subtyping` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/local-subtyping/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `local-subtyping` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md` and the earlier research note in `docs/wiki/raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/local-subtyping/index.md`
- `docs/wiki/binaryen/passes/local-subtyping/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-subtyping/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/local-subtyping/lubs-and-dominance.md`
- `docs/wiki/binaryen/passes/local-subtyping/wat-shapes.md`
- `docs/wiki/binaryen/passes/local-subtyping/starshine-strategy.md`

## Official sources consulted

### Binaryen `main`

- `LocalSubtyping.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalSubtyping.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/LocalSubtyping.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `local-subtyping.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-subtyping.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/local-subtyping.wast>

### Tagged comparison anchor

- `LocalSubtyping.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `local-subtyping.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>

## Reviewed source surfaces

The recheck focused on the same teaching-relevant surfaces already documented in the living dossier:

- the pass constructor and scheduler registration in `pass.cpp`
- the owner-file scan/get/refinalize/rewrite loop in `LocalSubtyping.cpp`
- the dedicated lit file families for repeated refinement, dominance, `local.tee`, parameter preservation, and nondefaultable preservation

## Durable observations

- Current `main` still registers `local-subtyping` with the same public description and places it before `coalesce-locals` in the GC/local cleanup neighborhood.
- The owner file still teaches the same contract already captured by the living dossier: reference-local scanning, set/tee-fed LUB selection, get-aware non-null dominance, body-local declaration rewrites, get/tee retagging, and iterative `ReFinalize()` between improvement rounds.
- The official lit surface still contains the same important boundaries: repeated refinement, nondefaultable preservation, parameter preservation, and scheduler-neighborhood behavior.
- No teaching-relevant drift was found on the reviewed current-main surfaces.
- The local Starshine story is unchanged by this source refresh: `local-subtyping` remains removed-registry only, with no active dispatcher case and no implementation file.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
