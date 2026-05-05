# 2026-05-05 `rereloop` current-main recheck

Primary-source freshness check for Binaryen `rereloop` / local `re-reloop`.

## Scope

Reviewed the official Binaryen current-main sources and compared them against the existing `version_129` oracle surface for the pass:

- `src/passes/ReReloop.cpp`
- `src/passes/pass.cpp`
- `src/cfg/Relooper.h`
- `src/cfg/Relooper.cpp`
- `src/ir/flat.h`
- `test/lit/passes/flatten_rereloop.wast`
- `test/lit/passes/opt_flatten.wast`

## Findings

No teaching-relevant drift was found on the reviewed surfaces.

The current-main source still matches the durable `version_129` contract already captured in the wiki:

- flatness is a hard precondition
- the pass builds a temporary CFG from flat control forms
- `Try` / `Throw` / `Rethrow` remain a hard EH boundary
- rendering still delegates to the shared `Relooper` engine
- the renderer still uses a fresh `i32` helper label local
- dead-end CFG blocks still receive explicit terminators before render
- the pass still repairs apparent result fallthroughs with `unreachable`
- `ReFinalize` still closes the mutation loop
- the `pass.cpp` `-O4` TODO still leaves `rereloop` outside the reviewed default optimize path

## Current-main anchor set

- `ReReloop.cpp#L1439-L1442` - hard EH boundary
- `ReReloop.cpp#L1462-L1477` - flatness precondition and CFG/task setup
- `ReReloop.cpp#L1559-L1577` - helper label local, render, and `ReFinalize`
- `pass.cpp#L3066-L3070` - public registration
- `pass.cpp#L3422-L3437` - flatten-era `-O4` TODO after `flatten -> simplify-locals-notee-nostructure -> local-cse`
- `Relooper.h#L1197-L1255` - shape taxonomy
- `Relooper.h#L1338-L1397` - builder helper and helper-label-local semantics

## Source URLs

- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReReloop.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/cfg/Relooper.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/cfg/Relooper.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/flat.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/flatten_rereloop.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/opt_flatten.wast>

## Notes

- This recheck is freshness-only; it does not supersede the older primary-source manifest.
- The local Starshine spelling `re-reloop` still maps to upstream `rereloop`.
