# `optimize-added-constants` current-main recheck and source-anchor follow-up

## Question

The existing plain `optimize-added-constants` dossier was already correct, but it still lacked a fresh 2026-05-05 source-anchor pass and exact local code locations. What are the concrete source anchors worth filing back into the wiki, and did current-main drift from the reviewed `version_129` contract?

## Findings

- The chosen pass remains the plain `optimize-added-constants` contract, not the propagate sibling.
- The upstream source remains a narrow memory-address canonicalizer:
  - direct `Load` / `Store` pointer folds,
  - constant-pointer normalization,
  - strict low-memory gating,
  - and no local-pair propagation in the plain variant.
- The official Binaryen source file `OptimizeAddedConstants.cpp` is the canonical owner. The important source locations are the header contract summary, `MemoryAccessOptimizer`, `optimizeConstantPointer`, `tryToOptimizeConstant`, `tryToOptimizePropagatedAdd`, `canOptimizeConstant`, `OptimizeAddedConstants::doWalkFunction`, and the two factory functions.
- `pass.cpp` still registers both public pass names, and `pass.h` still defines the `LowMemoryBound` constant that the tests exercise.
- The reviewed current-main source did not show teaching-relevant contract drift from the tagged `version_129` behavior on the reviewed surfaces.

## Wiki changes made from this research

- Added `docs/wiki/raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md`.
- The living plain-pass pages should now cite the new source-anchor digest and the exact local Starshine code locations that already exist in-tree.

## Follow-up conclusions

- The plain pass overview should keep saying “direct memory-address offset folding,” not “generic arithmetic optimization.”
- The Starshine strategy page should point readers at the exact local registry, CLI, command, HOT IR, binary, WAT, and validator files that already carry the required option / memory-op surfaces.
- The propagate sibling should remain a distinct contract in both wording and implementation planning.
