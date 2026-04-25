---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-merge-locals-current-main-source-correction.md
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
---

# `merge-locals` source correction and test-map follow-up

## Why this follow-up exists

The `merge-locals` folder already looked complete: overview, Binaryen strategy, shape catalog, LocalGraph page, Starshine page, raw manifest, and tracker entries all existed.
But the 2026-04-23 source correction overcorrected the earlier 2026-04-20 note.
It taught a `LocalStructuralDominance` / `EquivalentCopies` implementation that is not present in the reviewed Binaryen `version_129` or current-`main` `MergeLocals.cpp`.

This run therefore treated `merge-locals` as a wiki-health bug, not just a freshness pass.

## Primary-source recheck

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md`

The source-backed correction is:

- the real pass still skips functions that have local names
- it constructs an eager `LocalGraph` and computes ordinary plus set influences
- it scans locals with exactly one set
- the set must have a simple value under Binaryen's simple-expression predicate
- all influenced gets for the local must trace back to that same set
- a trivial `local.get` source chain can be reused when the source is small enough
- otherwise Binaryen creates a fresh temp, writes the simple value there, rewrites influenced gets, and removes redundant sets
- `pass.cpp` still gates the pass to stronger optimize/shrink levels, after `heap2local` and before `optimize-casts`, `local-subtyping`, `coalesce-locals`, `local-cse`, and `simplify-locals`
- current `main` did not show teaching-relevant drift from that corrected `version_129` contract on 2026-04-25

## What changed in the living wiki

Updated the `merge-locals` dossier to make the source-backed contract usable for beginner through advanced readers:

- `index.md` now teaches the one-set-local plus simple-value contract and marks the prior equivalent-copy model as stale.
- `binaryen-strategy.md` now walks the actual phases: local-name bailout, eager LocalGraph, one-set candidates, simple-value gate, source-local reuse versus fresh-temp allocation, and postwalk materialization.
- `implementation-structure-and-tests.md` was added as the missing owner/helper/lit-test map.
- `local-graph-and-copy-influences.md` now explains ordinary influence and set-influence facts without claiming `LocalStructuralDominance`.
- `wat-shapes.md` now gives concrete source-backed before/after families for direct reuse, fresh-temp allocation, branching/DAG/loop influence cases, complex-value bailouts, extra-set negatives, and named-local bailouts.
- `starshine-strategy.md` now points future local work at exact registry / rejection / test / planning lines and warns not to port the non-source-backed `EquivalentCopies` story.

## Local Starshine status checked

- `src/passes/optimize.mbt:144-151` tracks `merge-locals` under removed pass names.
- `src/passes/optimize.mbt:455-473` rejects removed pass requests instead of accepting them as no-ops.
- `src/passes/registry_test.mbt:171-179` proves removed-name requests reject; the current test uses `de-nan` as the sample removed name rather than `merge-locals` specifically.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:41-42` still lists `merge-locals` under removed-until-hot-implementation Batch 1 planning.
- `agent-todo.md` still has no dedicated `merge-locals` slice.

## Supersession

This note supersedes:

- `0128-2026-04-20-merge-locals-binaryen-research.md` for incomplete older strategy details.
- `0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md` for the incorrect rejection of the one-set/fresh-temp/local-name-bailout model and the incorrect `EquivalentCopies` / `LocalStructuralDominance` replacement model.

The older notes remain useful for historical queue context and neighboring-pass motivation.
