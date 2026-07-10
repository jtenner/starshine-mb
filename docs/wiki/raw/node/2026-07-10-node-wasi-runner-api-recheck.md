# Node `node:wasi` Runner API Recheck (2026-07-10)

## Purpose

Refresh the durable evidence for Starshine's Node-hosted WASI Preview 1 runner after rechecking the current official Node API and the two local runner implementations. This note supersedes neither the 2026-06-05 Preview 1/0.2/0.3 boundary notes nor their proposal-status evidence; it adds the current Node API details that matter for the local runner's explicit import composition and its lack of thread support.

## Primary external source checked

1. Node.js `node:wasi` API documentation, checked 2026-07-10: <https://nodejs.org/api/wasi.html>
   - `node:wasi` remains Stability 1 / Experimental and Node continues to warn that it is not a secure sandbox for untrusted WebAssembly.
   - `new WASI({ version: "preview1", args, env, preopens, stdout, stderr })` remains the Preview 1 construction shape; `preview1` uses the `wasi_snapshot_preview1` import module.
   - The current API exposes `wasi.getImportObject()` as the structured WASI import-object accessor. It also retains `wasi.wasiImport` for Preview 1 compatibility.
   - `wasi.start(instance)` is the command-style `_start` path and `wasi.initialize(instance)` is the reactor-style path.
   - The API documents `wasi.finalizeBindings(instance[, options])`, which sets up host bindings without calling `start` / `initialize` and is useful when child threads instantiate WASI modules that share memory. It is a distinct lifecycle surface from ordinary command/reactor startup.

## Local Starshine sources checked

- `node/internal/wasi-runner.js`
  - Constructs `new WASI({ version: "preview1", args, env, preopens, stdout, stderr })`.
  - Builds its own composite import object: `wasi_snapshot_preview1: wasi.wasiImport` plus `spectest`, `__moonbit_fs_unstable`, `__moonbit_time_unstable`, and `console`.
  - Uses `WebAssembly.Module.imports(module)` only to reject unknown **module namespaces** before instantiation. Missing fields inside a known namespace remain normal `WebAssembly.instantiate(...)` linking failures.
  - Calls `wasi.start(instance)` for `_start`, otherwise `wasi.initialize(instance)`.
  - Has no shared-memory/thread detection and never calls `wasi.finalizeBindings(instance)`.
- `scripts/lib/moonbit-wasi-runner.mjs`
  - Mirrors the same Preview 1 constructor, manually composed import object, module-namespace allowlist, `_start`/reactor split, and absence of thread finalization.
- `node/test/smoke.test.mjs`
  - Proves one optimized WASI artifact starts with `--help`; it does not prove thread-capable WASI behavior, per-import-field diagnostics, secure sandboxing, Preview 2/0.2, Preview 3/0.3, WIT, components, Canonical ABI, JSPI, or Wasm ESM Integration.

## Durable conclusions

1. Starshine remains a **Node-hosted WASI Preview 1 Core-module runner**. The current Node API recheck does not widen it to component/WIT/WASI 0.2/0.3 support.
2. The explicit `wasiImport` composition is intentional local behavior, not proof that `getImportObject()` is unavailable. It lets Starshine merge WASI with its nonstandard MoonBit and test host namespaces, but both package and script runners must stay synchronized if this construction changes.
3. The current preflight allowlist is namespace-level only. Classify an unknown namespace as a deliberate Starshine host-boundary rejection; classify a missing member in an accepted namespace as an instantiation/linking failure unless a future runner adds field-level diagnostics.
4. `finalizeBindings` is a future thread-capability requirement, not a call that should be inserted into the current non-threaded runner without a threaded-WASI design and tests. Current startup smoke coverage proves neither thread lifecycle nor secure isolation.
5. Node's experimental/security caveat remains current. `preopens` do not justify a secure-sandbox claim for untrusted wasm.

## Follow-ups

- If the runner is refactored to use `wasi.getImportObject()`, preserve the composite local import object, explicit module-namespace policy, `_start`/reactor distinction, and package/script-runner parity; add a focused test before treating it as a behavior-preserving cleanup.
- If Starshine adds threads or imports that require thread-aware WASI bindings, first design shared-memory/worker lifecycle, `finalizeBindings` timing, host-error classification, package API, and Node tests. Keep that work separate from Core validator, WIT/component, JSPI, and ordinary Preview 1 command-runner claims.
- Recheck this note whenever Node changes its experimental WASI API or security model.
