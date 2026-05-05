# 0461 - Binaryen `remove-unused-brs` current-main recheck

## Scope

- Continue the Binaryen pass wiki-ing campaign after the refreshed `remove-unused-brs` dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Deepen the existing `remove-unused-brs` folder with a 2026-05-05 freshness bridge and a dedicated Starshine strategy page.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/remove-unused-brs/`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the repo workflow again after the earlier `remove-unused-brs` dossier work.

At this point:

- the folder already had a strong upstream contract page, a source-confirmed implementation/test map, a shape catalog, and detailed local family pages
- the biggest remaining teaching gap was the lack of a dedicated Starshine strategy page that tied the local HOT strategy to exact MoonBit code locations
- the stale-reference angle was the dated current-main bridge: the folder still only carried the 2026-04-22 freshness layer before this run

So this run was not about choosing a new pass.
It was about updating an already-deep pass dossier so the current-main freshness layer and the local code map stay honest and easy to navigate.

## Official Binaryen sources re-checked

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md`

The reviewed surfaces were:

- `RemoveUnusedBrs.cpp`
- `pass.cpp`
- `remove-unused-brs.wast`
- `remove-unused-brs-gc.wast`
- `remove-unused-brs-eh.wast`
- `remove-unused-brs_branch-hints-unconditionalize.wast`
- the earlier `version_129` release/source/test anchors already in the dossier

## Durable findings

### 1. The upstream contract is still the same staged control-cleanup pass

The current-main spot check did not change the teaching story.
The pass is still best explained as a staged function-parallel structured-control cleanup with:

- flow cleanup
- loop cleanup
- block sinking
- GC `br_on_*` cleanup
- jump-threading
- late `br_if` / `br_table` / `select` / local-set-arm cleanup

### 2. The main local documentation gap was the Starshine strategy page

The folder already had `starshine-hot-ir-strategy.md`, but that page was an implementation companion, not a concise strategy overview.
This run closes that gap by adding a dedicated `starshine-strategy.md` that explains:

- the raw pre-lift gate in `pass_manager.mbt`
- the HOT rewrite engine in `remove_unused_brs.mbt`
- the exact registry / preset / dispatch / test code map in the repo
- the main local-vs-upstream boundaries

### 3. The freshness layer is now explicit

The folder now carries:

- the original 2026-04-22 raw primary-source manifest
- a 2026-05-05 current-main bridge
- the living upstream strategy and implementation pages that cite both

That keeps future follow-ups from having to reconstruct provenance from chat history.

## Files changed because of this follow-up

- `docs/wiki/raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md`
- `docs/wiki/raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/index.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## High-level conclusion

Binaryen `remove-unused-brs` still needs to be taught as more than dead-branch stripping, but the local dossier now has the missing current-main freshness bridge and an exact Starshine strategy page so readers can follow the implementation without guesswork.
