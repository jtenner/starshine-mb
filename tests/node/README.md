# Node/WASI Tests

This directory contains the Node-based WASI harness for Starshine's `wasm` target.

## What it does

- Builds both `wasm` profiles from MoonBit.
- Stages the artifacts in `tests/node/dist` as:
  - `starshine-debug-wasi.wasm`
  - `starshine-optimized-wasi.wasm`
  - `starshine-self-optimized-wasi.wasm`
- Builds the native Starshine CLI and runs `--optimize` against the debug wasm artifact to produce the self-optimized artifact.
- Compares `starshine-optimized-wasi.wasm` and `starshine-self-optimized-wasi.wasm`.
- Logs per-file size and hash stats to the console and writes a JSON report to `tests/node/dist/compare.report.json`.

## Run from the repository root

Run the full Node test flow:

```bash
npm --prefix tests/node test
```

Run just the Node unit tests:

```bash
npm --prefix tests/node run test:unit
```

Run just the artifact build + comparison flow:

```bash
npm --prefix tests/node run build:all
```

Run just the self-optimization step:

```bash
npm --prefix tests/node run optimize:wasm
```

`optimize:wasm` rebuilds the native release CLI before invoking `--optimize` so pass changes do not accidentally reuse a stale optimizer binary.

To surface verbose optimizer tracing, including `DeadArgumentElimination` hotspot output, set:

```bash
STARSHINE_TRACE_OPTIMIZE_VERBOSE=1 npm --prefix tests/node run optimize:wasm
```

Run the wasm spec runner manually:

```bash
npm --prefix tests/node run test:spec:wasm -- --limit 5
```

Bootstrap the staged self-optimized wasm with the Node WASI host:

```bash
npm --prefix tests/node run bootstrap:optimized -- --help
```

## Notes

- `build:all` always builds:
  - debug wasm: `_build/wasm/debug/build/cmd/cmd.wasm`
  - optimized wasm: `_build/wasm/release/build/cmd/cmd.wasm`
  - native optimizer: `_build/native/release/build/cmd/cmd.exe`
- If `starshine --optimize` fails, `build:all` records the failure in `tests/node/dist/optimize.error.txt` and falls back to copying the debug wasm to `starshine-self-optimized-wasi.wasm` so the comparison step still runs.
- Override the MoonBit binary by setting `MOON_BIN` before invoking the scripts.
