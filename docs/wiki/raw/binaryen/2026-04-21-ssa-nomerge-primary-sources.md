# Binaryen `ssa-nomerge` primary-source capture

_Capture date:_ 2026-04-21  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/ssa-nomerge/` dossier

## Scope

This file captures the exact primary online sources consulted for the Starshine `ssa-nomerge` strategy follow-up.
It is intentionally small and provenance-heavy rather than a prose reinterpretation of the pass.
Use the living dossier pages for explanation:

- `docs/wiki/binaryen/passes/ssa-nomerge/index.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/merge-shapes-and-canonical-slots.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/wat-shapes.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/parity.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-21 with publish date shown as **2026-01-23**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-21.
  - Important uncertainty preserved: the visible releases index also showed a newer-by-date page entry for **`version_125` on 2026-04-08**, so this run does **not** claim `version_129` is the latest global Binaryen release. The `ssa-nomerge` dossier still uses `version_129` because its checked source/test surfaces remain the tagged oracle already referenced by the existing wiki, and the reviewed `main` file surfaces still match those tagged `ssa-nomerge`-relevant sources.

### Official source files consulted

- `SSAify.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
- `LocalGraph.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/LocalGraph.cpp>
- `ReFinalize.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/ReFinalize.cpp>

### Official test files consulted

- Dedicated no-merge golden input:
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/ssa-nomerge_enable-simd.wast>
- Dedicated no-merge golden output:
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.txt>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/ssa-nomerge_enable-simd.txt>
- Shared `SSAify` helper surface:
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast>

## Durable observations from the captured sources

- `pass.cpp` registers both `ssa` and `ssa-nomerge`, with `ssa-nomerge` described as SSA-ifying variables while ignoring merges.
- `SSAify.cpp` implements both public passes through one shared `SSAify` engine with an `allowMerges` policy split.
- The dedicated `ssa-nomerge_enable-simd` test pair remains the smallest official file that directly locks the no-merge behavior.
- On the exact `ssa-nomerge`-relevant surfaces reviewed in this run, `main` still matched the tagged `version_129` files.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.