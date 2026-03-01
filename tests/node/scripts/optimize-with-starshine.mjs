import { execFileSync } from 'node:child_process';

import { optimizeDebugWasm } from './lib/optimize.mjs';
import { repoRootFromScript, resolveMoonBin } from './lib/paths.mjs';

const repoRoot = repoRootFromScript(import.meta.url);
const moonBin = resolveMoonBin();

execFileSync(
  moonBin,
  ['build', '--target', 'native', '--release', '--package', 'jtenner/starshine/cmd'],
  {
    cwd: repoRoot,
    stdio: 'inherit',
  },
);

const result = optimizeDebugWasm({ repoRoot });
console.log(`Wrote self-optimized wasm: ${result.outputPath} (${result.size} bytes)`);
