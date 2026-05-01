# `ssa-nomerge` implementation-structure wiki refresh

_Date:_ 2026-05-01  
_Status:_ absorbed into living wiki pages

## Question

The `ssa-nomerge` folder already explained the upstream LocalGraph strategy and the local Starshine strategy, but it lacked the now-standard source-owner / test-map page that many neighboring pass dossiers use. That made the folder harder to use for beginner-to-advanced maintenance because readers had to infer which files prove the Binaryen contract, which tests prove the no-merge variant, and which local MoonBit files implement Starshine's intentionally different HOT-SSA destruction strategy.

## Sources reviewed

Primary source manifest added in this run:

- `docs/wiki/raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md`

Existing sources reused:

- `docs/wiki/raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md`
- `docs/wiki/raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md`
- `docs/wiki/raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md`
- `src/passes/ssa_nomerge.mbt`
- `src/ir/ssa_destroy.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/ssa_nomerge_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

Official Binaryen sources cited by the new manifest include `SSAify.cpp`, `local-graph.h`, `LocalGraph.cpp`, `ReFinalize.cpp`, `pass.cpp`, `passes.h`, `ssa-nomerge_enable-simd.wast`, `ssa-nomerge_enable-simd.txt`, `ssa.wast`, and `local-graph.cpp` gtests.

## Findings

- Upstream `ssa-nomerge` still needs to be taught as one shared `SSAify.cpp` owner file with `allowMerges = false`, not as a separate pass body.
- The real supporting implementation surface is broader than `SSAify.cpp`: `LocalGraph` owns the reachability proof, `ReFinalize` repairs default-ref replacements, and pass registration/scheduling lives in `pass.cpp` / `passes.h`.
- The strongest dedicated upstream test surface is `test/passes/ssa-nomerge_enable-simd.wast` plus its golden `.txt`. The shared `ssa.wast` and LocalGraph gtests are supporting helper proof surfaces.
- Starshine's active pass has a materially different owner split: a thin `src/passes/ssa_nomerge.mbt` wrapper delegates to `src/ir/ssa_destroy.mbt`, while `src/passes/pass_manager.mbt` owns raw structured and straight-line fallbacks.
- The local tests now cover direct pass behavior, raw branch/loop/result-typed merge families, debug-artifact replay, and the extracted `Func 523` writeback-skip retirement.

## Living wiki changes made

- Added `docs/wiki/binaryen/passes/ssa-nomerge/implementation-structure-and-tests.md`.
- Updated `docs/wiki/binaryen/passes/ssa-nomerge/index.md` so the page map includes the implementation/test-map page.
- Updated `docs/wiki/binaryen/passes/ssa-nomerge/binaryen-strategy.md` to cite the new manifest and cross-link the implementation page.
- Updated `docs/wiki/binaryen/passes/ssa-nomerge/starshine-hot-ir-strategy.md` to cite the new manifest and sharpen the test/code-map boundary.
- Updated `docs/wiki/binaryen/passes/ssa-nomerge/parity.md` so implementation and validation evidence connect back to the new map.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Caveats

- This run does not claim `version_129` is the latest Binaryen release. It remains the tagged oracle for this dossier, with current-main checks treated as narrow freshness notes only.
- This run does not change Starshine code or pass behavior. It improves wiki usability and reference hygiene around an already implemented pass.
- Starshine remains intentionally different from upstream in representation strategy: local predecessor-copy lowering is Starshine-local and must not be described as Binaryen `ssa-nomerge` behavior.
