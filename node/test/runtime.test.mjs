import assert from 'node:assert/strict';
import test from 'node:test';

import { instantiateWasmGcBytes } from '../internal/runtime.js';

test('runtime instantiates a caller-supplied WasmGC byte buffer', async () => {
  const exports = await instantiateWasmGcBytes(
    Uint8Array.from([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]),
  );
  assert.deepEqual(Object.keys(exports), []);
});
