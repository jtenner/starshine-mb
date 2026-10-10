import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export function createExternalNpmConsumerScratch(repoRoot, base = os.tmpdir()) {
  const realRoot = fs.realpathSync(repoRoot);
  const realBase = fs.realpathSync(base);
  const relative = path.relative(realRoot, realBase);
  if (relative === '' || (relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative))) {
    throw new Error('npm consumer scratch must be outside the source checkout; set NPM_CONSUMER_TMPDIR to an existing external directory');
  }
  return fs.mkdtempSync(path.join(realBase, 'starshine-npm-consumers-'));
}
