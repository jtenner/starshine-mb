# Binaryen `strip-target-features` current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness manifest for `docs/wiki/binaryen/passes/strip-target-features/`

## Scope

This capture supersedes the **freshness claim** in the 2026-05-05 current-main recheck. It does not replace older immutable captures: the 2026-04-25 capture remains tagged-release provenance, and the 2026-04-26 / 2026-04-27 captures retain the correction and local-port-planning history.

The review was deliberately narrow. It reread the current Binaryen owner, public registration, and default scheduler surface, then reconciled the living Starshine status with the active local pass registry and compare-pass allowlist.

## Primary sources reread

### Upstream Binaryen `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp>
- Raw owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/StripTargetFeatures.cpp>
- Public registration and default scheduler: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Constructor declarations: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>

### Current Starshine evidence

- Registry: `src/passes/optimize.mbt`
- Compare-pass allowlist: `scripts/lib/pass-fuzz-compare-task.ts`
- Opaque custom-section model: `src/lib/types.mbt`, `src/binary/decode.mbt`, and `src/binary/encode.mbt`

## Current upstream result

No behavior-bearing drift was found on the reviewed upstream surface:

- `strip-target-features` and `emit-target-features` still share `StripTargetFeatures.cpp`.
- The owner still does not walk functions or expressions, still opts out of non-nullable-local fixups, and still assigns `module->hasFeaturesSection = !isStripped`.
- `createStripTargetFeaturesPass()` still constructs stripping mode; `createEmitTargetFeaturesPass()` still constructs emitting mode.
- `pass.cpp` still registers both public names with target-feature-section descriptions.
- Neither public name appears in Binaryen's inspected default optimization scheduler, so this remains an explicit output-metadata pass rather than a normal `-O` / `-Os` slot.

This is a source review, not an exhaustive audit of all Binaryen history, output-writer internals, or target-feature payload parsing.

## Current Starshine result

The local status remains upstream-only:

- neither sibling is active, boundary-only, or removed in `src/passes/optimize.mbt`;
- neither sibling appears in `SUPPORTED_PASS_FLAGS` in `scripts/lib/pass-fuzz-compare-task.ts`;
- therefore a `compare-pass --pass strip-target-features` command is currently rejected before it can produce Binaryen-vs-Starshine oracle evidence;
- the existing opaque `CustomSec` representation remains only a possible future landing zone, not proof of pass support.

## Consumability rule

Use this capture for the current-main owner/registration/default-scheduler and local-harness-status claims. Use the 2026-07-10 target-features custom-metadata recheck for the linking-convention payload boundary, and retain older captures as dated provenance rather than silently rewriting their history.
