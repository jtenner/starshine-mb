import fs from 'node:fs';
import path from 'node:path';

import * as binary from '../binary.js';
import * as cmd from '../cmd.js';
import { SAMPLE_BINARY_MODULE_TEXT, expectOk, makeTempDir } from './_shared.mjs';

const tempDir = makeTempDir('starshine-node-example-fs-');
const inputPath = path.join(tempDir, 'input.wat');
const outputPath = path.join(tempDir, 'output.wasm');

fs.writeFileSync(inputPath, SAMPLE_BINARY_MODULE_TEXT);

const summary = expectOk(
  cmd.runCmd(['--out', outputPath, inputPath]),
  'cmd.runCmd',
);
const outputBytes = fs.readFileSync(outputPath);
expectOk(binary.decodeModule(outputBytes), 'binary.decodeModule');

console.log(
  `runCmd ok: wrote ${path.basename(outputPath)} (${outputBytes.length} bytes) for ${summary.inputFiles.length} input`,
);
