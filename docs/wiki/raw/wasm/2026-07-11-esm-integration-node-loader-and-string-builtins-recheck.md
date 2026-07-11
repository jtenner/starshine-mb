# ESM Integration, Node Loader, And JS String Builtins Recheck

- Capture date: 2026-07-11
- Source family: official WebAssembly proposal/status sources, the ESM Integration JavaScript Interface draft, current Node.js documentation, and current Starshine package/runtime source
- Reason for capture: refresh the stale June ESM Integration / JS String Builtins bridge with the current proposal phase, the now-separate Node source-phase and instance-phase stability labels, loader-only builtin behavior, and the exact local direct-wrapper boundary.
- Status: immutable primary-source bridge. This supersedes the June bridge for the reviewed Node-loader and ESM/builtin-routing claims; it does not supersede the June stringref proposal or Binaryen pass-source evidence.

## Primary sources checked

1. WebAssembly proposals tracker, checked 2026-07-11: <https://github.com/WebAssembly/proposals>
   - `ESM Integration` remains a Phase-3 active proposal. It is not a finished/Core-3.0 feature claim.
2. ESM Integration JavaScript Interface editor's draft, checked 2026-07-11: <https://webassembly.github.io/esm-integration/js-api/index.html>
   - The 2026-03-04 draft explicitly permits implementations to support only the source phase; source-phase and instance-phase support are therefore distinct implementation capabilities.
   - Source-phase loading creates a `WebAssembly.Module` source record and enables the `js-string` builtin plus the `wasm:js/string-constants` builtin module while parsing an ESM-loaded module.
   - Node's instance-import policy reserves the `wasm-js:` prefix in module import names, module names, and export names; it reserves `wasm:` in module names and export names but permits it as an imported module name. Builtin functions are compile-time linked rather than ordinary entries observable through `WebAssembly.Module.imports(...)`.
3. Node.js v26.4.0 ECMAScript modules documentation, Wasm modules section, checked 2026-07-11: <https://nodejs.org/docs/latest/api/esm.html#wasm-modules>
   - Node documents source-phase `import source` and dynamic `import.source(...)` as release-candidate stability 1.2, and WebAssembly instance imports as active-development stability 1.1. Those Node labels are runtime documentation, not proposal-stage or Starshine-support evidence.
   - Node documents source-phase imports as returning `WebAssembly.Module`, instance imports as exposing exports after linking, and automatic `js-string` builtins / `wasm:js/string-constants` behavior for Wasm ESM imports.
   - Node documents distinct `wasm:` / `wasm-js:` namespace restrictions specifically for instance-imported Wasm modules: `wasm-js:` is reserved in all three checked name positions, while `wasm:` remains allowed as an imported module name. These are host-loader rules, not Core-module validation rules.
4. Current Starshine source, checked 2026-07-11:
   - [`../../../../node/package.json`](../../../../node/package.json) is ESM-first and exposes only JavaScript wrapper subpaths; it has no public `.wasm` export target or loader API.
   - [`../../../../node/internal/runtime.js`](../../../../node/internal/runtime.js) reads bytes, calls direct `WebAssembly.compile(...)` / `instantiate(...)` with `builtins: ["js-string"]`, and manually supplies ordinary `_` imports whose values are their import names. It does not use source-phase or instance-phase ESM imports, `importedStringConstants`, or a Node ESM-loader namespace policy.
   - [`../../../../node/internal/wasi-runner.js`](../../../../node/internal/wasi-runner.js) likewise reads arbitrary Core-module bytes and directly compiles/instantiates them with an explicit Preview-1 import object.

## Durable reconciliation

- **Proposal status and Node availability are different claims.** ESM Integration remains Phase 3, while Node's documentation describes two separately stabilized loader surfaces. Do not turn a Node support label into a finished-standard or Starshine-support claim.
- **Source phase and instance phase need separate tests.** Source phase produces a module for caller-controlled instantiation. Instance phase performs module-graph linking and exposes exports, so it additionally owns import-object/linking policy and the reserved-prefix rule.
- **Automatic ESM builtins and direct compile options are different evidence.** Node's ESM path enables `js-string` and its string-constant module through loader semantics. Starshine's wrapper explicitly passes `builtins: ["js-string"]`; its manual `_` string imports are not the JavaScript API `importedStringConstants` mechanism and not proof of ESM Integration.
- **Builtin imports are not normal host imports.** A future loader test must not expect a compile-time-linked builtin to appear in `WebAssembly.Module.imports(...)` or to require a property in the caller-provided import object.
- **No Core validator rule follows.** Node's `wasm-js:` all-name restriction and narrower `wasm:` rule belong to its instance-phase ESM loader. Starshine's Core binary decoder, WAST parser, and validator should not reject ordinary imports on that basis unless Starshine implements a separately tested loader policy.

## Supersession and uncertainty

- The 2026-06-05 ESM and JS String Builtins bridges remain useful historical captures and source pointers. This note supersedes their Node-loader version/stability and source/instance-phase-routing claims as of 2026-07-11.
- The Node documentation reviewed is v26.4.0, while Starshine's package metadata requires Node `>=25`. A future Starshine ESM-loader feature must establish its own supported-version matrix; this recheck does not prove identical syntax/behavior across every Node 25+ release.
- The ESM Integration editor's draft is an active proposal draft. Recheck it and the proposals tracker before treating a loader detail as finalized WebAssembly behavior.
