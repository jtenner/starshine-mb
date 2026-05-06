# Binaryen `local-cse` current-main line-anchor refresh

_Capture date:_ 2026-05-06  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/local-cse/` dossier

## Scope

This file records the official Binaryen source surfaces rechecked while refreshing the `local-cse` dossier's line anchors. It extends the earlier immutable captures in:

- `docs/wiki/raw/binaryen/2026-04-22-local-cse-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-25-local-cse-current-main-code-map.md`
- `docs/wiki/raw/binaryen/2026-05-05-local-cse-current-main-recheck.md`

The recheck did not change the teachable contract: `local-cse` is still the same scan/check/apply temp-local reuse pass for repeated whole trees in limited linear windows.

## Official sources consulted

### Binaryen `main`

- `src/passes/LocalCSE.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalCSE.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/LocalCSE.cpp>
- `src/passes/pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/opt-utils.h>
- `test/lit/passes/local-cse.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-cse.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/local-cse.wast>

### Tagged comparison anchor

- `src/passes/LocalCSE.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalCSE.cpp>
- `src/passes/pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `test/lit/passes/local-cse.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-cse.wast>

## Reviewed source surfaces

The refresh rechecked the same teaching-relevant surfaces already described in the living dossier:

- `LocalCSE.cpp`: pass declaration, windowed scan/check/apply flow, and whole-tree reuse rules.
- `pass.cpp`: public registration and the late cleanup / aggressive-prelude scheduling neighborhoods.
- `opt-utils.h`: nested optimizer rerun hook that makes `local-cse` recur after inlining-oriented changes.
- `local-cse.wast`: repeated arithmetic, load, barrier, and profitability families.

## Durable observations

- No teaching-relevant drift was found on the reviewed current-main surfaces.
- The source-backed contract remains: repeated whole-tree reuse, first-occurrence originals, parent-over-child request cancellation, shallow side-effect and generativity filtering, trap-insensitive invalidation for repeated loads, and the narrow idempotent-direct-call carveout.
- The local Starshine implementation anchors below are the ones the living dossier should use now:
  - `src/passes/local_cse.mbt:1-18` (summary + descriptor)
  - `src/passes/local_cse.mbt:543-559` (module-pass entry)
  - `src/passes/local_cse.mbt:809-816` (direct HotPass entry)
  - `src/passes/local_cse_test.mbt:14-94` (registry + direct behavior tests)
  - `src/passes/optimize.mbt:253,437-449,456-472` (registry and preset gate)
  - `src/passes/pass_manager.mbt:8939-8943` (dispatcher)
  - `src/passes/optimize_test.mbt:510-512,520-527,567-568` (category, preset, and trace proofs)

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
