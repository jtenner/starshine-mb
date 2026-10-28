import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

// Observe the actual private owner without adding a production diagnostics API.
// Only Map is instrumented; both shipped host implementations run unchanged.
async function loadHost(file) {
  const source = fs.readFileSync(new URL(file, import.meta.url), 'utf8');
  const instrumented = `
    export const tables = [];
    class Map extends globalThis.Map {
      constructor(...args) { super(...args); tables.push(this); }
    }
    ${source}
    ${file.includes('runtime.js') ? 'export { createMoonbitFsHost };' : ''}
    //# sourceURL=${file}
  `;
  return import(`data:text/javascript;base64,${Buffer.from(instrumented).toString('base64')}`);
}

function readBytes(host, value) {
  const reader = host.begin_read_byte_array(value);
  const bytes = [];
  try {
    for (let byte; (byte = host.byte_array_read_byte(reader)) !== -1;) bytes.push(byte);
  } finally {
    host.finish_read_byte_array(reader);
  }
  return Uint8Array.from(bytes);
}

function readString(host, value) {
  const reader = host.begin_read_string(value);
  const chars = [];
  try {
    for (let char; (char = host.string_read_char(reader)) !== -1;) chars.push(char);
  } finally {
    host.finish_read_string(reader);
  }
  return String.fromCodePoint(...chars);
}

for (const file of ['../internal/wasi-runner.js', '../internal/runtime.js']) {
  const { createMoonbitFsHost, tables } = await loadHost(file);

  test(`${file}: repeated failed Starshine decodes release input readers`, async () => {
    const { decodeModule } = await import('../binary.js');
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-reader-'));
    try {
      const input = path.join(dir, 'invalid.wasm');
      fs.writeFileSync(input, Uint8Array.of(0, 97, 115, 109, 2, 0, 0, 0));
      const host = createMoonbitFsHost();
      const handles = tables.at(-1);
      const start = handles.size;
      const retained = [];
      // Keep the same host and owner for every completed read and decode.
      for (let i = 0; i < 32; i++) {
        assert.equal(host.read_file_to_bytes_new(input), 0);
        const decoded = decodeModule(readBytes(host, host.get_file_content()));
        assert.equal(decoded.ok, false);
        assert.equal(decoded.display, 'Decode(InvalidMagicHeader)');
        retained.push(handles.size);
      }
      assert.deepEqual(retained, Array(32).fill(start));
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });

  test(`${file}: successful and early-finished byte readers release only their own handles`, () => {
    const host = createMoonbitFsHost();
    const handles = tables.at(-1);
    const start = handles.size;
    const pending = host.begin_read_byte_array(Uint8Array.of(17, 23));
    for (const bytes of [new Uint8Array(), Uint8Array.of(0, 255, 42)]) {
      assert.deepEqual(readBytes(host, bytes), bytes);
      assert.equal(handles.size, start + 1);
      assert.equal(handles.has(pending), true);
    }
    const abandoned = host.begin_read_byte_array(Uint8Array.of(9, 10));
    host.finish_read_byte_array(abandoned);
    assert.throws(() => host.byte_array_read_byte(abandoned), /Invalid MoonBit host handle/);
    assert.equal(host.byte_array_read_byte(pending), 17);
    host.finish_read_byte_array(pending);
    assert.equal(handles.size, start);
  });

  test(`${file}: repeated I/O errors release strings and their readers`, () => {
    const host = createMoonbitFsHost();
    const handles = tables.at(-1);
    const start = handles.size;
    for (let i = 0; i < 32; i++) {
      assert.equal(host.read_file_to_bytes_new(import.meta.filename + '/missing'), -1);
      assert.match(readString(host, host.get_error_message()), /ENOTDIR|ENOENT/);
      assert.equal(handles.size, start);
    }
  });

  test(`${file}: array and string readers keep overlapping reads alive`, () => {
    const host = createMoonbitFsHost({ args: ['first', 'λ😀'] });
    const handles = tables.at(-1);
    const start = handles.size;
    const source = host.args_get();
    const first = host.begin_read_string_array(source);
    const second = host.begin_read_string_array(source);
    const child = host.string_array_read_string(first);
    const childReader = host.begin_read_string(child);
    host.finish_read_string_array(first);
    assert.equal(readString(host, host.string_array_read_string(second)), 'first');
    assert.equal(readString(host, host.string_array_read_string(second)), 'λ😀');
    assert.equal(readString(host, host.string_array_read_string(second)), 'ffi_end_of_/string_array');
    host.finish_read_string_array(second);
    assert.equal(host.string_read_char(childReader), 'f'.codePointAt(0));
    host.finish_read_string(childReader);
    assert.equal(handles.size, start);
  });

  test(`${file}: finishing a reader keeps builders and overlapping string readers alive`, () => {
    const host = createMoonbitFsHost({ cwd: 'λ😀' });
    const handles = tables.at(-1);
    const builder = host.begin_create_byte_array();
    host.byte_array_append_byte(builder, 42);
    assert.deepEqual(readBytes(host, builder), Uint8Array.of(42));
    assert.equal(handles.has(builder), true);
    assert.deepEqual(host.finish_create_byte_array(builder), Uint8Array.of(42));
    const source = host.current_dir();
    const first = host.begin_read_string(source);
    const second = host.begin_read_string(source);
    host.finish_read_string(first);
    assert.equal(host.string_read_char(second), 'λ'.codePointAt(0));
    host.finish_read_string(second);
    assert.equal(handles.size, 0);
    if (file.includes('runtime.js')) {
      assert.equal(readString(host, 'direct 😀'), 'direct 😀');
      const pending = host.begin_create_string();
      assert.equal(readString(host, pending), String(pending));
      assert.equal(handles.has(pending), true);
      assert.equal(host.finish_create_string(pending), '');
      assert.equal(handles.size, 0);
    }
  });
}
