# 0438 — 2026-05-04 — global-effects current-main recheck

## Question

Did Binaryen current `main` drift in a teaching-relevant way from the existing `global-effects` / `generate-global-effects` wiki model?

## Sources

- `docs/wiki/raw/binaryen/2026-05-04-global-effects-current-main-recheck.md`
- official Binaryen `main` sources for `GlobalEffects.cpp`, `pass.cpp`, `effects.h`, `wasm.h`, `vacuum-global-effects.wast`, and `global-effects_simplify-locals.wast`

## Findings

- Current `main` still treats the pass as metadata-producing module analysis, not a WAT rewrite pass.
- The current implementation shape is SCC/call-graph based on `main`, but the durable contract is unchanged: shallow per-function scan, conservative opaque-call handling, recursive-cycle conservatism, and `Function.effects` writeback.
- The public name / lifecycle split still matters: `generate-global-effects` produces summaries and `discard-global-effects` clears them.
- The downstream consumer story still comes from the paired `vacuum` and `simplify-locals` lit tests.

## Wiki impact

- Refresh the living `global-effects` pages with the new current-main recheck date.
- Keep the stale `PassOptions` header wording caveat explicit.
- Keep `Function.effects` as the teaching contract for storage.
