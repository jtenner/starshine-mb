#!/usr/bin/env bun

import process from "node:process";
import { main } from "./lib/fuzz-task";

if (import.meta.main) {
  main(process.argv.slice(2));
}
