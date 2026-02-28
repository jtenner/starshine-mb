import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const packageRoot = path.join(__dirname, '..');
const examplesDir = path.join(packageRoot, 'examples');
const exampleFiles = fs.readdirSync(examplesDir)
  .filter((entry) => entry.endsWith('.mjs') && !entry.startsWith('_'))
  .sort();

test('published examples execute successfully', async (t) => {
  assert(exampleFiles.length >= 10, `expected at least 10 examples, found ${exampleFiles.length}`);

  for (const exampleFile of exampleFiles) {
    await t.test(exampleFile, async () => {
      const examplePath = path.join(examplesDir, exampleFile);
      const captured = [];
      const originalConsoleLog = console.log;

      try {
        console.log = (...args) => {
          captured.push(args.map((arg) => String(arg)).join(' '));
        };
        await import(`${pathToFileURL(examplePath).href}?example=${encodeURIComponent(exampleFile)}`);
      } finally {
        console.log = originalConsoleLog;
      }

      assert.notEqual(captured.join('\n').trim(), '', `example ${exampleFile} produced no console output`);
    });
  }
});
