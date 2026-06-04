---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-flatten-current-main-implementation-test-map.md
  - ../binaryen/2026-04-23-flatten-primary-sources.md
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/binaryen-strategy.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/wat-shapes.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cli/cli_test.mbt
  - 0065-2026-03-24-ir2-execution-plan.md
  - 0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
---

# `flatten` current-main and implementation/test-map follow-up

## Why this follow-up exists

The `flatten` folder already had the core pieces required for a pass dossier: overview, Binaryen strategy, transformed-shape catalog, focused Flat-IR/prelude guide, Starshine status page, and a tagged raw primary-source manifest.

The durable gap was narrower but still important: unlike neighboring refreshed dossiers, it did not have a dedicated `implementation-structure-and-tests.md` page that maps:

- upstream owner files,
- helper files,
- official lit proof surfaces,
- scheduler placement,
- and exact current Starshine code/status surfaces.

This follow-up adds that page and refreshes the folder around a 2026-04-25 current-main source bridge.

## Primary sources rechecked

Captured in:

- `docs/wiki/raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`

The recheck covered official Binaryen current `main` and retained `version_129` as the tagged oracle:

- `src/passes/Flatten.cpp`
- `src/ir/flat.h`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- helper surfaces: `branch-utils.h`, `eh-utils.h`, `properties.h`, `manipulation.h`
- dedicated tests: `flatten.wast`, `flatten_all-features.wast`, `flatten-eh-legacy.wast`
- neighboring tests retained from the tagged manifest: `opt_flatten.wast`, `flatten_rereloop.wast`, `flatten_i64-to-i32-lowering.wast`

## Durable findings

### 1. No teaching-relevant current-main drift was found

The 2026-04-25 current-main source bridge did not change the pass contract already taught by the folder.

The reviewed current-main surfaces still show:

- `Flatten.cpp` owns the public pass implementation;
- `flat.h` owns the formal Flat IR verifier contract;
- `pass.cpp` places `flatten` in the `optimizeLevel >= 4` aggressive cluster before `simplify-locals-notee-nostructure` and `local-cse`;
- `passes.h` keeps the public constructor declaration;
- `flatten_all-features.wast` is the broad direct behavior proof surface;
- `flatten-eh-legacy.wast` is the direct EH/nested-pop proof surface;
- `flatten.wast` is only a tiny smoke test and should not be over-cited as full coverage.

So the right wiki action was to add the missing file/test map, not to rewrite the strategy pages as a source correction.

### 2. The upstream implementation shape is compact enough to teach directly

The new implementation/test-map page teaches `flatten` as four cooperating surfaces:

1. `Flatten.cpp` for mutation;
2. `flat.h` for the target invariant;
3. `pass.cpp` / `passes.h` for public identity and aggressive scheduler placement;
4. the three dedicated lit files for smoke, all-features, and EH proof lanes.

That is more usable for future contributors than saying “read Binaryen” or embedding owner-file details inside the already-long strategy page.

### 3. The Starshine status remains unchanged but is now more exact

The rechecked local status is:

- `src/passes/optimize.mbt:144-151` lists `flatten` as a known removed pass name;
- `src/cli/cli_test.mbt:280-285` and `src/cli/cli_test.mbt:313-316` preserve `--flatten` in explicit pass-token resolution;
- `src/passes/pass_manager.mbt` has no active `flatten` dispatcher case;
- `docs/0065-2026-03-24-ir2-execution-plan.md:39` still places `flatten` first in old Batch 2 preferred order;
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:47` still lists it as removed until implementation lands;
- `agent-todo.md` still has no dedicated active `flatten` slice.

Mentions of “flattened” in active hot-lower and merge-blocks backlog text are shape descriptions, not a pass plan. The Starshine page and new implementation/test-map page now state that explicitly enough that future readers should not mistake those lines for a hidden `flatten` implementation slice.

### 4. Future test planning should split by proof lane

A faithful local port should not treat the dedicated upstream tests as one undifferentiated source.

The most useful split is:

- `flatten.wast`: tiny smoke / nonnullable-param sanity;
- `flatten_all-features.wast`: broad value-carrying control, branch payload, tee, and unsupported-family behavior;
- `flatten-eh-legacy.wast`: legacy EH and nested-pop repair;
- `opt_flatten.wast`: aggressive preset composition;
- `flatten_rereloop.wast`: downstream flat CFG consumer;
- `flatten_i64-to-i32-lowering.wast`: flattened-world prerequisite for lowering.

That split is now captured in the living implementation/test-map page.

## Files changed because of this follow-up

### New raw source manifest

- `docs/wiki/raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`

### New research note

- `docs/wiki/raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md`

### New living page

- `docs/wiki/binaryen/passes/flatten/implementation-structure-and-tests.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/flatten/index.md`
- `docs/wiki/binaryen/passes/flatten/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/flatten/flat-ir-contract-and-preludes.md`
- `docs/wiki/binaryen/passes/flatten/wat-shapes.md`
- `docs/wiki/binaryen/passes/flatten/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

For future `flatten` wiki work, keep these pages in sync:

1. `index.md` for beginner orientation and current local status;
2. `binaryen-strategy.md` for the detailed algorithm;
3. `implementation-structure-and-tests.md` for owner files, helper files, and proof surfaces;
4. `flat-ir-contract-and-preludes.md` for the formal invariant and prelude mechanics;
5. `wat-shapes.md` for before/after examples;
6. `starshine-strategy.md` for local status and future-port landing zone.

If a future source recheck discovers actual drift, update the strategy and shape pages first. If it only confirms the owner/test surfaces, update the implementation/test-map page and the raw manifest instead.
