# Binaryen `simplify-globals` current-main recheck

Date: 2026-05-05

## Reviewed official current-main surfaces

- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/find_all.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-single_use.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-non-init.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-read_only_to_write.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-dominance.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-offsets.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-nested.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-prefer_earlier.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals_func-effects.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/simplify-globals-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/propagate-globals-globally.wast>

## Recheck summary

- Current `main` still uses the same shared `SimplifyGlobals.cpp` family structure as `version_129` on the reviewed plain-pass surfaces.
- The public split between `simplify-globals`, `simplify-globals-optimizing`, and `propagate-globals-globally` remains intact.
- The reviewed current-main surfaces did not show teaching-relevant drift from the existing plain-pass contract in this repo.
- This recheck is therefore a freshness bridge, not a contract correction.
