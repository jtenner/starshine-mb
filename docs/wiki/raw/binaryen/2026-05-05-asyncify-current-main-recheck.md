---
kind: raw-source
status: supported
last_reviewed: 2026-05-05
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast
  - https://emscripten.org/docs/porting/asyncify.html
related:
  - ../../binaryen/passes/asyncify/index.md
  - ../../binaryen/passes/asyncify/binaryen-strategy.md
  - ../../binaryen/passes/asyncify/implementation-structure-and-tests.md
  - ../../binaryen/passes/asyncify/starshine-strategy.md
  - ../../binaryen/passes/asyncify/starshine-port-readiness-and-validation.md
  - ../research/0445-2026-05-05-asyncify-current-main-recheck.md
---

# Binaryen `asyncify` current-main recheck

This raw-source note captures the 2026-05-05 current-main spot check for Binaryen's `asyncify` pass.
It preserves the source URLs and the small set of teaching-relevant claims refreshed in this run.

## Primary online sources reviewed

- Binaryen current-main `src/passes/Asyncify.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp>
- Binaryen current-main `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen current-main `test/lit/passes/asyncify.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast>
- Emscripten Asyncify user documentation: <https://emscripten.org/docs/porting/asyncify.html>

## Source-backed claims refreshed

- `Asyncify.cpp` still frames Asyncify as a whole-module pause/resume transform with normal, unwinding, and rewinding states.
- The reviewed current-main source still documents the runtime helper surface, including `asyncify_get_state`, and still distinguishes wasm32 versus wasm64 Asyncify pointer width.
- The current-main source surface still treats unwinding from inside a catch block as a special boundary with an explicit ignore option rather than as generic EH support.
- `pass.cpp` still registers the public pass spelling `asyncify` with the async/await-style description and the `createAsyncifyPass` constructor.
- The current-main source review did not surface any new teaching-relevant change to the pass contract or to the `asyncify.wast` proof surface.

## Current-main drift result

No teaching-relevant drift was found from the existing 2026-04-26 Asyncify dossier.
The useful change from this run is a freshness refresh, not a strategy correction.

## Uncertainties and caveats

- GitHub line numbers remain unstable across upstream commits, so the living wiki should continue to cite file paths and source concepts rather than freezing current-main line numbers as normative.
- Starshine still has no local `asyncify` registry entry, owner file, dispatcher case, preset role, or host integration harness.
- The reviewed source still does not show `return_call` support in the Asyncify path, so the tail-call boundary should remain explicit in the living dossier.
