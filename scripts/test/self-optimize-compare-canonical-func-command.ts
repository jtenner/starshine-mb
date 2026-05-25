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

export function runSelfOptimizeCompareCanonicalFuncCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(
    path.join(os.tmpdir(), "starshine-self-opt-compare-canonical-func-"),
  );
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const printLog = path.join(tmpdir, "print.log");
  fs.writeFileSync(inputPath, "input");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
process.exit(0);
`,
  );

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
if (args[0] === "--print-func") {
  fs.appendFileSync(process.env.FAKE_PRINT_LOG, JSON.stringify(args) + "\\n");
  process.stderr.write("Log: " + args[2] + "\\n");
  process.stderr.write("0: Func[" + args[1] + "]\\n");
  process.stderr.write("  func code[0] abs[" + args[1] + "]\\n");
  const typeIndex = args[2].endsWith("binaryen.wasm") ? 1 : 0;
  process.stderr.write("    type_idx: (Type " + typeIndex + " (Func [] -> [I32]))\\n");
  process.stderr.write("    params: []\\n");
  process.stderr.write("    results: [I32]\\n");
  process.stderr.write("    locals:\\n");
  process.stderr.write("      [0] I32 (local)\\n");
  process.stderr.write("    body_raw:\\n");
  if (args[2].endsWith("binaryen.wasm")) {
    process.stderr.write("      (local.get (Local 0))(i32.const I32(10))i32.lt_u(if I32 (local.get (Local 0))(i32.const I32(1))i32.add else (local.get (Local 0)))(i32.const I32(1))(if I32 (i32.const I32(2)) else (i32.const I32(3)))(local.get (Local 0))(i32.const I32(0))i32.ge_si32.eqz(if (Void) unreachable)(global.get (Global 0))(call (Func 252))drop(block (Void) (local.get (Local 0)) (call (Func 45)) (local.get (Local 0)) drop)(end)(block (Void) (local.get (Local 0)) (call (Func 45)) (br (Label 1)) (end))(local.get (Local 2))(call (Func 4211))(local.set (Local 5))(local.get (Local 5))drop(if I32 (local.get (Local 0))(call (Func 45))(block (Void) (local.get (Local 0))(call (Func 45))(end)))(block I32 (block (Void) (block I32 (local.get (Local 0))(br (Label 1))(end))(local.get (Local 0))(call (Func 4211))(end))(local.tee (Local 6))(call (Func 309))(block (Void) (local.get (Local 1))(call (Func 880))(br (Label 3))(br (Label 5))(call_indirect (Type 5) (Table 1))(i32.const I32(0))(br (Label 1))(end)(block (Void)(call (Func 884)))\\n");
  } else {
    process.stderr.write("      (local.get (Local 0))(i32.const I32(1))i32.add(local.get (Local 0))(local.get (Local 0))(i32.const I32(10))i32.lt_uselect(local.set (Local 3))(local.get (Local 3))(local.get (Local 0))(i32.const I32(1))i32.adddrop(i32.const I32(1))(if (Void) (i32.const I32(2))return else (i32.const I32(3))return)unreachable(local.get (Local 0))(i32.const I32(0))i32.ge_s(if (Void) else unreachable)(global.get (Global 0))(local.set (Local 4))(local.get (Local 4))(call (Func 252))drop(block I32 (block (Void) (local.get (Local 0)) (call (Func 45)) (local.get (Local 0)) (end))drop)(end)(block I32 (block (Void) (local.get (Local 0)) (call (Func 45)) (br (Label 1)) (end))(local.get (Local 2))(call (Func 4211))(local.set (Local 5))(local.get (Local 5))(end))drop(if I32 (local.get (Local 0))(call (Func 45))(block I32 (block (Void) (local.get (Local 0))(call (Func 45))(end)))(block (Void) (block I32 (local.get (Local 0))(br (Label 1))(end))(local.get (Local 0))(call (Func 4211))(end))(local.tee (Local 6))(call (Func 309))(block I32 (block (Void) (local.get (Local 1))(call (Func 880))(br (Label 4))(br (Label 6))(call_indirect (Type 5) (Table 1))(i32.const I32(0))(end))(br (Label 1))(end)(block (Void)(call (Func 884)))\\n");
  }
  process.exit(0);
}
const outIndex = args.indexOf("--out");
if (outIndex === -1 || outIndex + 1 >= args.length) {
  process.stderr.write("missing --out\\n");
  process.exit(1);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "starshine-wasm");
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:tuple-optimization elapsed_us=1000 total_us=1000\\n");
`,
  );

  const fakeWasmOpt = makeExecutable(
    path.join(tmpdir, "fake-wasm-opt"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const outIndex = args.indexOf("-o");
if (outIndex === -1 || outIndex + 1 >= args.length) {
  process.stderr.write("missing -o\\n");
  process.exit(1);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  const input = args[0];
  if (input.endsWith("starshine.wasm")) {
    fs.writeFileSync(
      args[outIndex + 1],
      "(module\\n (import \\"env\\" \\"f\\" (func $imp))\\n (memory 1)\\n (data (i32.const 0) \\"\\\\00(\\\\00\\")\\n (func $0 (type $0) (result i32)\\n  (local $1 (tuple i32 i32))\\n )\\n)\\n",
    );
  } else if (input.endsWith("binaryen.wasm")) {
    fs.writeFileSync(
      args[outIndex + 1],
      "(module\\n (import \\"env\\" \\"f\\" (func $imp))\\n (memory 1)\\n (data (i32.const 0) \\"\\\\00(\\\\00\\")\\n (func $0 (type $0) (result i32)\\n  (local $1 i32)\\n )\\n)\\n",
    );
  } else {
    fs.writeFileSync(args[outIndex + 1], "(module)\\n");
  }
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

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
process.exit(0);
`,
  );

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
      "--tuple-optimization",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_PRINT_LOG: printLog,
      },
      encoding: "utf8",
    },
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`self-optimize-compare canonical-func test failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(
    fs.readFileSync(path.join(outDir, "result.json"), "utf8"),
  ) as {
    normalizedWatEqual: boolean;
    normalizedWatTextEqual?: boolean;
  };
  assert(summary.normalizedWatEqual === true, "expected canonical fallback equality");
  assert(summary.normalizedWatTextEqual === false, "expected raw normalized WAT mismatch");

  const printCalls = fs
    .readFileSync(printLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);
  assert(printCalls.length === 2, `expected two --print-func calls, got ${printCalls.length}`);
  assert(
    printCalls.every((args) => args[0] === "--print-func" && args[1] === "1"),
    `expected canonical fallback to compare absolute func 1, got ${JSON.stringify(printCalls)}`,
  );
}

if (import.meta.main) {
  runSelfOptimizeCompareCanonicalFuncCommandTest();
}
