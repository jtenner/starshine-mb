#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');
const nodeInternalDir = path.join(repoRoot, 'node', 'internal');
const moonBin = process.env.MOON_BIN || path.join(process.env.HOME ?? '', '.moon', 'bin', 'moon');

function run(command, args) {
  execFileSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
  });
}

function copyArtifact(fromRelativePath, toRelativePath) {
  const sourcePath = path.join(repoRoot, fromRelativePath);
  const targetPath = path.join(repoRoot, toRelativePath);
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`Missing build artifact: ${sourcePath}`);
  }
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.copyFileSync(sourcePath, targetPath);
  return fs.statSync(targetPath).size;
}

console.log('Generating Node package sources...');
run(process.execPath, [path.join(repoRoot, 'scripts', 'generate-node-package.mjs')]);

console.log('Building wasm-gc package adapter...');
run(moonBin, ['build', '--target', 'wasm-gc', '--release', '--package', 'jtenner/starshine/node_api']);

console.log('Building optimized WASI CLI...');
run(moonBin, ['build', '--target', 'wasm', '--release', '--package', 'jtenner/starshine/cmd']);

const wasmGcSize = copyArtifact(
  path.join('_build', 'wasm-gc', 'release', 'build', 'node_api', 'node_api.wasm'),
  path.join('node', 'internal', 'starshine.wasm-gc.wasm'),
);
const wasmWasiSize = copyArtifact(
  path.join('_build', 'wasm', 'release', 'build', 'cmd', 'cmd.wasm'),
  path.join('node', 'internal', 'starshine.wasm-wasi.wasm'),
);

console.log(`Wrote node/internal/starshine.wasm-gc.wasm (${wasmGcSize} bytes)`);
console.log(`Wrote node/internal/starshine.wasm-wasi.wasm (${wasmWasiSize} bytes)`);
