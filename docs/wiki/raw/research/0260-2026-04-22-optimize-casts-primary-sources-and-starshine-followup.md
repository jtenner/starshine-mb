---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/optimize-casts/binaryen-strategy.md
  - ../../binaryen/passes/optimize-casts/two-phase-dataflow.md
  - ../../binaryen/passes/optimize-casts/wat-shapes.md
  - ../../binaryen/passes/optimize-casts/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/heap2local/index.md
  - ../../binaryen/passes/local-subtyping/index.md
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/local-cse/index.md
---

# `optimize-casts` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `optimize-casts` dossier already had a useful landing page, Binaryen strategy page, asymmetrical-dataflow page, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still described the folder only as upstream research, without a clean bridge to the exact in-repo Starshine status and future port surfaces

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-optimize-casts-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `OptimizeCasts.cpp` on `version_129` and `main`
- `pass.cpp`
- `opt-utils.h`
- `linear-execution.h`, `properties.h`, `effects.h`, and `utils.h`
- the dedicated `optimize-casts.wast` file

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `heap2local`, `local-subtyping`, `coalesce-locals`, and `local-cse`

## Durable findings

### 1. The Binaryen side did not need a structural rewrite; it needed provenance and freshness anchors

The existing upstream pages were still broadly correct.
The missing piece was provenance:

- on 2026-04-22 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` check did not surface a new teaching-relevant drift beyond the existing strategy, two-phase-dataflow, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and then thread that provenance into the living pages, not to replace the pass explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`optimize-casts` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already has a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps the upstream spelling `optimize-casts` in the removed-name registry, so the pass is intentionally tracked rather than forgotten
- `agent-todo.md` keeps an explicit `OC` backlog slice with delivery expectations
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records where the pass belongs in the canonical GC/local cleanup cluster
- the neighboring dossiers for `heap2local`, `local-subtyping`, `coalesce-locals`, and `local-cse` already explain the passes a future port would need to line up with

Before this run, that local state was scattered.
The new Starshine page turns it into one teachable path.

### 3. The honest Starshine story here is “registry plus cluster planning,” not a fake implementation page

Unlike the already-implemented hot and module passes, `optimize-casts` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore makes three things explicit instead of smoothing them over:

- current Starshine executes no `optimize-casts` transform today
- the in-repo implementation status is deliberately removed-name tracking through the registry, backlog slice, and scheduler docs
- the exact read-along path for a future implementation already exists in neighboring code and docs, especially the GC/local cleanup cluster that feeds and consumes this pass

That is a more useful beginner-to-advanced teaching frame than pretending the dossier is only upstream-facing until code lands.

### 4. The local backlog wording is broader than the reviewed upstream `version_129` contract, and the docs should say that explicitly

One useful contradiction surfaced while re-reading the local planning note:

- the refreshed Binaryen dossier still source-confirms `optimize-casts` as a pass that handles only **`ref.cast` and `ref.as_non_null`** in `version_129`
- but the current `agent-todo.md` slice still says a future port should cover `ref.cast`, `ref.test`, nullability, and subtype simplifications

The new Starshine page records that mismatch explicitly instead of smoothing it over.
Today the source-backed interpretation should remain:

- treat the current Binaryen oracle as `ref.cast` plus `ref.as_non_null` only
- do not silently broaden the planned Starshine port to `ref.test` or wider cast families unless a newer upstream source or a deliberate Starshine-specific design document says so

### 5. The future local implementation should be taught as the bridge between `heap2local` and later local narrowing/coalescing, not as a generic cast pass

Re-reading the local scheduler docs and neighboring pass dossiers reinforces a useful local planning point:

- Binaryen places `optimize-casts` immediately after `heap2local`
- it then tightens local declarations and reuse opportunities through `local-subtyping -> coalesce-locals -> local-cse`
- the stricter earlier-motion half and the looser later-reuse half are both there to improve the quality of that later local-value traffic, not to subsume those later passes

So a future Starshine `optimize-casts` port should be taught as part of the GC/local cleanup cluster rather than as a free-standing generic cast simplifier.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-optimize-casts-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/optimize-casts/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/optimize-casts/index.md`
- `docs/wiki/binaryen/passes/optimize-casts/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-casts/two-phase-dataflow.md`
- `docs/wiki/binaryen/passes/optimize-casts/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `optimize-casts` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-optimize-casts-primary-sources.md`
2. `docs/wiki/binaryen/passes/optimize-casts/index.md`
3. `docs/wiki/binaryen/passes/optimize-casts/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/optimize-casts/two-phase-dataflow.md`
5. `docs/wiki/binaryen/passes/optimize-casts/wat-shapes.md`
6. `docs/wiki/binaryen/passes/optimize-casts/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `agent-todo.md`
9. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
10. `docs/wiki/binaryen/passes/heap2local/index.md`
11. `docs/wiki/binaryen/passes/local-subtyping/index.md`
12. `docs/wiki/binaryen/passes/coalesce-locals/index.md`
13. `docs/wiki/binaryen/passes/local-cse/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, the removed-registry tracking, and the neighboring passes that a real future local port would need to interoperate with.
