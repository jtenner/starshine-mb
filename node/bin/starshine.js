#!/usr/bin/env node

import process from 'node:process';

import { runCmdExitCode } from '../cmd.js';

const exitCode = runCmdExitCode(process.argv.slice(2));
if (typeof exitCode === 'number' && exitCode !== 0) {
  process.exitCode = exitCode;
}
