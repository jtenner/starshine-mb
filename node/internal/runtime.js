import fs from 'node:fs/promises';

let wasmGcExportsPromise;

function buildImportObject(module) {
  const imports = WebAssembly.Module.imports(module);
  const stringConstants = Object.create(null);
  const importObject = {
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
  const wasmBytes = await fs.readFile(new URL('./starshine.wasm-gc.wasm', import.meta.url));
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
