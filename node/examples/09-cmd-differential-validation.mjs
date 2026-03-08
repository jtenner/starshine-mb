import * as binary from '../binary.js';
import * as cmd from '../cmd.js';
import * as wast from '../wast.js';
import { SAMPLE_BINARY_MODULE_TEXT, expectOk, printJson } from './_shared.mjs';

const mod = expectOk(
  wast.wastToBinaryModule(SAMPLE_BINARY_MODULE_TEXT),
  'wast.wastToBinaryModule',
);
const bytes = expectOk(binary.encodeModule(mod), 'binary.encodeModule');
const report = expectOk(
  cmd.differentialValidateWasm(
    bytes,
    cmd.DifferentialAdapters.new(
      () => ({ ok: true, value: true }),
      () => ({ ok: true, value: true }),
    ),
  ),
  'cmd.differentialValidateWasm',
);

printJson('differential validation', report);
