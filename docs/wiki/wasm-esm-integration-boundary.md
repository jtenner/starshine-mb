---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - raw/wasm/2026-07-11-esm-integration-node-loader-and-string-builtins-recheck.md
  - https://nodejs.org/api/wasi.html
  - raw/wasm/2026-06-05-esm-integration-boundary-refresh.md
  - raw/wasm/2026-07-10-webassembly-core3-proposal-dashboard-recheck.md
  - wasm-js-string-builtins-boundary.md
  - wasm-jspi-host-async-boundary.md
  - wasm-component-model-boundary.md
  - tooling/node-package-surface.md
  - ../../node/package.json
  - ../../node/README.md
  - ../../node/internal/runtime.js
  - ../../node/internal/wasi-runner.js
related:
  - tooling/wasi-runner-and-preview-boundary.md
  - wasm-feature-status-and-proposal-boundaries.md
  - wasm-js-string-builtins-boundary.md
  - wasm-jspi-host-async-boundary.md
  - wasm-component-model-boundary.md
  - tooling/node-package-surface.md
  - tooling/release-process.md
  - binary/module-section-map.md
  - tooling/external-validator-adapters.md
---

# ESM Integration Boundary

## Overview

Use this page when a Starshine or WebAssembly claim mentions **ESM Integration**, `.wasm` imports in JavaScript modules, source-phase `import source`, dynamic `import.source(...)`, instance-phase Wasm imports, or Node's Wasm ESM loader.

For beginners: ECMAScript modules are JavaScript's `import` / `export` module system. WebAssembly Core modules are bytecode artifacts with their own imports and exports. **ESM Integration** is the active WebAssembly proposal that lets a JavaScript module graph treat a `.wasm` file as a module resource instead of making user code read bytes and call `WebAssembly.compile(...)` by hand.

The current source bridge is [`raw/wasm/2026-07-11-esm-integration-node-loader-and-string-builtins-recheck.md`](raw/wasm/2026-07-11-esm-integration-node-loader-and-string-builtins-recheck.md). It rechecked the official WebAssembly proposals tracker, the ESM Integration JavaScript Interface draft, Node.js v26.4.0 Wasm-module ESM docs, and Starshine's current Node/runtime sources. The earlier [`raw/wasm/2026-06-05-esm-integration-boundary-refresh.md`](raw/wasm/2026-06-05-esm-integration-boundary-refresh.md) remains historical provenance.

Durable status rule:

- **Standards status:** ESM Integration remains an active Phase-3 proposal as of the 2026-07-11 recheck, not finished/Core WebAssembly 3.0.
- **Runtime status:** Node v26.4.0 documents source-phase imports as release-candidate (1.2) and instance imports as active development (1.1). Those are Node support labels, not WebAssembly proposal-stage or Starshine-support claims.
- **Starshine package status:** the `@jtenner/starshine` package is ESM-first JavaScript, but it does not expose WebAssembly ESM Integration for user modules or for its internal artifacts.
- **Implementation layer:** future support would be Node/package/loader API work before WAST, binary, validator, generator, or optimizer work.

## What ESM Integration Means

There are two common host-facing shapes:

```js
// Source phase: the JavaScript module graph imports the wasm bytes as
// a compiled WebAssembly.Module, then user code instantiates it explicitly.
import source mod from './math.wasm';

const instance = await WebAssembly.instantiate(mod, imports);
```

```js
// Instance phase: the JavaScript module graph imports the wasm module as
// an instantiated module namespace, subject to host/module-linking rules.
import * as math from './math.wasm';

console.log(math.add(1, 2));
```

The proposal and Node docs also document a dynamic source-phase form, `import.source('./math.wasm')`, for code that wants a `Promise<WebAssembly.Module>` rather than a static import declaration.

These shapes are about **JavaScript module loading and linking**. They do not add a new Core WebAssembly instruction, section, WAST keyword, validation stack rule, optimizer pass, or Component Model representation.

## Current Starshine Boundary

