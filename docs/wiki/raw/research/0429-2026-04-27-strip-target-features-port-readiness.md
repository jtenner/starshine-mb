# 0429 - `strip-target-features` port readiness

_Date:_ 2026-04-27  
_Status:_ filed into living wiki  
_Raw source:_ [`../binaryen/2026-04-27-strip-target-features-port-readiness-primary-sources.md`](../binaryen/2026-04-27-strip-target-features-port-readiness-primary-sources.md)

## Question

The `strip-target-features` folder had a corrected source-backed dossier, but it still lacked the now-standard Starshine implementation-readiness / validation bridge. A current source recheck was also needed because the 2026-04-26 correction taught the right high-level contract but over-specified the mechanism as an explicit owner-file `modifiesBinaryenIR()` override.

## Findings

Official Binaryen `version_129` and current `main` agree on the important contract:

- `strip-target-features` and `emit-target-features` share `src/passes/StripTargetFeatures.cpp`;
- the class is parameterized by `isStripped`;
- stripping sets `module->hasFeaturesSection = false`;
- emitting sets `module->hasFeaturesSection = true`;
- the pass does not walk function bodies or rewrite executable wasm;
- the checked owner file inherits `Pass::modifiesBinaryenIR()`'s default-true behavior instead of defining its own explicit override;
- `requiresNonNullableLocalFixups()` returns false.

So the 2026-04-26 correction remains directionally right: this is module metadata mutation, not an output-option-only pass and not `modifiesBinaryenIR() == false`. The refreshed teaching text should say “reports IR/module-state mutation through the base default” rather than “the owner file returns true.”

## Starshine impact

Starshine still has no local `strip-target-features` or `emit-target-features` pass registry entry. The exact current state is:

- absent from boundary-only names;
- absent from removed names;
- absent from active module/hot pass entries and presets;
- explicit requests fail as unknown pass flags;
- opaque `Module.custom_secs` can preserve custom sections, but there is no first-class Binaryen-style `hasFeaturesSection` bit.

A future implementation therefore has two honest first slices:

1. add only explicit registry status, keeping the pass boundary-only/unknown-by-design; or
2. implement a narrow module pass that deletes only opaque `CustomSec("target_features", ...)` entries, while documenting that this is Starshine's representation-level strategy rather than Binaryen's internal flag strategy.

A more faithful long-term port would add target-feature metadata as first-class module state and make encode/decode semantics explicit.

## Wiki changes made

- Added the 2026-04-27 raw primary-source manifest.
- Added `starshine-port-readiness-and-validation.md` for the pass.
- Refreshed overview, Binaryen strategy, implementation/test-map, WAT-shape, and Starshine strategy pages with the shared owner, inherited `modifiesBinaryenIR()` default, `emit-target-features` sibling, first-slice choices, validation ladder, and exact Starshine code surfaces.
- Updated the pass index, tracker, top-level wiki index, and wiki log.

## Uncertainty

This run did not audit the binary payload format of the target-features section and did not chase the historical introduction commit. Those are not needed for the current readiness bridge because the Binaryen pass toggles section presence as a whole and does not inspect per-feature entries.
