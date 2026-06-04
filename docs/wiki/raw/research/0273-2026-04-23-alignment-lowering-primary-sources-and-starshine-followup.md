---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-alignment-lowering-primary-sources.md
  - ../../binaryen/passes/alignment-lowering/index.md
  - ../../binaryen/passes/alignment-lowering/binaryen-strategy.md
  - ../../binaryen/passes/alignment-lowering/implementation-structure-and-tests.md
  - ../../binaryen/passes/alignment-lowering/chunk-selection-and-unreachable-semantics.md
  - ../../binaryen/passes/alignment-lowering/wat-shapes.md
  - ../../binaryen/passes/alignment-lowering/starshine-strategy.md
  - ../../binaryen/passes/dealign/index.md
  - ../../binaryen/passes/avoid-reinterprets/index.md
  - ../../binaryen/passes/i64-to-i32-lowering/index.md
  - ../../../../src/passes/optimize.mbt
  - 0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `alignment-lowering` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `alignment-lowering` dossier already had the required living overview, Binaryen strategy page, implementation/test map, transformed-shape coverage, and the focused chunk-matrix explainer.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still taught the pass mostly as upstream-only research instead of also giving readers one clean bridge into the exact in-repo Starshine status, missing backlog slice, and open landing-shape questions

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `AlignmentLowering.cpp` on `version_129` and `main`
- `pass.cpp`
- `passes.h`
- `pass.h`
- `bits.h`
- the dedicated `alignment-lowering.wast` test

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `dealign`, `avoid-reinterprets`, and `i64-to-i32-lowering`

## Durable findings

### 1. The Binaryen side mostly needed provenance and freshness anchors, not another algorithm rewrite

The existing upstream pages were still broadly correct after the 2026-04-21 research wave.
The missing piece was provenance:

- on 2026-04-23 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the existing strategy, implementation/test, chunk-matrix, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and thread that provenance into the living pages, not to replace the already-correct Binaryen explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`alignment-lowering` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already had a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps `alignment-lowering` in the boundary-only registry surface
- the same file's `run_hot_pipeline_expand_passes(...)` path rejects the pass with a boundary-only error rather than pretending it exists in the active hot pipeline
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` already keeps the pass in the whole-module or layout transform planning bucket
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` still does **not** place the pass in the current canonical no-DWARF path
- `agent-todo.md` still has **no dedicated `alignment-lowering` slice**
- the neighboring `dealign`, `avoid-reinterprets`, and `i64-to-i32-lowering` dossiers already give a useful conceptual boundary map for what this pass is and is not

Before this run, that local status was scattered.
The new Starshine page turns it into one teachable path while keeping the missing-slice uncertainty explicit.

### 3. The honest Starshine story is boundary-only tracking plus an unresolved landing-shape question

Unlike `reorder-globals` or `directize`, the repo does **not** yet carry a dedicated `alignment-lowering` backlog slice that pins an exact future landing zone.
That matters because the reviewed Binaryen contract is slightly awkward relative to Starshine's current optimizer architecture:

- upstream `alignment-lowering` is a small per-function AST walker
- current Starshine optimization work is centered on HOT-IR rewrites plus some module passes
- the repo currently records the pass only as boundary-only compatibility/planning metadata, not as a sketched future HOT pass or module pass

So the new Starshine page deliberately records an uncertainty instead of smoothing it over:

- Starshine clearly tracks the pass name and rejects it honestly today
- but the repo has not yet chosen whether a future parity port should land as a dedicated post-writeback legalization pass, a HOT-side memory-legalization rewrite family, or some later boundary transform nearer emit/lowering

That uncertainty is durable knowledge, not a documentation failure.

### 4. Even without a chosen landing slot, the local correctness contract is already clear

The Binaryen dossier is mature enough that a future Starshine port already has a stable source-backed invariant list to preserve:

- ordinary scalar `Load` / `Store` scope only unless an intentional extension is documented
- natural-alignment no-op behavior
- single evaluation via fresh temporaries
- explicit signed narrow-load repair
- float reinterpret staging
- full-width 64-bit split/rebuild through 32-bit halves
- operand-preserving unreachable rewrites

That means the missing local decision is not “what does the pass do?”
It is “where should Starshine implement that contract honestly?”

### 5. The neighboring memory/legalization dossiers matter for future port planning

Re-reading the nearby folders sharpened the most useful local contrast set:

- `dealign` is the opposite-direction metadata-weakening sibling, not a chunk-lowering legality pass
- `avoid-reinterprets` is another memory/load-side cleanup pass, but it is about eliminating load-plus-reinterpret chains rather than legalizing weak alignment with explicit chunking
- `i64-to-i32-lowering` is another scalar-lowering family, but it is ABI and opcode-surface lowering rather than memarg-alignment legalization

So a future Starshine port should keep those boundaries explicit instead of treating all “memory-ish lowering” passes as one bucket.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0273-2026-04-23-alignment-lowering-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/alignment-lowering/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/alignment-lowering/index.md`
- `docs/wiki/binaryen/passes/alignment-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/alignment-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/alignment-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `alignment-lowering` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md`
2. `docs/wiki/binaryen/passes/alignment-lowering/index.md`
3. `docs/wiki/binaryen/passes/alignment-lowering/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/alignment-lowering/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/alignment-lowering/chunk-selection-and-unreachable-semantics.md`
6. `docs/wiki/binaryen/passes/alignment-lowering/wat-shapes.md`
7. `docs/wiki/binaryen/passes/alignment-lowering/starshine-strategy.md`
8. `docs/wiki/binaryen/passes/dealign/index.md`
9. `docs/wiki/binaryen/passes/avoid-reinterprets/index.md`
10. `docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md`
11. `src/passes/optimize.mbt`
12. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
13. `agent-todo.md`
14. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the explicit missing-slice and missing-landing-zone questions, and the neighboring local pass dossiers that a real future port would need to keep distinct.
