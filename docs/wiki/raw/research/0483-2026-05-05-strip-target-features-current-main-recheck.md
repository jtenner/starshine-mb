# 0483 - `strip-target-features` current-main recheck

_Date:_ 2026-05-05  
_Status:_ filed into living wiki  
_Raw source:_ [`../binaryen/2026-05-05-strip-target-features-current-main-recheck.md`](../binaryen/2026-05-05-strip-target-features-current-main-recheck.md)

## Question

Does current `main` still match the corrected `strip-target-features` contract, and do the living wiki pages still explain the pass cleanly for both Binaryen readers and future Starshine work?

## Findings

The recheck found no contract drift on the reviewed Binaryen surfaces:

- `StripTargetFeatures.cpp` still shared one owner for `strip-target-features` and `emit-target-features`;
- stripping still cleared `module->hasFeaturesSection`;
- emitting still set it;
- `requiresNonNullableLocalFixups()` still returned false;
- the pass still relied on Binaryen's inherited mutation reporting rather than a local owner override;
- function bodies and executable wasm remained untouched.

That means the existing dossier remains valid. The useful change here is freshness: the wiki can now point at a 2026-05-05 current-main recheck instead of stopping at the 2026-04-27 bridge.

## Wiki changes made

- Added `docs/wiki/raw/binaryen/2026-05-05-strip-target-features-current-main-recheck.md`.
- Refreshed the living `strip-target-features` overview, Binaryen strategy, implementation/test-map, WAT-shape catalog, Starshine strategy, and Starshine readiness page to include the new freshness layer.
- Updated the relevant wiki catalogs and log so the new recheck is discoverable.

## Uncertainty

The recheck still did not chase the historical introduction commit or audit the target-feature payload format. That is acceptable because the pass only toggles whole-section metadata; it does not parse the section contents.
