# `simplify-globals-optimizing` primary sources and Starshine follow-up

_Date:_ 2026-04-24  
_Status:_ absorbed into living wiki pages

## Question

The `simplify-globals-optimizing` folder already had a usable Binaryen strategy page, a focused linear-trace / `read-only-to-write` page, and a WAT-shape catalog, but it still lagged behind neighboring late-pass dossiers in two ways:

1. no immutable raw primary-source manifest for the official Binaryen sources reviewed for this exact pass, and
2. no dedicated Starshine strategy/status page that mapped the upstream contract to exact in-repo code and backlog surfaces.

The maintenance question for this run was whether to treat that as a worthwhile major gap despite the tracker having no obvious `none` target left.

## Sources reviewed

- New raw capture: `docs/wiki/raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`
- Existing research: `docs/wiki/raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`
- Existing sibling capture: `docs/wiki/raw/binaryen/2026-04-23-simplify-globals-primary-sources.md`
- Binaryen release and source URLs recorded in the raw capture, especially:
  - `src/passes/SimplifyGlobals.cpp`
  - `src/passes/pass.cpp`
  - `src/pass.h`
  - `src/ir/effects.h`
  - `src/ir/find_all.h`
  - `src/ir/linear-execution.h`
  - `src/ir/properties.h`
  - `src/ir/utils.h`
  - the `simplify-globals-*` and `propagate-globals-globally.wast` lit files
- Local Starshine surfaces:
  - `src/passes/optimize.mbt`
  - `src/passes/registry_test.mbt`
  - `src/cmd/fuzz_harness_wbtest.mbt`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `agent-todo.md`

## Findings

- The primary-source set for `simplify-globals-optimizing` deliberately overlaps the plain `simplify-globals` dossier because Binaryen implements both public pass names in the same `SimplifyGlobals.cpp` engine.
- The optimizing sibling still needs its own raw manifest because its public contract is not just the shared rewrite engine; it also includes the `optimize = true` changed-function bookkeeping and the nested default-function rerun.
- The key Binaryen distinction for Starshine remains:
  - plain `simplify-globals` = shared global rewrite algorithm and repair only,
  - `propagate-globals-globally` = startup-only propagation subset,
  - `simplify-globals-optimizing` = shared global rewrite algorithm plus nested default function cleanup on changed functions.
- Current Starshine has no `src/passes/simplify_globals_optimizing.mbt` or equivalent owner file.
- Current Starshine does keep `simplify-globals-optimizing` in `pass_registry_boundary_only_names()` in `src/passes/optimize.mbt`, and explicit requests fail through the boundary-only guard in `run_hot_pipeline_expand_passes(...)`.
- The active backlog already has an `SGO` slice in `agent-todo.md`, and it correctly names both the constant-global / dead-write rewrite surface and the nested default-function rerun without the `precompute-propagate` prefix.
- The current public `optimize` / `shrink` preset expansion in `src/passes/optimize.mbt` intentionally stops before this late boundary pass; that absence is part of the current honest local status, not a missing line in the docs.

## Durable wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/simplify-globals-optimizing/implementation-structure-and-tests.md` to make the upstream owner-file / helper / test split explicit for the optimizing sibling.
- Added `docs/wiki/binaryen/passes/simplify-globals-optimizing/starshine-strategy.md` as the dedicated local status and future-port map.
- Refreshed the existing `index.md`, `binaryen-strategy.md`, `linear-traces-read-only-to-write-and-reruns.md`, and `wat-shapes.md` pages so they cite the raw manifest and cross-link the new Starshine strategy page.
- Refreshed `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, and `docs/wiki/log.md`.

## Uncertainties and explicit non-claims

- No local implementation was added in this run.
- The current-main source spot check was narrow; it was sufficient for wiki provenance refresh, not a full upstream drift audit.
- The future local implementation sequence is still open: Starshine may land shared plain-`simplify-globals` machinery first, a startup-only subset first, or the optimizing wrapper first. The wiki should not imply that sequence has already been decided.
- The eventual nested rerun scheduler may need a broader boundary-pass framework rather than a one-off hook; this follow-up records that as a design pressure, not as a completed design.
