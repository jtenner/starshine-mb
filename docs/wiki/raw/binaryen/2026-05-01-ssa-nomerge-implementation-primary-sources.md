# Binaryen `ssa-nomerge` implementation primary-source refresh

_Capture date:_ 2026-05-01  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/ssa-nomerge/` implementation/test-map refresh

## Scope

This source capture refreshes the implementation-structure view for the existing `ssa-nomerge` dossier. It does not replace the earlier 2026-04-21 semantic source capture; it adds a focused owner-file/test-surface map so readers can connect the Binaryen algorithm, Starshine code map, and local validation evidence without searching chat history.

Living pages updated from this manifest:

- `docs/wiki/binaryen/passes/ssa-nomerge/index.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/parity.md`

## Official online sources consulted

### Upstream Binaryen tagged oracle

- `src/passes/SSAify.cpp`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SSAify.cpp>
- `src/ir/local-graph.h`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/local-graph.h>
- `src/ir/LocalGraph.cpp`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp>
- `src/ir/ReFinalize.cpp`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
- `src/passes/pass.cpp`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>

### Official test surfaces

- Dedicated no-merge test input:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.wast>
- Dedicated no-merge golden output:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.txt>
- Shared full-SSA lit surface:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast>
- LocalGraph gtest surface:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/gtest/local-graph.cpp>

### Current-main spot-check surfaces

The existing 2026-04-21 dossier recorded a narrow no-drift result for the relevant `main` surfaces. This refresh did not discover a new teaching-relevant contradiction in the official source URLs already tracked by that dossier; treat `version_129` as the tagged oracle and this manifest as a structure/test-map refresh, not as a claim about every later Binaryen release.

## Durable observations

- `SSAify.cpp` is the sole implementation owner for both `ssa` and `ssa-nomerge`; the public split is the `allowMerges` constructor flag.
- The owner file itself documents the no-merge variant as a pass that ignores merge-leading sets and creates fresh indexes only where that untangles locals without new overlapping-copy lifetimes.
- The run order is short and stable: build `LocalGraph`, compute set influences, compute SSA indexes, allocate fresh indexes, rewrite gets or full-SSA phis, add prepends, and run `ReFinalize` only when needed.
- `local-graph.h` is part of the proof surface because `ssa-nomerge` depends on `getSets`, `getSetInfluences`, `nullptr` entry/default sources, and `computeSSAIndexes` rather than a syntactic local-set/get scan.
- `LocalGraph.cpp` owns the control-flow walk that makes those sets meaningful across structured control.
- `ReFinalize.cpp` is only a narrow repair dependency for default reference replacement; it is not a second rewrite algorithm.
- `pass.cpp` and `passes.h` prove the public pass names and scheduler-facing constructors.
- `test/passes/ssa-nomerge_enable-simd.wast` plus `.txt` remain the strongest dedicated upstream proof surface for the no-merge variant.
- `test/lit/passes/ssa.wast` and `test/gtest/local-graph.cpp` are supporting surfaces for shared helper behavior, not direct evidence that `ssa-nomerge` materializes full-SSA merge locals.

## Starshine-local code surfaces rechecked

The implementation-structure page also cites the current local code map:

- `src/passes/ssa_nomerge.mbt`
- `src/ir/ssa_destroy.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/ssa_nomerge_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

The key local conclusion remains a deliberate scope distinction: Starshine's active pass is a HOT-SSA destruction plus raw-fallback family that can emit predecessor-copy traffic, while upstream Binaryen `ssa-nomerge` deliberately skips merge materialization.

## Uncertainties and caveats

- This manifest preserves `version_129` as the tagged oracle because that is the source base used by the existing pass wiki. It does not claim `version_129` is the newest Binaryen release.
- The current-main check is narrow and pass-surface-focused; future wiki work should re-open the official URLs before making any broad “latest Binaryen” claim.
- Starshine's local implementation is intentionally not described as a faithful source clone of `SSAify(false)`; the strategy page should continue treating local predecessor-copy lowering as a local representation choice, not an upstream behavior.
