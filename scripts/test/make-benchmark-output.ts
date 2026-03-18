import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

function fail(message: string): never {
  throw new Error(message);
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    fail(message);
  }
}

function makeExecutable(basePath: string, source: string): string {
  if (process.platform === "win32") {
    const scriptPath = `${basePath}.js`;
    fs.writeFileSync(scriptPath, source);
    const cmdPath = `${basePath}.cmd`;
    fs.writeFileSync(cmdPath, `@echo off\r\nnode "%~dp0\\${path.basename(scriptPath)}" %*\r\n`);
    return cmdPath;
  }

  fs.writeFileSync(basePath, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(basePath, 0o755);
  return basePath;
}

export function runMakeBenchmarkOutputTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-bench-test-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  fs.writeFileSync(inputPath, "\0asm");

  const fakeBinary = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
let out = "";
let input = "";
for (let i = 2; i < process.argv.length; i += 1) {
  const token = process.argv[i];
  if (token === "--out") {
    out = process.argv[i + 1];
    i += 1;
    continue;
  }
  input = token;
}
if (!out) {
  process.stderr.write("missing --out\\n");
  process.exit(1);
}
fs.writeFileSync(out, "0123456789");
process.stderr.write("[trace] input " + input + ":read bytes=20\\n");
process.stderr.write("[trace] input " + input + ":lowered bytes=16\\n");
process.stderr.write("[trace] input " + input + ":pass_count=2 optimize:start\\n");
process.stderr.write("[trace] input " + input + ":opt pass[1/2]:done pass=SimplifyLocals changed=true funcs_visited=4 funcs_changed=2 instrs_before=20 instrs_after=15 transform_elapsed_ms=4 validation_elapsed_ms=1 elapsed_ms=5\\n");
process.stderr.write("[trace] input " + input + ":opt pass[2/2]:done pass=Vacuum changed=false funcs_visited=4 funcs_changed=0 instrs_before=15 instrs_after=14 transform_elapsed_ms=2 validation_elapsed_ms=0 elapsed_ms=2\\n");
process.stderr.write("[trace] input " + input + ":opt done elapsed_ms=8\\n");
process.stderr.write("[trace] input " + input + ":encode bytes=10\\n");
`,
  );

  const output = execFileSync(
    "bun",
    ["make", "benchmark-optimize", "--binary", fakeBinary, "--passes", "simplify-locals,vacuum", "--input", inputPath, "--repeat", "1"],
    {
      cwd: repoRoot,
      encoding: "utf8",
    },
  );

  assert(output.includes("Benchmark Summary"), `expected benchmark summary header, got:\n${output}`);
  assert(output.includes("aggregate_wasm_bytes: 16 -> 10 (-6, -37.50%)"), `expected aggregate wasm byte delta, got:\n${output}`);
  assert(output.includes("SimplifyLocals"), `expected SimplifyLocals row, got:\n${output}`);
  assert(output.includes("Vacuum"), `expected Vacuum row, got:\n${output}`);
  assert(output.includes("-6"), `expected instruction or size delta in output, got:\n${output}`);
}

if (import.meta.main) {
  runMakeBenchmarkOutputTest();
}
