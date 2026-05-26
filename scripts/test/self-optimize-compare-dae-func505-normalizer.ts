import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

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
    fs.writeFileSync(
      cmdPath,
      `@echo off\r\nnode "%~dp0\\${path.basename(scriptPath)}" %*\r\n`,
    );
    return cmdPath;
  }

  fs.writeFileSync(basePath, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(basePath, 0o755);
  return basePath;
}

export function runSelfOptimizeCompareDaeFunc505NormalizerTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-dae-func505-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  fs.writeFileSync(inputPath, "input");

  const fakeMoon = makeExecutable(path.join(tmpdir, "fake-moon"), "process.exit(0);\n");

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
if (args[0] === "--print-func") {
  const isBinaryen = args[2].endsWith("binaryen.wasm");
  process.stderr.write("Log: " + args[2] + "\\n");
  process.stderr.write("0: Func[" + args[1] + "]\\n");
  process.stderr.write("  func code[505] abs[" + args[1] + "]\\n");
  process.stderr.write("    params: [I32]\\n");
  process.stderr.write("    results: [I32]\\n");
  process.stderr.write("    body_raw:\\n");
  const commonPrefix = "      (i32.const I32(8))(call (Func 24))(i32.const I32(2097152))(call (Func 24))(i32.const I32(1572864))";
  const commonSuffix = "(call (Func 26))(call (Func 28))(call (Func 4495))(i32.const I32(65760))(i32.const I32(55168))(call (Func 4211))(i32.const I32(65728))(call (Func 4211))(i32.const I32(1048832))(call (Func 4490))i64.div_u(i64.load align=1 offset=8)i64.store align=1 offset=8(i32.load align=1 offset=8)(i32.const I32(2097153))\\n";
  process.stderr.write(commonPrefix + (isBinaryen ? "(local.get (Local 2))i32.gt_s" : "(local.get (Local 3))i32.lt_s") + commonSuffix);
  process.exit(0);
}
const outIndex = args.indexOf("--out");
if (outIndex === -1 || outIndex + 1 >= args.length) process.exit(1);
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "starshine-wasm");
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:dae-optimizing elapsed_us=1000 total_us=1000\\n");
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
  fs.writeFileSync(args[outIndex + 1], input.endsWith("starshine.wasm")
    ? "(module\\n (import \\\"env\\\" \\\"f\\\" (func $imp))\\n (func $0 (result i32) (local i32))\\n)\\n"
    : "(module\\n (import \\\"env\\\" \\\"f\\\" (func $imp))\\n (func $0 (result i32) (local i64))\\n)\\n");
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

  const fakeWasmTools = makeExecutable(path.join(tmpdir, "fake-wasm-tools"), "process.exit(0);\n");

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
      "--dae-optimizing",
    ],
    { cwd: repoRoot, encoding: "utf8" },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    fail(`self-optimize-compare DAE Func505 normalizer test failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    normalizedWatEqual: boolean;
    normalizedWatTextEqual?: boolean;
    canonicalFuncPrettyEqual?: boolean;
  };
  assert(summary.normalizedWatTextEqual === false, "expected raw normalized WAT mismatch");
  assert(summary.canonicalFuncPrettyEqual === true, "expected Func505 canonical fallback equality");
  assert(summary.normalizedWatEqual === true, "expected Func505 diagnostic normalizer equality");
}

if (import.meta.main) {
  runSelfOptimizeCompareDaeFunc505NormalizerTest();
}
