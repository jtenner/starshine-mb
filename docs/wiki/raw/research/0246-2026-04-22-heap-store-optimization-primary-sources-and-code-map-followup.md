---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md
  - ../../binaryen/passes/heap-store-optimization/wat-shapes.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ../../../../src/passes/heap_store_optimization.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `heap-store-optimization` primary-source and Starshine code-map follow-up

## Why this follow-up exists

The living `heap-store-optimization` dossier was already a strong beginner-to-advanced explanation after the 2026-04-20 research pass, but two practical gaps remained:

- the folder still lacked an immutable raw primary-source manifest like the newer implemented-pass dossiers now carry
- the local Starshine strategy page still described the implementation accurately at a high level, but it did not yet give readers the exact MoonBit registry / dispatcher / helper-cluster / test map needed for fast code navigation

This follow-up closes that narrower provenance-and-navigation gap without claiming the folder previously lacked a real Binaryen or Starshine dossier.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`

The key reviewed surfaces were:

- official Binaryen GitHub release pages for `version_129`
- `HeapStoreOptimization.cpp` on both `version_129` and `main`
- `pass.cpp`, `cfg-traversal.h`, `effects.h`, `local-graph.h`, and `pass.h`
- the dedicated `heap-store-optimization.wast` lit file on both `version_129` and `main`

### Local Starshine code surfaces re-checked

- `src/passes/heap_store_optimization.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/heap_store_optimization_test.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implied

The earlier dossier already treated `version_129` as the Binaryen oracle, but it did not yet preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

That gives the folder a stable provenance anchor instead of relying only on interpreted living pages.

### 2. The most useful local teaching upgrade was an exact code map

Re-checking the MoonBit implementation confirmed that the cleanest read-along path is:

1. registry descriptor and summary in `src/passes/heap_store_optimization.mbt` plus the public registry tables in `src/passes/optimize.mbt`
2. raw fast-skip and dispatcher handoff in `src/passes/pass_manager.mbt`
3. local safety-predicate, constructor-shape, fold, and wrapper-repair helpers in `src/passes/heap_store_optimization.mbt`
4. focused pass, registry, and CLI replay coverage in the local test files

The older Starshine strategy page was directionally right, but it was too vague about where each part actually lives.

### 3. Current Starshine is best taught as a HOT-region proof stack, not as a hidden Binaryen `LazyLocalGraph` port

The local file still clearly centers on:

- effect-mask reasoning over HOT nodes and regions
- explicit target-local touch checks
- custom `may_skip_local_set` owner-label reasoning
- explicit default and descriptor constructor support
- lifted-prefix peeling, wrapper flattening, label retargeting, and unreachable-tail trimming needed for safe writeback

That code map makes the main local-vs-upstream difference easier to teach honestly:

- upstream Binaryen uses CFG blocks, `EffectAnalyzer`, `ShallowEffectAnalyzer`, and `LazyLocalGraph`
- current Starshine uses HOT traversal, cached subtree predicates, effect masks, owner-label reasoning, and writeback-oriented wrapper repair to preserve the same narrow constructor/store-folding semantics

### 4. The local evidence surface is broader than one test file, and the CLI lane is real

The re-check showed that the strongest local proof surface is spread across:

- `src/passes/heap_store_optimization_test.mbt` for reduced focused shapes
- `src/passes/registry_test.mbt` for registration/preset exposure
- `src/cmd/cmd_wbtest.mbt` for focused `--heap-store-optimization` replay cases

That is a small but useful clarification because the older page mentioned artifact replay in general terms without mapping readers to the exact local files.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `heap-store-optimization` work needs a quick provenance anchor plus a practical Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`
2. `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
3. `docs/wiki/binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md`
4. `src/passes/heap_store_optimization.mbt`
5. `src/passes/heap_store_optimization_test.mbt`
6. `src/cmd/cmd_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, its focused local evidence surface, and the honest boundary between current HOT-region behavior and the larger upstream CFG-plus-`LazyLocalGraph` contract.
