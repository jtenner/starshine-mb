---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md
  - ../../binaryen/passes/simplify-locals-nostructure/index.md
  - ../../binaryen/passes/simplify-locals-nostructure/binaryen-strategy.md
  - ../../binaryen/passes/simplify-locals-nostructure/variant-surface.md
  - ../../binaryen/passes/simplify-locals-nostructure/wat-shapes.md
  - ../../binaryen/passes/simplify-locals-nostructure/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/tuple-optimization/index.md
  - ../../binaryen/passes/simplify-locals/index.md
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/coalesce-locals/index.md
---

# `simplify-locals-nostructure` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `simplify-locals-nostructure` dossier already had a useful landing page, Binaryen strategy page, variant-surface explainer, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still described the folder only as upstream research, without a clean bridge to the exact in-repo Starshine status and future port surfaces

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `SimplifyLocals.cpp` on `version_129` and `main`
- `pass.cpp`
- `passes.h`
- `opt-utils.h`
- `local-utils.h`, `effects.h`, `equivalent_sets.h`, `linear-execution.h`, `properties.h`, and `branch-utils.h`
- the dedicated `simplify-locals-nostructure` lit files plus nearby variant tests

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/simplify_locals.mbt`
- `src/passes/reorder_locals.mbt`
- `src/passes/pass_manager_wbtest.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `tuple-optimization`, `simplify-locals`, `reorder-locals`, and `coalesce-locals`

## Durable findings

### 1. The Binaryen side did not need a rewrite; it needed provenance and freshness anchors

The existing upstream pages were still broadly correct.
The missing piece was provenance:

- on 2026-04-22 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` check did not surface a new teaching-relevant drift beyond the existing strategy, variant, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and then thread that provenance into the living pages, not to replace the pass explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`simplify-locals-nostructure` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already has a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps the local removed-name spelling `simplify-locals-no-structure` in the pass registry, so the pass is intentionally tracked rather than forgotten
- the same file keeps `tuple_optimization_exact_slot_prereqs_ready()` false until both `code-pushing` and `simplify-locals-no-structure` stop being removed placeholders, which means this missing pass already blocks an honest public tuple slot
- `src/passes/optimize_test.mbt` has a direct regression proving that exact-slot gate stays unavailable while the neighbors remain removed
- `agent-todo.md` keeps an explicit `SLNS` backlog slice with early locals-cleanup and artifact-proof deliverables
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records where the pass belongs in the canonical no-DWARF local-cleanup cluster
- neighboring implementation and test surfaces already show the local sinkability, conflict, rewrite, and replay machinery a future port would likely need to compose with, especially `src/passes/simplify_locals.mbt`, `src/passes/reorder_locals.mbt`, `src/passes/pass_manager_wbtest.mbt`, and `src/cmd/cmd_wbtest.mbt`

Before this run, that local state was scattered.
The new Starshine page turns it into one teachable path.

### 3. The honest Starshine story here is “tracked blocker and port plan,” not a fake implementation page

Unlike the already-implemented hot and module passes, `simplify-locals-nostructure` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore makes three things explicit instead of smoothing them over:

- current Starshine executes no `simplify-locals-nostructure` transform today
- the in-repo implementation status is deliberately tracked through the removed-name registry, the tuple-slot blocker helper, the direct optimize-test regression, and backlog slice `SLNS`
- the exact read-along path for a future implementation already exists in neighboring code and docs, especially the local sinkability/conflict machinery in `simplify_locals.mbt`, the local-index rewrite machinery in `reorder_locals.mbt`, and the existing raw / CLI replay lanes that exercise similar local-traffic cleanup

That is a more useful beginner-to-advanced teaching frame than pretending the dossier is only upstream-facing until code lands.

### 4. The future local port should be taught as the early no-structure bridge between tuple cleanup and later local cleanup

Re-reading the local scheduler docs and neighboring code reinforces a useful planning point:

- the canonical upstream slot is `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals`
- current Starshine already has a real `tuple-optimization` pass, a real later full `simplify-locals` pass, and a real `reorder-locals` pass
- the explicit tuple-slot gate proves the project already treats `simplify-locals-nostructure` as the missing neighbor that prevents honest preset placement
- current Starshine still lacks `code-pushing`, `simplify-locals-nostructure`, `local-subtyping`, `coalesce-locals`, and `local-cse`, so exact broader-cluster parity remains intentionally blocked

That means the practical Starshine strategy today is:

- keep the pass tracked in the registry, backlog, and tuple-slot gate
- keep the pipeline slot documented honestly
- point future port work at the exact local sinkability/conflict/rewrite files that already solve the closest problems in MoonBit terms
- avoid pretending that the exact Binaryen slot can be claimed before the missing neighbors land

### 5. The current local landing zone is concrete enough to document now

The new Starshine page records the most useful exact read-along path for a future port:

- registry, removed-name, and tuple-slot gate truth in `src/passes/optimize.mbt`
- slot-blocker regression coverage in `src/passes/optimize_test.mbt`
- backlog and artifact-proof expectations in `agent-todo.md`
- scheduler truth in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- local sinkability and conflict machinery in `src/passes/simplify_locals.mbt`
- local-index scan/rewrite machinery in `src/passes/reorder_locals.mbt`
- raw local-traffic regression surfaces in `src/passes/pass_manager_wbtest.mbt`
- CLI and artifact replay surfaces in `src/cmd/cmd_wbtest.mbt`

That map is useful even before any `simplify_locals_nostructure.mbt` file exists because it tells future contributors where the closest already-landed local reasoning lives in this repo.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/simplify-locals-nostructure/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/simplify-locals-nostructure/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/variant-surface.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `simplify-locals-nostructure` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`
2. `docs/wiki/binaryen/passes/simplify-locals-nostructure/index.md`
3. `docs/wiki/binaryen/passes/simplify-locals-nostructure/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/simplify-locals-nostructure/variant-surface.md`
5. `docs/wiki/binaryen/passes/simplify-locals-nostructure/wat-shapes.md`
6. `docs/wiki/binaryen/passes/simplify-locals-nostructure/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `src/passes/optimize_test.mbt`
9. `agent-todo.md`
10. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
11. `src/passes/simplify_locals.mbt`
12. `src/passes/reorder_locals.mbt`
13. `src/passes/pass_manager_wbtest.mbt`
14. `src/cmd/cmd_wbtest.mbt`
15. `docs/wiki/binaryen/passes/tuple-optimization/index.md`
16. `docs/wiki/binaryen/passes/simplify-locals/index.md`
17. `docs/wiki/binaryen/passes/reorder-locals/index.md`
18. `docs/wiki/binaryen/passes/coalesce-locals/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, the removed-registry tracking, the tuple-slot blocker story, and the neighboring implementation files and dossiers that a real future local port would need to interoperate with.
