---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../binaryen/passes/inlining-optimizing/index.md
  - ../../binaryen/passes/inlining-optimizing/implementation-structure-and-tests.md
  - ../../binaryen/passes/inlining-optimizing/binaryen-strategy.md
  - ../../binaryen/passes/inlining-optimizing/planning-partial-inlining-and-reruns.md
  - ../../binaryen/passes/inlining-optimizing/wat-shapes.md
  - ../../binaryen/passes/inlining-optimizing/starshine-strategy.md
  - ../../binaryen/passes/inlining/index.md
  - ../../binaryen/passes/inlining/implementation-structure-and-tests.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `inlining-optimizing` current-main and test-map follow-up

## Why this follow-up exists

The `inlining-optimizing` dossier already had the required overview, Binaryen strategy, transformed-shape catalog, planning/rerun explainer, and Starshine status page.
It still had one durable gap compared with neighboring pass folders: no dedicated implementation/test-map page for the optimizing variant.
Readers had to infer the owner/test split from the plain `inlining` folder plus the optimizing strategy page.

This follow-up closes that gap without duplicating the whole plain inliner dossier.

## Primary source ingested

New immutable source bridge:

- `docs/wiki/raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md`

The recheck used official Binaryen primary sources only:

- `version_129` release page and source files retained as the tagged oracle
- current `main` and `version_129` `Inlining.cpp`
- current `main` and `version_129` `pass.cpp`
- current `main` and `version_129` `opt-utils.h`
- current `main` and `version_129` `pass.h`
- current `main` and `version_129` `NoInline.cpp`
- current `main` and `version_129` `module-utils.cpp`
- current `main` and `version_129` `inlining*`, `no-inline*`, and `inline-main` lit tests

## Durable findings

### 1. No teaching-relevant current-main drift was found

The 2026-04-25 source bridge did not change the 2026-04-23 strategy conclusion.
The current dossier should still teach:

- one shared `Inlining.cpp` engine for plain `inlining` and `inlining-optimizing`
- chosen inline actions planned from reachable direct `call` / `return_call` sites in the reviewed contract
- `call_ref` / `call_indirect` families as repair, root, and surrounding-helper surfaces rather than a broad selected-callsite planner
- `NoInline.cpp` and `module-utils.cpp` as policy inputs that can block or preserve inlining eligibility
- `opt-utils.h` as the unique optimizing-variant proof surface

### 2. The missing page was not another strategy essay

The new living page is intentionally a file/test map.
It answers:

- which source file owns the shared inliner?
- which file proves the optimizing suffix?
- which tests prove the shared inline shapes?
- which tests prove no-inline policy?
- why ordinary WAT tests do not directly show the nested rerun as a single simple diff?
- which exact Starshine code locations currently track the pass name and reject active requests?

That is the missing beginner-to-advanced bridge.

### 3. The Starshine code-map needed one small health repair

While adding the map page, the touched Starshine page was checked against the current worktree.
The previous `src/passes/optimize.mbt#L281-L291` request-guard anchor was stale.
The current exact locations are:

- `src/passes/optimize.mbt#L127-L141` for `pass_registry_boundary_only_names()` and the `inlining-optimizing` entry
- `src/passes/optimize.mbt#L458-L468` for lookup plus boundary-only active-request rejection
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L57-L61` for the whole-module/layout boundary bucket
- `agent-todo.md#L513-L521` for the `INL` backlog slice and first deliverable
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md#L35-L40` for the canonical post-pass slot and shared nested-rerun rule

The Starshine page now points at the current line ranges.

## Files changed because of this follow-up

- `docs/wiki/raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md`
- `docs/wiki/raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/index.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/planning-partial-inlining-and-reruns.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

Future `inlining-optimizing` changes should keep five pages aligned:

1. `index.md` for overview and validation summary
2. `implementation-structure-and-tests.md` for owner/helper/test map
3. `binaryen-strategy.md` for algorithmic explanation
4. `planning-partial-inlining-and-reruns.md` for root/partial/rerun nuance
5. `starshine-strategy.md` for current local code locations and future port boundaries

If a later Binaryen source recheck changes the planner surface, update the plain `inlining` folder too because both public pass names share the same upstream implementation engine.
