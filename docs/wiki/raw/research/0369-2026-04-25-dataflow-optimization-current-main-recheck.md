---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md
  - ../binaryen/2026-04-23-dataflow-optimization-primary-sources.md
  - ./0278-2026-04-23-dataflow-optimization-primary-sources-and-starshine-followup.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/index.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
related:
  - ../../../wiki/binaryen/passes/dataflow-optimization/index.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/binaryen-strategy.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/implementation-structure-and-tests.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/flat-ir-dataflow-ir-and-boundaries.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/wat-shapes.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/starshine-strategy.md
---

# `dataflow-optimization` current-main recheck

## Question

The 2026-04-23 `dataflow-optimization` / `dfo` dossier was useful, but it still depended on a narrow current-main spot check and had stale Starshine request-guard line anchors. This run asked whether official Binaryen current `main` changed the teaching contract and whether the local status page still points to exact code locations.

## Method

- Re-read the wiki schema and pass tracker.
- Rechecked official Binaryen `main` sources for:
  - `src/passes/DataFlowOpts.cpp`
  - `src/dataflow/graph.h`
  - `src/dataflow/node.h`
  - `src/dataflow/users.h`
  - `src/dataflow/utils.h`
  - `src/ir/flat.h`
  - `src/passes/pass.cpp`
  - `test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast`
- Rechecked local Starshine status with repository search and `src/passes/optimize.mbt` line anchors.

## Findings

- No teaching-relevant current-main drift was found. Current Binaryen still presents `dfo` as a flat-input DataFlow SSA IR pass and still registers public CLI spelling `dfo`.
- The upstream algorithm remains the same narrow contract already taught in the dossier:
  - hard `Flat::verifyFlatness(func)` gate
  - integer-local relevance filter
  - synthetic DataFlow graph node vocabulary
  - conservative unsupported-op and loop handling
  - user-driven worklist
  - identical constant-phi collapse
  - all-constant expression folding only when nested `precompute` turns the expression into a `Const`
- The current Starshine code still tracks only the local removed spelling `dataflow-optimization`; there is no active descriptor, no `src/passes/dataflow_optimization.mbt`, no `src/dataflow/`, no `src/ir/flat*`, and no dedicated `agent-todo.md` slice.
- The main local hygiene correction was line-anchor drift: the removed-pass request guard is now `src/passes/optimize.mbt:468-472`, not the older `446-465` range.

## Durable wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md`.
- Refreshed the living `dataflow-optimization` folder with the current-main source bridge and updated local line anchors.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.

## Follow-up

No implementation work was done. A future port still needs an explicit design choice: faithfully create a flat/DataFlow substrate or document a narrower HOT-native approximation. The current dossier should remain a port-planning source, not an implementation-status claim.
