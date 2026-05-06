---
kind: research
status: supported
last_reviewed: 2026-05-06
sources:
  - ../binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../binaryen/2026-04-22-remove-unused-brs-primary-sources.md
  - ../../binaryen/passes/remove-unused-brs/index.md
  - ../../binaryen/passes/remove-unused-brs/binaryen-strategy.md
  - ../../binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md
  - ../../binaryen/passes/remove-unused-brs/wat-shapes.md
  - ../../binaryen/passes/remove-unused-brs/starshine-strategy.md
  - ../../binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
related:
  - ../../binaryen/passes/remove-unused-brs/parity.md
  - ../../binaryen/passes/remove-unused-brs/pattern-catalog.md
  - ../../binaryen/passes/remove-unused-brs/visit-order-and-bailouts.md
---

# `remove-unused-brs` current-main recheck and freshness refresh

## Why this follow-up exists

The `remove-unused-brs` dossier was already source-correct, but its freshness layer still stopped at the 2026-05-05 current-main bridge.
This follow-up records a 2026-05-06 current-main recheck so the living pages can carry a fresher provenance layer and keep the staged-control / GC / EH / branch-hint split explicit.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/RemoveUnusedBrs.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/remove-unused-brs.wast`
  - `test/lit/passes/remove-unused-brs-gc.wast`
  - `test/lit/passes/remove-unused-brs-eh.wast`
  - `test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast`
- Comparison anchors on `version_129`:
  - the same owner, registration, lit, and helper files
- Existing living dossier pages for the pass family

## Source-backed Binaryen conclusions

- Current `main` still matches the corrected `version_129` teaching contract on the reviewed surfaces.
- The pass remains a staged structured-control optimizer, not a generic CFG optimizer.
- `neverUnconditionalize` is still a real behavior knob, not a local test artifact.
- GC BrOn cleanup, EH throw-to-branch cleanup, and late `tablify` / `selectify` / local-set cleanup remain part of the real pass surface.
- No teaching-relevant current-main drift was found beyond the already-tracked `JumpThreader` type-equality relaxation.

## Starshine local status

The local status is unchanged by this source refresh:

- `remove-unused-brs` remains an active HOT pass in Starshine;
- the raw pre-lift gate still exists for obvious no-op families and cheap decision-ladder normalization;
- the current HOT implementation is still narrower than upstream Binaryen's full GC / EH / branch-hint surface;
- the safest next work still lives in the structured-control rewrite families already documented in the dossier.

## Living page updates from this follow-up

Updated or refreshed:

- `docs/wiki/raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/index.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the 2026-05-05 source capture and current-main bridge.
It does not change the contract story; it only refreshes provenance while keeping the upstream-only status and the local HOT gap explicit.
