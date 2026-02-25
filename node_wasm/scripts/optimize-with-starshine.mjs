import { optimizeDebugWasm } from './lib/optimize.mjs';
import { repoRootFromScript } from './lib/paths.mjs';

const repoRoot = repoRootFromScript(import.meta.url);
const result = optimizeDebugWasm({ repoRoot });
console.log(`Wrote self-optimized wasm: ${result.outputPath} (${result.size} bytes)`);
