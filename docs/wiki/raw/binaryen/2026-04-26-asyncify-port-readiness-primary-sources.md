---
kind: raw-source
status: supported
last_reviewed: 2026-04-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast
  - https://emscripten.org/docs/porting/asyncify.html
related:
  - ../../binaryen/passes/asyncify/index.md
  - ../../binaryen/passes/asyncify/starshine-port-readiness-and-validation.md
  - ../research/0401-2026-04-26-asyncify-port-readiness.md
---

# Binaryen `asyncify` port-readiness primary-source capture

This raw-source note captures the 2026-04-26 primary-source recheck used to add a Starshine implementation-readiness bridge for the upstream-only `asyncify` pass.
It is intentionally concise: the living pages carry the teaching prose, while this file preserves the exact sources and source-backed claims reviewed in this run.

## Primary online sources reviewed

- Binaryen current-main `src/passes/Asyncify.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp>
- Binaryen current-main `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen current-main `test/lit/passes/asyncify.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast>
- Emscripten Asyncify user documentation: <https://emscripten.org/docs/porting/asyncify.html>

## Source-backed claims refreshed

- `Asyncify.cpp` still frames the pass as a wasm-level pause/resume transform with three runtime states: normal, unwinding, and rewinding.
- The source comments still describe the wasm32/wasm64 data-layout split for the Asyncify stack, including the `i32` versus `i64` current-position/end-pointer fields.
- The same file still names the exported runtime API surface: `asyncify_start_unwind`, `asyncify_stop_unwind`, `asyncify_start_rewind`, `asyncify_stop_rewind`, and `asyncify_get_state`.
- The source still documents the conservative default around imports and indirect calls and the user option surface for import lists, ignored imports, ignored indirect calls, add/remove/only lists, catch-unwind behavior, verbose output, and Asyncify memory choice.
- `pass.cpp` current main still registers public pass spelling `asyncify` with the description "async/await style transform, allowing pausing and resuming" and constructor `createAsyncifyPass`.
- `asyncify.wast` current main still exercises the public `--asyncify` pass and checks for state/data globals, runtime helper exports, liveness/local save-restore code, call instrumentation, and option-sensitive output families.
- Emscripten's public docs still present Asyncify as a toolchain/runtime feature for making synchronous-looking code cooperate with asynchronous work, not as a generic wasm optimizer.

## Current-main drift result

No teaching-relevant drift was found from the existing 2026-04-25 Asyncify dossier.
The new durable value from this run is not a strategy correction; it is a future-port bridge that ties Binaryen's source-backed contract to exact Starshine code surfaces, first-slice sequencing, validation order, and the dynamic host-harness requirement.

## Uncertainties and caveats

- The GitHub web view line numbers are unstable across upstream commits. Living pages cite file paths and source concepts rather than freezing current-main line numbers as normative.
- Starshine still has no local `asyncify` registry entry, option model, owner file, dispatcher case, preset role, or host integration harness. Any future implementation must start by deciding whether the pass should become boundary-only, removed, or active.
- The Binaryen helper-pass family named `mod-asyncify-*` remains out of scope for the first local implementation slice unless an oracle comparison proves those helpers must be scheduled together.
- EH/catch behavior is source-backed but complex; a Starshine first slice can deliberately reject EH input, but it must not silently half-instrument EH shapes.
