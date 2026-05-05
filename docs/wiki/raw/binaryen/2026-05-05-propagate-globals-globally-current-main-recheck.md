# Binaryen `propagate-globals-globally` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/propagate-globals-globally/` dossier

## Scope

This file records the official current-main sources rechecked for the 2026-05-05 wiki-health refresh. It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md`.

## Primary sources rechecked

- Binaryen current-main `SimplifyGlobals.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SimplifyGlobals.cpp>
- Binaryen current-main `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Binaryen current-main `propagate-globals-globally.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/propagate-globals-globally.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/propagate-globals-globally.wast>

## Comparison anchors

- Binaryen `version_129` `SimplifyGlobals.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `propagate-globals-globally.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>

## Durable observations

- Current `main` still exposes `propagate-globals-globally` as a public Binaryen pass.
- The narrow `PropagateGlobalsGlobally` subclass still calls `propagateConstantsToGlobals()` only; the broader sibling still owns the function-body propagation path.
- The dedicated lit file still separates startup/global propagation from ordinary function-body `global.get` rewriting.
- No teaching-relevant drift was found on the reviewed surfaces.

## Drift note

This capture is a freshness update, not a contract change.
