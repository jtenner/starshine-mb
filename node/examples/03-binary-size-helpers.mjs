import * as binary from '../binary.js';
import { expectOk, printJson } from './_shared.mjs';

const unsignedSize = expectOk(binary.sizeUnsigned(255n, 32), 'binary.sizeUnsigned');
const signedSize = expectOk(binary.sizeSigned(-1n, 32), 'binary.sizeSigned');

printJson('leb128 sizes', {
  unsigned255I32: unsignedSize,
  signedMinus1I32: signedSize,
});
