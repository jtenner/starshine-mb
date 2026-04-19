import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import * as cmd from '../cmd.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const nodeRoot = path.join(__dirname, '..');
const repoRoot = path.join(nodeRoot, '..');

function readText(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

test('cmd runtime exports, d.ts surface, and MoonBit source all agree on renamed fuzz harness symbols', () => {
  const mbti = readText('src/cmd/pkg.generated.mbti');
  const dts = readText('node/cmd.d.ts');

  for (const symbol of ['CmdFuzzStats', 'runCmdFuzzHarness', 'runCmdFuzzHarnessProfile']) {
    assert.equal(symbol in cmd, true, `missing runtime export ${symbol}`);
    assert.match(dts, new RegExp(`\\b${symbol}\\b`), `missing declaration for ${symbol}`);
  }

  assert.match(mbti, /pub struct CmdFuzzStats/);
  assert.match(mbti, /pub fn run_cmd_fuzz_harness\(/);
  assert.match(mbti, /pub fn run_cmd_fuzz_harness_profile\(/);
});

test('cmd compatibility aliases remain present and point at the parity surface', () => {
  assert.equal(cmd.WasmSmithFuzzStats, cmd.CmdFuzzStats);
  assert.equal(cmd.runWasmSmithFuzzHarnessProfile, cmd.runCmdFuzzHarnessProfile);

  const legacyFailure = cmd.runWasmSmithFuzzHarness(-1, 0x5eedn, [], null, 0, null);
  assert.equal(legacyFailure.ok, false);
  assert.match(legacyFailure.error, /validTarget must be non-negative/);
});

test('cmd parity constructors expose the MoonBit field additions in runtime and declarations', () => {
  const dts = readText('node/cmd.d.ts');

  const io = cmd.CmdIO.new(
    () => null,
    () => false,
    () => ({ ok: false, error: 'missing' }),
    () => ({ ok: false, error: cmd.CmdEncodeError.adapter('encode disabled') }),
    () => ({ ok: false, error: 'print disabled' }),
    () => ({ ok: true, value: undefined }),
    () => ({ ok: true, value: undefined }),
    () => ({ ok: true, value: undefined }),
    () => [],
    () => ({ ok: false, error: 'lower disabled' }),
  );
  assert.equal(typeof io.printTextModule, 'function');
  assert.match(dts, /readonly printTextModule:/);

  const summary = cmd.CmdRunSummary.new([], [], [], 0, 0, false, 5, true, false, 1024n);
  assert.equal(summary.closedWorld, true);
  assert.match(dts, /readonly closedWorld: boolean;/);
});

test('cmd profile helper uses the parity name and returns a parity-shaped error', () => {
  const result = cmd.runCmdFuzzHarnessProfile('not-a-profile', 0x5eedn);
  assert.equal(result.ok, false);
  assert.match(result.error, /unknown cmd-harness fuzz profile/);
});
