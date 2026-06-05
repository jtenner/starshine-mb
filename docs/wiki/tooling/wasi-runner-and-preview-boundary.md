---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md
  - ../raw/node/2026-06-05-wasi-03-preview-boundary-refresh.md
  - ../../../node/internal/wasi-runner.js
  - ../../../scripts/lib/moonbit-wasi-runner.mjs
  - ../../../scripts/lib/build-node-package.mjs
  - ../../../node/test/smoke.test.mjs
  - ../../../scripts/lib/self-opt-task.ts
  - ../../../scripts/lib/run-self-optimized-spec-suite.mjs
related:
  - ./node-package-surface.md
  - ./release-process.md
  - ./validation-gates.md
  - ./o4z-debug-startup-trap.md
  - ../wasm-component-model-boundary.md
  - ../wasm-jspi-host-async-boundary.md
  - ../wasm-esm-integration-boundary.md
  - ../validate/start-section.md
  - ../wast/static-assertion-harness.md
---

# WASI Runner And Preview Boundary

## Overview

Use this page when a wiki claim, test, release step, Node package change, or runtime error mentions **WASI**, **`wasi_snapshot_preview1`**, **WASI Preview 1**, **WASI Preview 2 / WASI 0.2**, or a Starshine `*-wasi.wasm` artifact.

The current source bridges are [`../raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md`](../raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md) and [`../raw/node/2026-06-05-wasi-03-preview-boundary-refresh.md`](../raw/node/2026-06-05-wasi-03-preview-boundary-refresh.md). They rechecked Node's current `node:wasi` API docs, the WebAssembly/WASI repository, the WASI proposal/API catalog and roadmap, Component Model documentation, the Preview 1 WITX source, and current Starshine runner/build/test evidence.

Durable status:

- **Starshine status:** current checked-in and script-side JavaScript runners are **Node-hosted WASI Preview 1 Core-module runners**.
- **Not supported by that runner:** WASI Preview 2 / WASI 0.2 components, WASI Preview 3 / WASI 0.3 native-async component APIs, WIT/world parsing, component binary validation, Canonical ABI lift/lower adapters, JSPI Promise suspension, or Wasm ESM Integration imports.
- **Security caveat:** Node's own `node:wasi` docs describe the API as experimental and warn that its current threat model is not a secure sandbox. Do not describe Starshine's runner as secure isolation for untrusted wasm just because it sets preopens.

## Beginner model

WASI is a family of host APIs that lets WebAssembly programs talk to an operating-system-like environment: arguments, environment variables, files, clocks, random bytes, exit codes, and similar capabilities.

There are three names that are easy to confuse:

1. **WASI Preview 1** is the older Core-module ABI. A module imports functions from a module named `wasi_snapshot_preview1`. Node's `node:wasi` class can provide this import object.
2. **WASI Preview 2 / WASI 0.2** is the newer component/WIT-oriented family. It uses WIT interfaces and the Component Model ecosystem. It is not the same import shape as a Core module importing `wasi_snapshot_preview1`.
3. **WASI Preview 3 / WASI 0.3** is current roadmap work around native async component APIs. Treat it as future component/WIT/WASI design evidence, not as current support in Starshine's Preview 1 runner.

Starshine's current Node runner is in the first bucket. It loads bytes, compiles an ordinary Core wasm module, supplies a Preview 1 import object, supplies a few Starshine/MoonBit-specific imports, instantiates the module directly, and then runs `_start` or initializes a reactor.

```text
starshine.wasm-wasi.wasm
        |
        v
WebAssembly.compile(bytes)
        |
        v
imports = {
  wasi_snapshot_preview1: nodeWasi.wasiImport,
  spectest: ...,
  __moonbit_fs_unstable: ...,
  __moonbit_time_unstable: ...,
  console: ...
}
        |
        v
_start ? wasi.start(instance) : wasi.initialize(instance)
```

## Current Starshine layer map

