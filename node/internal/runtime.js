import fs from 'node:fs';
import fsPromises from 'node:fs/promises';
import process from 'node:process';

const ARRAY_SENTINEL = 'ffi_end_of_/string_array';

function toCodePoints(value) {
  const out = [];
  for (const char of value) {
    out.push(char.codePointAt(0));
  }
  return out;
}

function createMoonbitFsHost({ cwd = process.cwd(), args = [] } = {}) {
  let nextHandle = 1;
  const handles = new Map();
  const errors = new Map();

  function alloc(data) {
    const handle = nextHandle;
    nextHandle += 1;
    handles.set(handle, data);
    return handle;
  }

  function get(handle, expectedType) {
    const data = handles.get(handle);
    if (!data || data.type !== expectedType) {
      throw new Error(`Invalid MoonBit host handle ${handle} (expected ${expectedType})`);
    }
    return data;
  }

  function allocError(error) {
    const handle = nextHandle;
    nextHandle += 1;
    errors.set(handle, String(error));
    return handle;
  }

  function allocExternString(value) {
    return alloc({ type: 'extern-string', value });
  }

  function readString(value) {
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number' && handles.has(value)) {
      const handleData = handles.get(value);
      if (handleData?.type === 'extern-string') {
        return handleData.value;
      }
    }
    return String(value);
  }

  function readBytes(value) {
    if (value instanceof Uint8Array) {
      return value;
    }
    if (typeof value === 'number' && handles.has(value)) {
      const handleData = handles.get(value);
      if (handleData?.type === 'byte-array') {
        return Uint8Array.from(handleData.values);
      }
    }
    return new Uint8Array();
  }

  function collectCandidates(rootDir) {
    const out = [];

    function walk(currentRelative) {
      const currentAbsolute = currentRelative === '.'
        ? rootDir
        : `${rootDir}/${currentRelative}`;
      const entries = fs.readdirSync(currentAbsolute, { withFileTypes: true });
      for (const entry of entries) {
        if (entry.name === '.' || entry.name === '..') {
          continue;
        }
        const nextRelative = currentRelative === '.'
          ? entry.name
          : `${currentRelative}/${entry.name}`;
        const nextAbsolute = `${currentAbsolute}/${entry.name}`;
        if (entry.isDirectory()) {
          walk(nextRelative);
        } else if (entry.isFile()) {
          out.push(nextRelative);
        } else {
          try {
            const stat = fs.statSync(nextAbsolute);
            if (stat.isDirectory()) {
              walk(nextRelative);
            } else if (stat.isFile()) {
              out.push(nextRelative);
            }
          } catch {
            // Ignore racey entries that vanish during traversal.
          }
        }
      }
    }

    walk('.');
    out.sort();
    return out;
  }

  return {
    get_error_message(errorHandle) {
      return errors.get(errorHandle) ?? '';
    },
    begin_read_string(value) {
      return alloc({
        type: 'string-reader',
        codepoints: toCodePoints(readString(value)),
        index: 0,
      });
    },
    string_read_char(readerHandle) {
      const reader = get(readerHandle, 'string-reader');
      if (reader.index >= reader.codepoints.length) {
        return -1;
      }
      const codepoint = reader.codepoints[reader.index];
      reader.index += 1;
      return codepoint;
    },
    finish_read_string(_readerHandle) {},
    begin_create_string() {
      return alloc({ type: 'string-builder', codepoints: [] });
    },
    string_append_char(builderHandle, codepoint) {
      const builder = get(builderHandle, 'string-builder');
      builder.codepoints.push(codepoint >>> 0);
    },
    finish_create_string(builderHandle) {
      const builder = get(builderHandle, 'string-builder');
      handles.delete(builderHandle);
      return String.fromCodePoint(...builder.codepoints);
    },
    begin_create_byte_array() {
      return alloc({ type: 'byte-array', values: [] });
    },
    byte_array_append_byte(arrayHandle, byte) {
      const array = get(arrayHandle, 'byte-array');
      array.values.push(byte & 0xff);
    },
    finish_create_byte_array(arrayHandle) {
      const array = get(arrayHandle, 'byte-array');
      handles.delete(arrayHandle);
      return Uint8Array.from(array.values);
    },
    write_bytes_to_file_new(pathValue, bytesValue) {
      try {
        fs.writeFileSync(readString(pathValue), readBytes(bytesValue));
        return 0;
      } catch (error) {
        return allocError(error);
      }
    },
    remove_file_new(pathValue) {
      try {
        fs.rmSync(readString(pathValue), { force: true });
        return 0;
      } catch (error) {
        return allocError(error);
      }
    },
    args_get() {
      return alloc({ type: 'extern-string-array', values: [...args] });
    },
    list_candidates() {
      return alloc({
        type: 'extern-string-array',
        values: collectCandidates(cwd),
      });
    },
    current_dir() {
      return allocExternString(cwd);
    },
    begin_read_string_array(externStringArrayHandle) {
      const arrayData = get(externStringArrayHandle, 'extern-string-array');
      return alloc({
        type: 'string-array-reader',
        values: arrayData.values,
        index: 0,
      });
    },
    string_array_read_string(readerHandle) {
      const reader = get(readerHandle, 'string-array-reader');
      if (reader.index >= reader.values.length) {
        return allocExternString(ARRAY_SENTINEL);
      }
      const value = reader.values[reader.index];
      reader.index += 1;
      return allocExternString(value);
    },
    finish_read_string_array(_readerHandle) {},
  };
}

