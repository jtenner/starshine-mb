---
kind: research
status: supported
last_reviewed: 2026-04-27
sources:
  - ../binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md
  - ../binaryen/2026-04-23-dataflow-optimization-primary-sources.md
  - ./0369-2026-04-25-dataflow-optimization-current-main-recheck.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/index.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/starshine-port-readiness-and-validation.md
related:
  - ../../../wiki/binaryen/passes/dataflow-optimization/index.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/binaryen-strategy.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/implementation-structure-and-tests.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/flat-ir-dataflow-ir-and-boundaries.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/wat-shapes.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/starshine-strategy.md
  - ../../../wiki/binaryen/passes/dataflow-optimization/starshine-port-readiness-and-validation.md
---

# `dataflow-optimization` port-readiness bridge

## Question

The `dataflow-optimization` / upstream `dfo` dossier already had correct overview, Binaryen strategy, shape, and Starshine status pages. It still lacked the newer campaign's implementation-readiness bridge: what first slice would be safe in Starshine, which exact local code surfaces prove the current status, and which validation lanes should prevent a misleading partial port.

## Method

- Re-read the existing living `dataflow-optimization` folder.
- Rechecked official Binaryen current `main` sources for `DataFlowOpts.cpp`, `src/dataflow/*`, `flat.h`, `pass.cpp`, and the combo `flatten_simplify-locals-nonesting_dfo_O3.wast` proof surface.
- Rechecked local Starshine state in `src/passes/optimize.mbt`, workspace file layout, and `agent-todo.md`.
- Added a dedicated Starshine port-readiness and validation page rather than duplicating the already-correct Binaryen strategy pages.

## Findings

- No teaching-relevant upstream drift was found since the 2026-04-25 current-main recheck.
- The implementation contract remains narrow and flat-input:
  - hard `Flat::verifyFlatness(func)` gate
  - integer-local DataFlow graph construction
  - conservative loop-varying unknowns
  - unsupported/EH boundaries
  - identical-constant-phi collapse
  - all-constant `Expr` folding only through nested `precompute`
- The local status remains unchanged:
  - `dataflow-optimization` is a removed registry spelling in `src/passes/optimize.mbt`
  - explicit requests are rejected honestly
  - there is no owner file, module/hot registry entry, local `src/dataflow/` substrate, local `src/ir/flat*` substrate, or dedicated backlog slice
- The next useful future work is analyzer-first scaffolding, not a direct mutation:
  - classify flat-like candidate regions and bailout causes
  - prove a local replacement model can preserve uses and writeback safely
  - only then implement same-constant branch-merge and all-constant supported-expression rewrites

## Durable wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/dataflow-optimization/starshine-port-readiness-and-validation.md`.
- Refreshed the `dataflow-optimization` landing, Binaryen strategy, shape, implementation/test-map, Flat/DataFlow boundary, and Starshine status pages to cross-link the new bridge and current source recheck.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Follow-up

A future implementation still needs a policy choice before coding: either build a faithful local Flat/DataFlow substrate, or explicitly document a narrower HOT/IR2-native approximation. The new readiness page intentionally keeps that choice open and testable rather than pretending the current repo already contains the required substrate.
