# `global-effects` port-readiness research

_Date:_ 2026-04-27  
_Status:_ absorbed into living wiki pages  
_Main living pages:_ `docs/wiki/binaryen/passes/global-effects/`  
_Primary-source capture:_ `docs/wiki/raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md`

## Question

The `global-effects` folder already had a source-backed overview, Binaryen strategy, shape catalog, and Starshine status page, but the tracker still classified it as a dossier rather than deep coverage. The remaining durable gap was implementation-readiness: what exact Starshine code surfaces would a faithful future port touch, what order should slices land in, and how should validation avoid overclaiming for a metadata-only pass?

## Findings

- Upstream Binaryen's public pass is still `generate-global-effects`; Starshine's local compatibility name is `global-effects`.
- The pass is still best taught as metadata production, not direct WAT rewriting.
- Current Binaryen `main` keeps the same durable contract as the earlier `version_129` dossier while structuring propagation around call-graph SCC/component aggregation.
- The official Optimizer Cookbook remains important supporting context for lifecycle: pass metadata can be invalidated when later passes add effects, so the producer dossier should continue to cross-link the cleanup sibling `discard-global-effects`.
- Starshine has enough local ingredients for an analyzer-first slice—stable call/global instruction shapes, HOT effect masks, revision-keyed function-local effect caches, and module-pass dispatch—but not the persistent module-level per-function summary store or per-global read/write lattice needed for full parity.

## Durable wiki changes made

- Added `docs/wiki/binaryen/passes/global-effects/starshine-port-readiness-and-validation.md`.
- Refreshed the `global-effects` overview, Binaryen strategy, Starshine strategy, and shape catalog so the new bridge is discoverable from every major entry point.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Suggested future implementation slices

1. Registry honesty: keep `global-effects` boundary-only until storage and validation scaffolding exist, or land an explicit no-rewrite analyzer under `ModulePass` with tests that prove summaries are observable only through diagnostics/test hooks.
2. Summary model: add per-function metadata with separate global-read and global-write sets plus conservative unknown-call/trap flags.
3. Scanner: collect direct call edges, direct globals, imports, indirect calls, `call_ref`, return-call variants, and unknown bodies.
4. Solver: implement SCC/component propagation or a documented `version_129` reachability equivalent.
5. Consumers: wire `vacuum` / movement passes only after stale-summary invalidation or discard behavior is designed.
6. Validation: compare standalone no-visible-WAT behavior and paired `--generate-global-effects --vacuum` / `--generate-global-effects --simplify-locals` pipelines against the chosen Binaryen oracle.

## Uncertainties

- The best local data structure for per-global effects is undecided. The current HOT `EffectMask` is too coarse for full Binaryen consumer precision but useful for a fast conservative first slice.
- It is still unclear whether Starshine should expose generated summaries through a persistent module side table, function annotations, or an analysis cache keyed by module revision. The living bridge keeps this as a design choice rather than implying a chosen ABI.