let wasmGcExportsPromise;

function buildImportObject(module) {
  const imports = WebAssembly.Module.imports(module);
  const stringConstants = Object.create(null);
  const moonbitFs = createMoonbitFsHost({ cwd: process.cwd(), args: [] });
  const importObject = {
    __moonbit_fs_unstable: moonbitFs,
    __moonbit_time_unstable: {
      now() {
        return BigInt(Date.now());
      },
    },
    console: {
      log(...args) {
        console.log(...args);
      },
    },
  };

  for (const entry of imports) {
    if (entry.module === '_') {
      stringConstants[entry.name] = entry.name;
      continue;
    }
    if (entry.module === '__moonbit_time_unstable') {
      continue;
    }
    if (entry.module === '__moonbit_fs_unstable') {
      continue;
    }
    if (entry.module === 'console') {
      continue;
    }
    throw new Error(`Unsupported wasm-gc import module: ${entry.module}`);
  }

  if (Object.keys(stringConstants).length > 0) {
    importObject._ = stringConstants;
  }

  return importObject;
}

async function instantiateWasmGc() {
  const wasmBytes = await fsPromises.readFile(new URL('./starshine.wasm-gc.wasm', import.meta.url));
  const module = await WebAssembly.compile(wasmBytes, { builtins: ['js-string'] });
  const importObject = buildImportObject(module);
  const instance = await WebAssembly.instantiate(module, importObject, { builtins: ['js-string'] });
  return instance.exports;
}

export async function getWasmGcExports() {
  if (!wasmGcExportsPromise) {
    wasmGcExportsPromise = instantiateWasmGc();
  }
  return wasmGcExportsPromise;
}

export function countProvidedArgs(argsLike) {
  let count = argsLike.length;
  while (count > 0 && argsLike[count - 1] === undefined) {
    count -= 1;
  }
  return count;
}

export function unsupportedExport(name, reason) {
  return function unsupported() {
    throw new Error(`${name} is unsupported in the generated JS adapter. ${reason}`);
  };
}

function expectArray(value, descriptor) {
  if (!Array.isArray(value)) {
    throw new TypeError(`Expected an array for ${descriptor.kind}.`);
  }
}

function expectUint8Array(value) {
  if (!(value instanceof Uint8Array)) {
    throw new TypeError('Expected a Uint8Array.');
  }
}

function maybeDisplay(descriptor, value, wasm) {
  if (descriptor.kind === 'named' && descriptor.showExport) {
    return wasm[descriptor.showExport](value);
  }
  return undefined;
}

