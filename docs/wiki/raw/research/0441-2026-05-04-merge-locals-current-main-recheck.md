---
kind: research
status: supported
last_reviewed: 2026-05-04
sources:
  - ../binaryen/2026-05-04-merge-locals-current-main-recheck.md
  - ../../binaryen/passes/merge-locals/index.md
  - ../../binaryen/passes/merge-locals/binaryen-strategy.md
  - ../../binaryen/passes/merge-locals/implementation-structure-and-tests.md
  - ../../binaryen/passes/merge-locals/local-graph-and-copy-influences.md
  - ../../binaryen/passes/merge-locals/wat-shapes.md
  - ../../binaryen/passes/merge-locals/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
supersedes:
  - 0128-2026-04-20-merge-locals-binaryen-research.md
  - 0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md
  - 0363-2026-04-25-merge-locals-source-correction-and-test-map.md
---

# `merge-locals` current-main recheck and source correction

## Why this recheck exists

The living `merge-locals` dossier had drifted into a stale one-set-local narrative.
A fresh source re-read on 2026-05-04 showed the implementation is still the older copy-shape local traffic pass, with eager `LocalGraph` set-influence verification and post-rewrite rollback checks.

## Primary-source recheck

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md`

The source-backed correction is:

- `merge-locals` starts from copy-shaped `local.set` / `local.get` traffic, not from a generic one-set-local summary
- `visitLocalSet` instruments the copy by introducing a trivial `local.tee` candidate on the source side
- `optimizeCopies()` then uses an eager `LocalGraph` set-influence snapshot to decide whether influenced gets should be retargeted toward the destination local or the source local
- the pass validates the rewrite against a post-graph and rolls back candidates that no longer have the intended single-set story
- the implementation still invalidates DWARF because the local identity changes are observable
- the reviewed `merge-locals.wast` surface remains narrow; the visible regression anchor is the `between-unreachable` family rather than the broad shape catalog taught by the stale dossier
- current `main` did not drift from `version_129` on the reviewed surfaces

## What changed in the living wiki

Updated the dossier to teach the copy-shape contract directly:

- `index.md` now describes `merge-locals` as a copy-balancing pass rather than one-set local merging.
- `binaryen-strategy.md` now tracks the actual copy instrumentation, `LocalGraph` set-influence solve, orientation choice, and rollback step.
- `implementation-structure-and-tests.md` now maps the real owner files and notes the narrow official lit surface.
- `local-graph-and-copy-influences.md` now explains the copy-oriented graph proof instead of the stale one-set/simple-value story.
- `wat-shapes.md` now centers the copy retargeting shapes and the `between-unreachable` conservative family.
- `starshine-strategy.md` now points future local work at the removed-name registry and request guard while keeping the copy-shape future target explicit.

## Local Starshine status checked

- `src/passes/optimize.mbt:144-151` tracks `merge-locals` under removed pass names.
- `src/passes/optimize.mbt:455-473` rejects removed pass requests instead of accepting them as no-ops.
- `src/passes/registry_test.mbt:171-179` proves removed-name requests reject; the current test uses `de-nan` as the sample removed name rather than `merge-locals` specifically.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:41-42` still lists `merge-locals` under removed-until-hot-implementation Batch 1 planning.
- `agent-todo.md` still has no dedicated `merge-locals` slice.

## Supersession

This note supersedes the earlier one-set/fresh-temp source-correction chain for the maintained algorithm summary.
The older notes remain useful for historical queue context and for tracking how the overread happened.
