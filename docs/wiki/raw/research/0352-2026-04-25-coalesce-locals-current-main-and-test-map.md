---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/binaryen-strategy.md
  - ../../binaryen/passes/coalesce-locals/implementation-structure-and-tests.md
  - ../../binaryen/passes/coalesce-locals/interference-and-ordering.md
  - ../../binaryen/passes/coalesce-locals/wat-shapes.md
  - ../../binaryen/passes/coalesce-locals/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `coalesce-locals` current-main and test-map follow-up

## Why this follow-up exists

The `coalesce-locals` dossier already had the required overview, Binaryen strategy, transformed-shape catalog, interference/order guide, and Starshine status page. It still lacked the now-standard dedicated implementation/test-map page, and the older 2026-04-22 source manifest did not give readers a fresh current-`main` bridge.

This follow-up keeps the existing pass explanation, adds the missing file/test map, and records a narrow current-`main` source recheck without inventing a Starshine implementation.

## Primary-source recheck

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`

The recheck used official Binaryen sources:

- `CoalesceLocals.cpp` on `version_129` and current `main`
- `pass.cpp` on `version_129` and current `main`
- `opt-utils.h` on `version_129` and current `main`
- `liveness-traversal.h`, `numbering.h`, and `utils.h` helper surfaces from `version_129`
- `test/lit/passes/coalesce-locals.wast` on `version_129` and current `main`

Durable result: no teaching-relevant drift was found on the checked current-`main` surfaces. The pass remains a late function-parallel local-slot coalescer: liveness plus value-numbered interference, exact-type greedy coloring, copy-profit ordering, backedge priority, and cleanup/refinalization.

## New living page

Added:

- `docs/wiki/binaryen/passes/coalesce-locals/implementation-structure-and-tests.md`

The new page closes the reader-facing gap between the high-level Binaryen strategy and the concrete upstream source layout. It explains:

- why `CoalesceLocals.cpp` is the owner file to read first
- how `LivenessWalker`, `numbering.h`, and `utils.h` participate
- where `pass.cpp` registers the normal and learning variants
- where scheduler slots prove the two default no-DWARF placements
- what each important region of `coalesce-locals.wast` proves
- which Starshine files are only status/prerequisite surfaces today

## Starshine status clarified

No local pass was implemented in this run.

The source-backed local status remains:

- `src/passes/optimize.mbt:146` tracks `coalesce-locals` in `pass_registry_removed_names()`.
- `src/passes/pass_manager.mbt` has no `coalesce-locals` dispatcher case.
- There is no `src/passes/coalesce_locals.mbt` owner file.
- `agent-todo.md` keeps the future `CL` work as active backlog rather than landed behavior.
- `src/passes/reorder_locals.mbt` and `src/passes/simplify_locals.mbt` are neighboring implementation surfaces a future port must compose with, not a substitute coalescer.

## Files updated by this follow-up

- `docs/wiki/raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`
- `docs/wiki/raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md`
- `docs/wiki/binaryen/passes/coalesce-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/coalesce-locals/index.md`
- `docs/wiki/binaryen/passes/coalesce-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

`CHANGELOG.md` was intentionally not edited in this run because the worktree already had unrelated local `CHANGELOG.md` changes before this wiki task began.

## Maintenance rule going forward

Start future `coalesce-locals` research from this order:

1. `docs/wiki/binaryen/passes/coalesce-locals/index.md`
2. `docs/wiki/binaryen/passes/coalesce-locals/implementation-structure-and-tests.md`
3. `docs/wiki/binaryen/passes/coalesce-locals/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/coalesce-locals/interference-and-ordering.md`
5. `docs/wiki/binaryen/passes/coalesce-locals/wat-shapes.md`
6. `docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md`
7. `docs/wiki/raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`
8. `docs/wiki/raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`

If current-main behavior changes later, add a new raw recheck and update the living pages instead of editing either raw source manifest in place.
