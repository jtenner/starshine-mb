# Binaryen `signature-refining` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main freshness manifest for the `signature-refining` pass

## Scope

This capture rechecks the official Binaryen sources that matter to the `signature-refining` contract.
It follows the earlier `version_129` primary-source manifest and the 2026-04-26 port-readiness pass and asks one question: does current `main` still match the corrected teaching story?

The answer on the reviewed surfaces is yes.

## Official sources reviewed

- Binaryen `src/passes/SignatureRefining.cpp`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignatureRefining.cpp>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignatureRefining.cpp>
  - Reviewed surfaces: GC/table gates, per-function parallel analysis, heap-type aggregation, param LUB collection, result LUB collection, body repair, signature rewrite, `call.without.effects` repair, and refinalization.
- Binaryen `src/passes/pass.cpp`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Reviewed surfaces: registration and closed-world GC/type-cluster placement for `signature-pruning`, `signature-refining`, and `global-refining`.
- Binaryen `test/lit/passes/signature-refining.wast`
  - `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining.wast>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-refining.wast>
  - Reviewed surfaces: direct-call and `call_ref` positives, result refinement, public/import/tag/continuation blockers, and `call.without.effects` repair.

## Durable observations

- Current `main` still matches the corrected `version_129` contract on the reviewed surfaces.
- The pass remains GC-gated, table-free, heap-type-wide, and conservative around public/imported/tag/subtype families.
- The dedicated lit file still teaches the same core families: param LUBs, result LUBs, body repair, `call_ref`, and `call.without.effects`.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Uncertainty and caveats

- This is a narrow freshness check, not a proof that every neighboring helper file is unchanged.
- The local WAT parser gap for direct `call_ref` remains a Starshine-side concern; the upstream source still treats it as a real contract surface.
