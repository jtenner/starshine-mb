# Binaryen `asyncify` current-main and EH/options source bridge

_Capture date:_ 2026-04-25  
_Status:_ immutable source bridge for the `docs/wiki/binaryen/passes/asyncify/` dossier

## Scope

This file supplements the 2026-04-24 `asyncify` primary-source manifest. It does not replace the tagged `version_129` oracle; it records a focused re-read of current upstream and the official runtime-facing docs to correct and deepen the living dossier.

Living pages updated from this bridge:

- `docs/wiki/binaryen/passes/asyncify/index.md`
- `docs/wiki/binaryen/passes/asyncify/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/asyncify/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/asyncify/wat-shapes.md`
- `docs/wiki/binaryen/passes/asyncify/state-machine-memory-and-eh-boundaries.md`
- `docs/wiki/binaryen/passes/asyncify/starshine-strategy.md`

## Primary online sources consulted

### Official Binaryen source

- `src/passes/Asyncify.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Asyncify.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Asyncify.cpp>
  - focused locations reviewed:
    - file header / top-level options and design comments for helper globals, memory selection, import/export-global modes, indirect-call handling, and exception/catch behavior;
    - state-machine helpers for unwind, rewind, sleep-state, and `asyncify_get_state`;
    - call instrumentation paths for direct calls, indirect calls, and tail-call rejection;
    - local save/restore and liveness-related logic inside the owner file;
    - `ModAsyncify` helper passes that simplify known Asyncify-state branches after the main transform.
- `src/passes/pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - focused location reviewed: public registration for `asyncify` plus the neighboring helper/host-integration pass context.
- `src/passes/passes.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - focused location reviewed: `createAsyncifyPass()` constructor declaration.

### Official Binaryen tests

- `test/lit/passes/asyncify.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/asyncify.wast>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/asyncify.wast>
  - focused locations reviewed: direct-call, indirect-call, runtime-helper, import/export-global, memory, and exception/catch-related output sections.

### Official Emscripten docs

- Emscripten Asyncify documentation
  - URL: <https://emscripten.org/docs/porting/asyncify.html>
  - focused locations reviewed: user-visible motivation, overhead warnings, `ASYNCIFY_IMPORTS`, `ASYNCIFY_REMOVE`, `ASYNCIFY_ADD`, `ASYNCIFY_ONLY`, and `ASYNCIFY_IGNORE_INDIRECT` tuning surface.

## Durable observations

- The 2026-04-25 current-main check found no teaching-level drift from the tagged `version_129` contract: `asyncify` remains a public whole-module pause/resume transformation owned by `Asyncify.cpp`, not a local optimizer.
- The previous living dossier correctly described runtime helpers, memory-backed data, callgraph reachability, direct and indirect call instrumentation, memory32-vs-memory64 pointer traffic, and tail-call rejection.
- The dossier needed deeper coverage of exception/catch behavior. Binaryen has an explicit option boundary around unwinding from `catch`-like paths. Future Starshine docs and tests should treat this as part of the pass contract, not as an unrelated EH cleanup concern.
- The dossier also over-factored the source owner split by naming `AsyncifyLocals` as if it were a standalone class. The reviewed source should be taught as one `Asyncify.cpp` mini-pipeline whose local liveness/save/restore logic is part of the owner file and flow instrumentation machinery; do not send readers searching for a separate `AsyncifyLocals` owner.
- The `ModAsyncify` helpers remain related but separate from the main user-facing `asyncify` pass. They are useful for understanding follow-up simplification, but they should not be conflated with the first Starshine port target.
- Starshine still has no `asyncify` registry entry, no owner file, no dispatcher case, no preset slot, and no active backlog slice. The correct local status remains unknown-pass, not boundary-only or removed.

## Uncertainty and caveats

- This bridge is a focused source/shape correction, not a full implementation audit. A future port must re-read the exact current option names and generated helper bodies immediately before coding.
- The exact generated WAT is verbose and option-sensitive. Living pages should teach stable shapes and cite official `asyncify.wast` for byte-for-byte output.
- Host/runtime correctness still requires an execution harness. Normalized WAT compare can prove helper/module shape, but it cannot alone prove a real unwind/rewind round trip.

## Consumability rule

Use this source bridge for the 2026-04-25 correction that `asyncify` has EH/catch option boundaries and no separate `AsyncifyLocals` owner. Use the 2026-04-24 primary-source manifest for the broader tagged `version_129` source map.
