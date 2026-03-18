#!/usr/bin/env node

import { pathToFileURL } from 'node:url';

const DISABLED_MESSAGE =
  'Node package generation is disabled during the optimization pipeline refactor. '
  + 'The old generator depended on the removed passes and node_api packages.';

export function generateNodePackage() {
  throw new Error(DISABLED_MESSAGE);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    generateNodePackage();
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
