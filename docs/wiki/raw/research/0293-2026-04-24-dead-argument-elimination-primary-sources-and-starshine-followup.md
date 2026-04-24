# 0293 - `dead-argument-elimination` primary-source and Starshine follow-up

- Date: 2026-04-24
- Scope: refresh the existing plain `dead-argument-elimination` dossier after the `dae-optimizing` bridge landed, add an immutable primary-source manifest, and add the missing Starshine status/port-strategy page.
- Chosen pass: `dead-argument-elimination`.
- Upstream public CLI alias: `dae`.
- Local Starshine registry name: `dead-argument-elimination` in `src/passes/optimize.mbt`.
- Current registry status: boundary-only.
- Backlog status: no dedicated plain-DAE slice; the active `DAE` backlog family in `agent-todo.md` is for the default-path optimizing sibling.

## Why this pass was selected

The existing folder already had a landing page, Binaryen strategy, WAT-shape catalog, and source-confirmed implementation/test-map page, but it still lagged the newer wiki quality bar in two ways:

1. it cited online primary sources directly without an immutable raw source manifest under `docs/wiki/raw/binaryen/`;
2. it had no dedicated Starshine strategy/status page tying the upstream `dae` contract to exact local registry, request-rejection, backlog, and future-port code surfaces.

That made plain DAE worse than its `dae-optimizing` sibling for readers who need the complete chain from upstream source to local Starshine status.

## Sources consulted

Primary-source manifest added in this run:

- `docs/wiki/raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md`

Main official Binaryen sources captured there:

- <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast>

Local source/status surfaces reviewed:

- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/fuzz_harness_wbtest.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dae2/index.md`
- `agent-todo.md`

## Durable conclusions

- Upstream plain DAE is the original shared `DeadArgumentElimination.cpp` engine with the default `optimize = false` setting.
- Upstream `dae-optimizing` is the same engine with the optimizing flag enabled and an extra nested cleanup rerun after productive changes.
- Upstream `dae2` is a separately registered experimental sibling and must not be treated as evidence for plain DAE.
- Current Starshine knows the descriptive name `dead-argument-elimination` as a boundary-only registry entry; it does not know the upstream shorthand `dae` today.
- Current Starshine also knows `dead-argument-elimination-optimizing` as boundary-only, but that is the local descriptive sibling name rather than exact upstream `dae-optimizing`.
- Current presets omit both plain and optimizing DAE because neither is implemented.
- `agent-todo.md` has DAE backlog slices for the optimizing sibling (`[DAE]001` and `[DAE]002`) but no dedicated plain-DAE slice.
- Future implementation should share one module-boundary core between plain and optimizing names, then make the nested cleanup scheduler difference explicit.

## Wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/dead-argument-elimination/starshine-strategy.md`.
- Refreshed the plain-DAE landing, Binaryen strategy, implementation/test-map, and WAT-shape catalog with the raw manifest, 2026-04-24 provenance, and Starshine page links.
- Updated `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, `docs/wiki/log.md`, and `CHANGELOG.md` so the new provenance and Starshine status page are visible from the main catalogs.

## Follow-up questions

- Should Starshine add exact upstream aliases `dae` and `dae-optimizing`, or keep only the descriptive local names?
- Should plain DAE get its own backlog slice, or should it be implemented only as a public/debug entry point derived from the optimizing DAE core?
- When the port starts, which existing module-pass machinery should own signature rewrites, local additions for constant actuals, and type-section repair?
