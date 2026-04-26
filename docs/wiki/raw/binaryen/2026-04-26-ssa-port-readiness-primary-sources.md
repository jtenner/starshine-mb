# Binaryen `ssa` port-readiness primary sources

Date captured: 2026-04-26

## Scope

Focused current-main and Starshine-facing port-readiness recheck for Binaryen's public full `ssa` pass after the existing tagged `version_129` dossier in `docs/wiki/raw/binaryen/2026-04-24-ssa-primary-sources.md`.

This manifest is intentionally narrow. It does not replace the tagged source manifest; it records the official source surfaces and local implementation-readiness conclusions needed to add a dedicated Starshine validation bridge for full `ssa`.

## Primary online sources checked

Official Binaryen repository sources:

- `src/passes/SSAify.cpp` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp>
- `src/passes/SSAify.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp>
- `src/passes/pass.cpp` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/passes/pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `src/passes/passes.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/ir/local-graph.h` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
- `src/ir/LocalGraph.cpp` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/LocalGraph.cpp>
- `src/ir/ReFinalize.cpp` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/ReFinalize.cpp>
- `test/lit/passes/ssa.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/ssa.wast>
- `test/gtest/local-graph.cpp` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/gtest/local-graph.cpp>
- sibling contrast test `test/passes/ssa-nomerge_enable-simd.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/ssa-nomerge_enable-simd.wast>

## Source locations that matter

- `src/passes/SSAify.cpp` owns the shared `SSAify(bool allowMerges)` implementation for `ssa` and `ssa-nomerge`; `allowMerges = true` is the full `ssa` mode.
- `src/passes/pass.cpp` publishes both pass spellings and keeps the default no-DWARF optimize path on `ssa-nomerge`, not full `ssa`.
- `src/passes/passes.h` exposes `createSSAifyPass()` and `createSSAifyNoMergePass()`, proving the sibling split is public API.
- `src/ir/local-graph.h` and `src/ir/LocalGraph.cpp` define the reaching-set proof model, including the `nullptr` implicit-entry source that full `ssa` must treat differently for params versus ordinary defaultable locals.
- `src/ir/ReFinalize.cpp` is the narrow repair dependency when default ref/null replacement sharpens parent expression types.
- `test/lit/passes/ssa.wast` is the direct public lit oracle for repeated-param splitting plus default ref/tuple replacement; the merge-local and entry-prepend families remain source-derived from `SSAify.cpp` rather than isolated in that small lit file.

## Current-main drift result

No teaching-relevant drift was found from the 2026-04-24 `version_129` dossier:

- full `ssa` remains the same shared `SSAify.cpp` engine as `ssa-nomerge` with merges enabled;
- multi-source gets still materialize merge locals rather than leaving reads on canonical slots;
- explicit incoming sets still feed merge locals by wrapping set values with `local.tee`;
- parameter-entry incoming sources still need function-entry prepends;
- ordinary defaultable-local entry sources still rely on the fresh merge local's default value instead of a prepended zero/null store;
- the direct lit surface remains much smaller than the full source-derived merge contract.

## Starshine-facing port-readiness conclusions

A faithful Starshine full-`ssa` port should be treated as a new public sibling, not an alias for the implemented `ssa-nomerge` pass:

1. add an explicit known registry status for `ssa` before implementing rewrites, while keeping presets on `ssa-nomerge` unless a parity path requires the full sibling;
2. decide whether to reuse `HotLocalSsa` facts directly or add a Binaryen-shaped reaching-set view that can distinguish explicit writes, parameter-entry values, ordinary default-entry values, and nondefaultable defaults at each `local.get`;
3. implement full-`ssa` merge-local materialization as its own rewrite surface instead of relying on current predecessor-copy SSA destruction;
4. preserve the Binaryen shape choice that explicit incoming definitions become `local.tee mergeLocal value`, not separate after-the-fact copies;
5. add entry prepends only for parameter-entry incoming sources;
6. prove defaultable ordinary entry sources through the fresh local's default value and leave nondefaultable entry cases untouched when no sound default exists;
7. keep validation focused on direct `ssa.wast` families first, then add source-derived merge-local / entry-prepend cases, then run Binaryen oracle comparison with `--ssa`.

## Local source surfaces checked

Starshine currently exposes `ssa-nomerge`, not full `ssa`:

- `src/passes/optimize.mbt` active registry starts with `ssa-nomerge`; there is no `ssa` entry in the active, module, boundary-only, removed, or preset name sets.
- `src/passes/ssa_nomerge.mbt` uses cached CFG plus `HotLocalSsa` and delegates to `ssa_destroy_into_hot(...)`.
- `src/ir/ssa_local.mbt` builds a local SSA overlay with entry params/defaults and block phis.
- `src/ir/ssa_destroy.mbt` lowers phis through concrete-local assignment and predecessor copies, which is useful infrastructure but not Binaryen full-`ssa`'s merge-local + incoming-tee encoding.
- `src/passes/ssa_nomerge_test.mbt` has branch-join predecessor-copy tests for the implemented sibling that should remain stable if full `ssa` is added.

## Uncertainty and caveats

- This was a focused source-location and drift recheck, not a line-by-line transcript of upstream current `main`.
- Binaryen can drift after 2026-04-26; refresh this manifest before coding the pass.
- Starshine's HOT SSA overlay already models phis, but this manifest deliberately treats that as reusable infrastructure, not proof that the public Binaryen `ssa` contract is already implemented locally.
