# 0502 — 2026-05-06 — global-effects current-main recheck

## Question

Did Binaryen `global-effects` drift on current `main` relative to the existing `version_129` contract?

## Answer

No teaching-relevant drift was found on the reviewed surfaces. The pass still reads as a metadata-producing interprocedural effect summary pass, not a WAT-rewriting optimizer.

## Reviewed sources

- `docs/wiki/raw/binaryen/2026-05-06-global-effects-current-main-recheck.md`
- official Binaryen `main` / `version_129` source pages for:
  - `src/passes/GlobalEffects.cpp`
  - `src/passes/pass.cpp`
  - `src/ir/effects.h`
  - `src/wasm.h`
  - `test/lit/passes/vacuum-global-effects.wast`
  - `test/lit/passes/global-effects_simplify-locals.wast`

## Durable takeaway

Keep the 2026-05-05 dossier contract. The 2026-05-06 recheck only refreshed source provenance; it did not change the pass model.
