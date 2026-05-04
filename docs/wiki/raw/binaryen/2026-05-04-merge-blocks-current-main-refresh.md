# Binaryen `merge-blocks` current-main refresh

_Capture date:_ 2026-05-04  
_Status:_ immutable source-correction manifest for `docs/wiki/binaryen/passes/merge-blocks/`

## Scope

This capture refreshes the living `merge-blocks` dossier against the official Binaryen current-main source and corrects the stale local teaching frame that had drifted toward a named-block deblocking story.

The reviewed upstream pass is still the old block-merging / loop-tail-merging family in `MergeBlocks.cpp`, not a generic label-retargeting pass.

## Official sources consulted

### Current-main primary sources

- `MergeBlocks.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `merge-blocks.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast>
- Supporting helpers used by the pass
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>

### Tagged source oracle

- Binaryen `version_129` release page
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `MergeBlocks.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `merge-blocks.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
- Supporting helpers
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-traversal.h>

## Durable observations

- `MergeBlocks.cpp` is built around `optimizeDroppedBlock(...)`, `optimizeBlock(...)`, `optimizeIf(...)`, `optimizeThrow(...)`, and `visitFunction(...)`.
- `ProblemFinder` is part of the dropped-block / break-value cleanup path, not evidence of a named-block retargeting engine.
- The core rewrite still merges block children into their parent block list when the trailing shape is safe, and it still has loop-tail handling.
- The pass can also move code out of `drop(block ...)`, `if` conditions, and `throw` operands when the source shape is safe enough.
- The dedicated lit file still exercises branch-free child merging, loop-tail cleanup, `if`-condition movement, top-level block-value movement, and the `remove-unused-names --merge-blocks` assumption that blocks without names have no branch targets.
- On the reviewed surfaces, current-main and `version_129` matched; the correction is against the repo's earlier interpretation, not against a new upstream drift.

## Supersession note

This capture supersedes the stale 2026-04-25 named-block deblocking reading in the living dossier. Use it together with the refreshed wiki pages rather than the older interpretation when teaching the pass.
