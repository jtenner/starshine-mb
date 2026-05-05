# Binaryen `minify-imports` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main freshness manifest for the plain `minify-imports` pass

## Scope

This capture rechecks the official Binaryen sources that matter to the plain `minify-imports` contract.
It follows the earlier source-correction and port-readiness notes and asks only one question: does current `main` still match the corrected `version_129` teaching story?

The answer on the reviewed surfaces is yes.

## Official sources reviewed

- Binaryen `src/passes/MinifyImportsAndExports.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MinifyImportsAndExports.cpp>
  - Reviewed surfaces: shared owner for the three public names; plain-mode `env` / `wasi_` import-base gate; import walk over all import kinds; import-base mutation; `module->updateMaps()` after declaration rewrites; JSON row-array output.
- Binaryen `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed surfaces: public registration and help text for `minify-imports`, `minify-imports-and-exports`, and `minify-imports-and-exports-and-modules`.
- Binaryen `src/passes/passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Reviewed surfaces: separate factories for the three public names, all routed to the same owner.
- Binaryen official test surface
  - `test/passes/minify-imports-and-exports-and-modules.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.wast>
  - `test/passes/minify-imports-and-exports-and-modules.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.txt>
  - Rechecked caveat: the reviewed tree still does not expose a dedicated plain `minify-imports.wast` / `.txt` pair.

## Starshine sources checked

- `src/passes/optimize.mbt:127-144` - boundary-only and removed-name registry tables remain the decision surface for current local pass availability.
- `src/passes/optimize.mbt:513-513` - absent names still fail as `unknown pass flag ...`.
- `src/passes/pass_manager.mbt:8939-8941` - the active module-pass dispatcher still has no minification arm.
- `src/lib/types.mbt:218` - `Import(Name, Name, ExternType)` stores the ABI-facing module/base pair.
- `src/lib/types.mbt:430` - `ImportSec(Array[Import])` is the declaration section a future plain pass must rewrite.
- `src/binary/decode.mbt:1899-1906` - binary import decoding reads module name, base name, and external type.
- `src/binary/encode.mbt:1156-1165` - binary import encoding writes module name, base name, and external type.
- `src/wast/lower_to_lib.mbt:2924-3004` - WAT imports lower into local import records across all import kinds.

## Durable observations

- Current Binaryen `main` still matches the corrected teaching contract for plain `minify-imports`.
- The pass is a module-declaration rewrite with JSON reporting, not a HOT-region instruction rewrite.
- The plain mutating slice is still narrow: rewrite qualifying import base names, leave export names alone, leave import module names alone, and compare JSON output separately from WAT/binary output.
- The plain pass remains distinct from `minify-imports-and-exports` and `minify-imports-and-exports-and-modules`.

## Uncertainty and caveats

- Exact generated names, used-name avoidance, and JSON row ordering still need to be checked against the target Binaryen revision when a local port exists.
- Because the reviewed official tree still lacks a dedicated plain-pass lit fixture, plain-mode oracle checks should stay executable-comparison driven.
- The 2026-05-05 recheck did not surface teaching-relevant drift; it only refreshed provenance and exact local code anchors.
