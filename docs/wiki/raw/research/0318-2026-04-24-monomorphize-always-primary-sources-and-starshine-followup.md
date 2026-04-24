# `monomorphize-always` primary sources and Starshine follow-up

Date: 2026-04-24  
Status: supported  
Pass: `monomorphize-always`  
Local registry status: `boundary-only` in `src/passes/optimize.mbt`  
Living dossier: `docs/wiki/binaryen/passes/monomorphize-always/`

## Why this follow-up happened

The existing `monomorphize-always` folder had a landing page, Binaryen strategy, implementation/test map, sibling-split note, and WAT-shape catalog. It still had two important wiki-health gaps:

1. no dedicated immutable raw primary-source manifest for the sibling itself
2. no dedicated Starshine status/port-strategy page mapping the local boundary-only state to exact code locations

A focused source reread also exposed one stale wording issue: older pages treated `monomorphize-benefit.wast` as a direct `monomorphize-always` lit proof. The refreshed source capture keeps the relationship more precise: `monomorphize-types.wast` directly runs `--monomorphize-always`, while `monomorphize-benefit.wast` supports the neighboring threshold-policy story for ordinary `monomorphize`.

## Sources reviewed

- Raw manifest added in this run: `docs/wiki/raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md`
- Existing parent raw manifest: `docs/wiki/raw/binaryen/2026-04-24-monomorphize-primary-sources.md`
- Older research note: `docs/wiki/raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md`
- Official Binaryen `version_129` source and tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
- Local Starshine sources:
  - `src/passes/optimize.mbt`
  - `src/passes/registry_test.mbt`
  - `src/cli/cli.mbt`
  - `src/cmd/cmd.mbt`
  - `src/cmd/cmd_wbtest.mbt`
  - `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
  - `agent-todo.md`

## Durable conclusions

- Upstream `monomorphize-always` is a public pass, not a local invention and not only a pass-arg recipe.
- Upstream implements it through the same `Monomorphize.cpp` engine as ordinary `monomorphize`.
- The real split is a constructor/policy flag: ordinary `monomorphize` keeps clones only when they are helpful enough; `monomorphize-always` keeps legal nontrivial clones without that final usefulness rejection.
- The split is less dramatic than the pass name suggests: all correctness, triviality, movement, dropped-result, and parameter-limit guards remain in force.
- The direct upstream lit proof for `--monomorphize-always` is `monomorphize-types.wast`; `monomorphize-benefit.wast` remains supporting evidence for the threshold-tuned parent-policy surface.
- Current Starshine tracks `monomorphize-always` only as a boundary-only registry name in `src/passes/optimize.mbt`; explicit execution expands through `run_hot_pipeline_expand_passes(...)` and returns the boundary-only not-implemented error before any output write.
- Starshine does have relevant option plumbing for ordinary `monomorphize_min_benefit` in CLI/config surfaces, but that is not an implementation of the always sibling.
- `agent-todo.md` has no dedicated `monomorphize-always` backlog slice on 2026-04-24.

## Files updated

- Added `docs/wiki/raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/monomorphize-always/starshine-strategy.md`.
- Refreshed every living page in `docs/wiki/binaryen/passes/monomorphize-always/` to cite the raw manifest and clarify the direct-lit-test surface.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md` so the dossier is discoverable and no longer looks like a provenance/local-status gap.
- Updated `CHANGELOG.md` with a concise docs entry.

## Remaining uncertainty

- The exact practical overlap between `--monomorphize-always` and `--monomorphize --pass-arg=monomorphize-min-benefit@0` should still be described as a close relationship rather than exact equivalence unless a future pass-port thread re-derives every branch in `Monomorphize.cpp` and the pass-runner option plumbing.
- This follow-up did not add implementation work; it only makes the current boundary-only local state and future module-pass requirements explicit.
