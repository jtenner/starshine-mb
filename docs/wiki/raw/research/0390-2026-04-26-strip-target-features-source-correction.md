# 0390 - `strip-target-features` source correction

_Date:_ 2026-04-26  
_Status:_ filed into living wiki  
_Raw source:_ [`../binaryen/2026-04-26-strip-target-features-source-correction.md`](../binaryen/2026-04-26-strip-target-features-source-correction.md)

## Question

The existing `strip-target-features` wiki folder looked complete, but it taught the pass as a Binaryen output-option-only toggle with `modifiesBinaryenIR() == false`. Rechecking official Binaryen sources was needed before relying on it for future Starshine port planning.

## Findings

Official Binaryen `version_129` and current `main` source show a different contract:

- the pass owner is still `src/passes/StripTargetFeatures.cpp`;
- `modifiesBinaryenIR()` returns `true`;
- `run(...)` mutates `module->hasFeaturesSection = false`;
- public registration and constructor surfaces still expose `strip-target-features` as the pass that strips the target-features section from output.

So the output-level teaching remains right: the pass removes target-feature metadata, not feature-using instructions. The mechanism was wrong: it is module metadata mutation, not pass-runner option state.

## Wiki changes made

- Corrected the pass overview, Binaryen strategy page, implementation/test-map page, shape catalog, and Starshine strategy page.
- Added the raw source-correction manifest.
- Updated index/log/tracker wording so the stale `emitTargetFeatures = false` and `modifiesBinaryenIR() == false` claims no longer look canonical.

## Starshine impact

Starshine still has no registered `strip-target-features` pass. The future implementation choice is now clearer:

1. add first-class target-feature metadata and a module pass that clears it; or
2. implement a narrower opaque custom-section mutation that deletes only `CustomSec("target_features", ...)`; or
3. keep the pass unknown and documented as upstream-only.

The relevant local code surfaces are opaque custom-section representation and round-trip paths, especially `src/lib/types.mbt`, `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/validate/validate.mbt`, and the pass registry in `src/passes/optimize.mbt`.

## Uncertainty

This run did not chase the upstream introductory commit. The corrected contract is source-backed for the tag and current head surfaces that the wiki currently uses as its Binaryen baseline.
