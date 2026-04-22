---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../binaryen/passes/code-folding/index.md
  - ../../binaryen/passes/code-folding/binaryen-strategy.md
  - ../../binaryen/passes/code-folding/terminating-tails.md
  - ../../binaryen/passes/code-folding/wat-shapes.md
  - ../../binaryen/passes/code-folding/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cli/cli_test.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/merge-blocks/index.md
  - ../../binaryen/passes/remove-unused-brs/index.md
  - ../../binaryen/passes/remove-unused-names/index.md
  - ../../binaryen/passes/rse/index.md
---

# `code-folding` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `code-folding` dossier already had a useful landing page, Binaryen strategy page, terminating-tail deep dive, and WAT-shape catalog.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still described the folder only as an upstream research home, without a clean bridge to the exact in-repo Starshine status and future port surfaces

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-code-folding-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `CodeFolding.cpp` on `version_129` and `main`
- `pass.cpp`
- `opt-utils.h`
- the dedicated `code-folding.wast` file
- the supporting helper files `utils.h`, `branch-utils.h`, `effects.h`, `eh-utils.h`, and `label-utils.h`

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `src/cli/cli_test.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, and `rse`

## Durable findings

### 1. The Binaryen side did not need a rewrite; it needed provenance and freshness anchors

The existing upstream pages were still broadly correct.
The missing piece was provenance:

- on 2026-04-22 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` check did not surface a new teaching-relevant drift beyond the existing strategy, terminating-tail, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and then thread that provenance into the living pages, not to replace the pass explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still unimplemented

`code-folding` is still unimplemented in Starshine, and that remains the right top-line status.
But the repo already has a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` keeps `code-folding` in the removed-name registry, so the name is intentionally tracked rather than forgotten
- `src/cli/cli_test.mbt` proves the CLI still accepts and preserves the spelling `--code-folding`
- `agent-todo.md` keeps an explicit `CF` backlog slice with motion-safety and artifact-validation deliverables
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already records where the pass belongs in the canonical late cleanup cluster
- the neighboring Starshine dossiers for `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, and `rse` already explain the surrounding passes a future port would need to compose with

Before this run, that local state was scattered.
The new Starshine page turns it into one teachable path.

### 3. The honest Starshine story here is “boundary and port plan,” not a fake implementation page

Unlike the already-implemented hot and module passes, `code-folding` does not have an in-tree MoonBit owner file yet.
The new Starshine page therefore makes three things explicit instead of smoothing them over:

- current Starshine executes no `code-folding` transform today
- the in-repo implementation status is deliberately boundary-only tracking through the removed-name registry, CLI pass-name plumbing, backlog slice, and scheduler docs
- the exact read-along path for a future implementation already exists in neighboring code and docs, especially the late-cluster passes that would consume or clean up `code-folding` output

That is a more useful beginner-to-advanced teaching frame than pretending the dossier is only upstream-facing until code lands.

### 4. The future local implementation should be taught as a late-cluster HOT rewrite family, not as an isolated pass port

Re-reading the local scheduler docs and neighboring pass dossiers reinforces a useful local planning point:

- Binaryen places `code-folding` late, between the second `vacuum` / `reorder-locals` cluster and the final `merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> precompute -> optimize-instructions -> heap-store-optimization -> rse -> vacuum` cleanup tail
- Starshine already implements several of those late neighbors as active HOT passes
- a future Starshine `code-folding` port would therefore have to be explained together with those neighboring cleanup consumers, not as a free-standing generic tail-merging transform

The new local page makes that dependency map explicit.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-code-folding-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/code-folding/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/code-folding/index.md`
- `docs/wiki/binaryen/passes/code-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-folding/terminating-tails.md`
- `docs/wiki/binaryen/passes/code-folding/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `code-folding` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-code-folding-primary-sources.md`
2. `docs/wiki/binaryen/passes/code-folding/index.md`
3. `docs/wiki/binaryen/passes/code-folding/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/code-folding/terminating-tails.md`
5. `docs/wiki/binaryen/passes/code-folding/wat-shapes.md`
6. `docs/wiki/binaryen/passes/code-folding/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `src/cli/cli_test.mbt`
9. `agent-todo.md`
10. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
11. `docs/wiki/binaryen/passes/merge-blocks/index.md`
12. `docs/wiki/binaryen/passes/remove-unused-brs/index.md`
13. `docs/wiki/binaryen/passes/remove-unused-names/index.md`
14. `docs/wiki/binaryen/passes/rse/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the backlog and scheduler placement, the CLI-tracked pass name, and the neighboring implemented passes that a real future local port would need to interoperate with.
