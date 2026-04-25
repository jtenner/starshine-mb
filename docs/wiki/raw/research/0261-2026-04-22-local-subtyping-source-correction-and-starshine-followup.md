---
kind: research
status: partially_superseded
last_reviewed: 2026-04-25
superseded_by:
  - ./0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
sources:
  - ../binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../binaryen/passes/local-subtyping/index.md
  - ../../binaryen/passes/local-subtyping/binaryen-strategy.md
  - ../../binaryen/passes/local-subtyping/lubs-and-dominance.md
  - ../../binaryen/passes/local-subtyping/wat-shapes.md
  - ../../binaryen/passes/local-subtyping/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/local-cse/index.md
  - ../../binaryen/passes/reorder-locals/index.md
  - ./0116-2026-04-20-local-subtyping-binaryen-research.md
---

# `local-subtyping` source-correction and Starshine follow-up

## 2026-04-25 supersession note

This note remains useful as the first correction away from the older over-broad `LocalUpdater` / copy-local-insertion reading. It is partially superseded by [`0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](./0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md) for owner-file mechanics: Binaryen `version_129` does record `local.get` sites, iterates with `ReFinalize()`, splits parameter scan from body-local rewrite, and does not use the `TypeUpdating::canHandleAsLocal(...)` gate described here.

## Why this follow-up exists

The existing `local-subtyping` dossier already had the required landing page, Binaryen strategy page, transformed-shape page, and a focused helper-mechanics page.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- parts of the Binaryen explanation had drifted into an over-broad reading of `LocalSubtyping.cpp`

This follow-up closes the provenance gap, adds the missing Starshine page, and corrects the teaching-critical Binaryen story.
The correction matters: the older 2026-04-20 note and the first living pages over-read the pass as a `local.get` / `ref.as_non_null` collector that rewrites through `LocalUpdater` plus copy-local insertion.
The reviewed upstream source on 2026-04-22 showed that the real `version_129` contract is narrower.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-local-subtyping-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `LocalSubtyping.cpp`
- `pass.cpp`
- `opt-utils.h`
- `lubs.h`
- `type-updating.h`
- `local-structural-dominance.h`
- the dedicated `local-subtyping.wast` file

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `optimize-casts`, `coalesce-locals`, `local-cse`, and `reorder-locals`

## Durable findings

### 1. The big need was not another overview page; it was a source correction

The existing folder already covered the pass's role and scheduler neighborhood.
The real problem was factual drift in the Binaryen explanation.
The reviewed source corrected the dossier in these important ways:

- the pass seeds one `LUBFinder` per original local, but it gathers new evidence from **`local.set` / `local.tee` only**
- it does **not** have a `visitLocalGet` evidence collector
- it does **not** have a `visitRefAs` / `ref.as_non_null` evidence collector
- it does **not** call `LocalUpdater(...).changeType(...)`
- it does **not** model copy-local insertion as part of this pass's own contract
- it does **not** end with a `ReFinalize()` call in the reviewed `version_129` body

The living pages now teach the smaller source-backed contract instead of smoothing that older overread away.

### 2. `local-subtyping` is really a definition-driven declaration-and-use retag pass

The reviewed `LocalSubtyping.cpp` body is small.
Its real shape is:

1. seed non-parameter vars with their current declared type
2. note concrete `local.set` / `local.tee` definition types into a LUB per local
3. skip non-reference locals and helper-unsupported locals
4. narrow the declared local type directly when the candidate LUB is better
5. if the only improvement is nullability, require `LocalStructuralDominance::dominatesAll(...)` before keeping the non-null declaration
6. retag `local.get` and `local.tee` expression types to the new declaration where safe

That is still a useful pass, but it is much smaller than the earlier local summary had taught.

### 3. Dominance still matters, but in a narrower way than the older dossier said

The old dossier was right that dominance matters, but wrong about how much of the rewrite it owns.
The reviewed source shows a smaller story:

- dominance is used as a **gate** for non-nullability tightening
- and as a guard when retagging `local.get` types after the declaration changes
- it is not a generic `LocalUpdater`-driven whole-function local rewrite engine in this pass

So the updated helper page now keeps named-block / catch / loop structure explicit while removing the earlier copy-local and helper-rewrite overstatement.

### 4. The local Starshine gap was both provenance and a missing status/port map

`local-subtyping` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already has real local planning surfaces for it:

- `src/passes/optimize.mbt` keeps `local-subtyping` in the removed-name registry
- `agent-todo.md` keeps an explicit `LS` backlog slice
- the no-DWARF optimizer docs already place it between `optimize-casts` and `coalesce-locals`
- the neighboring `coalesce-locals`, `local-cse`, and `reorder-locals` dossiers already explain why this slot matters for honest future scheduler placement

Before this run, that local state was scattered.
The new Starshine page turns it into one usable read-along path.

### 5. The current backlog wording is broader than the reviewed upstream contract, and the docs should say so explicitly

One useful contradiction surfaced while re-reading the local planning note.
The current `LS` backlog slice still describes the future work as:

- compute safe narrower local types from uses and defs
- preserve multivalue and tuple-local behavior

The reviewed upstream `version_129` contract is narrower:

- it is definition-driven first, not a broad uses-plus-defs collector
- it narrows only reference-typed locals here
- tuple locals are skipped through `TypeUpdating::canHandleAsLocal(...)`

The new Starshine page records that mismatch explicitly instead of smoothing it over.
A future local port can choose to stay source-faithful or deliberately widen scope, but the docs should not silently pretend those are the same plan.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-local-subtyping-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/local-subtyping/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/local-subtyping/index.md`
- `docs/wiki/binaryen/passes/local-subtyping/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-subtyping/lubs-and-dominance.md`
- `docs/wiki/binaryen/passes/local-subtyping/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `local-subtyping` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-local-subtyping-primary-sources.md`
2. `docs/wiki/binaryen/passes/local-subtyping/index.md`
3. `docs/wiki/binaryen/passes/local-subtyping/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/local-subtyping/lubs-and-dominance.md`
5. `docs/wiki/binaryen/passes/local-subtyping/wat-shapes.md`
6. `docs/wiki/binaryen/passes/local-subtyping/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `agent-todo.md`
9. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
10. `docs/wiki/binaryen/passes/optimize-casts/index.md`
11. `docs/wiki/binaryen/passes/coalesce-locals/index.md`
12. `docs/wiki/binaryen/passes/local-cse/index.md`
13. `docs/wiki/binaryen/passes/reorder-locals/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the corrected Binaryen mechanics, the exact current Starshine status, the backlog and scheduler placement, the removed-registry tracking, and the neighboring passes that a real future local port would need to interoperate with.
