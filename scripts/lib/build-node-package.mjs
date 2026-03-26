#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import { repoRootFromScript, resolveMoonBin, run } from './self-optimized-artifacts.mjs';

const repoRoot = repoRootFromScript(import.meta.url);

// Copy one generated artifact from build tree into the packaged path and return
// the copied size so callers can print size deltas.
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

// Build the CLI release artifact and sync it into node/internal. The wasm-gc
// adapter artifact is currently a checked-in boundary artifact while the old
// generated `src/node_api` path is no longer part of the active rebuild flow
// and the Node surface is rebuilt from the live CLI binary.
export function buildNodePackage({
  repoRoot: root = repoRoot,
  moonBin = resolveMoonBin(),
} = {}) {
  console.log('Building optimized WASI CLI...');
  run(moonBin, ['build', '--target', 'wasm', '--release', 'src/cmd'], root);

  const frozenWasmGcPath = path.join(root, 'node', 'internal', 'starshine.wasm-gc.wasm');
  if (!fs.existsSync(frozenWasmGcPath)) {
    throw new Error(
      `Missing checked-in node/internal/starshine.wasm-gc.wasm; rebuilding the wasm-gc adapter is disabled while the active Node flow no longer rebuilds the legacy src/node_api path.`,
    );
  }
  const wasmGcSize = fs.statSync(frozenWasmGcPath).size;
  const wasmWasiSize = copyArtifact(
    root,
    path.join('_build', 'wasm', 'release', 'build', 'cmd', 'cmd.wasm'),
    path.join('node', 'internal', 'starshine.wasm-wasi.wasm'),
  );

  console.log(`Kept node/internal/starshine.wasm-gc.wasm (${wasmGcSize} bytes)`);
  console.log(`Wrote node/internal/starshine.wasm-wasi.wasm (${wasmWasiSize} bytes)`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  buildNodePackage();
}
