# Binaryen `global-effects` current-main recheck

_Status:_ immutable focused source recheck and code-map refresh for the `docs/wiki/binaryen/passes/global-effects/` dossier

This file captures a 2026-05-05 current-`main` recheck of the upstream `global-effects` surfaces. It narrows the earlier 2026-04-27 bridge to two questions:

- did current `main` drift in any teaching-relevant way from the existing Binaryen `version_129` contract?
- did the exact local Starshine code anchors used by the living dossier need a refresh?

## Pages this manifest supports

- `docs/wiki/binaryen/passes/global-effects/index.md`
- `docs/wiki/binaryen/passes/global-effects/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/global-effects/metadata-naming-and-consumers.md`
- `docs/wiki/binaryen/passes/global-effects/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-effects/starshine-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/starshine-port-readiness-and-validation.md`

## Primary sources rechecked

- `GlobalEffects.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `effects.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `wasm.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- dedicated lit tests
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-global-effects.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-effects_simplify-locals.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-effects_simplify-locals.wast>

## Recheck result

The reviewed current-`main` sources still support the same teaching-level contract as the existing dossier:

- the pass still computes per-function summaries instead of rewriting WAT directly;
- the reviewed `pass.cpp` still keeps `generate-global-effects` outside the default optimize sequence;
- `GlobalEffects.cpp` still models shallow local effects plus transitive call propagation, with current-main SCC aggregation as the implementation shape;
- the stale `PassOptions` wording remains a comment-vs-implementation mismatch, not a behavior change;
- the downstream consumer tests still prove the same `vacuum` and `simplify-locals` payoff shapes.

No teaching-relevant current-`main` drift was recorded for the reviewed upstream contract.

## Local code-map refresh

The 2026-05-05 recheck also confirmed that the local Starshine anchors used by the living dossier still point at the same surfaces:

- `src/passes/optimize.mbt:127-137`
- `src/passes/optimize.mbt:307-308`
- `src/passes/optimize.mbt:481-487`
- `src/cli/cli_test.mbt:207-210`
- `src/passes/pass_manager.mbt:8661-8687`
- `src/ir/effects.mbt:5-32`
- `src/ir/analysis_cache.mbt:19-23`
- `src/passes/pass_common.mbt:318-338`
- `src/passes/simplify_locals.mbt`
- `src/passes/heap_store_optimization.mbt`

## Source provenance

- [`../../research/0480-2026-05-05-global-effects-current-main-recheck.md`](../../research/0480-2026-05-05-global-effects-current-main-recheck.md)
