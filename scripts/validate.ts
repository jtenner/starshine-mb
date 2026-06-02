#!/usr/bin/env bun

import process from "node:process";
import { main } from "./lib/validate-task";

if (import.meta.main) {
  await main(process.argv.slice(2));
}
