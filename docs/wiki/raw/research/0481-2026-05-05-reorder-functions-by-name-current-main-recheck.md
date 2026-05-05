# 0481-2026-05-05-reorder-functions-by-name-current-main-recheck

## Question

Did Binaryen `reorder-functions-by-name` drift on current `main`, and did the exact Starshine code anchors in the living dossier need a refresh?

## Answer

No teaching-relevant current-`main` drift was found. The reviewed upstream contract is still the same tiny declaration-order pass:

- sort `module->functions` by ascending internal name;
- keep the pass public and debugging-oriented;
- preserve the declaration-only boundary;
- keep the four lit-backed `$a/$b/$c` permutation families.

The local Starshine code map did not need a behavior change; the existing anchor set still points at the correct registry, dispatcher-gap, lowering, and remap surfaces.

## Files involved

- `docs/wiki/raw/binaryen/2026-05-05-reorder-functions-by-name-current-main-recheck.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/index.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/lexical-order-proof-and-boundaries.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/module-shapes.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/starshine-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/starshine-port-readiness-and-validation.md`

## Follow-up

The living dossier was refreshed to point at the new 2026-05-05 raw capture and to add a dedicated Starshine implementation-readiness bridge.
