# Correction: Node WASI `finalizeBindings` And Starshine Startup (2026-07-10)

## Scope

This companion correction supersedes only the `finalizeBindings` conclusion in [`2026-07-10-node-wasi-runner-api-recheck.md`](2026-07-10-node-wasi-runner-api-recheck.md). The earlier note correctly records that neither local JavaScript runner directly invokes `wasi.finalizeBindings(...)`; it was incomplete to imply that normal Starshine Preview 1 startup therefore performs no binding finalization.

## Primary source rechecked

Node.js v26.5.0 `node:wasi` API documentation, rechecked 2026-07-10: <https://nodejs.org/api/wasi.html>

- `wasi.finalizeBindings(instance[, options])` binds a WASI instance without calling `initialize()` or `start()` and is useful for child-thread instances that share memory.
- `wasi.start(instance)` and `wasi.initialize(instance)` call `finalizeBindings()` internally.

## Correct local interpretation

- `node/internal/wasi-runner.js` and `scripts/lib/moonbit-wasi-runner.mjs` do **not explicitly call** `finalizeBindings(...)`.
- Their ordinary paths call `wasi.start(instance)` for `_start` or `wasi.initialize(instance)` for a reactor, so Node performs normal binding finalization internally for those non-threaded startup paths.
- The runners still have no shared-memory/thread detection, child-worker lifecycle, direct child-thread `finalizeBindings(...)` policy, or tests for threaded WASI modules. A normal `--help` startup smoke therefore proves ordinary Preview 1 startup only, not child-thread support.

## Durable correction

Do not describe current Starshine as omitting all WASI binding finalization. Describe it as using Node's normal command/reactor startup path, which finalizes bindings internally, while lacking an explicit child-thread binding design. This correction does not widen Starshine to WASI threads, Preview 2 / WASI 0.2, Preview 3 / WASI 0.3, components/WIT, JSPI, or secure sandboxing.
