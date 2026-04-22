---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../binaryen/passes/merge-blocks/index.md
  - ../../binaryen/passes/merge-blocks/binaryen-strategy.md
  - ../../binaryen/passes/merge-blocks/wat-shapes.md
  - ../../binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md
  - ../../../../src/passes/merge_blocks.mbt
  - ../../../../src/passes/merge_blocks_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../src/ir/hot_lower_test.mbt
---

# `merge-blocks` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `merge-blocks` dossier already had a useful Binaryen overview, strategy page, and shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy/code-map page
- several catalog pages still described `merge-blocks` as unimplemented even though the pass is active in the current hot-pass registry, presets, tests, and CLI surface

This follow-up closes the provenance gap, adds the missing local strategy page, and repairs the stale implementation-status story across the touched wiki area.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `MergeBlocks.cpp` on `version_129` and `main`
- `pass.cpp`
- the dedicated `merge-blocks.wast` file
- the supporting upstream helper files `branch-utils.*`, `effects.h`, and `wasm-traversal.h`

## Local Starshine code surfaces rechecked

- `src/passes/merge_blocks.mbt`
- `src/passes/merge_blocks_test.mbt`
- `src/passes/optimize.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `src/ir/hot_lower_test.mbt`

## Durable findings

### 1. `merge-blocks` is already an active Starshine hot pass

The living tracker and pass-folder map were stale.
The code now clearly says otherwise:

- `src/passes/optimize.mbt` registers `merge-blocks` as a `HotPass`
- the default `optimize` and `shrink` presets schedule it twice in the late cleanup cluster
- `src/passes/registry_test.mbt` asserts the hot-pass category and descriptor wiring
- `src/passes/optimize_test.mbt` asserts the two preset slots and the `heap2local -> simplify-locals -> merge-blocks` handoff
- `src/cmd/cmd_wbtest.mbt` proves direct `--merge-blocks` CLI acceptance

So the practical documentation gap was not “research an unimplemented pass” anymore.
It was “repair the stale status story and add the missing local strategy/code-map page.”

### 2. The Starshine algorithm is related to Binaryen, but not a direct AST port

Rechecking `src/passes/merge_blocks.mbt` shows the local pass is a HOT-region-root flattener, not an AST tail-child splice port.
The main differences are:

- Starshine flattens branch-free block roots directly out of HOT regions
- it rejects any block whose label is still referenced anywhere in the function
- it has no same-name branch-retargeting path, so it does not need Binaryen's `ProblemFinder` or named-child effect barrier machinery
- it has explicit typed-carrier guards for block params and loop contexts because the HOT lower/writeback contract has to stay Binaryen-stable for typed block/loop lowering
- it preserves dead value work before `unreachable` by rewriting dead suffix values to explicit `drop`s before splicing

So the right teaching frame is “same optimization family, different IR-level proof obligations,” not “Starshine copied `MergeBlocks.cpp` directly.”

### 3. The missing local page mattered because exact code ownership was hard to recover from the old folder

Before this run, a reader could understand the Binaryen side but still have to rediscover where the Starshine pass actually lived.
The new local strategy page fixes that by pointing directly to:

- the descriptor, summary, and entry point in `src/passes/merge_blocks.mbt`
- the flattening helpers and typed-carrier guards in the same file
- preset placement in `src/passes/optimize.mbt`
- preset and registry proof lanes in `src/passes/optimize_test.mbt` and `src/passes/registry_test.mbt`
- CLI coverage in `src/cmd/cmd_wbtest.mbt`
- HOT-lower / Binaryen-stable carrier evidence in `src/ir/hot_lower_test.mbt`

### 4. The Binaryen dossier itself needed provenance, not a full rewrite

The earlier Binaryen pages were still useful and still aligned with the reviewed upstream sources.
The missing piece was provenance:

- on 2026-04-22 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs reviewed in this run
- a narrow current-`main` check did not surface a new teaching-relevant drift beyond the existing Binaryen strategy and shape pages

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/merge-blocks/index.md`
- `docs/wiki/binaryen/passes/merge-blocks/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-blocks/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `merge-blocks` work needs a clean provenance-plus-code-map path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`
2. `docs/wiki/binaryen/passes/merge-blocks/index.md`
3. `docs/wiki/binaryen/passes/merge-blocks/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/merge-blocks/wat-shapes.md`
5. `docs/wiki/binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md`
6. `src/passes/merge_blocks.mbt`
7. `src/passes/merge_blocks_test.mbt`
8. `src/passes/optimize.mbt`
9. `src/passes/optimize_test.mbt`
10. `src/passes/registry_test.mbt`
11. `src/cmd/cmd_wbtest.mbt`
12. `src/ir/hot_lower_test.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, the preset and CLI exposure, the HOT-lower parity constraints, and the explicit statement that Starshine's active pass is a HOT-region-root cleanup port rather than a direct AST-level `ProblemFinder` clone.
