# Binaryen `global-effects` current-main line-anchor refresh

_Status:_ immutable current-main source-anchor refresh for the `docs/wiki/binaryen/passes/global-effects/` dossier

This note records the official Binaryen `main` line anchors that support the existing `global-effects` / `generate-global-effects` teaching contract and the exact local Starshine code-map anchors that still matter for the living dossier.

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
- downstream lit checks
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-global-effects.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-effects_simplify-locals.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-effects_simplify-locals.wast>

## Current-main line anchors

- `GlobalEffects.cpp#L1006-L1035` - stale `PassOptions` wording plus the shallow `FuncInfo` setup shell
- `GlobalEffects.cpp#L1046-L1155` - parallel shallow scan plus direct-call and unknown-call classification
- `GlobalEffects.cpp#L1329-L1530` - SCC/component propagation plus per-function `Function.effects` writeback
- `pass.cpp#L2475-L2480` - `discard-global-effects` registration
- `pass.cpp#L2558-L2561` - `generate-global-effects` registration
- `pass.cpp#L3687-L3692` - explicit note that the pass stays out of the default optimize sequence
- `effects.h#L3479-L3525` - direct-call consumer lookup on `Call`

## Local Starshine anchors that still matter

- `src/passes/optimize.mbt:127-137` - boundary-only registry names include `global-effects`
- `src/passes/optimize.mbt:315-318` - boundary-only registry entries are materialized into the hot registry
- `src/passes/optimize.mbt:525-531` - boundary-only requests are rejected from the hot pipeline
- `src/cmd/cli_test.mbt:207-210` - CLI parsing accepts `--global-effects`
- `src/cmd/cmd.mbt:1721-1731` - `optimize_module_with_pass_flags(...)` hands pass flags into the hot pipeline
- `src/cmd/cmd.mbt:1919-1923` - pass-flag pipeline resolution stays explicit
- `src/passes/pass_common.mbt:118-120` - local hot-analysis requests route through `pass_require_effects(...)`
- `src/passes/pass_common.mbt:318-338` - the shared effects-analysis helper builds and caches function-local summaries
- `src/ir/analysis_cache.mbt:19-23` - `HotEffectsSummary` owns the cached effect masks
- `src/passes/simplify_locals.mbt:4413-4607` - the simplify-locals family consumes the shared effects cache and exposes the no-tees/no-structure sibling
- `src/passes/heap_store_optimization.mbt:2224-2234` - HSO also depends on the shared effects cache

## Recheck result

The 2026-05-05 spotcheck did not change the teaching contract:

- `global-effects` remains a metadata-producing pass, not a WAT-rewriting pass
- the upstream public name remains `generate-global-effects`
- the pass is still not part of the default optimize sequence
- `discard-global-effects` remains the sibling lifecycle clue
- the current Starshine status remains boundary-only until a real module-level metadata pass exists

## Source provenance

- [`../research/0490-2026-05-05-global-effects-current-main-line-anchor-refresh.md`](../research/0490-2026-05-05-global-effects-current-main-line-anchor-refresh.md)
