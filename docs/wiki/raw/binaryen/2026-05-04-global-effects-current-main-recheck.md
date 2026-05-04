---
kind: source-capture
status: supported
last_reviewed: 2026-05-04
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-global-effects.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-effects_simplify-locals.wast
related:
  - ../research/0438-2026-05-04-global-effects-current-main-recheck.md
  - ../../binaryen/passes/global-effects/index.md
---

# Binaryen `global-effects` / `generate-global-effects` current-main recheck

Captured: 2026-05-04

## Source set

- `src/passes/GlobalEffects.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - Reviewed surfaces: shallow per-function effect scan, direct-call collection, conservative unknown/opaque call handling, SCC-shaped propagation on current `main`, recursive-cycle conservatism, and `Function.effects` writeback.
- `src/passes/pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed surfaces: public registration for `generate-global-effects`, sibling registration for `discard-global-effects`, and the unchanged note that the producer pass is not scheduled in the default optimize pipeline.
- `src/ir/effects.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
  - Reviewed surfaces: direct-call effect queries can still consult a callee's stored summary.
- `src/wasm.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h>
  - Reviewed surfaces: `Function` still owns optional `effects` metadata.
- `test/lit/passes/vacuum-global-effects.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-global-effects.wast>
  - Reviewed surfaces: the downstream `vacuum` consumer proof remains part of the contract.
- `test/lit/passes/global-effects_simplify-locals.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-effects_simplify-locals.wast>
  - Reviewed surfaces: the downstream `simplify-locals` consumer proof remains part of the contract.

## Recheck result

- The upstream contract still matches the living wiki frame: metadata-producing module analysis, per-function `Function.effects` storage, conservative handling for imports/indirect/opaque calls, recursive-cycle conservatism, and explicit cleanup-sibling lifecycle.
- Current `main` still shows the implementation-shape refactor already captured in the 2026-04-24 / 2026-04-27 notes: explicit call-graph/SCC aggregation instead of the older deferred-queue wording.
- No teaching-relevant drift was found in the reviewed source surfaces beyond that already-noted implementation-shape difference.
- The stale `PassOptions` wording caveat still applies in the owner-file header, so the wiki should continue teaching `Function.effects` as the observed storage contract.
