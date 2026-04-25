---
kind: research
status: partially_superseded
last_reviewed: 2026-04-25
superseded_by:
  - ./0348-2026-04-25-rse-source-correction-and-starshine-followup.md
sources:
  - ../binaryen/2026-04-22-rse-primary-sources.md
  - ../../binaryen/passes/rse/index.md
  - ../../binaryen/passes/rse/binaryen-strategy.md
  - ../../binaryen/passes/rse/cfg-and-value-tracking.md
  - ../../binaryen/passes/rse/wat-shapes.md
  - ../../binaryen/passes/rse/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/simplify-locals/index.md
  - ../../binaryen/passes/vacuum/index.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/merge-blocks/index.md
---

# `rse` primary-source and Starshine follow-up

## 2026-04-25 partial supersession

[`0348-2026-04-25-rse-source-correction-and-starshine-followup.md`](0348-2026-04-25-rse-source-correction-and-starshine-followup.md) supersedes this note's algorithm interpretation where it describes Binaryen `version_129` `rse` as LocalGraph/liveness/dataflow, copied-local inheritance, same-block read rewriting, predecessor merging, or broad overwritten-write deletion. This note remains useful for folder provenance, local status at the time, and the raw-source ingest trail.

## Why this follow-up exists

The existing `rse` dossier already had a useful landing page, Binaryen strategy page, CFG/value-tracking page, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still described the folder only as an upstream research home, without a clean bridge to the exact in-repo Starshine status and future port surfaces

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-rse-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `RedundantSetElimination.cpp` on `version_129` and `main`
- `pass.cpp`
- `opt-utils.h`
- `local-graph.h`, `liveness.h`, `numbering.h`, and `properties.h`
- the dedicated `rse_all-features.wast`, `rse_all-features.txt`, and `rse-gc.wast` files

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `simplify-locals`, `vacuum`, `heap-store-optimization`, and `merge-blocks`

## Durable findings

### 1. The Binaryen side did not need a rewrite; it needed provenance and freshness anchors

The existing upstream pages were still broadly correct.
The missing piece was provenance:

- on 2026-04-22 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` check did not surface a new teaching-relevant drift beyond the existing strategy, CFG/value-tracking, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and then thread that provenance into the living pages, not to replace the pass explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`rse` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already has a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps the upstream spelling `redundant-set-elimination` in the removed-name registry, so the pass is intentionally tracked rather than forgotten
- `agent-todo.md` keeps an explicit `RSE` backlog slice with delivery expectations
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records where the pass belongs in the canonical late cleanup cluster
- the neighboring Starshine dossiers for `simplify-locals`, `vacuum`, `heap-store-optimization`, and `merge-blocks` already explain the surrounding passes a future port would need to compose with

Before this run, that local state was scattered.
The new Starshine page turns it into one teachable path.

### 3. The honest Starshine story here is “boundary and port plan,” not a fake implementation page

Unlike the already-implemented hot and module passes, `rse` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore makes three things explicit instead of smoothing them over:

- current Starshine executes no `rse` transform today
- the in-repo implementation status is deliberately boundary-only tracking through the removed-name registry, backlog slice, and scheduler docs
- the exact read-along path for a future implementation already exists in neighboring code and docs, especially the late-cluster cleanup passes that expose or consume the same local-value traffic

That is a more useful beginner-to-advanced teaching frame than pretending the dossier is only upstream-facing until code lands.

### 4. The local backlog wording is broader than the reviewed upstream `version_129` contract, and the docs should say that explicitly

One useful contradiction surfaced while re-reading the local planning note:

- the refreshed Binaryen dossier still source-confirms `rse` as a **locals-only** pass in `version_129`
- but the current `agent-todo.md` slice still says a future port should cover locals, globals, and GC field writes “where applicable”

The new Starshine page records that mismatch explicitly instead of smoothing it over.
Today the source-backed interpretation should remain:

- treat the current Binaryen oracle as locals-only
- do not silently broaden the planned Starshine port to global or GC field stores unless a newer upstream source or a deliberate Starshine-specific design document says so

### 5. The future local implementation should be taught as a very late local-cleanup pass, not a generic write-elimination pass

Re-reading the local scheduler docs and neighboring pass dossiers reinforces a useful local planning point:

- Binaryen places `rse` extremely late, after `code-folding -> merge-blocks` and immediately before the final `vacuum`
- earlier local cleanup and peephole passes such as `simplify-locals` and `heap-store-optimization` make the final local-value story easier to see
- late structural cleanup such as `merge-blocks` can simplify the control shapes that `rse` reasons about, and the final `vacuum` is expected to clean up the debris `rse` leaves behind

So a future Starshine `rse` port should be taught as part of the late cleanup cluster rather than as a free-standing generic redundancy pass.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-rse-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/rse/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/rse/index.md`
- `docs/wiki/binaryen/passes/rse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/rse/cfg-and-value-tracking.md`
- `docs/wiki/binaryen/passes/rse/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `rse` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-rse-primary-sources.md`
2. `docs/wiki/binaryen/passes/rse/index.md`
3. `docs/wiki/binaryen/passes/rse/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/rse/cfg-and-value-tracking.md`
5. `docs/wiki/binaryen/passes/rse/wat-shapes.md`
6. `docs/wiki/binaryen/passes/rse/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `agent-todo.md`
9. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
10. `docs/wiki/binaryen/passes/simplify-locals/index.md`
11. `docs/wiki/binaryen/passes/vacuum/index.md`
12. `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
13. `docs/wiki/binaryen/passes/merge-blocks/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, the removed-registry tracking, and the neighboring implemented passes that a real future local port would need to interoperate with.
