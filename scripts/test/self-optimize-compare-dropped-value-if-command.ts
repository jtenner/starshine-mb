import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function fail(message: string): never {
  throw new Error(message);
}

function assert(condition: boolean, message: string): void {
  if (!condition) fail(message);
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

export function runSelfOptimizeCompareDroppedValueIfCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-dropped-value-if-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  fs.writeFileSync(inputPath, "input");

  const fakeMoon = makeExecutable(path.join(tmpdir, "fake-moon"), `process.exit(0);\n`);

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
if (args[0] === "--print-func") {
  process.stderr.write("Log: " + args[2] + "\\n");
  process.stderr.write("0: Func[" + args[1] + "]\\n");
  process.stderr.write("  func code[0] abs[" + args[1] + "]\\n");
  process.stderr.write("    params: [I32]\\n");
  process.stderr.write("    results: [I32]\\n");
  process.stderr.write("    body_raw:\\n");
  if (args[2].endsWith("binaryen.wasm")) {
    process.stderr.write("      (local.get (Local 0))(i32.const I32(0))i32.ge_u(if I32 (call (Func 2))(local.get (Local 1)) else (call (Func 3))(local.get (Local 2)))drop(i32.const I32(7))(local.tee (Local 4))(call (Func 4))drop(local.get (Local 0))(i32.const I32(4))i32.add(end)\\n");
  } else {
    process.stderr.write("      (local.get (Local 0))(i32.const I32(0))i32.ge_u(if (Void) (call (Func 2)) else (call (Func 3)))(i32.const I32(7))(local.set (Local 4))(local.get (Local 4))(call (Func 4))drop(local.get (Local 0))(i32.const I32(4))i32.add(end)\\n");
  }
  process.exit(0);
}
const outIndex = args.indexOf("--out");
if (outIndex === -1 || outIndex + 1 >= args.length) process.exit(1);
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "starshine-wasm");
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:simplify-locals elapsed_us=1000 total_us=1000\\n");
`,
  );

  const fakeWasmOpt = makeExecutable(
    path.join(tmpdir, "fake-wasm-opt"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const outIndex = args.indexOf("-o");
if (outIndex === -1 || outIndex + 1 >= args.length) process.exit(1);
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  const input = args[0];
  const local = input.endsWith("binaryen.wasm") ? "i32" : "i64";
  fs.writeFileSync(args[outIndex + 1], "(module\\n (import \\\"env\\\" \\\"f\\\" (func $imp))\\n (func $0 (type $0) (param i32) (result i32)\\n  (local $1 " + local + ")\\n )\\n)\\n");
  process.exit(0);
}
if (args.includes("--strip-debug")) {
  fs.writeFileSync(args[outIndex + 1], "same-wasm");
  process.exit(0);
}
process.stderr.write("[PassRunner] passes took 0.002000 seconds.\\n");
fs.writeFileSync(args[outIndex + 1], "same-wasm");
`,
  );

  const fakeWasmTools = makeExecutable(path.join(tmpdir, "fake-wasm-tools"), `process.exit(0);\n`);

  const result = spawnSync(
    "bun",
    [
      path.join(repoRoot, "scripts", "self-optimize-compare.ts"),
      inputPath,
      "--out-dir",
      outDir,
      "--moon",
      fakeMoon,
      "--starshine-bin",
      fakeStarshine,
      "--wasm-opt-bin",
      fakeWasmOpt,
      "--wasm-tools-bin",
      fakeWasmTools,
      "--simplify-locals",
    ],
    { cwd: repoRoot, encoding: "utf8" },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) fail(`self-optimize-compare dropped value-if test failed:\n${result.stderr}`);

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    normalizedWatEqual: boolean;
    normalizedWatTextEqual?: boolean;
  };
  assert(summary.normalizedWatEqual === true, "expected dropped value-if canonical fallback equality");
  assert(summary.normalizedWatTextEqual === false, "expected raw normalized WAT mismatch");
}

if (import.meta.main) {
  runSelfOptimizeCompareDroppedValueIfCommandTest();
}
