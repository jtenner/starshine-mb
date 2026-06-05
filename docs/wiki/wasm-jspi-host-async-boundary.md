---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md
  - raw/wasm/2026-06-05-jspi-host-async-boundary-refresh.md
  - tooling/node-package-surface.md
  - ../../node/internal/runtime.js
  - ../../node/internal/wasi-runner.js
  - ../../node/README.md
  - ../../node/package.json
related:
  - tooling/wasi-runner-and-preview-boundary.md
  - wasm-feature-status-and-proposal-boundaries.md
  - wasm-stack-switching-boundary.md
  - wasm-js-string-builtins-boundary.md
  - wasm-esm-integration-boundary.md
  - wasm-component-model-boundary.md
  - tooling/node-package-surface.md
  - tooling/release-process.md
  - tooling/external-validator-adapters.md
---

# JSPI Host-Async Boundary

## Overview

Use this page when a Starshine or WebAssembly claim mentions **JavaScript Promise Integration (JSPI)**, `WebAssembly.Suspending`, `WebAssembly.promising(...)`, Promise-returning imports, async host calls, or JavaScript embedding of suspending WebAssembly.

For beginners: ordinary WebAssembly functions run synchronously once the module has been instantiated. JavaScript Promises are asynchronous. JSPI is the proposal that lets a JavaScript embedding suspend a WebAssembly call while a Promise is pending and resume it later. That is a host/JavaScript API boundary, not a new Starshine WAST keyword, binary section, validator rule, or optimizer pass.

The current source bridge is [`raw/wasm/2026-06-05-jspi-host-async-boundary-refresh.md`](raw/wasm/2026-06-05-jspi-host-async-boundary-refresh.md). It rechecked the current WebAssembly proposals tracker, the JSPI proposal repository and overview, the WebAssembly JS API repository, and Starshine's current Node package runtime code.

## Current Status Rule

Treat JSPI as **active Phase 4 proposal evidence** and a **JavaScript embedding API** surface:

- **not finished/Core WebAssembly 3.0** until the finished-proposals table and Core/JS API spec pages say so;
- **not Starshine support** unless the Node package or another host adapter explicitly wraps imports with `WebAssembly.Suspending`, adapts exports with `WebAssembly.promising(...)`, and tests the behavior;
- **not WAST/binary/validator/generator/pass evidence** by itself.

The active proposal tracker can move. Use this focused 2026-06-05 bridge for current JSPI routing and preserve older raw captures as historical evidence rather than silently rewriting them.

## What JSPI Means In Practice

The proposal-facing shape is about wrapper placement around host imports and WebAssembly exports:

```js
const imports = {
  host: {
    // JSPI proposal shape: a Promise-returning host function can be wrapped
    // so WebAssembly can suspend while the Promise is pending.
    readFile: new WebAssembly.Suspending(async (path) => {
      return await readBytes(path);
    }),
  },
};

const instance = await WebAssembly.instantiate(module, imports);

// JSPI proposal shape: a WebAssembly export can be adapted to return a Promise.
const runAsync = WebAssembly.promising(instance.exports.run);
await runAsync();
```

That example is intentionally a **proposal-shape sketch**, not current Starshine package code. It shows where future support would live: in a JavaScript host adapter and its public API, not in core module validation.

## Current Starshine Boundary

| Surface | Current Starshine evidence | JSPI status |
| --- | --- | --- |
| wasm-gc adapter loading | [`node/internal/runtime.js`](../../node/internal/runtime.js) reads the local wasm-gc artifact, compiles/instantiates it with `builtins: ["js-string"]`, and caches exports behind async JavaScript functions. | Async loading only; no `WebAssembly.Suspending` import wrappers and no `WebAssembly.promising(...)` export adaptation. |
| wasm-gc imports | The import object currently handles MoonBit filesystem/time shims, console logging, and string constants. Unsupported import modules throw. | No Promise-suspending host import policy. |
| WASI runner | [`node/internal/wasi-runner.js`](../../node/internal/wasi-runner.js) instantiates a Core module with a Preview 1 `wasi_snapshot_preview1` import object, then runs `_start` or initializes a reactor; focused runner details live in [`tooling/wasi-runner-and-preview-boundary.md`](tooling/wasi-runner-and-preview-boundary.md). | Preview 1 runner execution; no JSPI wrapper policy and no Preview 2 / WASI 0.2 or Preview 3 / WASI 0.3 component support. |
| Package contract | [`node/README.md`](../../node/README.md) and [`node/package.json`](../../node/package.json) require Node.js 25+ with WebAssembly GC and JS string builtins. | No advertised JSPI requirement or JSPI API. |
| Core/WAST/binary/validator | Current Starshine module docs route Core module syntax, binary, validation, generator, and pass claims through focused pages. | No JSPI-specific module layer exists today. |

