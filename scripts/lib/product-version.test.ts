import { expect, test } from 'bun:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { readProductVersion, generateProductVersion } from './generate-product-version.mjs';

function fixture(action: (root: string) => void) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-version-'));
  fs.mkdirSync(path.join(root, 'node'));
  fs.mkdirSync(path.join(root, 'ffi'));
  fs.writeFileSync(path.join(root, 'moon.mod'), 'name = "test/starshine"\nversion = "0.1.2-beta.0"\n');
  fs.writeFileSync(path.join(root, 'node/package.json'), JSON.stringify({ version: '0.1.2-beta.0' }));
  fs.writeFileSync(path.join(root, 'ffi/moon.mod'), 'name = "test/ffi"\nversion = "0.1.1"\nimport { "jtenner/starshine@0.1.1", }\n');
  try { action(root); } finally { fs.rmSync(root, { recursive: true, force: true }); }
}

test('product version derives CLI text from synchronized candidate metadata', () => fixture(root => {
  expect(readProductVersion(root)).toBe('0.1.2-beta.0');
  generateProductVersion({ root });
  const generated = path.join(root, 'src/cmd/version.generated.mbt');
  expect(fs.readFileSync(generated, 'utf8')).toContain('"v0.1.2-beta.0"');
  expect(fs.readFileSync(path.join(root, 'ffi/moon.mod'), 'utf8')).toContain('"jtenner/starshine@0.1.2-beta.0"');
  expect(fs.readFileSync(path.join(root, 'ffi/moon.mod'), 'utf8')).toContain('version = "0.1.1"');
  expect(() => generateProductVersion({ root, check: true })).not.toThrow();
  fs.writeFileSync(path.join(root, 'ffi/moon.mod'), 'import { "jtenner/starshine@0.1.1", }\n');
  expect(() => generateProductVersion({ root, check: true })).toThrow('stale');
  generateProductVersion({ root });
  fs.writeFileSync(generated, 'const CMD_VERSION : String = "v0.1.0"\n');
  expect(() => generateProductVersion({ root, check: true })).toThrow('stale');
}));

test('product version rejects missing, ambiguous, malformed, and mismatched metadata', () => fixture(root => {
  fs.writeFileSync(path.join(root, 'node/package.json'), JSON.stringify({ version: '0.1.1' }));
  expect(() => readProductVersion(root)).toThrow('mismatch');
  fs.writeFileSync(path.join(root, 'node/package.json'), JSON.stringify({ version: '0.1.2-beta.0' }));
  for (const text of [
    '',
    'version = "0.1.2-beta.0"\nversion = "0.1.2-beta.0"\n',
    'version = "0.1.2-beta.0"\nversion = "0.1.1" // duplicate\n',
    'version = "0.1.2-beta.0"\nversion =123\n',
    'version =123\n',
    'version = "01.1.2"\n',
    'version = "0.1.2-beta.00"\n',
    'version = "9007199254740992.1.2"\n',
  ]) {
    fs.writeFileSync(path.join(root, 'moon.mod'), text);
    expect(() => readProductVersion(root)).toThrow();
  }
}));
