import fs from 'node:fs';
import { BulkCliExit, createBulkCliHost } from './bulk-cli-host.js';

export async function runBulkCli({ wasmPath, args = [], ...options }) {
  let instance;
  const host = createBulkCliHost({ ...options, args, memory: () => instance.exports.memory });
  const module = await WebAssembly.compile(fs.readFileSync(wasmPath));
  // MoonBit retains closures for optional CmdIO defaults in module globals.
  // Their legacy imports are unreachable through this entry point. A call is
  // an integration error, so it must fail instead of using byte-wise transfer.
  host.imports.__moonbit_fs_unstable = Object.fromEntries(
    WebAssembly.Module.imports(module)
      .filter(item => item.module === '__moonbit_fs_unstable')
      .map(item => [item.name, () => { throw new Error(`Unexpected legacy filesystem call: ${item.name}`); }]),
  );
  instance = await WebAssembly.instantiate(module, host.imports);
  let exitCode = 0;
  try { instance.exports._start(); } catch (error) {
    if (!(error instanceof BulkCliExit)) throw error;
    exitCode = error.code;
  }
  return { exitCode, hostCalls: host.calls };
}
