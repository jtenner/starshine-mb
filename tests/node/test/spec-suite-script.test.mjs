import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';

import { collectSpecFiles, parseCliArgs } from '../scripts/run-wasm-spec-suite.mjs';

function withTempDir(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-node-wasm-spec-suite-'));
  try {
    fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

function writeFile(filePath) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, '(module)');
}

test('collectSpecFiles returns sorted *.wast files recursively', () => {
  withTempDir((dir) => {
    const specRoot = path.join(dir, 'tests', 'spec');
    writeFile(path.join(specRoot, 'b.wast'));
    writeFile(path.join(specRoot, 'a.wast'));
    writeFile(path.join(specRoot, 'nested', 'c.wast'));
    writeFile(path.join(specRoot, 'ignore.txt'));

    const files = collectSpecFiles(specRoot);
    assert.deepEqual(files, [
      path.join(specRoot, 'a.wast'),
      path.join(specRoot, 'b.wast'),
      path.join(specRoot, 'nested', 'c.wast'),
    ]);
  });
});

test('parseCliArgs parses --limit, --wasm, and --file overrides', () => {
  const parsed = parseCliArgs([
    '--limit',
    '5',
    '--wasm',
    'tests/node/dist/starshine-optimized-wasi.wasm',
    '--file',
    'tests/spec/a.wast',
    '--file',
    'tests/spec/b.wast',
  ]);
  assert.equal(parsed.limit, 5);
  assert.equal(parsed.wasmPath, 'tests/node/dist/starshine-optimized-wasi.wasm');
  assert.deepEqual(parsed.onlyFiles, ['tests/spec/a.wast', 'tests/spec/b.wast']);
});
