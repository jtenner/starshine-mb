# Binaryen `type-ssa` current-main recheck

_Capture date:_ 2026-05-06  
_Status:_ immutable current-main freshness manifest for the `type-ssa` pass

## Scope

This capture rechecks the official Binaryen sources that matter to the corrected `type-ssa` contract.
It follows the 2026-04-26 source-correction manifest and asks one question: does current `main` still match the allocation-subtype teaching story?

The answer on the reviewed surfaces is yes.

## Official sources reviewed

- Binaryen `src/passes/TypeSSA.cpp`
  - version_129: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeSSA.cpp>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeSSA.cpp>
  - Reviewed surfaces: GC gate, allocation-candidate scanning, exact-observation blockers, `isInteresting(...)`, fresh rec-group creation, exact non-null retagging, naming reuse, and `ReFinalize`.
- Binaryen `src/passes/pass.cpp`
  - version_129: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Reviewed surfaces: public `type-ssa` registration and help text.
- Binaryen `test/lit/passes/type-ssa.wast`
  - version_129: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-ssa.wast>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-ssa.wast>
  - Reviewed surfaces: fresh type creation for `struct.new`, `array.new`, `array.new_data`, `array.new_elem`, `array.new_fixed`, exact-type-sensitive bailouts, and refinalized output shapes.

## Durable observations

- Current `main` still matches the corrected allocation-subtype contract on the reviewed surfaces.
- The pass remains a GC pass that specializes allocation result types, not a local/global SSA-like value-flow retagging pass.
- Allocation candidates are still drawn from struct and array creation sites.
- Exact-observation blockers and interestingness filtering still gate which allocations receive fresh private subtypes.
- `ReFinalize` remains part of the post-rewrite contract.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Uncertainty and caveats

- This is a narrow freshness check, not a proof that every neighboring helper file is unchanged.
- The local Starshine status remains upstream-only, so the current-main recheck does not imply a local implementation exists.
