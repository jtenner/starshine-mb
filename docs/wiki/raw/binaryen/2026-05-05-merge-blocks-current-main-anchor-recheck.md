# Binaryen `merge-blocks` current-main anchor recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable source-correction manifest for `docs/wiki/binaryen/passes/merge-blocks/`

## Scope

This capture rechecked the official Binaryen current-main `merge-blocks` surfaces after the 2026-05-04 refresh and corrected the living wiki's stale local line anchors for the Starshine code-map pages.

The upstream teaching model is unchanged: `merge-blocks` remains the helper-driven block-merging / loop-tail-merging pass in `MergeBlocks.cpp`, not a named-block retargeting engine.

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
  - <https://github.com/WebAssembly/binaryen/blob/main/src/wasm/wasm-traversal.h>

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

- The reviewed upstream source still centers on `optimizeDroppedBlock(...)`, `optimizeBlock(...)`, `optimizeIf(...)`, `optimizeThrow(...)`, and `visitFunction(...)`.
- `ProblemFinder` still guards the dropped-block / break-value cleanup path; it is not a label-retargeting proof engine.
- The upstream contract still covers child-block splicing, loop-tail merging, `drop(block ...)` cleanup, `if`-condition motion, and `throw`-operand motion.
- The dedicated lit file still proves the same merged shapes on the reviewed surfaces, and the tag/current-main comparison still shows no teaching-relevant upstream drift.
- The stale part was local documentation metadata: several Starshine code-map pages had drifted from the current in-tree line numbers.

## Local anchor correction

The recheck fixes the living docs to the current repository line map:

- `src/passes/pass_common.mbt:2-45`
- `src/passes/merge_blocks.mbt:2-13`
- `src/passes/merge_blocks.mbt:15-17`
- `src/passes/merge_blocks.mbt:20-32`
- `src/passes/merge_blocks.mbt:34-45`
- `src/passes/merge_blocks.mbt:47-57`
- `src/passes/merge_blocks.mbt:59-77`
- `src/passes/merge_blocks.mbt:79-86`
- `src/passes/merge_blocks.mbt:88-132`
- `src/passes/merge_blocks.mbt:134-232`
- `src/passes/merge_blocks.mbt:234-281`
- `src/passes/merge_blocks.mbt:283-314`
- `src/passes/merge_blocks.mbt:316-335`
- `src/passes/optimize.mbt:249-251`
- `src/passes/optimize.mbt:288-291`
- `src/passes/optimize.mbt:300-303`
- `src/passes/optimize.mbt:444-447`
- `src/passes/optimize.mbt:458-461`
- `src/passes/pass_manager.mbt:9002`

## Supersession note

This capture supersedes the stale local line anchors in the living `merge-blocks` code-map pages. Use it together with the refreshed wiki pages rather than the older anchor ranges.
