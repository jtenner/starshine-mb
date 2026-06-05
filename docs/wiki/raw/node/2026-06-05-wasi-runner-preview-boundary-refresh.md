# Node WASI Runner / Preview Boundary Refresh (2026-06-05)

## Purpose

Support a focused Starshine wiki page for the Node-hosted WASI runner and keep WASI Preview 1, WASI Preview 2 / 0.2, Component Model, JSPI, ESM Integration, and ordinary Starshine Core-module validation claims separate.

## Primary external sources checked

1. Node.js v26.3.0 `node:wasi` API documentation, checked 2026-06-05: <https://nodejs.org/api/wasi.html>
   - `node:wasi` remains Stability 1 / Experimental.
   - Node documents a security warning: capability options exist, but Node's current threat model does not provide secure sandboxing equivalent to some WASI runtimes, and file-system sandboxing can be escaped.
   - `new WASI({ version: "preview1", args, env, preopens, ... })` is the documented modern shape; the `version` option is mandatory and currently supports only `unstable` and `preview1`.
   - For `preview1`, Node's import object uses the `wasi_snapshot_preview1` module name.
   - `wasi.start(instance)` runs a command-style module with `_start`; `wasi.initialize(instance)` initializes a reactor-style module and rejects `_start` modules.
2. WebAssembly/WASI repository README, checked 2026-06-05: <https://github.com/WebAssembly/WASI>
   - WASI started with what is now called Preview 1 using the `witx` IDL.
   - WASI Preview 2 is described as stable and as a modular collection of APIs defined with WIT, with lessons from Preview 1.
3. WASI.dev interface/proposal catalog, checked 2026-06-05: <https://wasi.dev/interfaces>
   - Current WASI API work is organized by proposal phases and per-API repositories such as I/O, Clocks, Random, Filesystem, Sockets, CLI, and HTTP.
   - This is API-family status evidence, not proof that Node's `node:wasi` implements those component/WIT APIs for Starshine.
4. Bytecode Alliance Component Model documentation home, checked 2026-06-05: <https://component-model.bytecodealliance.org/>
   - The Component Model documentation presents components, interfaces, worlds, and WIT as the user-facing layer for interoperable WebAssembly components.
   - It states that stable WASI 0.2.0 is a set of WIT definitions components can target; this is separate from a Core-module Preview 1 import object.
5. WASI Preview 1 WITX source, checked 2026-06-05: <https://raw.githubusercontent.com/WebAssembly/WASI/main/legacy/preview1/witx/wasi_snapshot_preview1.witx>
   - The module name is `wasi_snapshot_preview1`.
   - The API contains command/environment/file/clock/random/process calls such as `args_get`, `environ_get`, `fd_write`, path/file operations, `random_get`, and `proc_exit`.

## Local Starshine sources checked

- `node/internal/wasi-runner.js`
  - Uses `new WASI({ version: "preview1", args, env, preopens, stdout, stderr })` and wires `wasi_snapshot_preview1: wasi.wasiImport`.
  - Also supplies Starshine/MoonBit-specific imports: `spectest.print_char`, `__moonbit_fs_unstable`, `__moonbit_time_unstable`, and `console.log`.
  - Rejects any import module that is not present in its explicit import object.
  - Calls `wasi.start(instance)` when `_start` exists, otherwise calls `wasi.initialize(instance)`.
- `scripts/lib/moonbit-wasi-runner.mjs`
  - Mirrors the package runner for self-optimized artifact validation and spec-suite replay.
- `scripts/lib/build-node-package.mjs`
  - Builds the release `src/cmd` wasm target and copies `_build/wasm/release/build/cmd/cmd.wasm` to `node/internal/starshine.wasm-wasi.wasm`.
  - Requires `node/internal/starshine.wasm-gc.wasm` to already exist; wrapper generation remains separate.
- `node/test/smoke.test.mjs`
  - Smoke-tests that the optimized WASI artifact starts through the runner.
- `scripts/lib/self-opt-task.ts` and `scripts/lib/run-self-optimized-spec-suite.mjs`
  - Use the script-side WASI runner for self-optimized artifact gates and WAST spec replay.

## Durable conclusions

1. Starshine's current WASI runner is a Node-hosted **Preview 1 Core-module runner**, not WASI Preview 2 / WASI 0.2, not WIT, and not Component Model support.
2. The runner is intentionally an execution helper for Starshine CLI artifacts and selected test/spec workloads. It is not a general-purpose secure sandbox for untrusted wasm because Node itself warns that `node:wasi` does not currently provide comprehensive file-system sandbox security.
3. The runner combines standard Preview 1 imports with Starshine/MoonBit-specific host imports. A module importing arbitrary WASI Preview 2 component interfaces, `wasi:` package-style component imports, or unsupported host modules should fail at the import-module boundary rather than being treated as a Starshine Core-module validation result.
4. `_start` versus reactor initialization is host-runner behavior. It should not be confused with Starshine's Core `start` section validation, WAST `start` command authoring, JSPI Promise suspension, or ESM Integration module-loader behavior.
5. Release and validation docs should treat `node/internal/starshine.wasm-wasi.wasm`, `tests/node/dist/*-wasi.wasm`, and self-opt wasm artifacts as Preview 1 runner artifacts unless a future implementation explicitly adds Preview 2/component support.

## Follow-ups

- If Starshine adds a component/WASI Preview 2 path, design it through the Component Model boundary first: representation, decoder/parser policy, WIT/world handling, host adapter strategy, tests, and Node/package API shape.
- If Starshine keeps the runner but changes the Node host API, recheck current `node:wasi` docs because `node:wasi` is experimental and its security/runtime caveats can change.
- If a future release claims sandboxing, require runtime-specific security evidence; do not infer it from preopens alone.
