# Binaryen `type-generalizing` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main freshness manifest for the `type-generalizing` pass

## Scope

This capture rechecks the official Binaryen sources that matter to the corrected `type-generalizing` contract.
It follows the 2026-04-27 primary-source correction and asks one question: does current `main` still match the source-correct teaching story?

The answer on the reviewed surfaces is yes.

## Official sources reviewed

- Binaryen `src/passes/TypeGeneralizing.cpp`
  - version_129: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeGeneralizing.cpp>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeGeneralizing.cpp>
  - Reviewed surfaces: nested DCE, CFG construction and failure handling, backward local/value-stack requirement analysis, `ContentOracle`-assisted call/global/table/ref/struct/array reasoning, `call_ref`, local declaration rewriting, `local.get` / `local.tee` result repair, unsupported-family guards, and conditional refinalization.
- Binaryen `src/passes/pass.cpp`
  - version_129: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Reviewed surfaces: hidden test-pass registration and the "not yet sound" description for `experimental-type-generalizing`.
- Binaryen `test/lit/passes/type-generalizing.wast`
  - version_129: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing.wast>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-generalizing.wast>
  - Reviewed surfaces: local generalization, params/results, `call_ref`, globals, tables, `ref.*`, struct, array, and unsupported-family shape coverage.

## Durable observations

- Current `main` still matches the corrected `version_129` contract on the reviewed surfaces.
- The pass remains a hidden, not-yet-sound test pass rather than a public optimizer.
- The real contract is CFG-backed backward type-requirement analysis, not a local-set/local-tee peephole.
- `call_ref`, `struct.*`, and `array.*` remain first-class teaching surfaces in the official lit file.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Uncertainty and caveats

- This is a narrow freshness check, not a proof that every neighboring helper file is unchanged.
- The local Starshine contract remains boundary-only, so the current-main recheck does not imply a local implementation exists.
