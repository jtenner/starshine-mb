import process from 'node:process';
import { pathToFileURL } from 'node:url';

import {
  copyWasmArtifacts,
  optimizeDebugWasm,
  repoRootFromScript,
  resolveMoonBin,
  run,
} from './self-optimized-artifacts.mjs';

// Only recognized option is optional fallback behavior for optimizer failures.
function parseCliArgs(argv) {
  let fallbackDebugOnFailure = false;
  let i = 0;
  while (i < argv.length) {
    const token = argv[i];
    if (token === '--fallback-debug-on-failure') {
      fallbackDebugOnFailure = true;
      i += 1;
      continue;
    }
    throw new Error(`Unknown option: ${token}`);
  }
  return { fallbackDebugOnFailure };
}

// End-to-end self-optimization flow:
// build wasm debug/release + native optimizer, copy artifacts, then re-run optimizer
// over debug wasm to produce self-optimized output (or fallback copy when enabled).
export async function buildSelfOptimized({
  repoRoot,
  moonBin = resolveMoonBin(),
  fallbackDebugOnFailure = false,
} = {}) {
  console.log('Building debug wasm target...');
  run(moonBin, ['build', '--target', 'wasm'], repoRoot);

  console.log('Building optimized wasm target...');
  run(moonBin, ['build', '--target', 'wasm', '--release'], repoRoot);

  console.log('Building native optimizer target...');
  run(moonBin, ['build', '--target', 'native', '--release', '--package', 'jtenner/starshine/cmd'], repoRoot);

  const copyResult = copyWasmArtifacts({ repoRoot });
  console.log(`Copied debug wasm: ${copyResult.debug.path} (${copyResult.debug.size} bytes)`);
  console.log(`Copied optimized wasm: ${copyResult.optimized.path} (${copyResult.optimized.size} bytes)`);

  const optimizeResult = optimizeDebugWasm({
    repoRoot,
    fallbackToDebugOnFailure: fallbackDebugOnFailure,
  });
  console.log(`Wrote self-optimized wasm: ${optimizeResult.outputPath} (${optimizeResult.size} bytes)`);
  if (optimizeResult.fallback) {
    console.warn(`warning: optimizer failed; debug wasm was copied as fallback. See ${optimizeResult.errorPath}`);
  }
}

async function main() {
  const repoRoot = repoRootFromScript(import.meta.url);
  const options = parseCliArgs(process.argv.slice(2));
  await buildSelfOptimized({
    repoRoot,
    fallbackDebugOnFailure: options.fallbackDebugOnFailure,
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
