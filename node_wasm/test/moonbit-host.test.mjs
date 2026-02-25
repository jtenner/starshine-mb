import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createMoonbitFsHost } from '../scripts/lib/moonbit-wasi-runner.mjs';

function readExternString(host, stringHandle) {
  const readerHandle = host.begin_read_string(stringHandle);
  const chars = [];
  while (true) {
    const codepoint = host.string_read_char(readerHandle);
    if (codepoint === -1) break;
    chars.push(String.fromCodePoint(codepoint));
  }
  host.finish_read_string(readerHandle);
  return chars.join('');
}

function readExternStringArray(host, arrayHandle) {
  const readerHandle = host.begin_read_string_array(arrayHandle);
  const out = [];
  while (true) {
    const value = readExternString(host, host.string_array_read_string(readerHandle));
    if (value === 'ffi_end_of_/string_array') {
      break;
    }
    out.push(value);
  }
  host.finish_read_string_array(readerHandle);
  return out;
}

test('createMoonbitFsHost exposes args_get as a readable extern string array', () => {
  const host = createMoonbitFsHost({
    args: ['--help', 'tests/spec/address.wast'],
    cwd: '/tmp/demo',
  });

  const args = readExternStringArray(host, host.args_get());
  assert.deepEqual(args, ['--help', 'tests/spec/address.wast']);
});

test('createMoonbitFsHost exposes current_dir as extern string', () => {
  const host = createMoonbitFsHost({
    args: [],
    cwd: '/workspace/starshine',
  });

  const cwd = readExternString(host, host.current_dir());
  assert.equal(cwd, '/workspace/starshine');
});
