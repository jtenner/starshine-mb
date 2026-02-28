import * as binary from '../binary.js';
import * as wast from '../wast.js';
import { SAMPLE_BINARY_MODULE_TEXT, expectOk } from './_shared.mjs';

const mod = expectOk(
  wast.wastToBinaryModule(SAMPLE_BINARY_MODULE_TEXT),
  'wast.wastToBinaryModule',
);
const bytes = expectOk(binary.encodeModule(mod), 'binary.encodeModule');
const [decoded, trailingOffset] = expectOk(
  binary.decodeModuleWithDetail(bytes, 0),
  'binary.decodeModuleWithDetail',
);

console.log(
  `decode detail ok: ${bytes.length} bytes, trailing offset ${trailingOffset}, decoded=${typeof decoded}`,
);
