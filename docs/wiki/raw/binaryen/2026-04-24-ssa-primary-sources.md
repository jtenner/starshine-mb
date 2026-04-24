# Binaryen `ssa` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/ssa/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `ssa` provenance and Starshine status follow-up. It is provenance-heavy rather than explanatory; use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/ssa/index.md`
- `docs/wiki/binaryen/passes/ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/ssa/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/ssa/merge-locals-entry-prepends-and-default-values.md`
- `docs/wiki/binaryen/passes/ssa/wat-shapes.md`
- `docs/wiki/binaryen/passes/ssa/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release timestamp as **2026-04-01 14:31** and tag commit `d0e2be9` when observed in this run.

### Official source files consulted

- `src/passes/SSAify.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SSAify.cpp>
  - strategy anchors:
    - shared `SSAify(bool allowMerges)` owner and pass construction surface: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp#L895-L927>
    - function-level run order: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp#L960-L980>
    - fresh-index creation for non-SSA sets: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp#L1016-L1063>
    - get and phi computation, including implicit-entry handling and merge-local allocation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp#L1072-L1202>
    - `local.tee` insertion for explicit incoming sets and entry prepend planning: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp#L1135-L1198>
    - function-entry prepend block construction: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp#L1204-L1223>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SSAify.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - public pass registration anchors:
    - `ssa`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L1264-L1267>
    - `ssa-nomerge`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L1269-L1272>
  - scheduler context anchor for the canonical early no-merge sibling: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L772-L789>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `src/passes/passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - constructor anchors:
    - `createSSAifyPass()`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h#L146-L149>
    - `createSSAifyNoMergePass()`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h#L151-L154>
- `src/ir/local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - LocalGraph contract anchors:
    - reaching-set maps and implicit entry representation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h#L45-L70>
    - already-SSA and influence helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h#L80-L116>
- `src/ir/LocalGraph.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp>
  - flow and helper implementation anchors:
    - set/get location collection: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp#L293-L354>
    - `computeSetInfluences()` and `computeSSAIndexes()`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp#L390-L440>
- `src/ir/ReFinalize.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>

### Official test files consulted

- `test/lit/passes/ssa.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/ssa.wast>
  - behavior anchors:
    - run line and repeated param overwrite coverage: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast#L1-L34>
    - ref-default replacement and refinalization coverage: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast#L36-L72>
    - tuple default replacement coverage: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast#L74-L94>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/ssa.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/ssa.wast>
- `test/gtest/local-graph.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/gtest/local-graph.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/gtest/local-graph.cpp>
- Sibling contrast file, `test/passes/ssa-nomerge_enable-simd.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/ssa-nomerge_enable-simd.wast>

## Durable observations from the captured sources

- `ssa` is a real public Binaryen pass in `version_129`, registered separately from `ssa-nomerge`.
- `ssa` and `ssa-nomerge` share one owner file, `src/passes/SSAify.cpp`; the public split is the `allowMerges` policy used by `SSAify(true)` versus `SSAify(false)`.
- The function-level algorithm builds `LocalGraph`, computes set influences and already-SSA indexes, creates fresh local indexes for non-SSA sets, rewrites gets, optionally materializes merge locals, prepends entry copies when needed, and runs `ReFinalize` only for the narrow reference-default typing repair.
- Full `ssa`'s defining extra surface is multi-source `local.get` handling: allocate a merge local, retarget the get to that local, rewrite explicit incoming set values through `local.tee`, and add function-entry prepends for parameter-entry sources. Defaultable ordinary-local entry sources do not need prepends because fresh locals already start at the default value.
- The dedicated `ssa.wast` file directly proves repeated parameter overwrite splitting plus ref/default and tuple default replacement. The branch-merge local, incoming tee, and entry-prepend families are source-derived from `SSAify.cpp` and helper contracts rather than isolated in the tiny lit file.
- A narrow current-`main` spot check on 2026-04-24 found the same public source/test surfaces (`SSAify.cpp`, `pass.cpp`, and `ssa.wast`) still available. This is not a full trunk-equivalence audit.

## Starshine-specific observations captured with the same source review

- Current Starshine does **not** register a public `ssa` pass name in `src/passes/optimize.mbt`; only `ssa-nomerge` is active.
- Starshine does have a local HOT SSA overlay and destruction layer in `src/ir/ssa_policy.mbt`, `src/ir/ssa_local.mbt`, and `src/ir/ssa_destroy.mbt`.
- The active local `ssa-nomerge` wrapper in `src/passes/ssa_nomerge.mbt` uses that overlay/destruction layer and can lower phis through predecessor copies, which is intentionally not the same surface as upstream Binaryen full `ssa`'s LocalGraph merge-local + `local.tee` materialization.

## Uncertainties and contradictions

- `docs/wiki/raw/research/0207-2026-04-21-ssa-binaryen-research.md` remains valid for the initial source reading, but is superseded for provenance by this immutable raw manifest and by the dedicated `starshine-strategy.md` page for local status.
- The reviewed official `ssa.wast` file is narrow. The living dossier must continue to label merge-local and entry-prepend examples as source-derived, not directly golden-locked by that lit file.
- Starshine's local HOT-SSA destruction has phi/predecessor-copy machinery, but there is no source-confirmed local full-`ssa` pass with Binaryen's exact merge-local/tee/prepend behavior. Treat that as a future-port landing zone, not current parity.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and the 2026-04-24 Starshine follow-up research note.