export function lowerValue(descriptor, value, wasm) {
  switch (descriptor.kind) {
    case 'bool':
      if (typeof value !== 'boolean') {
        throw new TypeError('Expected a boolean.');
      }
      return value;
    case 'string':
      if (typeof value !== 'string') {
        throw new TypeError('Expected a string.');
      }
      return value;
    case 'number':
      if (typeof value !== 'number') {
        throw new TypeError('Expected a number.');
      }
      return value;
    case 'bigint':
      if (typeof value === 'bigint') {
        return value;
      }
      if (typeof value === 'number' && Number.isInteger(value)) {
        return BigInt(value);
      }
      throw new TypeError('Expected a bigint.');
    case 'byte':
      if (typeof value !== 'number' || !Number.isInteger(value)) {
        throw new TypeError('Expected an integer byte.');
      }
      return value & 0xff;
    case 'char':
      if (typeof value === 'string') {
        if (value.length === 0) {
          throw new TypeError('Expected a non-empty string for Char.');
        }
        return value.codePointAt(0);
      }
      if (typeof value === 'number' && Number.isInteger(value)) {
        return value;
      }
      throw new TypeError('Expected a numeric code point or single-character string.');
    case 'unit':
      return undefined;
    case 'bytes': {
      expectUint8Array(value);
      const byteArray = wasm[descriptor.helper.byteArray.new]();
      for (let index = 0; index < value.length; index += 1) {
        wasm[descriptor.helper.byteArray.push](byteArray, value[index]);
      }
      return wasm[descriptor.helper.fromArray](byteArray);
    }
    case 'array': {
      expectArray(value, descriptor);
      const arrayValue = wasm[descriptor.helper.new]();
      for (const item of value) {
        wasm[descriptor.helper.push](arrayValue, lowerValue(descriptor.item, item, wasm));
      }
      return arrayValue;
    }
    case 'option':
      if (value === null || value === undefined) {
        return wasm[descriptor.helper.none]();
      }
      return wasm[descriptor.helper.some](lowerValue(descriptor.item, value, wasm));
    case 'tuple':
      expectArray(value, descriptor);
      if (value.length !== descriptor.items.length) {
        throw new TypeError(`Expected a tuple with ${descriptor.items.length} items.`);
      }
      return wasm[descriptor.helper.make](...descriptor.items.map((item, index) => lowerValue(item, value[index], wasm)));
    case 'named':
    case 'opaque':
      return value;
    case 'result':
      throw new Error('Lowering JS result objects back into MoonBit Result values is not supported.');
    case 'function':
      throw new Error(`Function values are unsupported for ${descriptor.brand ?? 'this export'}.`);
    default:
      throw new Error(`Unknown descriptor kind: ${descriptor.kind}`);
  }
}

export function liftValue(descriptor, value, wasm) {
  switch (descriptor.kind) {
    case 'bool':
      return Boolean(value);
    case 'string':
      return value;
    case 'number':
    case 'byte':
    case 'char':
      return Number(value);
    case 'bigint':
      return BigInt(value);
    case 'unit':
      return undefined;
    case 'bytes': {
      const length = wasm[descriptor.helper.length](value);
      const out = new Uint8Array(length);
      for (let index = 0; index < length; index += 1) {
        out[index] = wasm[descriptor.helper.get](value, index);
      }
      return out;
    }
    case 'array': {
      const length = wasm[descriptor.helper.length](value);
      const out = new Array(length);
      for (let index = 0; index < length; index += 1) {
        out[index] = liftValue(descriptor.item, wasm[descriptor.helper.get](value, index), wasm);
      }
      return out;
    }
    case 'option':
      if (!wasm[descriptor.helper.isSome](value)) {
        return null;
      }
      return liftValue(descriptor.item, wasm[descriptor.helper.unwrap](value), wasm);
    case 'result':
      if (wasm[descriptor.helper.isOk](value)) {
        return {
          ok: true,
          value: liftValue(descriptor.ok, wasm[descriptor.helper.unwrapOk](value), wasm),
        };
      }
      {
        const rawError = wasm[descriptor.helper.unwrapErr](value);
        const error = liftValue(descriptor.err, rawError, wasm);
        const display = maybeDisplay(descriptor.err, rawError, wasm);
        return display === undefined
          ? { ok: false, error }
          : { ok: false, error, display };
      }
    case 'tuple':
      return descriptor.items.map((item, index) => liftValue(item, wasm[descriptor.helper.getters[index]](value), wasm));
    case 'named':
    case 'opaque':
      return value;
    case 'function':
      throw new Error('Function values cannot be lifted into JavaScript.');
    default:
      throw new Error(`Unknown descriptor kind: ${descriptor.kind}`);
  }
}
