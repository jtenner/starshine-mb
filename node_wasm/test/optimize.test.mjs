import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';

import { optimizeDebugWasm } from '../scripts/lib/optimize.mjs';

function withTempDir(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-node-wasm-optimize-'));
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

function writeExecutable(filePath, content) {
  writeFile(filePath, content);
  fs.chmodSync(filePath, 0o755);
}

test('optimizeDebugWasm writes starshine.self-optimized.wasm from debug input', () => {
  withTempDir((repoRoot) => {
    const distDir = path.join(repoRoot, 'node_wasm', 'dist');
    const debugPath = path.join(distDir, 'starshine.debug.wasm');
    writeFile(debugPath, Buffer.from([0, 97, 115, 109, 7]));

    const fakeStarshine = path.join(repoRoot, 'fake-starshine.sh');
    writeExecutable(
      fakeStarshine,
      [
        '#!/usr/bin/env bash',
        'set -eu',
        'cp "$4" "$3"',
      ].join('\n'),
    );

    const result = optimizeDebugWasm({
      repoRoot,
      starshinePath: fakeStarshine,
    });

    assert.equal(result.outputPath, path.join(distDir, 'starshine.self-optimized.wasm'));
    assert.deepEqual(fs.readFileSync(result.outputPath), fs.readFileSync(debugPath));
  });
});

test('optimizeDebugWasm writes optimize.error.txt and throws on non-zero optimizer status', () => {
  withTempDir((repoRoot) => {
    const distDir = path.join(repoRoot, 'node_wasm', 'dist');
    const debugPath = path.join(distDir, 'starshine.debug.wasm');
    writeFile(debugPath, Buffer.from([0, 97, 115, 109, 9]));

    const fakeStarshine = path.join(repoRoot, 'fake-starshine.sh');
    writeExecutable(
      fakeStarshine,
      [
        '#!/usr/bin/env bash',
        'set -eu',
        'echo "intentional failure" >&2',
        'exit 2',
      ].join('\n'),
    );

    assert.throws(
      () =>
        optimizeDebugWasm({
          repoRoot,
          starshinePath: fakeStarshine,
        }),
      /status=2/,
    );

    const errorPath = path.join(distDir, 'optimize.error.txt');
    assert.equal(fs.existsSync(errorPath), true);
    assert.match(fs.readFileSync(errorPath, 'utf8'), /status=2/);
    assert.match(fs.readFileSync(errorPath, 'utf8'), /intentional failure/);
  });
});

test('optimizeDebugWasm can fall back to copying debug wasm when optimizer fails', () => {
  withTempDir((repoRoot) => {
    const distDir = path.join(repoRoot, 'node_wasm', 'dist');
    const debugPath = path.join(distDir, 'starshine.debug.wasm');
    writeFile(debugPath, Buffer.from([0, 97, 115, 109, 11]));

    const fakeStarshine = path.join(repoRoot, 'fake-starshine.sh');
    writeExecutable(
      fakeStarshine,
      [
        '#!/usr/bin/env bash',
        'set -eu',
        'exit 9',
      ].join('\n'),
    );

    const result = optimizeDebugWasm({
      repoRoot,
      starshinePath: fakeStarshine,
      fallbackToDebugOnFailure: true,
    });

    assert.equal(result.fallback, true);
    assert.deepEqual(
      fs.readFileSync(path.join(distDir, 'starshine.self-optimized.wasm')),
      fs.readFileSync(debugPath),
    );
    assert.match(fs.readFileSync(path.join(distDir, 'optimize.error.txt'), 'utf8'), /status=9/);
  });
});
