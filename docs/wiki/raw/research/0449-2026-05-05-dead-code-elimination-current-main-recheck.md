# 0449 - `dead-code-elimination` current-main recheck and Starshine strategy refresh

Date: 2026-05-05  
Status: completed research ingest  
Pass: `dead-code-elimination` / upstream `dce`  
Local registry status: `active hot` in `src/passes/optimize.mbt`  
Related living dossier: `docs/wiki/binaryen/passes/dead-code-elimination/`

## Why this follow-up exists

The `dead-code-elimination` dossier was already useful, but it still lacked a fresh current-main source bridge and a dedicated Starshine strategy page that made the local HOT rewrite family easy to scan from the folder entry point.
This follow-up records the 2026-05-05 current-main recheck and the associated wiki cleanup so the living pages can point at a fresher provenance layer and a cleaner local navigation path.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/DeadCodeElimination.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/dce_all-features.wast`
  - `test/lit/passes/dce_vacuum_remove-unused-names.wast`
  - `test/lit/passes/dce-eh.wast`
  - `test/lit/passes/dce-eh-legacy.wast`
  - `test/lit/passes/dce-stack-switching.wast`
- Tagged comparison anchors:
  - the same owner and lit files on `version_129`
- Existing living dossier pages for the pass

## Source-backed Binaryen conclusions

- `dce` still exposes the same small contract on the reviewed `main` surfaces: preserve earlier executing children as `drop`s before the first unreachable child, trim dead block suffixes, change some control nodes to `unreachable`, and keep the narrow EH nested-pop repair.
- `pass.cpp` still registers `dce` as `removes unreachable code` and still places it immediately after `ssa-nomerge` in the no-DWARF default function pipeline.
- The dedicated lit files still exercise the same teaching-relevant families: unreachable-shape cleanup, EH and stack-switching boundaries, and the intended downstream neighborhood with `vacuum` and `remove-unused-names`.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Starshine local status

The local status is unchanged by this source refresh:

- `dead-code-elimination` remains an active hot pass in Starshine;
- the local implementation is still a broader HOT rewrite family with cache-heavy region rewriting, explicit tail repair, raw-skip heuristics, and writeback guards;
- the pass does **not** claim a direct Binaryen AST port.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/index.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/wat-shapes.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the earlier 2026-04-22 and 2026-04-21 source layers.
It does not change the contract story; it only refreshes the provenance and current-main freshness layer while adding a cleaner Starshine strategy entry point.
