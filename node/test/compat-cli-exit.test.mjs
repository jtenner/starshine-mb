import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';

// This separate host lane needs the compatibility GC artifact and Moonrun.
test('compatibility GC command returns nonzero for a missing input', { skip: !process.env.STARSHINE_COMPAT_WASM }, () => {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-gc-exit-'));
  try {
    const artifact = path.resolve(process.env.STARSHINE_COMPAT_WASM);
    // Moonrun's compatibility filesystem opens /dev/stdout. Node's socket
    // stdio cannot be reopened that way; real files preserve the host contract.
    function invoke(args) {
      const stdout = path.join(cwd, 'stdout');
      const stderr = path.join(cwd, 'stderr');
      const out = fs.openSync(stdout, 'w');
      const err = fs.openSync(stderr, 'w');
      try {
        const result = spawnSync('moonrun', [artifact, '--', ...args], { cwd, stdio: ['ignore', out, err] });
        assert.ifError(result.error);
        return { status: result.status, stdout: fs.readFileSync(stdout, 'utf8'), stderr: fs.readFileSync(stderr, 'utf8') };
      } finally { fs.closeSync(out); fs.closeSync(err); }
    }
    const failed = invoke(['missing.wasm', '--out', 'result.wasm']);
    assert.notEqual(failed.status, 0, failed.stderr);
    assert.equal(fs.existsSync(path.join(cwd, 'result.wasm')), false);
    const success = invoke(['--version']);
    assert.equal(success.status, 0, success.stderr);
    assert.match(success.stdout, /^v\d+\.\d+\.\d+/);
  } finally { fs.rmSync(cwd, { recursive: true, force: true }); }
});
