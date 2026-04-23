---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../binaryen/passes/inlining-optimizing/index.md
  - ../../binaryen/passes/inlining-optimizing/binaryen-strategy.md
  - ../../binaryen/passes/inlining-optimizing/planning-partial-inlining-and-reruns.md
  - ../../binaryen/passes/inlining-optimizing/wat-shapes.md
  - ../../binaryen/passes/inlining-optimizing/starshine-strategy.md
  - ../../binaryen/passes/inlining/index.md
  - ../../binaryen/passes/inlining/binaryen-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/dae-optimizing/index.md
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/precompute-propagate/index.md
---

# `inlining-optimizing` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `inlining-optimizing` dossier already had the required landing page, Binaryen strategy page, planning/rerun explainer, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- older 2026-04-20 wording in the living pages still overread the reviewed `version_129` source by teaching some `call_ref` sites as chosen inline-planner inputs instead of keeping the stricter direct-call-only planning surface explicit

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched pages and catalogs so the dossier is usable from beginner orientation through future port planning without preserving the older planner overread.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `Inlining.cpp` on `version_129` and `main`
- `pass.cpp`
- `opt-utils.h`
- `pass.h`
- `NoInline.cpp`
- `module-utils.cpp`
- the main `inlining*`, `no-inline*`, `inline-main`, and inline-hint lit roster

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `agent-todo.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring `dae-optimizing`, `duplicate-function-elimination`, `precompute-propagate`, and plain `inlining` dossiers

## Durable findings

### 1. The existing Binaryen dossier needed provenance and a planner-surface correction, not a brand-new pass explanation

The existing pages were already directionally strong about whole-module planning, partial inlining, and nested reruns.
What changed in this run was a tighter source readback:

- on 2026-04-23 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- the reviewed `version_129` source still supports the later plain-`inlining` correction: chosen inline actions are planned from reachable direct `call` / `return_call` sites, not from a general `call_ref`-selection surface
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the updated dossier claims

So the right maintenance action was to add an immutable source manifest and align the optimizing pages with the stricter direct-call planner wording already captured in the neighboring plain `inlining` dossier.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`inlining-optimizing` remains unimplemented in Starshine.
There is still no `src/passes/inlining_optimizing.mbt` owner file.

But the repo already had a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps `inlining-optimizing` in the boundary-only registry surface
- the same file's request expansion path rejects the pass with a boundary-only error rather than pretending it exists in the active hot pipeline
- `agent-todo.md` already keeps a dedicated `INL` backlog slice with both rewrite and nested-rerun deliverables
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records the canonical late-tail slot and the shared nested post-inlining rerun rule with `dae-optimizing`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` already treats the pass as a boundary-only whole-module transform, not a future HOT peephole

Before this run, that local status was scattered.
The new Starshine page turns it into one teachable read-along path.

### 3. The current local planning story is narrower and cleaner than a fake “partial implementation” story

The most honest local summary is not “nothing exists.”
It is:

- boundary-only name preserved
- active request guard preserved
- backlog slice and scheduler slot preserved
- exact future landing zone visible
- transform itself still absent

That matters because `inlining-optimizing` is not a plausible fit for the current HOT-only pass manager surface without new boundary/module machinery.
Its future implementation must own:

- module-wide function summaries
- whole-module inline planning
- callsite rewrite plus dead-helper cleanup
- touched-function tracking
- nested reruns of `precompute-propagate` plus the default function pipeline

This is much more than adding one more function-local rewrite file beside the current HOT passes.

### 4. The direct-call-only planner correction should stay explicit across the whole optimizing folder

The older dossier wording blurred together three different facts:

- chosen inline actions are planned from direct `call` / `return_call` sites
- copied code may still contain `call_ref` / `return_call_ref` that the updater must repair
- `ref.func` and other non-direct uses still matter for keeping the callee boundary alive

The updated living pages now keep those separate instead of teaching `version_129` as if it selected arbitrary precise `call_ref` sites directly.
That correction matters because it changes both beginner understanding and future port scope.
A first parity port should start from the direct-call planner contract and treat broader indirect/ref-call work as a deliberate future expansion only if newer upstream source requires it.

### 5. A future local implementation should be taught as a late boundary/module pass with one nested helper contract

Re-reading the local scheduler and backlog surfaces reinforces a planning point:

- `dae-optimizing` and `inlining-optimizing` share the same post-inlining nested cleanup rule
- `inlining-optimizing` sits immediately before the late `duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements` cleanup tail
- the pass depends on `precompute-propagate` and the existing default function-pass cluster as nested work, not just on a standalone inline rewrite primitive

So the right local mental model is:

1. boundary/module planner pass
2. inline rewrite plus dead-helper removal
3. touched-function set
4. filtered nested `precompute-propagate` + default function-pipeline rerun
5. only then late-tail boundary cleanup passes

That is the practical Starshine landing shape the new page makes explicit.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/inlining-optimizing/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/inlining-optimizing/index.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/planning-partial-inlining-and-reruns.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `inlining-optimizing` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md`
2. `docs/wiki/binaryen/passes/inlining-optimizing/index.md`
3. `docs/wiki/binaryen/passes/inlining-optimizing/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/inlining-optimizing/planning-partial-inlining-and-reruns.md`
5. `docs/wiki/binaryen/passes/inlining-optimizing/wat-shapes.md`
6. `docs/wiki/binaryen/passes/inlining-optimizing/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `agent-todo.md`
9. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
10. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
11. `docs/wiki/binaryen/passes/dae-optimizing/index.md`
12. `docs/wiki/binaryen/passes/duplicate-function-elimination/index.md`
13. `docs/wiki/binaryen/passes/precompute-propagate/index.md`
14. `docs/wiki/binaryen/passes/inlining/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, the corrected planner surface, and the neighboring local passes a real future port would need to interoperate with.
