import fs from 'node:fs';
import process from 'node:process';
import { WASI } from 'node:wasi';
import path from 'node:path';

const ARRAY_SENTINEL = 'ffi_end_of_/string_array';

function toCodePoints(value) {
  const out = [];
  for (const char of value) {
    out.push(char.codePointAt(0));
  }
  return out;
}

export function createMoonbitFsHost({ args = [], cwd = process.cwd() } = {}) {
  let nextHandle = 1;
  const handles = new Map();

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

  function allocExternString(value) {
    return alloc({ type: 'extern-string', value });
  }

  function collectCandidates(rootDir) {
    const out = [];

    function walk(currentRelative) {
      const currentAbsolute = currentRelative === '.'
        ? rootDir
        : path.join(rootDir, currentRelative);
      const entries = fs.readdirSync(currentAbsolute, { withFileTypes: true });
      for (const entry of entries) {
        if (entry.name === '.' || entry.name === '..') {
          continue;
        }
        const nextRelative = currentRelative === '.'
          ? entry.name
          : path.posix.join(currentRelative, entry.name);
        const nextAbsolute = path.join(currentAbsolute, entry.name);
        if (entry.isDirectory()) {
          walk(nextRelative);
        } else if (entry.isFile()) {
          out.push(nextRelative);
        } else {
          try {
            if (fs.statSync(nextAbsolute).isDirectory()) {
              walk(nextRelative);
            } else if (fs.statSync(nextAbsolute).isFile()) {
              out.push(nextRelative);
            }
          } catch {
            // Ignore entries that disappear or cannot be stat'ed mid-walk.
          }
        }
      }
    }

    walk('.');
    out.sort();
    return out;
  }

  return {
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
    begin_read_string(externStringHandle) {
      const externString = get(externStringHandle, 'extern-string');
      return alloc({
        type: 'string-reader',
        codepoints: toCodePoints(externString.value),
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

function extractExitCode(error) {
  if (typeof error?.exitCode === 'number') {
    return error.exitCode;
  }
  if (typeof error?.code === 'number') {
    return error.code;
  }
  return null;
}

export async function runWasmStart({
  wasmPath,
  args = [],
  cwd = process.cwd(),
  env = process.env,
  preopens,
  stdoutFd = 1,
  stderrFd = 2,
  print = (text) => process.stdout.write(text),
} = {}) {
  if (!wasmPath) {
    throw new Error('Missing wasmPath');
  }

  const wasmBytes = fs.readFileSync(wasmPath);
  const module = await WebAssembly.compile(wasmBytes);
  const moduleImports = WebAssembly.Module.imports(module);

  const wasi = new WASI({
    version: 'preview1',
    args,
    env,
    preopens: preopens ?? { '.': cwd },
    stdout: stdoutFd,
    stderr: stderrFd,
  });
  const moonbitFs = createMoonbitFsHost({ args, cwd });

  const importObject = {
    wasi_snapshot_preview1: wasi.wasiImport,
    spectest: {
      print_char(ch) {
        const codepoint = ch >>> 0;
        print(String.fromCodePoint(codepoint));
      },
    },
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

  for (const entry of moduleImports) {
    if (!Object.hasOwn(importObject, entry.module)) {
      throw new Error(`Missing import module: ${entry.module}`);
    }
  }

  const instance = await WebAssembly.instantiate(module, importObject);

  try {
    let maybeExitCode = 0;
    if (instance.exports._start) {
      maybeExitCode = wasi.start(instance);
    } else {
      wasi.initialize(instance);
    }
    if (typeof maybeExitCode === 'number') {
      return maybeExitCode;
    }
    return 0;
  } catch (error) {
    const exitCode = extractExitCode(error);
    if (exitCode !== null) {
      return exitCode;
    }
    throw error;
  }
}
