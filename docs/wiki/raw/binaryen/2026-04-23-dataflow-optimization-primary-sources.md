# Binaryen `dataflow-optimization` / `dfo` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/dataflow-optimization/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `dataflow-optimization` / `dfo` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/dataflow-optimization/index.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/flat-ir-dataflow-ir-and-boundaries.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/starshine-strategy.md`
- `docs/wiki/binaryen/passes/flatten/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/index.md`
- `docs/wiki/binaryen/passes/souperify/index.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-23.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-23.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier during this run.

### Official source files consulted

- `DataFlowOpts.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DataFlowOpts.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/dataflow/graph.h>
- `node.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/dataflow/node.h>
- `users.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/users.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/dataflow/users.h>
- `utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/dataflow/utils.h>
- `flat.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>

### Official test files consulted

- `flatten_simplify-locals-nonesting_dfo_O3.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page and releases index both showing the release on **2026-04-01**.
- The reviewed upstream implementation still matched the existing living dossier's main teaching claims: hard flat-input gating through `Flat::verifyFlatness`, a narrow integer-local DataFlow side graph, deliberate loop-precision cutoffs, the tiny user-driven worklist, identical-constant-phi collapse, and nested `precompute`-driven constant-expression folding.
- The reviewed helper headers still exposed the same crucial teaching boundaries already captured in the living pages: the synthetic node vocabulary, relevant-type integer filtering, unsupported-op degradation to unknown values, and the small direct helper predicates that define the rewrite surface.
- The reviewed combo lit file still exposed the same main usage story already taught in the living pages: `dfo` is part of a flatten-era aggressive pipeline neighborhood rather than a heavily isolated standalone pass.
- A narrow 2026-04-23 current-`main` spot check on `DataFlowOpts.cpp`, `pass.cpp`, the `dataflow/*` helpers, `flat.h`, and `flatten_simplify-locals-nonesting_dfo_O3.wast` did not surface a new teaching-relevant contract drift beyond the dossier's refreshed claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
