#!/usr/bin/env bun

import process from "node:process";
import { main } from "./lib/self-optimize-compare-task";

if (import.meta.main) {
  await main(process.argv.slice(2));
}