| Surface | Current Starshine evidence | ESM Integration status |
| --- | --- | --- |
| Package format | [`node/package.json`](../../node/package.json) sets `"type": "module"` and an explicit JavaScript `exports` map. | ESM-first JavaScript package only; not proof that `.wasm` resources are importable through WebAssembly ESM Integration. |
| Internal wasm-gc adapter | [`node/internal/runtime.js`](../../node/internal/runtime.js) reads `starshine.wasm-gc.wasm`, calls `WebAssembly.compile(...)` with `builtins: ["js-string"]`, manually supplies ordinary `_` string imports, and calls `WebAssembly.instantiate(...)`. | Direct JavaScript API loading; no `import source`, no `import.source(...)`, no instance-phase Wasm namespace import, and no `importedStringConstants` option. The `_` object is Starshine host glue, not Node's ESM string-constant builtin module. |
| WASI runner | [`node/internal/wasi-runner.js`](../../node/internal/wasi-runner.js) reads an arbitrary wasm file path, compiles bytes, constructs a Preview 1 `wasi_snapshot_preview1` import object plus Starshine/MoonBit host shims, and instantiates directly. | Execution helper for Core modules; not an ESM module graph, source-phase import, instance-phase loader integration, WASI Preview 2 / WASI 0.2 component path, or WASI Preview 3 / WASI 0.3 native-async path. See [`tooling/wasi-runner-and-preview-boundary.md`](tooling/wasi-runner-and-preview-boundary.md). |
| README/API | [`node/README.md`](../../node/README.md) documents an ESM-first Node package and runtime requirements for WebAssembly GC plus JS string builtins. | No advertised source-phase or instance-phase `.wasm` import API. |
| Core/WAST/binary/validator | Starshine's core pages cover ordinary Core module parsing, binary decode/encode, validation, fuzzing, and optimizer passes. | No JavaScript module-record model, host ESM resolver, source-phase parser, instance-phase wrapper, or ESM reserved-namespace policy. |

The key wording rule is: **Starshine is an ESM package, but it is not a Wasm ESM Integration package yet.** Ordinary JavaScript ESM package metadata is not the same as WebAssembly `.wasm` modules participating in the JavaScript module graph.

## Source Phase And Instance Phase Are Separate Delivery Slices

Both forms are proposed together, but the ESM Integration draft permits an implementation to support only the **source phase**. Node likewise documents different stability labels: source phase is 1.2 (release candidate), while instance imports are 1.1 (active development) in v26.4.0. A future Starshine feature must therefore test and document them separately rather than treating “Wasm ESM support” as one boolean.

| Slice | What the caller gets | Extra policy it needs | Starshine status |
| --- | --- | --- | --- |
| Source phase: `import source mod from "./m.wasm"` or `await import.source("./m.wasm")` | A `WebAssembly.Module`; the caller supplies imports and instantiates it. | A package/resource route and runtime-version matrix. It does not decide Starshine's default host import object. | No package export, helper, example, or smoke test uses this syntax. |
| Instance phase: `import * as ns from "./m.wasm"` | The Wasm exports after ECMAScript module-graph linking. | An explicit linking/import-object policy, plus Node's asymmetric instance-import namespace policy: `wasm-js:` is reserved in module import names, module names, and export names; `wasm:` is reserved in module/export names but remains allowed as an imported module name. | No package export, helper, example, or smoke test uses this syntax. |

These Node namespace rules are deliberately **not** Core validation rules. Starshine's WAST parser, binary codec, and validator should continue to model ordinary Core imports unless Starshine adds an ESM loader with a focused policy and tests.

### Builtins are loader-linked, not ordinary import-object entries

For ESM-loaded modules, the draft and Node documentation make `js-string` / `wasm:js/string-constants` loader behavior automatic. Builtin functions are compile-time linked and are not ordinary entries returned from `WebAssembly.Module.imports(...)`. Therefore, an ESM Integration smoke test must not add fake `wasm:js-string` properties to an import object and use their absence/presence as its assertion.

This is distinct from current Starshine code: [`node/internal/runtime.js`](../../node/internal/runtime.js) passes the direct API option `builtins: ["js-string"]`, then explicitly constructs ordinary imports. Its `_` string constants are host-created from import names by local wrapper code, not the JavaScript API `importedStringConstants` option or ESM's `wasm:js/string-constants` loader behavior.

## Do Not Conflate With Nearby Features

| Nearby feature | Why it is different | Routing |
| --- | --- | --- |
| JS String Builtins | Node's ESM-loaded Wasm path automatically enables JS String Builtins; Starshine's current wrapper enables them explicitly through direct `WebAssembly.compile(...)` / `instantiate(...)` options. That is a host string-helper boundary, not proof of ESM Integration. | [`wasm-js-string-builtins-boundary.md`](wasm-js-string-builtins-boundary.md) |
| JSPI | JavaScript Promise Integration wraps imports/exports for Promise suspension. It is a host async API proposal, not a module-loader proposal. | [`wasm-jspi-host-async-boundary.md`](wasm-jspi-host-async-boundary.md) |
| Component Model / WASI 0.2 / WASI 0.3 | Components, WIT, Canonical ABI, WASI 0.2 interfaces, and WASI 0.3 native-async roadmap items are higher-level artifact/interface layers. ESM Integration loads Core Wasm modules through JavaScript module graphs, while the current Starshine WASI runner is Preview 1 direct instantiation. | [`wasm-component-model-boundary.md`](wasm-component-model-boundary.md), [`tooling/wasi-runner-and-preview-boundary.md`](tooling/wasi-runner-and-preview-boundary.md) |
| Core module binary/text support | Starshine can decode, validate, print, fuzz, and optimize ordinary Core modules. That does not imply Node can import them through `import source` from Starshine's package. | [`binary/module-section-map.md`](binary/module-section-map.md), [`tooling/node-package-surface.md`](tooling/node-package-surface.md) |
| External validator adapters | `wasm-tools`, WABT, Binaryen, and Starshine command adapters validate/print/optimize modules. They do not prove JavaScript module-loader behavior. | [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md) |

