# Binaryen `merge-blocks` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/merge-blocks/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `merge-blocks` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/merge-blocks/index.md`
- `docs/wiki/binaryen/passes/merge-blocks/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-blocks/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-22.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-22.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier during this run.

### Official source files consulted

- `MergeBlocks.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Supporting upstream helper surfaces reviewed for this dossier's narrow control/effect story
  - `branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - `branch-utils.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.cpp>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `wasm-traversal.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-traversal.h>

### Official test files consulted

- `merge-blocks.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass remained a small AST cleanup concentrated in `MergeBlocks.cpp`: a whole-function `ProblemFinder` prescan, tail-child-only block matching, child-name and type gating, a named-child effect barrier, a small splice rewrite, and post-rewrite `ReFinalize`.
- The reviewed dedicated lit file still demonstrated the same teaching-relevant positive and negative families already captured in the living dossier: unnamed tail merges, same-name tail merges, preserved same-name descendant-shadow hazards, and named-child non-merges where retargeting could skip observable work.
- A narrow 2026-04-22 current-`main` spot check on `MergeBlocks.cpp`, `pass.cpp`, and the dedicated `merge-blocks.wast` file did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
