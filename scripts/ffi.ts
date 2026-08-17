#!/usr/bin/env bun

import process from "node:process";

import { runFfi, type FfiCommand } from "./lib/ffi-task";

if (import.meta.main) {
  runFfi(process.argv[2] as FfiCommand);
}
