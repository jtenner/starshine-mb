import * as cmd from '../cmd.js';
import { expectOk, printJson } from './_shared.mjs';

const writes = new Map();
const report = cmd.FuzzFailureReport.new(
  1n,
  2,
  3,
  'stage',
  'message',
  ['optimize'],
  ['vacuum'],
  new Uint8Array([0, 97, 115, 109]),
);
const persisted = expectOk(
  cmd.persistFuzzFailureReport(
    report,
    cmd.FuzzFailurePersistIO.new(
      () => ({ ok: true, value: undefined }),
      (targetPath, bytes) => {
        writes.set(targetPath, bytes.length);
        return { ok: true, value: undefined };
      },
    ),
    'tmp-corpus',
  ),
  'cmd.persistFuzzFailureReport',
);

printJson('persisted fuzz report', {
  metaPath: persisted[0],
  wasmPath: persisted[1],
  writes: [...writes.entries()],
});
