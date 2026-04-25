# `reorder-globals-always` primary-source bridge and Starshine follow-up

Date: 2026-04-25  
Status: source bridge for existing living dossier  
Pass: `reorder-globals-always`  
Local registry status: `boundary-only` in `src/passes/optimize.mbt`  
Binaryen release reviewed: `version_129`  
Current-main drift check: narrow spot check on 2026-04-25; no teaching-relevant drift found on the reviewed files

## Why this follow-up exists

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/`
- the existing `docs/wiki/binaryen/passes/reorder-globals-always/` folder

The dossier was already accurate about the small-module/test/internal-fixup sibling mechanics, but it still had two durable gaps relative to the current wiki quality bar:

1. no sibling-specific immutable primary-source manifest under `docs/wiki/raw/binaryen/`
2. no dedicated Starshine status/port-strategy page for readers who want to follow the local repository surfaces instead of only upstream Binaryen sources

This follow-up closes those gaps without creating a near-duplicate overview page.

## Primary sources captured

Added:

- `docs/wiki/raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md`

That raw manifest captures:

- official Binaryen `version_129` release page
- `src/passes/ReorderGlobals.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/GlobalStructInference.cpp`
- `src/support/topological_sort.h`
- `src/wasm-traversal.h`
- `src/wasm.h`
- `test/lit/passes/reorder-globals.wast`
- `test/lit/passes/reorder-globals-real.wast`
- current-`main` counterparts used for a narrow drift spot check

## Source-backed Binaryen contract preserved

The durable upstream contract remains:

- `reorder-globals-always` is a real public/test pass name, not just a local nickname.
- `pass.cpp` registers it separately from ordinary `reorder-globals`.
- `passes.h` declares the separate constructor.
- `ReorderGlobals.cpp` implements both variants through one shared `ReorderGlobals` class.
- Ordinary `reorder-globals` takes the `< 128`-globals early return; the always sibling does not.
- Always mode uses the smooth synthetic score multiplier `1.0 + (i / 128.0)`.
- Always mode still preserves imports-first ordering, initializer dependency edges, original-index ties, and declaration-list rebuild plus `updateMaps()`.
- `GlobalStructInference.cpp` is the practical internal caller: after helper-global creation, it runs nested `reorder-globals-always` so added globals appear before their uses.
- The dedicated lit proof split is still `reorder-globals.wast` for small-module sibling behavior and `reorder-globals-real.wast` for the production contrast.

## Starshine local status recorded

Added:

- `docs/wiki/binaryen/passes/reorder-globals-always/starshine-strategy.md`

The local status is now explicit:

- `src/passes/optimize.mbt` keeps `reorder-globals-always` in `pass_registry_boundary_only_names()`.
- `run_hot_pipeline_expand_passes(...)` rejects active requests for boundary-only passes with the standard boundary-only error.
- Public `optimize` / `shrink` presets do not schedule the sibling.
- Starshine has no `src/passes/reorder_globals_always.mbt` owner file and no shared `reorder_globals.mbt` owner file today.
- `agent-todo.md` has an `RG - Reorder Globals` production-pass slice but no dedicated `reorder-globals-always` slice.
- A future sibling-faithful port should share the eventual production `reorder-globals` module-pass engine, differing only in the small-module cutoff and smooth scoring policy.

## Local code surfaces for future readers

The new Starshine page points to exact repository surfaces:

- `src/passes/optimize.mbt#L127-L140` for boundary-only name tracking
- `src/passes/optimize.mbt#L446-L461` for boundary-only request rejection
- `src/passes/optimize.mbt#L242-L270` and `#L382-L410` for active preset omission
- `src/lib/types.mbt#L113`, `#L171`, `#L193`, `#L224`, `#L442`, `#L539-L540`, and `#L8059-L8061` for the index-bearing global representation a future module pass must update
- `agent-todo.md#L668-L680` for the adjacent production `RG` backlog and the explicit lack of a sibling slice
- `docs/wiki/binaryen/passes/reorder-globals/starshine-strategy.md` for the broader production-pass landing-zone map

## Health fixes included

The living pages now cite the new raw manifest instead of relying only on direct online URLs and older research notes.
The older research notes remain valuable historical work, but they are now marked superseded for raw-source provenance and Starshine local-status coverage:

- `docs/wiki/raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md`
- `docs/wiki/raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md`

## Open questions and uncertainty

- The current-main check is intentionally narrow. It did not reveal drift in the reviewed files, but it should not be treated as proof that all future Binaryen global-layout interactions are unchanged.
- Starshine has not yet chosen whether `reorder-globals-always` should become a user-facing pass, an internal-only helper for future GSI-like repairs, or stay deferred until production `reorder-globals` lands.
- Because Starshine uses numeric `GlobalIdx` surfaces while Binaryen IR uses global names internally, any future port must source-confirm every index-bearing repair path before claiming parity.

## Outcome

`reorder-globals-always` now has the complete wiki chain expected for a mature pass dossier:

- overview page
- transformed-shape catalog
- Binaryen strategy page
- implementation/test map
- focused mechanics/proof page
- immutable primary-source manifest
- Starshine status/port-strategy page
- index / tracker / log / changelog coverage
