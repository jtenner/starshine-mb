import { copyWasmArtifacts } from './lib/artifacts.mjs';
import { repoRootFromScript } from './lib/paths.mjs';

const repoRoot = repoRootFromScript(import.meta.url);
const result = copyWasmArtifacts({ repoRoot });

console.log(`Copied debug wasm: ${result.debug.path} (${result.debug.size} bytes)`);
console.log(`Copied optimized wasm: ${result.optimized.path} (${result.optimized.size} bytes)`);
