# `ssa` port-readiness bridge

Date: 2026-04-26

## Question

The full `ssa` folder already had a source-backed overview, shape catalog, Binaryen strategy, and Starshine status page. The remaining gap was that future implementers still had to infer the first safe Starshine slice and validation ladder from the contrast with `ssa-nomerge`.

This note asks: what should a future Starshine full-`ssa` port do first, and which local surfaces make it different from the implemented `ssa-nomerge` sibling?

## Sources read

- Existing living pages in `docs/wiki/binaryen/passes/ssa/`.
- Neighboring `docs/wiki/binaryen/passes/ssa-nomerge/` coverage.
- Official Binaryen sources captured in `docs/wiki/raw/binaryen/2026-04-26-ssa-port-readiness-primary-sources.md`.
- Local Starshine sources:
  - `src/passes/optimize.mbt`
  - `src/passes/ssa_nomerge.mbt`
  - `src/ir/ssa_policy.mbt`
  - `src/ir/ssa_local.mbt`
  - `src/ir/ssa_destroy.mbt`
  - `src/passes/pass_common.mbt`
  - `src/ir/analysis_cache.mbt`
  - `src/passes/ssa_nomerge_test.mbt`

## Findings

- Binaryen full `ssa` is still the shared `SSAify.cpp` engine with `allowMerges = true`; no current-main teaching drift was found from the `version_129` dossier.
- The key full-`ssa` contract is not generic phi SSA. It is a concrete AST encoding:
  - fresh merge local per multi-source get;
  - explicit incoming set values wrapped with `local.tee mergeLocal ...`;
  - function-entry prepends for parameter-entry sources;
  - no prepend for ordinary defaultable local-entry sources because fresh locals already hold defaults.
- Starshine's implemented `ssa-nomerge` does not encode the same shapes. It builds a `HotLocalSsa` overlay and destroys phis through concrete-local assignment plus predecessor `local.set` copies.
- That overlay is reusable for a future full-`ssa` port, but a faithful Binaryen-compatible pass still needs an explicit sibling rewrite path rather than aliasing `ssa-nomerge`.
- Local code-map line anchors in the old `ssa` Starshine page had drifted as `optimize.mbt` grew; the refreshed pages now cite code surfaces rather than pretending the old exact line numbers are stable.

## Port-readiness recommendation

Recommended first slice:

1. Registry honesty: add a known `ssa` status only when a test proves the desired request behavior. Do not silently make `ssa` an alias for `ssa-nomerge`.
2. Analyzer/no-rewrite stage: derive and expose the per-get source classification needed for Binaryen full `ssa`: explicit write, parameter entry, ordinary default entry, nondefaultable entry.
3. Straight direct-lit compatibility: prove existing official `ssa.wast` families or local analogues for repeated-param splitting and default ref/tuple replacement.
4. Merge-local first rewrite: add source-derived branch-join tests for two explicit incoming writes and one-arm parameter overwrite, and require Binaryen-oracle shape comparison against `wasm-opt --ssa`.
5. Default-entry negative/positive split: prove ordinary defaultable entries need no prepended store and nondefaultable entries do not get invented defaults.
6. Sibling stability: rerun existing `ssa-nomerge` tests to prove predecessor-copy lowering remains unchanged.

## Durable wiki changes made

- Added `docs/wiki/binaryen/passes/ssa/starshine-port-readiness-and-validation.md`.
- Refreshed `docs/wiki/binaryen/passes/ssa/index.md` and `starshine-strategy.md` to link the new bridge and updated source manifest.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/binaryen/passes/tracker.md` so `ssa` is classified as a deep dossier with a port-readiness bridge.

## Uncertainty

- This note does not assert that a full `ssa` port is currently on the active no-DWARF or saved `-O4z` queue.
- This note does not choose whether the future implementation should reuse `HotLocalSsa` directly or build a thinner Binaryen-shaped reaching-set adapter first; it only states the source classifications and rewrite shapes such an implementation must preserve.
