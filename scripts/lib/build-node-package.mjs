#!/usr/bin/env node

import { pathToFileURL } from 'node:url';

const DISABLED_MESSAGE =
  'Node package rebuilds are disabled during the optimization pipeline refactor. '
  + 'The previous build depended on the removed node_api package.';

export function buildNodePackage() {
  throw new Error(DISABLED_MESSAGE);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    buildNodePackage();
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
