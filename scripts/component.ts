#!/usr/bin/env bun

import process from "node:process";

import { runComponent } from "./lib/component-task";

if (import.meta.main) {
  runComponent(process.argv.slice(2));
}
