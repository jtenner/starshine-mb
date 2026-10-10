#!/usr/bin/env node

import process from 'node:process';

import { runWasmStart } from '../internal/wasi-runner.js';

const exitCode = await runWasmStart({ wasmPath: new URL('../internal/starshine.wasm-wasi.wasm', import.meta.url), args: ['starshine', ...process.argv.slice(2)] });
if (typeof exitCode === 'number' && exitCode !== 0) {
  process.exitCode = exitCode;
}
