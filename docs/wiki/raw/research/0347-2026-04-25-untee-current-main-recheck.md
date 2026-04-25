---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-untee-current-main-recheck.md
  - ../binaryen/2026-04-23-untee-primary-sources.md
  - ./0279-2026-04-23-untee-primary-sources-and-starshine-followup.md
  - ./0185-2026-04-21-untee-binaryen-research.md
  - ../../binaryen/passes/untee/index.md
  - ../../binaryen/passes/untee/binaryen-strategy.md
  - ../../binaryen/passes/untee/implementation-structure-and-tests.md
  - ../../binaryen/passes/untee/flattening-code-pushing-and-tee-boundaries.md
  - ../../binaryen/passes/untee/wat-shapes.md
  - ../../binaryen/passes/untee/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../agent-todo.md
supersedes:
  - ./0279-2026-04-23-untee-primary-sources-and-starshine-followup.md
---

# `untee` current-main recheck

## Why this follow-up exists

The `untee` dossier was already complete enough for beginner-through-advanced readers, but a focused hygiene check found stale freshness wording inside the folder:

- the landing page and source manifest described the pass as rechecked on 2026-04-23
- `binaryen-strategy.md` and `implementation-structure-and-tests.md` still contained a narrower “2026-04-21 drift check” sentence

That mismatch did not change the pass contract, but it made the current-main provenance harder to trust.
This follow-up records a fresh 2026-04-25 primary-source bridge and normalizes the living pages around it.

## Primary source ingested

Added:

- `docs/wiki/raw/binaryen/2026-04-25-untee-current-main-recheck.md`

It captures official Binaryen `version_129` and current-`main` URLs for:

- `src/passes/Untee.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/SimplifyLocals.cpp`
- `test/lit/passes/untee.wast`

## Current-main result

The recheck found no teaching-relevant upstream drift from the documented `version_129` contract:

- `Untee` remains a function-parallel `PostWalker`.
- The only real visitor is still `visitLocalSet(...)`.
- Ordinary `local.set` nodes still remain outside the pass scope.
- Reachable `local.tee` nodes still expand into explicit `local.set` plus `local.get` form.
- The synthetic `local.get` still uses the function's declared local type.
- Unreachable tees still delete the tee shell and keep the unreachable child instead of fabricating a get-after-unreachable wrapper.
- `pass.cpp` still exposes the public `untee` spelling and description.
- `passes.h` still declares the pass constructor.
- The dedicated `untee.wast` proof surface remains the same small shape oracle.
- The default no-DWARF optimization roster still does not schedule `untee`.

## Living pages updated

- `docs/wiki/binaryen/passes/untee/index.md`
- `docs/wiki/binaryen/passes/untee/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/untee/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/untee/flattening-code-pushing-and-tee-boundaries.md`
- `docs/wiki/binaryen/passes/untee/wat-shapes.md`
- `docs/wiki/binaryen/passes/untee/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## Starshine status

The local status did not change:

- `src/passes/optimize.mbt` still tracks `untee` as a removed registry name.
- Removed pass requests are still rejected before hot-pipeline execution.
- There is still no `src/passes/untee.mbt` owner file.
- `src/passes/simplify_locals.mbt` remains only the nearest locals-rewrite landing zone, not an implementation of upstream `untee`.
- `src/passes/pass_manager_wbtest.mbt` still contains adjacent-tee simplify-locals coverage rather than `untee` pass coverage.
- `agent-todo.md` still has no dedicated `untee` slice.

## Remaining uncertainty

No new upstream contradiction was found.
The only caveat is scope: this was a focused current-main recheck of the pass owner, public registration, constructor declaration, nearby locals-family source, and dedicated test file. It was not a full scheduler audit beyond confirming that `untee` is still absent from the reviewed default function-optimization roster.
