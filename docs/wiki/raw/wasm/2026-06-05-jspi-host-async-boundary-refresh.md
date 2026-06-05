# JSPI Host-Async Boundary Refresh

Capture date: 2026-06-05

Purpose: support the living JSPI boundary page at `docs/wiki/wasm-jspi-host-async-boundary.md` and refresh the feature-status router so JavaScript Promise Integration is not confused with Starshine's current Node package async loading, JS String Builtins compile options, Component Model, WASI, or optimizer/runtime behavior.

## Primary external sources rechecked

- WebAssembly proposals tracker, current public README: <https://github.com/WebAssembly/proposals>
  - The active tracker currently lists **JavaScript Promise Integration (JSPI)** in Phase 4. Phase 4 is still active proposal work, not the finished/Core table. The same tracker currently routes nearby host/async-adjacent rows separately: Stack Switching under Phase 2, Component Model under Phase 1, and ESM Integration under Phase 3.
  - This bridge supersedes shorthand that treated JSPI only as a generic row inside the 2026-06-04 active-proposal snapshot. It does not rewrite older raw captures, which remain historical source material.
- WebAssembly JSPI proposal repository: <https://github.com/WebAssembly/js-promise-integration>
  - The repository frames JSPI as JavaScript API integration for suspending and resuming WebAssembly around Promises, not as a new Starshine WAST syntax or optimizer pass.
- JSPI explainer / overview: <https://github.com/WebAssembly/js-promise-integration/blob/main/proposals/js-promise-integration/Overview.md>
  - The overview describes the two host-facing wrappers maintainers should recognize: imports can be wrapped with `WebAssembly.Suspending`, and exports can be adapted with `WebAssembly.promising(...)` so Promise-returning JavaScript and WebAssembly call stacks can interoperate.
  - JSPI behavior is about JavaScript embedding and host continuation management. It should not be cited as evidence for Core module binary sections, WAST parser/printer support, module validation, GenValid, or Binaryen pass parity unless a future source explicitly adds such a local layer.
- WebAssembly JS API repository: <https://github.com/WebAssembly/js-api>
  - The JS API repository owns JavaScript embedding API proposals and draft spec work. Use it as the standards-neighborhood source for `WebAssembly.*` API behavior rather than Core module syntax pages.

## Repository evidence rechecked

- `node/internal/runtime.js`
  - Current wasm-gc adapter loading is asynchronous because it reads and compiles an artifact, then calls `WebAssembly.compile(...)` and `WebAssembly.instantiate(...)` with `builtins: ["js-string"]`.
  - The current import object supports MoonBit filesystem/time shims, console logging, and string constants. It does not construct `WebAssembly.Suspending` wrappers, call `WebAssembly.promising(...)`, or expose JSPI-specific wrapper policy to package consumers.
- `node/internal/wasi-runner.js`
  - Current WASI execution instantiates a module and runs `_start` or initializes WASI. It does not wrap imports/exports for Promise suspension/resumption.
- `node/README.md` and `node/package.json`
  - The package declares Node.js 25+ with WebAssembly GC and JS string builtins as its runtime requirement. It does not advertise JSPI support, Promise-suspending imports, or JSPI-adapted exports.
- `docs/wiki/tooling/node-package-surface.md`
  - The Node package surface already separates JS String Builtins compile options from Starshine `StringRefsSec`. It needed a sibling host-async boundary so future JSPI work does not get filed as a string-builtin, component-model, WASI, or generic async-instantiation fact.

## Durable conclusions

1. JSPI is active Phase 4 proposal evidence and a JavaScript embedding API boundary. It is not finished/Core WebAssembly 3.0 evidence and not local Starshine support by itself.
2. Starshine's current Node package uses async JavaScript functions for file I/O and instantiation, but it does not implement JSPI's host-suspension wrappers. Do not describe `getWasmGcExports()` or WASI runner async code as JSPI support.
3. JSPI is distinct from JS String Builtins (`builtins: ["js-string"]`), Reference-Typed Strings / `stringref`, Component Model / Canonical ABI async/lift-lower work, WASI Preview 2, and Stack Switching proposal mechanics.
4. A future Starshine JSPI slice should be Node-package/API work first: explicit wrapper design, package README/API docs, runtime support tests, host import/export examples, and feature-status routing. It should not start by changing WAST, binary decode/encode, module validation, or optimizer passes unless those layers receive concrete JSPI-facing requirements.
5. Whole-wiki health check should prefer newest focused bridges for active proposal row placement because the tracker can move; older raw captures remain useful historical evidence but should not override a same-day focused recheck.