| Layer | Current behavior | Code / docs |
| --- | --- | --- |
| Published package runner | Loads a wasm path, constructs `new WASI({ version: "preview1", args, env, preopens, stdout, stderr })`, wires `wasi_snapshot_preview1`, and runs `_start` or initializes. | [`node/internal/wasi-runner.js`](../../../node/internal/wasi-runner.js) |
| Script-side runner | Mirrors the package runner for self-optimized artifact and spec-suite workflows. | [`scripts/lib/moonbit-wasi-runner.mjs`](../../../scripts/lib/moonbit-wasi-runner.mjs) |
| Package build artifact | Builds `src/cmd` for wasm release and copies the output to `node/internal/starshine.wasm-wasi.wasm`. | [`scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs), [`node/package.json`](../../../node/package.json) |
| Package smoke test | Starts the optimized WASI artifact through the package runner. | [`node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs) |
| Self-opt gates | Validate artifacts with `wasm-tools --features all`, then run the artifact under the runner for `--help` and selected/full WAST spec workloads. | [`validation-gates.md`](validation-gates.md), [`scripts/lib/self-opt-task.ts`](../../../scripts/lib/self-opt-task.ts), [`scripts/lib/run-self-optimized-spec-suite.mjs`](../../../scripts/lib/run-self-optimized-spec-suite.mjs) |
| MoonBit imports | Some wasm-targeted code imports Preview 1 functions such as `proc_exit`, while JavaScript runner code also supplies Starshine/MoonBit-specific filesystem/time shims. | [`src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt), [`src/spec_runner/imports.mbt`](../../../src/spec_runner/imports.mbt), [`node/internal/wasi-runner.js`](../../../node/internal/wasi-runner.js) |

## Import modules and failure classification

The runner intentionally accepts only the import modules it wires:

| Import module | Meaning in the current runner | Classification guidance |
| --- | --- | --- |
| `wasi_snapshot_preview1` | Standard Preview 1 imports provided by Node's `WASI` object. | Runner support for Preview 1 execution. |
| `spectest` | Minimal spec-test helper used by selected WAST/spec workflows. | Test harness convenience, not WASI. |
| `__moonbit_fs_unstable` | Starshine/MoonBit filesystem/string/byte-array adapter helpers. | Local host ABI, not standardized WASI. |
| `__moonbit_time_unstable` | Starshine/MoonBit time helpers backed by JavaScript time APIs. | Local host ABI, not standardized WASI. |
| `console` | JavaScript logging helper. | Package/runtime convenience, not WASI. |
| Any other module | The runner throws `Missing import module: ...`. | Host-linking/runner gap, not a Core validator result. |

This distinction matters for bug triage. If a wasm module validates as a Core module but imports a Preview 2 component interface or some unsupported host module, Starshine's Core validator has not contradicted the runner. The failure is at the host import/instantiation boundary.

## `_start`, reactor initialization, and Core `start`

There are three nearby concepts:

| Concept | Owner | What it means |
| --- | --- | --- |
| WASI command `_start` export | Node runner / WASI Preview 1 ABI | If `_start` exists, Starshine's runner calls `wasi.start(instance)` and returns/extracts the process exit code. |
| WASI reactor initialization | Node runner | If `_start` is absent, the runner calls `wasi.initialize(instance)`. This is host-runner initialization, not a Starshine WAST command. |
| Core module `start` section | WebAssembly Core validator | Validated by Starshine as a function-index/signature rule. It is documented in [`../validate/start-section.md`](../validate/start-section.md). |

Do not use a successful `_start` smoke test as proof that the Core `start` section validator is correct, and do not use a Core `start` validation test as proof that the Node WASI runner behaves like a command runner.

## Preview 1 versus Preview 2 / WASI 0.2 and Preview 3 / WASI 0.3

Use this rule of thumb:

- **`wasi_snapshot_preview1` import object + Core module bytes:** this page.
- **WIT packages, worlds, component binaries, WASI 0.2 interfaces, WASI 0.3 / native-async WASI roadmap items, Canonical ABI adapters:** [`../wasm-component-model-boundary.md`](../wasm-component-model-boundary.md).
- **Promise-returning host imports or `WebAssembly.Suspending` / `WebAssembly.promising(...)`:** [`../wasm-jspi-host-async-boundary.md`](../wasm-jspi-host-async-boundary.md).
- **JavaScript source-phase `import source`, dynamic `import.source(...)`, or instance-phase `.wasm` module imports:** [`../wasm-esm-integration-boundary.md`](../wasm-esm-integration-boundary.md).

A future Preview 2 or Preview 3 implementation should not be treated as a small import-object tweak. It would need a component/WIT design slice: representation, decoder/parser policy, validation strategy, Canonical ABI handling, native-async host behavior when relevant, fuzzing, Node API, release checks, and docs.

## Release and validation checklist

When a change touches the WASI runner, `*-wasi.wasm` artifacts, or release packaging:

1. **Name the artifact role.** `node/internal/starshine.wasm-wasi.wasm` is the package CLI artifact; `tests/node/dist/*-wasi.wasm` are self-opt/debug/optimized validation artifacts.
2. **Keep build and runner evidence separate.** `npm run build` refreshes the package WASI CLI artifact, but it does not regenerate JavaScript/TypeScript wrappers or the wasm-gc adapter artifact; see [`node-package-surface.md`](node-package-surface.md) and [`release-process.md`](release-process.md).
3. **Run the right smoke.** Package changes need the Node smoke path; self-opt artifact changes need the self-opt smoke/full gates described in [`validation-gates.md`](validation-gates.md).
4. **Classify import failures as host boundary failures.** Missing import modules, unsupported Preview 2 interfaces, and missing Starshine/MoonBit host shims are not Core validation failures unless the module itself is also invalid.
5. **Do not overclaim sandboxing.** Preopens limit ordinary Preview 1 filesystem access in the import object, but Node's `node:wasi` docs do not make this a secure sandbox promise.
6. **Update adjacent proposal pages if behavior widens.** JSPI, ESM Integration, Component Model, and WASI 0.2/0.3 claims must move through their focused boundary pages, not through this runner page alone.

## Common mistakes

- **Mistake: “Starshine supports WASI Preview 2 or WASI 0.3 because it has a WASI runner.”** Current support is Preview 1 Core-module execution through `wasi_snapshot_preview1`.
- **Mistake: “A `*-wasi.wasm` artifact is a component.”** The current artifacts are ordinary Core wasm modules built for a Preview 1 runner.
- **Mistake: “Async JavaScript runner code is JSPI.”** It is ordinary JavaScript `async` around file I/O/instantiation. JSPI needs the JSPI APIs and host import/export wrapping.
- **Mistake: “`preopens` makes untrusted wasm safe.”** Treat runner execution as a development/test/package workflow unless a future security review proves a stronger sandbox claim.

## Sources

- Current source bridges: [`../raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md`](../raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md), [`../raw/node/2026-06-05-wasi-03-preview-boundary-refresh.md`](../raw/node/2026-06-05-wasi-03-preview-boundary-refresh.md)
- Package and script runners: [`../../../node/internal/wasi-runner.js`](../../../node/internal/wasi-runner.js), [`../../../scripts/lib/moonbit-wasi-runner.mjs`](../../../scripts/lib/moonbit-wasi-runner.mjs)
- Package build/test: [`../../../scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs), [`../../../node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs), [`../../../node/package.json`](../../../node/package.json), [`../../../node/README.md`](../../../node/README.md)
- Self-opt validation: [`validation-gates.md`](validation-gates.md), [`../../../scripts/lib/self-opt-task.ts`](../../../scripts/lib/self-opt-task.ts), [`../../../scripts/lib/run-self-optimized-spec-suite.mjs`](../../../scripts/lib/run-self-optimized-spec-suite.mjs)
- Related boundaries: [`node-package-surface.md`](node-package-surface.md), [`release-process.md`](release-process.md), [`../wasm-component-model-boundary.md`](../wasm-component-model-boundary.md), [`../wasm-jspi-host-async-boundary.md`](../wasm-jspi-host-async-boundary.md), [`../wasm-esm-integration-boundary.md`](../wasm-esm-integration-boundary.md), [`../validate/start-section.md`](../validate/start-section.md)
