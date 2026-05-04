# Binaryen `tuple-optimization` current-main recheck and Starshine maintenance bridge

_Capture date:_ 2026-05-04  
_Status:_ immutable current-main and local code-anchor recheck for the `docs/wiki/binaryen/passes/tuple-optimization/` dossier

## Scope

This file captures the focused primary online sources rechecked on 2026-05-04 while refreshing the `tuple-optimization` dossier.

The tagged `version_129` source manifest in `docs/wiki/raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md` remains the baseline oracle. This bridge answers maintenance questions:

- has current Binaryen `main` changed the teaching-important `tuple-optimization` contract since the earlier source capture?
- which exact local Starshine code anchors should the living pages point at now?
- which local surfaces are implementation anchors and validation anchors rather than a separate upstream story?

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/tuple-optimization/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/tuple-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/tuple-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/tuple-optimization/scheduler-and-gates.md`
- `docs/wiki/binaryen/passes/tuple-optimization/parity.md`
- `docs/wiki/binaryen/passes/tuple-optimization/starshine-strategy.md`
- `docs/wiki/binaryen/passes/tuple-optimization/implementation-map.md`

## Primary source URLs checked

### Official Binaryen current `main`

- `TupleOptimization.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `OptimizeInstructions.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeInstructions.cpp>
- `tuple-optimization.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast>

### Baseline tag retained for comparison

- Existing baseline manifest: `docs/wiki/raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md`
- Representative tagged URLs remain:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>

### Local code anchors rechecked

- `src/passes/tuple_optimization.mbt:97-114`
  - descriptor and summary surface for the active hot pass
- `src/passes/tuple_optimization.mbt:134-241`
  - seed-group discovery and local ownership initialization
- `src/passes/tuple_optimization.mbt:1901-1935`
  - analysis entry points
- `src/passes/tuple_optimization.mbt:4750-5268`
  - rewrite planning, cleanup, and top-level run entry point
- `src/passes/optimize.mbt:407-431`
  - exact-slot prereq helper plus preset omission comment
- `src/passes/pass_manager.mbt:7938-7946`
  - targeted debug trace hook for tuple-group inspection
- `src/passes/pass_manager.mbt:8699`
  - active hot-pass dispatcher arm
- `src/passes/registry_test.mbt:137,172-235`
  - registry category / acceptance tests
- `src/passes/tuple_optimization_wbtest.mbt:120-1109`
  - focused analysis, rewrite, and evidence families
- `src/cmd/cmd_wbtest.mbt:1998-2369`
  - explicit CLI acceptance and lowered-module validity coverage
- `src/cmd/cmd_native_wbtest.mbt:404-1281`
  - direct Binaryen-oracle compare lane for the committed tuple families

## Recheck result

No teaching-relevant current-main drift was found for the existing dossier.

The current `main` surfaces checked on 2026-05-04 still support the same durable contract taught from `version_129`:

- `tuple-optimization` remains a narrow tuple-local scalarization pass, not a general multivalue optimizer.
- The pass still approves only tuple-local writer/reader surfaces, then poisons copy-connected components when any member escapes that contract.
- The pass still splits good tuple locals into fresh scalar locals and rewrites tuple readers and tees accordingly.
- The tuple-specific `OptimizeInstructions.cpp` peephole still handles direct `tuple.extract(tuple.make(...))` cleanup separately.
- The scheduler still places tuple-opt after `code-pushing` and before `simplify-locals-nostructure`, with the direct pass still intentionally excluded from public presets.
- The dedicated `tuple-optimization.wast` lit file still exercises the same narrow positive and negative families.

## Explicit non-changes to preserve in the living pages

The recheck did **not** find evidence to teach any of these as current Binaryen behavior:

- full multivalue lowering as part of `tuple-optimization`;
- CFG / dominance / effects / liveness analysis ownership inside this pass;
- global refinalization as a tuple-opt responsibility;
- treating direct `tuple.extract(tuple.make(...))` as tuple-opt work rather than `OptimizeInstructions.cpp` work;
- public preset enablement;
- a current Starshine implementation in a separate module pass file.

## Starshine maintenance findings from local source review

The local review did not change implementation status: Starshine still has an active direct `tuple-optimization` hot pass and still keeps the pass separate from the public presets.

It did confirm the useful anchor refresh:

- `src/passes/tuple_optimization.mbt:97-114` is the active registry surface and help-text summary.
- `src/passes/tuple_optimization.mbt:134-241` is the seed-group discovery entry surface.
- `src/passes/tuple_optimization.mbt:1901-1935` is the analysis entry surface.
- `src/passes/tuple_optimization.mbt:4750-5268` is the rewrite / run entry surface.
- `src/passes/optimize.mbt:407-431` is the exact-slot helper plus preset omission rule.
- `src/passes/pass_manager.mbt:7938-7946` and `:8699` are the dispatch/debug trace anchors.
- `src/passes/tuple_optimization_wbtest.mbt:120-1109`, `src/cmd/cmd_wbtest.mbt:1998-2369`, and `src/cmd/cmd_native_wbtest.mbt:404-1281` remain the useful behavior and oracle anchors.

Those local surfaces are implementation anchors and validation anchors, not evidence that the upstream `tuple-optimization` contract has changed.

## Remaining caveats

- This was a focused source-surface recheck, not a semantic diff across every Binaryen commit after `version_129`.
- The existing `version_129` manifest remains the tagged source oracle; this file is a current-main no-drift and line-anchor bridge layered on top of it.
- The Starshine registry gap is no longer current for the direct pass, but this source capture remains useful as a maintenance reference for the exact code anchors and validation surfaces.

## Consumability rule

Cite this file when refreshing `last_reviewed`, current-main freshness wording, exact local code-map anchors, or Starshine strategy guidance for `tuple-optimization`.
Do not treat it as a replacement for the `version_129` primary-source manifest; use both together.
