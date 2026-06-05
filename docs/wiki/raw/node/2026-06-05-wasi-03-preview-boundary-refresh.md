# WASI 0.3 / Node Preview Boundary Refresh (2026-06-05)

## Purpose

Refresh the WASI runner boundary after checking current WASI 0.3 / Preview 3 roadmap material and Node's current `node:wasi` API. This source note keeps Starshine's Node-hosted Preview 1 Core-module runner separate from WASI 0.2 / Preview 2 component APIs and the newer WASI 0.3 native-async roadmap.

## Primary external sources checked

1. Node.js v26.3.0 `node:wasi` API documentation, checked 2026-06-05: <https://nodejs.org/api/wasi.html>
   - `node:wasi` remains Stability 1 / Experimental.
   - The current documented constructor shape still requires `new WASI({ version: "preview1", ... })` for Preview 1 modules; the import object for that version uses `wasi_snapshot_preview1`.
   - Node continues to document that its WASI API is not a secure sandbox; preopens and capabilities are not enough to treat arbitrary wasm execution as isolation.
2. WebAssembly/WASI repository README, checked 2026-06-05: <https://github.com/WebAssembly/WASI>
   - The repository still distinguishes the legacy Preview 1 / WITX family from the component/WIT-oriented later WASI work.
   - Preview 2 / WASI 0.2 is described as stable WIT/component API work, not as a `wasi_snapshot_preview1` Core-module import surface.
3. WASI.dev roadmap, checked 2026-06-05: <https://wasi.dev/roadmap>
   - The current roadmap names WASI 0.3.0 / WASI P3 as the next major focus around native async support.
   - This roadmap is future/API-family evidence. It is not evidence that Node's current `node:wasi` Preview 1 runner, Starshine's package runner, or Starshine's Core module validator support WASI 0.3.
4. WASI.dev interfaces catalog, checked 2026-06-05: <https://wasi.dev/interfaces>
   - Current WASI APIs are organized as WIT/package-style API families with proposal/status metadata.
   - The catalog is useful for component/WIT roadmap triage, not for proving support in Starshine's current Core-module runner.
5. Bytecode Alliance Component Model documentation, checked 2026-06-05: <https://component-model.bytecodealliance.org/>
   - The documentation presents components, interfaces/worlds, WIT, and Canonical ABI as the interoperability layer for component-oriented WebAssembly.
   - This is the right conceptual route for future WASI 0.2/0.3 support; it remains separate from direct `WebAssembly.compile(...)` / `instantiate(...)` of a Core module with a Preview 1 import object.

## Local Starshine sources checked

- `node/internal/wasi-runner.js`
  - Still constructs `new WASI({ version: "preview1", args, env, preopens, stdout, stderr })`.
  - Still wires `wasi_snapshot_preview1: wasi.wasiImport` plus local `spectest`, `__moonbit_fs_unstable`, `__moonbit_time_unstable`, and `console` shims.
  - Still rejects missing import modules at the host import boundary.
  - Does not parse WIT, load component binaries, instantiate components, or implement native async WASI APIs.
- `scripts/lib/moonbit-wasi-runner.mjs`
  - Mirrors the same Preview 1 Core-module runner for self-opt/spec workflows.
- `docs/wiki/tooling/wasi-runner-and-preview-boundary.md` and `docs/wiki/wasm-component-model-boundary.md`
  - Already separate Preview 1 runner claims from Component Model / WIT / WASI 0.2 claims; they needed an explicit WASI 0.3 / P3 routing note so future native-async WASI references do not get mistaken for current Starshine support.

## Durable conclusions

1. Starshine's checked-in Node runners remain **Preview 1 Core-module runners**. They execute ordinary Core wasm artifacts that import `wasi_snapshot_preview1` and local Starshine/MoonBit host shims.
2. WASI 0.2 / Preview 2 and WASI 0.3 / Preview 3 belong to the component/WIT/WASI API-family roadmap. They are not implemented by Starshine's current Preview 1 runner, Core binary decoder, WAST parser, validator, generator, or optimizer passes.
3. A future Starshine WASI 0.3 claim must be routed through Component Model / WIT / Canonical ABI design first, with explicit native-async host behavior and Node/public-API policy. It should not be described as a small update to the current `node:wasi` import object.
4. Node's current `node:wasi` security warning still applies to the current Starshine runner. Do not use WASI 0.2/0.3 roadmap status or preopens as sandbox evidence for untrusted wasm.

## Follow-ups

- Update the living WASI runner and Component Model pages so WASI 0.3 / P3 references route to Component Model design work rather than the Preview 1 runner.
- If Starshine later adds component/WASI support, capture fresh primary sources and current local implementation evidence before changing the runner/support claim.
