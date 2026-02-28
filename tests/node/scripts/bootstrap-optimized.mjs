import process from 'node:process';

import { runWasmStart } from './lib/moonbit-wasi-runner.mjs';
import { distArtifactPaths, repoRootFromScript } from './lib/paths.mjs';

function parseArgs(argv, defaultWasmPath) {
  let wasmPath = defaultWasmPath;
  const passthrough = [];
  let i = 0;
  while (i < argv.length) {
    const token = argv[i];
    if (token === '--wasm') {
      if (i + 1 >= argv.length) {
        throw new Error('Missing value for --wasm');
      }
      wasmPath = argv[i + 1];
      i += 2;
      continue;
    }
    passthrough.push(token);
    i += 1;
  }
  if (passthrough.length === 0) {
    passthrough.push('--help');
  }
  return { wasmPath, passthrough };
}

const repoRoot = repoRootFromScript(import.meta.url);
const dist = distArtifactPaths(repoRoot);
const { wasmPath, passthrough } = parseArgs(process.argv.slice(2), dist.selfOptimized);
const exitCode = await runWasmStart({
  wasmPath,
  args: passthrough,
  cwd: repoRoot,
});
process.exitCode = exitCode;
