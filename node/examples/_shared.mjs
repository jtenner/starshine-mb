import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export const SAMPLE_BINARY_MODULE_TEXT = '(module (func (export "run")))';
export const SAMPLE_OPTIMIZE_MODULE_TEXT = '(module (func (export "run") nop drop unreachable))';

function displayError(error) {
  if (error instanceof Error) {
    return error.message;
  }
  if (error && typeof error === 'object' && 'display' in error && typeof error.display === 'string') {
    return error.display;
  }
  return String(error);
}

export function expectOk(result, label) {
  if (!result.ok) {
    throw new Error(`${label} failed: ${result.display ?? displayError(result.error)}`);
  }
  return result.value;
}

export function makeTempDir(prefix) {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

export function printJson(label, value) {
  console.log(`${label}: ${JSON.stringify(value, null, 2)}`);
}
