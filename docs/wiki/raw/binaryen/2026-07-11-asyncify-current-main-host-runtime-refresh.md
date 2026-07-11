# Binaryen `asyncify` current-main and host-runtime refresh

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness and host-contract manifest for `docs/wiki/binaryen/passes/asyncify/`

## Scope

This capture renews the living dossier's current-source and host-runtime evidence. It supersedes the **freshness** claim in the 2026-05-05 bridge, but does not replace that bridge or the earlier tagged/current-main captures: those remain historical provenance for detailed source navigation.

The review deliberately separates three layers that are often conflated:

1. Binaryen's `asyncify` pass rewrites a Core Wasm module into an unwind/rewind state machine.
2. Emscripten driver settings decide which call paths receive that treatment and provide the host-facing integration story.
3. A Starshine pass-fuzz lane would require an active local transform and harness admission; neither exists today.

This is a targeted source/contract reread, not a line-by-line audit of all `Asyncify.cpp` helpers or a claim that Starshine implements any Asyncify behavior.

## Primary sources reread

### Upstream Binaryen `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp>
- Public registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Constructor declaration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Focused transform oracle: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast>

### Emscripten host documentation

- Asyncify guide: <https://emscripten.org/docs/porting/asyncify.html>

### Current Starshine evidence

- Pass registry/request handling: `src/passes/optimize.mbt`
- Compare-harness allowlist and early parser rejection: `scripts/lib/pass-fuzz-compare-task.ts`
- Pass-fuzz eligibility policy: `docs/wiki/tooling/pass-fuzz-compare.md`

## Durable findings

- The current Binaryen source surface still exposes `asyncify` through `Asyncify.cpp`, normal pass registration, a normal pass-constructor declaration, and the dedicated `asyncify.wast` lit fixture. The existing dossier's pass identity, module-scale scope, and source/test routing remain current on this reviewed surface.
- The Emscripten guide remains essential evidence rather than background reading: it distinguishes the compiler transformation from host/runtime cooperation, documents configurable async-root selection (including imports and add/remove/only-style controls), and explains why a transformed module needs an actual host-driven unwind/rewind exercise in addition to static output inspection.
- The guide's discussion of indirect-call handling and Asyncify stack sizing reinforces two existing implementation boundaries: indirect-call policy is a semantic configuration decision, and save-area storage is a runtime-resource contract rather than a formatting detail.
- The docs do **not** make Asyncify equivalent to JS Promise Integration. Asyncify is a generated Wasm-side unwind/rewind protocol; JSPI has a separate embedding/API contract. Keep proposal/host-wrapper claims on `wasm-jspi-host-async-boundary.md`.
- Current Starshine has no `asyncify` spelling in the active, boundary-only, or removed registry lists. It has no owner or dispatcher implementation.
- `asyncify` is also absent from `SUPPORTED_PASS_FLAGS` in `scripts/lib/pass-fuzz-compare-task.ts`. `bun fuzz compare-pass --pass asyncify ...` is rejected during harness argument parsing, before input generation or either optimizer executes. That is a status fact, not failed or successful parity evidence.

## Reconciliation and uncertainty

- The older 2026-05-05 raw bridge correctly recorded a narrow no-drift source check for the core transform. This capture refreshes its date and adds the explicit Emscripten host-contract / local-harness distinction; it does not silently erase the older capture.
- A source-backed static transform does not by itself prove a usable host integration. A future Starshine implementation needs an execution test that exercises a deliberate unwind/rewind lifecycle, and must document its reentrancy/nested-entry policy instead of assuming it from WAT shape alone.
- The Emscripten setting names and JS glue are driver/runtime API evidence. Do not treat every Emscripten configuration knob as an already-decided future Starshine CLI option.
