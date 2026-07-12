#!/usr/bin/env bun
import { formatOiMismatchSummary, summarizeOiMismatchRun } from "./lib/oi-mismatch-summary";

const args = process.argv.slice(2);
const json = args.includes("--json");
const positional = args.filter((arg) => arg !== "--json");
if (positional.length !== 1 || positional[0] === "--help" || positional[0] === "-h") {
  process.stdout.write("usage: bun scripts/oi-mismatch-summary.ts [--json] <compare-pass-out-dir>\n");
  process.exit(positional.length === 1 ? 0 : 1);
}
const summary = summarizeOiMismatchRun(positional[0]);
process.stdout.write(json ? `${JSON.stringify(summary, null, 2)}\n` : formatOiMismatchSummary(summary));
