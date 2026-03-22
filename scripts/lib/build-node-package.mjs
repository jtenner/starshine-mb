#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import { repoRootFromScript, resolveMoonBin, run } from './self-optimized-artifacts.mjs';

const repoRoot = repoRootFromScript(import.meta.url);

function copyArtifact(root, fromRelativePath, toRelativePath) {
  const sourcePath = path.join(root, fromRelativePath);
  const targetPath = path.join(root, toRelativePath);
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`Missing build artifact: ${sourcePath}`);
  }
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.copyFileSync(sourcePath, targetPath);
  return fs.statSync(targetPath).size;
}

export function buildNodePackage({
  repoRoot: root = repoRoot,
  moonBin = resolveMoonBin(),
} = {}) {
  console.log('Building wasm-gc package adapter...');
  run(moonBin, ['build', '--target', 'wasm-gc', '--release', 'src/node_api'], root);

  console.log('Building optimized WASI CLI...');
  run(moonBin, ['build', '--target', 'wasm', '--release', 'src/cmd'], root);

  const wasmGcSize = copyArtifact(
    root,
    path.join('_build', 'wasm-gc', 'release', 'build', 'node_api', 'node_api.wasm'),
    path.join('node', 'internal', 'starshine.wasm-gc.wasm'),
  );
  const wasmWasiSize = copyArtifact(
    root,
    path.join('_build', 'wasm', 'release', 'build', 'cmd', 'cmd.wasm'),
    path.join('node', 'internal', 'starshine.wasm-wasi.wasm'),
  );

  console.log(`Wrote node/internal/starshine.wasm-gc.wasm (${wasmGcSize} bytes)`);
  console.log(`Wrote node/internal/starshine.wasm-wasi.wasm (${wasmWasiSize} bytes)`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  buildNodePackage();
}
