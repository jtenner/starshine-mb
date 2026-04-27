# Binaryen `minify-imports` port-readiness primary sources

_Capture date:_ 2026-04-27  
_Status:_ immutable port-readiness manifest for the plain `minify-imports` pass

## Scope

This capture rechecks the official Binaryen sources that matter to a future Starshine `minify-imports` port. It builds on the 2026-04-26 source correction, which already retired the stale non-mutating / function-only reading of the plain pass.

The 2026-04-27 recheck found no teaching-relevant drift from that corrected contract. The added value here is implementation sequencing: the first Starshine slice should not be a HOT rewrite; it should be a registry/reporting decision plus a module-section import-base rewrite.

## Official sources consulted

- Binaryen `src/passes/MinifyImportsAndExports.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinifyImportsAndExports.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MinifyImportsAndExports.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MinifyImportsAndExports.cpp>
  - Reviewed locations: shared constructor flags for the three public names; import walk over all import kinds; plain-mode `env` / `wasi_` gate; import-base mutation; `module->updateMaps()` after declaration rewrites; JSON row-array map output.
- Binaryen `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed locations: public pass registration and help text for `minify-imports`, `minify-imports-and-exports`, and `minify-imports-and-exports-and-modules`.
- Binaryen `src/passes/passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Reviewed locations: separate factory declarations for the three public names, all routed to the shared owner.
- Binaryen `src/support/name.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/name.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/support/name.h>
  - Reviewed locations: `Names::MinifiedNameGenerator`, which a faithful port must match instead of hard-coding illustrative `a`, `b`, `c` examples.
- Binaryen official pass-test surface
  - `test/passes/minify-imports-and-exports-and-modules.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.wast>
  - `test/passes/minify-imports-and-exports-and-modules.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.txt>
  - Rechecked caveat: no dedicated plain `minify-imports.wast` / `.txt` pair was found in the reviewed pass-test surface.

## Starshine sources checked

- `src/passes/optimize.mbt:1-36` - registry category model includes active, boundary-only, removed, and preset categories.
- `src/passes/optimize.mbt:479-491` - an absent pass name fails as `unknown pass flag ...`; boundary-only names reject with a different explicit message.
- `src/passes/pass_manager.mbt:8661-8685` - active module-pass dispatcher has no minification arm.
- `src/lib/types.mbt:218` - `Import(Name, Name, ExternType)` stores the ABI-facing import module and base strings.
- `src/lib/types.mbt:227` - `Export(Name, ExternIdx)` is the sibling export-minification surface, intentionally not part of the plain pass.
- `src/lib/types.mbt:430` - `ImportSec(Array[Import])` is the section a future plain pass must rewrite.
- `src/binary/decode.mbt:1899-1906` - binary import decoding reads module name, base name, and external type.
- `src/binary/encode.mbt:1151-1165` - binary import encoding writes module name, base name, and external type.
- `src/wast/lower_to_lib.mbt:2924-3004` - WAT imports lower into local import records across import kinds.

## Durable observations

- Current Binaryen `main` still matches the corrected `version_129` teaching contract for plain `minify-imports`.
- Plain `minify-imports` is a module-declaration rewrite, not a HOT-region instruction rewrite.
- The first local implementation choice is a CLI/API/reporting decision: Starshine must decide whether JSON map output is unsupported, captured separately, or integrated into a pass result object before claiming parity.
- A safe first mutating slice is narrower than the full family: rewrite only qualifying import base names, leave export names alone, leave import module names alone, and compare JSON output against Binaryen separately from WAT/binary output.
- `minify-imports` should remain separate from `minify-imports-and-exports`; the sibling may be implemented first in a future campaign, but the plain pass has a narrower public contract that needs its own negatives.

## Uncertainty and caveats

- Exact generated names, used-name avoidance, and JSON row ordering must be checked against the target Binaryen revision. The wiki's `a`, `b`, `c` examples are only explanatory.
- Because official Binaryen still lacks a dedicated plain-pass lit fixture in the reviewed tree, a Starshine port should use direct Binaryen executable comparisons for the plain-mode oracle.
- This manifest does not claim that Starshine should add the pass to default presets. The pass is ABI-visible and should require explicit opt-in unless a release decision says otherwise.
