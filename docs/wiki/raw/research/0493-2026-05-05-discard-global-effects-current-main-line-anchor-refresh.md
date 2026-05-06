# 0493 — 2026-05-05 — discard-global-effects current-main line-anchor refresh

## Question

Do the existing `discard-global-effects` dossier pages still point at the right upstream Binaryen source anchors, and can we make the cleanup sibling's lifecycle contract more explicit without changing the teaching model?

## Findings

- `GlobalEffects.cpp` still shows the same cleanup loop: the pass resets each function's stored effect summary and does not rewrite bodies.
- `pass.cpp` still publicly registers `discard-global-effects` and keeps the lifecycle placement note explicit near the function-pass scheduler.
- The current-main contract stays metadata-only; the printed Wasm body is expected to remain unchanged.
- The upstream producer `generate-global-effects` still owns the SCC-shaped propagation story, but that is separate from the cleanup sibling.

## Files reviewed

- `docs/wiki/raw/binaryen/2026-05-05-discard-global-effects-current-main-line-anchor-refresh.md`
- `docs/wiki/binaryen/passes/discard-global-effects/index.md`
- `docs/wiki/binaryen/passes/discard-global-effects/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/discard-global-effects/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/discard-global-effects/starshine-strategy.md`
- `docs/wiki/binaryen/passes/discard-global-effects/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/global-effects/index.md`
- `docs/wiki/binaryen/passes/global-effects/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/implementation-structure-and-tests.md`
- `src/passes/GlobalEffects.cpp`
- `src/passes/pass.cpp`

## Outcome

This was a reference-hygiene refresh only.

No behavior or contract change was recorded.
