# starshine node_wasm scaffold

This package is a local scaffold for shipping and consuming Starshine's `wasm` target artifact in Node.

## Goals implemented

- Builds both wasm profiles (`debug` + `release`) from MoonBit.
- Copies artifacts to `dist/starshine.debug.wasm` and `dist/starshine.release.wasm`.
- Produces `dist/starshine.self-optimized.wasm` by running native Starshine (`--optimize`) over the debug wasm artifact.
- Records optimizer failures in `dist/optimize.error.txt` and falls back to copying debug wasm to `self-optimized` during `build:all` so downstream scripts can still run.
- Writes a comparison report to `dist/compare.report.json`.
- Includes a Node/Bun bootstrap script that runs `_start` with WASI + MoonBit host shims.

## Commands

From the repository root:

```bash
cd node_wasm
npm run build:all
```

Individual steps:

```bash
npm run build:wasm:debug
npm run build:wasm:release
npm run copy:wasm
npm run optimize:wasm
npm run compare
npm run bootstrap:optimized -- --help
npm run test:spec:wasm -- --limit 5
```

## Optimizer binary note

`build:wasm:artifacts` and `optimize:wasm` use `_build/native/release/build/cmd/cmd.exe`.
If it is missing, the build script compiles it automatically via:

```bash
/home/jtenner/.moon/bin/moon build --target native --release --package jtenner/starshine/cmd
```
