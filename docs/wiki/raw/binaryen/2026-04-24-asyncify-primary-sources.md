# Binaryen `asyncify` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/asyncify/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `asyncify` dossier.
Use the living pages for explanation:

- `docs/wiki/binaryen/passes/asyncify/index.md`
- `docs/wiki/binaryen/passes/asyncify/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/asyncify/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/asyncify/wat-shapes.md`
- `docs/wiki/binaryen/passes/asyncify/starshine-strategy.md`

## Provenance

### Official release and docs pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.
- Emscripten Asyncify documentation
  - URL: <https://emscripten.org/docs/porting/asyncify.html>
  - Page observed on 2026-04-24.
  - Key reviewed surface: Asyncify is the Emscripten-supported mechanism that rewrites Wasm so synchronous-looking C/C++ can pause and resume around asynchronous host work; the page also documents the overhead / whole-program-analysis / indirect-call tuning story exposed through `ASYNCIFY_IMPORTS`, `ASYNCIFY_REMOVE`, `ASYNCIFY_ADD`, `ASYNCIFY_ONLY`, and `ASYNCIFY_IGNORE_INDIRECT`.

### Official Binaryen source files consulted

- `Asyncify.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Asyncify.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Asyncify.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp>
  - Key reviewed locations:
    - file header describing the Wasm-level structured-control "skip while rewinding, break while unwinding" design and the runtime state/data layout;
    - public runtime API comments for `asyncify_start_unwind`, `asyncify_stop_unwind`, `asyncify_start_rewind`, `asyncify_stop_rewind`, and `asyncify_get_state`;
    - `ModuleAnalyzer`, which marks imports, indirect calls, and callgraph predecessors that can change Asyncify state while honoring add/remove/only lists;
    - `AsyncifyFlow`, which flattens before inserting state checks around call sites and emits fake intrinsics for unwind / call-index handling;
    - `AsyncifyLocals`, which chooses locals live at relevant call sites and emits stack load/store repair;
    - top-level `Asyncify::run(...)`, which ensures or creates memory, chooses pointer width from the selected memory, adds globals, runs nested flatten/DCE/optimization plus flow/local passes, and finally adds runtime API functions;
    - `ModAsyncify`, the helper-pass family that simplifies known-impossible `__asyncify_state` checks after Asyncify.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Key reviewed locations: public `asyncify` registration and the adjacent helper registrations for `jspi` / JS-interface passes, confirming `asyncify` is a real public transformation pass rather than an Emscripten-only wrapper name.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: pass constructor declaration for `createAsyncifyPass()`.

### Official Binaryen tests consulted

- `asyncify.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/asyncify.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/asyncify.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast>
  - Key reviewed surface: direct before/after proof for representative `--asyncify` rewrites, including runtime exports, state globals, call-site checks, unwind/rewind stack traffic, and tuning-list behavior.
- `test/lit/passes/` directory listing and search surfaces for Asyncify-related fixtures
  - `version_129` directory URL: <https://github.com/WebAssembly/binaryen/tree/version_129/test/lit/passes>
  - Key reviewed surface: `asyncify.wast` is the central pass lit file for this dossier; helper passes and Emscripten-level integration are outside this page's local Starshine scope unless a future implementation chooses to support them.

## Durable observations from the captured sources

- `asyncify` is a real public Binaryen pass in `version_129`.
- The pass is a whole-module Wasm-level transformation for pause/resume semantics; it is not an ordinary local optimizer.
- The transformed module gains mutable state/data globals, exported runtime functions, and instrumentation around call sites that may unwind or rewind.
- Binaryen uses callgraph/import/indirect-call analysis plus user lists to avoid instrumenting functions that cannot affect Asyncify state.
- Tail calls are explicitly not supported by the reviewed source path.
- The pass ensures an Asyncify memory exists or creates a secondary memory when requested, then chooses `i32` or `i64` pointer width from that memory.
- Flow instrumentation is intentionally staged through nested passes: flattening and DCE happen before call-site instrumentation, optional default function optimization surrounds local save/restore insertion, and final runtime API functions are added after the prior passes have run.
- The helper API includes `asyncify_get_state` in the reviewed `version_129` source.
- The Emscripten docs frame Asyncify as a supported way to make synchronous-looking C/C++ interact with asynchronous JavaScript, while warning about code-size/runtime overhead and indirect-call analysis limits.
- No local Starshine registry entry for `asyncify` was found in this repo on 2026-04-24. Starshine still has reusable module/function/global/memory/call/validation/binary surfaces that would be prerequisites for a future port.

## Uncertainty and caveats

- This capture describes the core `asyncify` pass. It does not claim Starshine should also implement Binaryen's helper pass family (`mod-asyncify-*`) or Emscripten driver settings in the same first port.
- The reviewed source uses Binaryen's internal `FakeGlobalHelper`, `ModuleAnalyzer`, `InstrumentedPassRunner`, flattening, DCE, and local liveness machinery. Starshine has adjacent concepts, but no equivalent integrated Asyncify pipeline today.
- Asyncify's user-facing behavior depends on a JavaScript or host runtime following the exported API contract. A compiler-only port can create the Wasm shape, but integration tests would still need an external harness.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
