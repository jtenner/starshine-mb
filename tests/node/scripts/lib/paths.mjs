import path from 'node:path';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs';

export function repoRootFromScript(importMetaUrl) {
  const scriptPath = fileURLToPath(importMetaUrl);
  let current = path.dirname(scriptPath);
  while (true) {
    if (fs.existsSync(path.join(current, 'moon.mod.json'))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      throw new Error(`Could not locate repository root from ${scriptPath}`);
    }
    current = parent;
  }
}

export function wasmBuildArtifactPaths(repoRoot) {
  return {
    debug: path.join(repoRoot, '_build', 'wasm', 'debug', 'build', 'cmd', 'cmd.wasm'),
    release: path.join(repoRoot, '_build', 'wasm', 'release', 'build', 'cmd', 'cmd.wasm'),
  };
}

export function distArtifactPaths(repoRoot) {
  const distDir = path.join(repoRoot, 'node_wasm', 'dist');
  return {
    distDir,
    debug: path.join(distDir, 'starshine.debug.wasm'),
    release: path.join(distDir, 'starshine.release.wasm'),
    selfOptimized: path.join(distDir, 'starshine.self-optimized.wasm'),
    optimizeError: path.join(distDir, 'optimize.error.txt'),
    compareReport: path.join(distDir, 'compare.report.json'),
  };
}

export function nativeStarshineBinaryPaths(repoRoot) {
  return [
    path.join(repoRoot, '_build', 'native', 'release', 'build', 'cmd', 'cmd.exe'),
    path.join(repoRoot, '_build', 'native', 'debug', 'build', 'cmd', 'cmd.exe'),
  ];
}
