# 0480-2026-05-05-global-effects-current-main-recheck

## Question

Did Binaryen `global-effects` drift on current `main`, and did the exact Starshine code anchors in the living dossier need a refresh?

## Answer

No teaching-relevant current-`main` drift was found. The reviewed upstream contract is still the same metadata-producing interprocedural summary pass:

- compute shallow per-function effects;
- propagate through direct and transitive call edges;
- keep imports, indirect calls, and recursive/opaque cases conservative;
- store the result as `Function.effects` metadata;
- let later passes consume that metadata through `EffectAnalyzer`.

The local Starshine code map did not need a behavior change; the existing anchor set still points at the correct registry, CLI, dispatcher, and effect-cache surfaces.

## Files involved

- `docs/wiki/raw/binaryen/2026-05-05-global-effects-current-main-recheck.md`
- `docs/wiki/binaryen/passes/global-effects/index.md`
- `docs/wiki/binaryen/passes/global-effects/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/global-effects/metadata-naming-and-consumers.md`
- `docs/wiki/binaryen/passes/global-effects/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-effects/starshine-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/starshine-port-readiness-and-validation.md`

## Follow-up

The living dossier was refreshed to point at the new 2026-05-05 raw capture and to keep the current-main freshness layer explicit.
