import fs from 'node:fs';

import { distArtifactPaths, wasmBuildArtifactPaths } from './paths.mjs';

function assertExists(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing wasm build artifact: ${filePath}`);
  }
}

export function copyWasmArtifacts({ repoRoot }) {
  const source = wasmBuildArtifactPaths(repoRoot);
  const target = distArtifactPaths(repoRoot);

  assertExists(source.debug);
  assertExists(source.release);

  fs.mkdirSync(target.distDir, { recursive: true });
  fs.copyFileSync(source.debug, target.debug);
  fs.copyFileSync(source.release, target.release);

  return {
    debug: {
      path: target.debug,
      size: fs.statSync(target.debug).size,
    },
    release: {
      path: target.release,
      size: fs.statSync(target.release).size,
    },
  };
}
