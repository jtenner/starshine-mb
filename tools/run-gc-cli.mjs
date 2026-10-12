#!/usr/bin/env node
import process from 'node:process';
import { runBulkCli } from '../node/internal/bulk-cli-runner.js';

const [wasmPath, ...args] = process.argv.slice(2);
if (!wasmPath) {
  console.error('Usage: run-gc-cli.mjs <cmd_gc.wasm> [Starshine arguments]');
  process.exitCode = 2;
} else {
  try {
    const { exitCode } = await runBulkCli({ wasmPath, args });
    process.exitCode = exitCode;
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