## Correct Wording For Wiki Claims

Prefer:

- “`@jtenner/starshine` is an ESM-first JavaScript package, but current wasm artifacts are loaded with direct JS API calls, not source-phase or instance-phase Wasm ESM imports.”
- “ESM Integration is active Phase 3 proposal evidence; a Starshine support claim needs Node/package loader code and tests, not only Core module decode/validation support.”
- “Node's Wasm ESM loader may auto-enable JS String Builtins, but Starshine's current runtime opts into `builtins: ["js-string"]` explicitly during direct compile/instantiate.”
- “A `.wasm` file accepted by Starshine's binary decoder can still be outside the Starshine Node package's ESM import surface.”

Avoid:

- “Starshine supports Wasm ESM because `node/package.json` has `"type": "module"`.”
- “The Node wrapper uses source-phase imports” when the code reads bytes and calls `WebAssembly.compile(...)`.
- “ESM Integration is Component Model support.”
- “A validator pass should enforce Node's `wasm:` / `wasm-js:` namespace policy” without a specific ESM-loader implementation slice.

## Future Implementation Checklist

If Starshine decides to support ESM Integration in the Node package, design it as host/package work first:

1. **Surface choice:** decide whether to expose importable `.wasm` package subpaths, helpers around `import.source(...)`, examples for user-owned `.wasm` imports, or all of these.
2. **Runtime matrix:** record the Node/runtime versions and flags needed for source-phase and instance-phase imports, and keep them separate from WebAssembly GC / JS String Builtins runtime requirements.
3. **Instantiation policy:** define how instance-phase imports get host import objects, WASI support, `spectest`, MoonBit FS/time shims, and string constants. Source-phase imports may deliberately leave instantiation to callers.
4. **Namespace policy:** for instance-phase imports, decide whether Starshine exposes Node's asymmetric namespace policy (`wasm-js:` is fully reserved; `wasm:` is still permitted as an imported module name) as a package diagnostic or leaves Node to report it. This is loader/package behavior, not ordinary Core validation.
5. **Tests:** add separate source-phase, dynamic-source-phase, and instance-phase Node API/smoke/example tests. Test that source phase leaves imports to the caller; test instance-phase linking, reserved names, and automatic builtin behavior without expecting compile-time builtins in `WebAssembly.Module.imports(...)`; add graceful unsupported-runtime cases when needed.
6. **Docs and release:** update [`node/README.md`](../../node/README.md), [`tooling/node-package-surface.md`](tooling/node-package-surface.md), [`tooling/release-process.md`](tooling/release-process.md), this page, and the feature-status router together.

Do **not** start by adding Starshine WAST syntax, binary opcode cases, validation rules, GenValid gates, or optimizer rewrites unless a concrete ESM-loader design requires new local module metadata.

## Sources

- Current source bridge: [`raw/wasm/2026-07-11-esm-integration-node-loader-and-string-builtins-recheck.md`](raw/wasm/2026-07-11-esm-integration-node-loader-and-string-builtins-recheck.md)
- Historical ESM source bridge: [`raw/wasm/2026-06-05-esm-integration-boundary-refresh.md`](raw/wasm/2026-06-05-esm-integration-boundary-refresh.md)
- Shared Core/proposal status bridge: [`raw/wasm/2026-07-10-webassembly-core3-proposal-dashboard-recheck.md`](raw/wasm/2026-07-10-webassembly-core3-proposal-dashboard-recheck.md)
- Shared feature-status router: [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md)
- JS String Builtins boundary: [`wasm-js-string-builtins-boundary.md`](wasm-js-string-builtins-boundary.md)
- JSPI boundary: [`wasm-jspi-host-async-boundary.md`](wasm-jspi-host-async-boundary.md)
- Component Model boundary: [`wasm-component-model-boundary.md`](wasm-component-model-boundary.md)
- WASI runner / Preview boundary: [`tooling/wasi-runner-and-preview-boundary.md`](tooling/wasi-runner-and-preview-boundary.md), [Node `node:wasi` documentation](https://nodejs.org/api/wasi.html)
- Node package surface: [`tooling/node-package-surface.md`](tooling/node-package-surface.md)
- Current Node package files: [`../../node/package.json`](../../node/package.json), [`../../node/README.md`](../../node/README.md), [`../../node/internal/runtime.js`](../../node/internal/runtime.js), [`../../node/internal/wasi-runner.js`](../../node/internal/wasi-runner.js)
