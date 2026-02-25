import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

import { copyWasmArtifacts } from './lib/artifacts.mjs';
import { optimizeDebugWasm } from './lib/optimize.mjs';
import { nativeStarshineBinaryPaths, repoRootFromScript } from './lib/paths.mjs';

const repoRoot = repoRootFromScript(import.meta.url);
const moonBin = process.env.MOON_BIN ?? '/home/jtenner/.moon/bin/moon';
const [nativeReleaseBinary] = nativeStarshineBinaryPaths(repoRoot);

function run(command, args) {
  execFileSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
  });
}

run(moonBin, ['build', '--target', 'wasm']);
run(moonBin, ['build', '--target', 'wasm', '--release']);

if (!fs.existsSync(nativeReleaseBinary)) {
  run(moonBin, ['build', '--target', 'native', '--release', '--package', 'jtenner/starshine/cmd']);
}

const copyResult = copyWasmArtifacts({ repoRoot });
console.log(`Copied debug wasm: ${copyResult.debug.path} (${copyResult.debug.size} bytes)`);
console.log(`Copied release wasm: ${copyResult.release.path} (${copyResult.release.size} bytes)`);

const optimizeResult = optimizeDebugWasm({
  repoRoot,
  starshinePath: nativeReleaseBinary,
  fallbackToDebugOnFailure: true,
});
console.log(`Wrote self-optimized wasm: ${optimizeResult.outputPath} (${optimizeResult.size} bytes)`);
if (optimizeResult.fallback) {
  console.warn('warning: optimizer failed; self-optimized artifact is a debug-copy fallback. See dist/optimize.error.txt');
}
