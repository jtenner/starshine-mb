# Binaryen `local-cse` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/local-cse/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `local-cse` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-22-local-cse-primary-sources.md` and the earlier current-main code map in `docs/wiki/raw/binaryen/2026-04-25-local-cse-current-main-code-map.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/local-cse/index.md`
- `docs/wiki/binaryen/passes/local-cse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-cse/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/local-cse/basic-block-windows-and-barriers.md`
- `docs/wiki/binaryen/passes/local-cse/wat-shapes.md`
- `docs/wiki/binaryen/passes/local-cse/starshine-strategy.md`

## Official sources consulted

### Binaryen `main`

- `LocalCSE.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalCSE.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/LocalCSE.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `opt-utils.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/opt-utils.h>
- `local-cse.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-cse.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/local-cse.wast>

### Tagged comparison anchor

- `LocalCSE.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalCSE.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `local-cse.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-cse.wast>

## Reviewed source surfaces

The recheck focused on the same teaching-relevant surfaces already documented in the living dossier:

- the pass declaration and scheduler registration in `pass.cpp`
- the owner-file scan/check/apply temp-local reuse loop in `LocalCSE.cpp`
- the `optimizeAfterInlining` rerun surface in `opt-utils.h`
- the dedicated lit file families for whole-tree reuse, barriers, generativity, and profitability

## Durable observations

- Current `main` still registers `local-cse` with the same public description and keeps it in the same late local-cleanup / aggressive-prelude neighborhoods.
- The owner file still teaches the same contract already captured by the living dossier: repeated whole-tree reuse in limited linear windows, first-occurrence originals, parent-over-child request cancellation, shallow side-effect and generativity filtering, trap-insensitive invalidation for repeated loads, and the narrow idempotent-direct-call carveout.
- The dedicated lit surface still demonstrates the same high-value positive and negative families already captured in the living dossier.
- No teaching-relevant drift was found on the reviewed current-main surfaces.
- The local Starshine story is unchanged by this source refresh: `local-cse` remains removed-registry only, with no active dispatcher case and no implementation file.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
