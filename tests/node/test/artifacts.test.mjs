import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';

import { copyWasmArtifacts } from '../scripts/lib/artifacts.mjs';

function withTempDir(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-node-wasm-artifacts-'));
  try {
    fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

function writeFile(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

test('copyWasmArtifacts copies debug and release artifacts to dist with expected names', () => {
  withTempDir((repoRoot) => {
    const debugSource = path.join(repoRoot, '_build', 'wasm', 'debug', 'build', 'cmd', 'cmd.wasm');
    const releaseSource = path.join(repoRoot, '_build', 'wasm', 'release', 'build', 'cmd', 'cmd.wasm');
    writeFile(debugSource, Buffer.from([0, 97, 115, 109]));
    writeFile(releaseSource, Buffer.from([0, 97, 115, 109, 1]));

    const result = copyWasmArtifacts({ repoRoot });

    assert.equal(result.debug.path, path.join(repoRoot, 'node_wasm', 'dist', 'starshine.debug.wasm'));
    assert.equal(result.release.path, path.join(repoRoot, 'node_wasm', 'dist', 'starshine.release.wasm'));
    assert.deepEqual(fs.readFileSync(result.debug.path), Buffer.from([0, 97, 115, 109]));
    assert.deepEqual(fs.readFileSync(result.release.path), Buffer.from([0, 97, 115, 109, 1]));
  });
});

test('copyWasmArtifacts throws when debug artifact is missing', () => {
  withTempDir((repoRoot) => {
    const releaseSource = path.join(repoRoot, '_build', 'wasm', 'release', 'build', 'cmd', 'cmd.wasm');
    writeFile(releaseSource, Buffer.from([0, 97, 115, 109]));

    assert.throws(
      () => copyWasmArtifacts({ repoRoot }),
      /Missing wasm build artifact/,
    );
  });
});
