---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-rse-current-main-recheck.md
  - ../binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../binaryen/passes/rse/index.md
  - ../../binaryen/passes/rse/binaryen-strategy.md
  - ../../binaryen/passes/rse/implementation-structure-and-tests.md
  - ../../binaryen/passes/rse/cfg-and-value-tracking.md
  - ../../binaryen/passes/rse/wat-shapes.md
  - ../../binaryen/passes/rse/starshine-strategy.md
  - ../../binaryen/passes/rse/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/rse.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/passes/rse_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `rse` current-main recheck and health follow-up

## Why this follow-up exists

The `rse` dossier was already source-correct and teaching-complete for the `version_129` contract, but it still lacked a fresh current-main bridge for the 2026-05-05 wiki-health sweep.
This follow-up records that freshness layer and keeps the living pages aligned with the exact local Starshine code map.

## Primary source rechecked

The refreshed source bridge rechecked official Binaryen `main` sources for:

- `src/passes/RedundantSetElimination.cpp`
- `src/passes/pass.cpp`
- `test/passes/rse_all-features.wast`
- `test/lit/passes/rse-gc.wast`

The review stayed aligned with the existing contract on the reviewed surface.
No teaching-relevant drift surfaced beyond the older already-recorded distinction between CFG/value-flow `rse` and broad `LocalGraph`/liveness dead-store elimination.

## Durable updates

- Added `docs/wiki/raw/binaryen/2026-05-05-rse-current-main-recheck.md`.
- Added this research note as the append-only audit trail for the freshness bridge.
- Refreshed the living `rse` pages so the new source anchor and exact local code map are visible from the dossier.

## Starshine takeaway

The local Starshine status did not change:

- `redundant-set-elimination` remains an active direct hot pass.
- The implemented slice still covers same-value local-set / local-tee shell removal, raw fast-path replay, CLI/registry/dispatcher/harness wiring, and direct compare evidence.
- The remaining first-class gap is the full CFG fixed-point plus strict-subtype refined-get surface.

## Pages updated by this follow-up

- `docs/wiki/raw/binaryen/2026-05-05-rse-current-main-recheck.md`
- `docs/wiki/raw/research/0463-2026-05-05-rse-current-main-recheck.md`
- `docs/wiki/binaryen/passes/rse/index.md`
- `docs/wiki/binaryen/passes/rse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/rse/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/rse/cfg-and-value-tracking.md`
- `docs/wiki/binaryen/passes/rse/wat-shapes.md`
- `docs/wiki/binaryen/passes/rse/starshine-strategy.md`
- `docs/wiki/binaryen/passes/rse/starshine-port-readiness-and-validation.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
