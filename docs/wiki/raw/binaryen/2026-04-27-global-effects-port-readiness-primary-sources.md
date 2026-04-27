# Binaryen `generate-global-effects` / Starshine `global-effects` port-readiness primary-source capture

_Capture date:_ 2026-04-27  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/global-effects/starshine-port-readiness-and-validation.md` bridge

## Scope

This file captures the primary sources rechecked while deepening the `global-effects` dossier from source-correct overview coverage into a concrete Starshine implementation-readiness and validation bridge. Use the living pages for teaching prose:

- `docs/wiki/binaryen/passes/global-effects/index.md`
- `docs/wiki/binaryen/passes/global-effects/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-effects/metadata-naming-and-consumers.md`
- `docs/wiki/binaryen/passes/global-effects/starshine-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/discard-global-effects/index.md`

## Official Binaryen sources rechecked

- `GlobalEffects.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `effects.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `wasm.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- Optimizer lifecycle documentation:
  - <https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook>
- representative lit proof files:
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-global-effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-effects_simplify-locals.wast>

## Source-backed observations from the 2026-04-27 recheck

- Current `main` still keeps `generate-global-effects` as a public producer pass and `discard-global-effects` as the explicit cleanup/lifecycle sibling.
- The useful teaching distinction remains unchanged: `generate-global-effects` writes metadata, while visible WAT rewrites show up only when later consumers such as `vacuum` or `simplify-locals` consult that metadata.
- The current-main implementation shape remains SCC/component-oriented, while the tagged `version_129` teaching contract remains shallow per-function effect scan, direct-callee collection, unknown/opaque-call conservatism, recursive-cycle conservatism, and per-function summary storage.
- `effects.h` remains the consumer bridge: later `EffectAnalyzer` call queries can use stored callee summaries when present.
- `wasm.h` remains the storage oracle: the summary is per-function metadata, not pass-local state and not a textual custom section.
- The Optimizer Cookbook remains relevant for lifecycle framing: passes that invalidate function effects need to declare that they add effects, and existing effects may be discarded automatically. That supports keeping `discard-global-effects` cross-linked from the producer dossier.
- No teaching-relevant upstream drift from the 2026-04-24 / 2026-04-25 captures was found. The new durable gap was Starshine sequencing: how to move from today's boundary-only local name to a no-rewrite analyzer, then to stored module-level summaries, then to consumers.

## Local Starshine surfaces rechecked

- `src/passes/optimize.mbt`
  - `pass_registry_boundary_only_names()` includes `global-effects`
  - `run_hot_pipeline_expand_passes(...)` rejects boundary-only requests before module-pass dispatch
  - active module passes use `HotPassRegistryCategory::ModulePass`, so a future `global-effects` implementation must change registry category before it can run
- `src/passes/pass_manager.mbt`
  - `run_hot_pipeline_apply_module_pass(...)` dispatches active module passes by name and currently has no `global-effects` case
- `src/cli/cli_test.mbt`
  - CLI parsing accepts `--global-effects` and normalizes it to the pass flag, but this is parse coverage only
- `src/ir/effects.mbt`
  - HOT effect masks include call, throw, trap, local, global, memory, and table bits
  - `HotOp::GlobalGet` and `HotOp::GlobalSet` currently collapse to one coarse `EFFECT_MASK_GLOBAL_STATE` bit
- `src/ir/analysis_cache.mbt`
  - `HotEffectsSummary` stores node, block, and root-region masks keyed by HOT revision
  - cache invalidation is function-local, not persistent module metadata
- `src/passes/pass_common.mbt`
  - `pass_require_effects(...)` builds and times the local HOT effects analysis for individual functions
- `src/lib/types.mbt`
  - the stable instruction model already represents direct calls, indirect calls, `call_ref`, return-call variants, and global get/set, which are the minimum source shapes a module-level analysis must scan

## Uncertainties and non-goals

- This capture does not choose whether Starshine should model Binaryen's tagged reachability algorithm exactly or jump straight to a current-main-style SCC component solver. The living bridge recommends starting with an analyzer-only SCC-shaped design because it is easier to validate and closer to the current upstream structure, but Binaryen parity should still be compared against a selected tagged oracle.
- Starshine's current `EffectMask` vocabulary is coarser than Binaryen's per-global read/write summaries. Reusing it directly would be useful for a first no-rewrite safety check but insufficient for full consumer precision.
- No Starshine implementation was added in this documentation run. The local pass remains boundary-only until registry, storage, dispatcher, and consumer work land together.
