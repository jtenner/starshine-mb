import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const fixtures = fileURLToPath(new URL('./', import.meta.url));

test('native filesystem closes each owned stream on every recoverable I/O failure', () => {
  const source = process.env.STARSHINE_FS_SOURCE ?? path.join(root, 'src/internal/xfs');
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-native-lifetime-'));
  try {
    const pkg = path.join(scratch, 'fs');
    fs.mkdirSync(pkg);
    fs.writeFileSync(path.join(scratch, 'moon.mod'), 'name = "jtenner/resource-lifetime-tests"\nimport { "moonbitlang/x@0.5.1" }\n');
    for (const file of ['fs.mbt', 'fs_native.mbt', 'fs_native.c', 'moon.pkg']) {
      fs.copyFileSync(path.join(source, file), path.join(pkg, file));
    }
    // Compile the exact owning MoonBit code and C bridge. Only libc calls are
    // intercepted, and no test hooks or counters enter the production binary.
    fs.renameSync(path.join(pkg, 'fs_native.c'), path.join(pkg, 'fs_native.inc'));
    fs.copyFileSync(path.join(fixtures, 'native_faults.c'), path.join(pkg, 'fs_native.c'));
    fs.copyFileSync(path.join(fixtures, 'native_lifetime_wbtest.mbt'), path.join(pkg, 'native_lifetime_wbtest.mbt'));
    const result = spawnSync(process.env.MOON_BIN ?? 'moon', ['-C', scratch, 'test', '--target', 'native'], {
      encoding: 'utf8', timeout: 180_000, maxBuffer: 4 * 1024 * 1024,
    });
    assert.ifError(result.error);
    assert.equal(result.status, 0, `native lifetime tests\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
    assert.match(result.stdout, /Total tests: 12, passed: 12, failed: 0/);
    process.stdout.write(result.stdout);
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});

test('local and upstream native filesystem packages can be linked together', () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-native-coexist-'));
  try {
    const pkg = path.join(scratch, 'fs');
    fs.mkdirSync(pkg);
    fs.writeFileSync(path.join(scratch, 'moon.mod'), 'name = "jtenner/resource-lifetime-tests"\nimport { "moonbitlang/x@0.5.1" }\n');
    for (const file of ['fs.mbt', 'fs_native.mbt', 'fs_native.c', 'moon.pkg']) {
      fs.copyFileSync(path.join(root, 'src/internal/xfs', file), path.join(pkg, file));
    }
    fs.appendFileSync(path.join(pkg, 'moon.pkg'), '\nimport { "moonbitlang/x/fs" @upstream } for "wbtest"\n');
    fs.writeFileSync(path.join(pkg, 'coexist_wbtest.mbt'), `
///|
test "local and upstream filesystem packages coexist" {
  assert_true(path_exists("."))
  assert_true(@upstream.path_exists("."))
}
`);
    const result = spawnSync(process.env.MOON_BIN ?? 'moon', ['-C', scratch, 'test', '--target', 'native'], {
      encoding: 'utf8', timeout: 180_000, maxBuffer: 4 * 1024 * 1024,
    });
    assert.ifError(result.error);
    assert.equal(result.status, 0, `native coexistence test\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
    assert.match(result.stdout, /Total tests: 1, passed: 1, failed: 0/);
    process.stdout.write(result.stdout);
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});
