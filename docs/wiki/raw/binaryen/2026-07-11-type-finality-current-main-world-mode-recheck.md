# Binaryen type-finality siblings: current-main world-mode recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness manifest for the sibling `type-finalizing` and `type-unfinalizing` dossiers

## Scope

This capture supersedes the **current-main freshness claim** in the 2026-04-27 port-readiness manifests for:

- `docs/wiki/binaryen/passes/type-finalizing/`
- `docs/wiki/binaryen/passes/type-un-finalizing/`

It does not replace their tagged `version_129` manifests or the older 2026-04-27 captures. Those remain useful historical provenance. This review reread the shared owner, public registration/default scheduler, dedicated lit oracle, and the relevant global type-rewrite helper interface to check the claim that these passes are GC-only private-type rewrites rather than closed-world-only type optimizers.

## Primary sources reread

### Upstream Binaryen `main`

- Shared owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeFinalizing.cpp>
- Registration and default scheduler: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Dedicated oracle: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-finalizing.wast>
- Global rewrite helper: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>

### Current Starshine status evidence

- Boundary-only names: `src/passes/optimize.mbt`, `pass_registry_boundary_only_names()`
- No local owner: no `src/passes/type_finalizing.mbt`, `src/passes/type_un_finalizing.mbt`, or shared `type_finality.mbt`
- Harness admission: `scripts/lib/pass-fuzz-compare-task.ts` has neither sibling spelling in `SUPPORTED_PASS_FLAGS`

## Current upstream result

The shared pass contract remains intact:

- `TypeFinalizing::run` returns immediately without the GC feature.
- Finalizing builds `SubTypes` and selects only private types with no immediate subtypes.
- Unfinalizing deliberately skips that leaf proof and can select every eligible private type.
- The shared rewriter still changes only the selected `TypeBuilder` entries with `setOpen(!finalize)`.
- Binaryen still registers the public names `type-finalizing` and `type-unfinalizing`; the latter remains different from Starshine's boundary-only `type-un-finalizing` alias.
- Neither sibling appears in the reviewed default global or function optimization rosters, so public registration is not evidence of default `-O` / `-Os` scheduling.
- The dedicated fixture remains the focused proof surface for public-type preservation, private state changes, non-leaf finalization rejection, and function heap-type participation.

## Material interface drift: world mode is now threaded through the helper boundary

The old living pages correctly said these passes are **not closed-world-only**: `TypeFinalizing.cpp` does not contain a `worldMode == Closed` gate, unlike the neighboring closed-world GC/type cluster in `pass.cpp`.

However, current `main` no longer calls the helper with no policy argument. It now passes `getPassOptions().worldMode` to both:

1. `ModuleUtils::getPrivateHeapTypes(*module, getPassOptions().worldMode)` when selecting candidates; and
2. `GlobalTypeRewriter(wasm, parent.getPassOptions().worldMode)` when rebuilding the type graph.

This is a material **helper-interface** change, not evidence that the pass itself became closed-world-only. The exact behavior of private-type selection and global rewriting can depend on the requested world mode, so future ports must carry an explicit visibility/rewrite policy through both phases rather than hard-code the older no-argument helper model.

## Starshine reconciliation

Starshine's implementation status has not changed:

- both local spellings remain `BoundaryOnly` in `src/passes/optimize.mbt`;
- neither is scheduled in Starshine presets;
- no local implementation owner or compare-pass admission exists.

The implementation consequence is sharpened rather than broadened: a shared future type-finality engine needs a defined Starshine visibility policy and must pass it consistently to candidate discovery and global type remapping. A port must not treat “not closed-world-only” as permission to mutate every apparently private type under every world configuration.

## Consumability rule

Use this capture for the current-main world-mode and freshness claims. Use the older tagged manifests for `version_129` provenance, and keep the 2026-04-27 notes as dated historical evidence rather than silently rewriting them.
