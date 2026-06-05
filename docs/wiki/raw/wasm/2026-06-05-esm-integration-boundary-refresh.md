# ESM Integration Boundary Refresh

Capture date: 2026-06-05

Purpose: separate active **WebAssembly ESM Integration** proposal evidence from Starshine's current ESM-first Node package, direct JavaScript `WebAssembly.compile(...)` / `instantiate(...)` wrappers, JS String Builtins compile options, JSPI, Component Model, and Core-module parser/validator support.

## Primary sources checked

1. WebAssembly proposals tracker: <https://github.com/WebAssembly/proposals>
   - Checked 2026-06-05.
   - Finding: `ESM Integration` is listed in Phase 3 / implementation phase. It is not in the finished-proposals table and should not be described as Core WebAssembly 3.0 or finished local support.
   - Nearby rows remain separate: `JS Promise Integration` is Phase 4, `Stack Switching` and `Wide Arithmetic` are Phase 3, and `Component Model` is Phase 1. ESM Integration support claims should not be routed through those boundaries unless the specific feature is involved.
2. WebAssembly ESM Integration proposal repository: <https://github.com/WebAssembly/esm-integration>
   - Checked 2026-06-05.
   - Finding: the repository is a proposal/spec prototype for adding ES module integration to WebAssembly, with details in the proposal subfolder and formatted draft pages.
3. WebAssembly JavaScript Interface ESM Integration editor's draft: <https://webassembly.github.io/esm-integration/js-api/index.html#esm-integration>
   - Checked 2026-06-05.
   - Finding: the draft has an explicit `Integration with ECMAScript modules` section. It models WebAssembly modules in ECMAScript module graphs and records that implementations may choose source-phase support without the full evaluation/instance phase.
   - Finding: the draft's module-record model parses WebAssembly bytes into a WebAssembly module record, associates a `WebAssembly.Module` source kind, enables `js-string` builtins and the `wasm:js/string-constants` module during ESM parsing, derives requested modules from Wasm imports, and instantiates/link-checks through ECMAScript module resolution and WebAssembly JS API semantics.
4. Node.js ECMAScript modules documentation, Wasm modules section: <https://nodejs.org/dist/latest/docs/api/esm.html#wasm-modules>
   - Checked 2026-06-05.
   - Finding: current Node docs say importing both WebAssembly module instances and source-phase imports is supported and is in line with the ES Module Integration proposal.
   - Finding: source-phase `import source` yields a `WebAssembly.Module` object for custom instantiation; dynamic `import.source(...)` is also documented.
   - Finding: instance-phase imports let `.wasm` files be imported as normal modules and expose the instantiated module's exports namespace.
   - Finding: Node documents automatic JS String Builtins enablement through ESM Integration, with compile-time `wasm:js-string` and `wasm:js/string-constants` behavior that is not the same as Starshine's direct JS wrapper code.
   - Finding: Node reserves `wasm:` / `wasm-js:` prefixes for ESM-loaded Wasm modules. This is a host-loader/linking rule, not a Starshine Core-module validator rule.

## Starshine repository evidence checked

- `node/package.json`
  - The package is ESM-first (`"type": "module"`) and exports JavaScript wrapper subpaths for Starshine APIs.
  - There is no package export whose target is a `.wasm` file, no wildcard wasm export pattern, and no documented package API for importing user `.wasm` modules as JavaScript module records.
- `node/internal/runtime.js`
  - `instantiateWasmGc()` reads `starshine.wasm-gc.wasm` with `fs.promises.readFile`, calls `WebAssembly.compile(wasmBytes, { builtins: ["js-string"] })`, builds an explicit import object, then calls `WebAssembly.instantiate(module, importObject, { builtins: ["js-string"] })`.
  - This is direct JavaScript API loading of the internal adapter artifact, not `import source`, dynamic `import.source(...)`, or instance-phase `import * as M from "./x.wasm"`.
- `node/internal/wasi-runner.js`
  - `runWasmStart(...)` reads a file path, compiles bytes with `WebAssembly.compile(wasmBytes)`, constructs an explicit WASI/import object, and instantiates directly.
  - This path is a package execution helper for user-supplied wasm files, not an ESM module graph integration.
- `node/README.md`
  - The README calls the package ESM-first and documents a Node.js 25+ runtime with WebAssembly GC and JS string builtins.
  - It does not claim that consumers can import `.wasm` files from `@jtenner/starshine` through Node's Wasm ESM integration, and it does not expose source-phase or instance-phase import helpers.
- `src/binary`, `src/wast`, `src/validate`, and `src/lib`
  - These Starshine layers represent, decode/encode, parse, validate, fuzz, and optimize Core WebAssembly modules. They do not contain an ECMAScript module loader, JavaScript module-record representation, source-phase import parser, instance-phase namespace wrapper, or host-reserved-name enforcement for ESM-loaded Wasm.

## Durable reconciliation

- Treat **ESM Integration** as active Phase-3 WebAssembly proposal evidence. It is about JavaScript/ECMAScript module-loader integration for `.wasm` resources, not Core WAST syntax, binary section support, validation rules, optimizer passes, or the Component Model.
- Treat Starshine's **ESM-first Node package** as ordinary JavaScript package-format evidence. `node/package.json` using `"type": "module"` and an `exports` map does not prove WebAssembly ESM Integration support.
- Treat Starshine's current internal wasm loading as **direct JS API loading**. Reading bytes and calling `WebAssembly.compile(...)` / `instantiate(...)` is not source-phase or instance-phase ESM import support.
- Keep the JS String Builtins split visible: Node's ESM-loaded Wasm path automatically enables compile-time builtins, while Starshine's direct wasm-gc wrapper opts in explicitly with `builtins: ["js-string"]` and does not use `import source`.
- Future Starshine ESM Integration support would be Node/package/loader API work first: package-export design, runtime support matrix, import-object policy for instance-phase imports, tests for source-phase and dynamic source-phase imports, reserved namespace handling, README/API docs, and release packaging checks.
