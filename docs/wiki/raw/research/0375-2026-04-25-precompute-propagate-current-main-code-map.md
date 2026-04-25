---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md
  - ../binaryen/2026-04-24-precompute-propagate-primary-sources.md
  - ./0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md
  - ./0198-2026-04-21-precompute-propagate-worklist-followup.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/precompute.mbt
  - ../../../../src/passes/pass_manager.mbt
related:
  - ../../binaryen/passes/precompute-propagate/index.md
  - ../../binaryen/passes/precompute-propagate/starshine-strategy.md
  - ../../binaryen/passes/precompute-propagate/local-worklist-fallthrough-and-merge-boundaries.md
  - ../../binaryen/passes/precompute/index.md
---

# `precompute-propagate` current-main and code-map refresh

## Question

The `precompute-propagate` dossier already had overview, Binaryen strategy, implementation/test-map, shape, worklist-boundary, and Starshine status pages. The remaining health gap was practical navigation: the tracker still marked the folder as only `dossier`, the Starshine strategy page named local files and functions without exact line ranges, and the most recent source manifest was a 2026-04-24 tagged-source capture rather than a 2026-04-25 current-main recheck.

## Sources checked

The primary-source manifest is [`../binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md`](../binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md). It rechecked official Binaryen current-`main` and `version_129` sources for:

- `src/passes/Precompute.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/ir/local-graph.h`
- `src/ir/properties.h`
- `src/wasm-interpreter.h`
- `test/lit/passes/precompute-propagate-partial.wast`
- `test/lit/passes/precompute-propagate_all-features.wast`

Local Starshine navigation was rechecked in:

- `src/passes/optimize.mbt`
- `src/passes/precompute.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/registry_test.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/precompute_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Findings

### Binaryen contract is stable enough for the existing dossier

No teaching-relevant current-main drift was found. The existing contract still holds:

- `precompute-propagate` is a public pass name, not just an internal flag.
- The owner remains the shared `Precompute.cpp` family.
- The sibling mode runs ordinary semantic precompute, then a `LazyLocalGraph`-grounded `propagateLocals(...)` phase, then one extra ordinary walk when propagation added `getValues` facts.
- The local propagation layer still depends on fallthrough-value analysis for sets, all-reaching-set consensus for gets, defaultable-local entry zeros, param/nondefaultable-entry bailouts, subtype checks, and a deliberate one-extra-walk stopping rule.
- The scheduler role remains important: higher-aggression top-level paths and `optimizeAfterInlining(...)` use `precompute-propagate`, while the current Starshine modeled no-DWARF top-level path uses plain `precompute` slots.

### Starshine remains explicitly non-implemented for the sibling

Current local code still proves a negative result:

- `src/passes/optimize.mbt:144-151` keeps `"precompute-propagate"` in the removed-name table.
- `src/passes/optimize.mbt:211-215` registers only active plain `"precompute"` for this family.
- `src/passes/optimize.mbt:250-269` expands `optimize` / `shrink` presets with plain `"precompute"` slots, not the sibling.
- `src/passes/optimize.mbt:463-472` rejects removed pass requests before dispatch.
- `src/passes/pass_manager.mbt:8670-8704` has a HOT-dispatch arm for `"precompute"` only.
- `src/passes/precompute.mbt:1095-1166` runs an iterative plain HOT fold/cleanup loop, not Binaryen's `LazyLocalGraph` get/set propagation sibling.

This means future docs should continue to say that plain `precompute` is reusable infrastructure, not a hidden implementation of `precompute-propagate`.

### The folder should be treated as deep

The folder now has all durable pieces expected from a beginner-to-advanced pass dossier:

- pass overview / landing page;
- Binaryen strategy page;
- implementation/test-map page;
- dedicated shape catalog;
- dedicated mechanics page for the hard local-worklist half;
- Starshine status/port strategy page with exact local code ranges;
- current-main raw source manifest and archived research note.

So the tracker should mark `precompute-propagate` as `deep`, not merely `dossier`.

## Updates made

- Added the current-main raw source/code-map manifest.
- Added this numbered research note.
- Refreshed the `precompute-propagate` overview, Binaryen strategy, implementation/test-map, local-worklist guide, WAT-shape catalog, and Starshine strategy pages so they all cite the 2026-04-25 manifest.
- Sharpened the Starshine page from function-name pointers to exact line-range navigation.
- Updated the wiki catalogs and tracker to record that the dossier is now deep and current.

## Health-check result

Focused touched-area hygiene found one stale classification issue: the tracker still marked `precompute-propagate` as `dossier` even though the folder already had multiple supporting pages. The refresh promotes it to `deep` and keeps the local non-implementation wording explicit.

## Remaining uncertainty

This was not a full semantic diff of every `Precompute.cpp` helper. If current `main` later changes evaluator internals in a way that affects plain `precompute`, update the plain `precompute` dossier first and then decide which conclusions carry over to the sibling.