The key wording rule is: **Starshine's Node package is async, but not JSPI-enabled.** JavaScript `async` functions used for file I/O, artifact loading, or package API ergonomics are not the same as JSPI's Promise-aware WebAssembly call-stack suspension.

## Do Not Conflate With Nearby Features

| Nearby feature | Why it is different | Routing |
| --- | --- | --- |
| JS String Builtins | Uses JavaScript compile/instantiate options such as `builtins: ["js-string"]` and reserved `wasm:js-string` imports. It is about string helpers, not Promise suspension. | [`wasm-js-string-builtins-boundary.md`](wasm-js-string-builtins-boundary.md) |
| ESM Integration | Loads `.wasm` resources through JavaScript module graphs with source-phase or instance-phase imports. It is about module loading/linking, not Promise-aware suspension. | [`wasm-esm-integration-boundary.md`](wasm-esm-integration-boundary.md) |
| Reference-Typed Strings / `stringref` | Active proposal/local string instruction and literal-pool surfaces. | [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md), [`strings/string-const-surface.md`](strings/string-const-surface.md) |
| Component Model / Canonical ABI | Higher-level components, WIT worlds, and lift/lower adapters. It may eventually have async interface questions, but it is not the same as JSPI. | [`wasm-component-model-boundary.md`](wasm-component-model-boundary.md) |
| WASI Preview 1 runner / WASI 0.2 / WASI 0.3 | Current Starshine's runner is Preview 1 Core-module execution through `wasi_snapshot_preview1`; Preview 2 / WASI 0.2 and Preview 3 / WASI 0.3 are component/WIT-facing roadmap surfaces. None is JSPI Promise suspension. | [`tooling/wasi-runner-and-preview-boundary.md`](tooling/wasi-runner-and-preview-boundary.md), [`wasm-component-model-boundary.md`](wasm-component-model-boundary.md) |
| Stack Switching | Separate active Phase-3 typed-continuations proposal mechanics for stackful Core-module control transfer. JSPI may be discussed near suspension/resumption, but Starshine support claims need continuation-type / `cont.*` / `resume*` source and local implementation evidence. | [`wasm-stack-switching-boundary.md`](wasm-stack-switching-boundary.md), [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md) |
| External validator support | `wasm-tools`, WABT, and Binaryen command adapters validate/print/optimize modules; they do not prove JavaScript host wrapper behavior. | [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md) |

## Future Implementation Checklist

If Starshine decides to support JSPI in the Node package, the first slice should be explicit host-adapter work:

1. **API design:** decide whether JSPI is automatic, opt-in per import/export, or exposed through wrapper helpers.
2. **Runtime detection:** check whether the target Node/runtime exposes the relevant `WebAssembly` JSPI APIs and report a clear unsupported-runtime error when absent.
3. **Import wrapper policy:** define which host imports may return Promises and how argument/result conversion interacts with the current wasm-gc adapter.
4. **Export wrapper policy:** define which exported functions are adapted to Promise-returning JS functions and how errors/traps propagate.
5. **Tests:** add Node smoke/API tests with a small module and Promise-returning host function. Keep these tests separate from WAST parser or validator tests unless those layers change.
6. **Docs:** update `node/README.md`, [`tooling/node-package-surface.md`](tooling/node-package-surface.md), [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md), and this page together.
7. **Release:** if runtime requirements change, update [`tooling/release-process.md`](tooling/release-process.md) and package metadata/testing gates.

Do **not** start by adding a Starshine WAST keyword, binary opcode, validation rule, GenValid gate, or optimizer pass unless a concrete JSPI design requires a local module-level carrier. Current evidence points to JavaScript embedding work first.

## Source Map

- Current source bridge: [`raw/wasm/2026-06-05-jspi-host-async-boundary-refresh.md`](raw/wasm/2026-06-05-jspi-host-async-boundary-refresh.md)
- Shared feature-status router: [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md)
- Stack Switching boundary: [`wasm-stack-switching-boundary.md`](wasm-stack-switching-boundary.md)
- JS String Builtins boundary: [`wasm-js-string-builtins-boundary.md`](wasm-js-string-builtins-boundary.md)
- Component Model boundary: [`wasm-component-model-boundary.md`](wasm-component-model-boundary.md)
- ESM Integration boundary: [`wasm-esm-integration-boundary.md`](wasm-esm-integration-boundary.md)
- WASI runner / Preview boundary: [`tooling/wasi-runner-and-preview-boundary.md`](tooling/wasi-runner-and-preview-boundary.md), [`raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md`](raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md)
- Node package surface: [`tooling/node-package-surface.md`](tooling/node-package-surface.md)
- Current Node package files: [`../../node/internal/runtime.js`](../../node/internal/runtime.js), [`../../node/internal/wasi-runner.js`](../../node/internal/wasi-runner.js), [`../../node/README.md`](../../node/README.md), [`../../node/package.json`](../../node/package.json)
