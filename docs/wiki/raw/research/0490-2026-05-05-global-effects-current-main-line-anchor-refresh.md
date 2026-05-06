# 0490 — 2026-05-05 — global-effects current-main line-anchor refresh

## Question

Does the existing `global-effects` dossier still point at the right upstream Binaryen and local Starshine code surfaces, and can we add more exact code anchors without changing the teaching contract?

## Findings

- Official Binaryen `main` still shows the same durable contract for `GlobalEffects.cpp`, `pass.cpp`, and `effects.h`.
- The upstream pass remains metadata-producing and still sits outside the default optimize sequence.
- The current `main` implementation shape is still shallow-scan + propagation + writeback; the current-page story did not drift in a teaching-relevant way.
- The local Starshine status still depends on the same registry-only boundary, CLI acceptance, hot-pipeline rejection, and shared function-local effects cache.
- The exact local code-map anchors now read cleanly enough to expose in the living dossier.

## Files reviewed

- `docs/wiki/raw/binaryen/2026-05-05-global-effects-current-main-line-anchor-refresh.md`
- `docs/wiki/binaryen/passes/global-effects/index.md`
- `docs/wiki/binaryen/passes/global-effects/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/global-effects/starshine-strategy.md`
- `src/passes/optimize.mbt`
- `src/cmd/cli_test.mbt`
- `src/cmd/cmd.mbt`
- `src/passes/pass_common.mbt`
- `src/ir/analysis_cache.mbt`
- `src/passes/simplify_locals.mbt`
- `src/passes/heap_store_optimization.mbt`

## Outcome

This was a reference-hygiene refresh only.

No behavior or contract change was recorded.
