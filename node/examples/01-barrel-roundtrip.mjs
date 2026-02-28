import { binary, validate, wast } from '../index.js';
import { SAMPLE_BINARY_MODULE_TEXT, expectOk } from './_shared.mjs';

const mod = expectOk(
  wast.wastToBinaryModule(SAMPLE_BINARY_MODULE_TEXT),
  'wast.wastToBinaryModule',
);
const bytes = expectOk(binary.encodeModule(mod), 'binary.encodeModule');
const decoded = expectOk(binary.decodeModule(bytes), 'binary.decodeModule');
expectOk(validate.validateModule(decoded), 'validate.validateModule');

console.log(`barrel roundtrip ok: ${bytes.length} bytes`);
