import { execFileSync } from 'node:child_process';

import { copyWasmArtifacts } from './lib/artifacts.mjs';
import { optimizeDebugWasm } from './lib/optimize.mjs';
import { nativeStarshineBinaryPaths, repoRootFromScript, resolveMoonBin } from './lib/paths.mjs';

const repoRoot = repoRootFromScript(import.meta.url);
const moonBin = resolveMoonBin();
const [nativeReleaseBinary] = nativeStarshineBinaryPaths(repoRoot);

function run(command, args) {
  execFileSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
  });
}

console.log('Building debug wasm target...');
run(moonBin, ['build', '--target', 'wasm']);
console.log('Building optimized wasm target...');
run(moonBin, ['build', '--target', 'wasm', '--release']);
console.log('Building native optimizer target...');
run(moonBin, ['build', '--target', 'native', '--release', '--package', 'jtenner/starshine/cmd']);

const copyResult = copyWasmArtifacts({ repoRoot });
console.log(`Copied debug wasm: ${copyResult.debug.path} (${copyResult.debug.size} bytes)`);
console.log(`Copied optimized wasm: ${copyResult.optimized.path} (${copyResult.optimized.size} bytes)`);

const optimizeResult = optimizeDebugWasm({
  repoRoot,
  starshinePath: nativeReleaseBinary,
  fallbackToDebugOnFailure: true,
});
console.log(`Wrote self-optimized wasm: ${optimizeResult.outputPath} (${optimizeResult.size} bytes)`);
if (optimizeResult.fallback) {
  console.warn(`warning: optimizer failed; self-optimized artifact is a debug-copy fallback. See ${optimizeResult.errorPath}`);
}
