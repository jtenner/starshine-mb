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
    fs.writeFileSync(cmdPath, `@echo off\r\nnode "%~dp0\\${path.basename(scriptPath)}" %*\r\n`);
    return cmdPath;
  }

  fs.writeFileSync(basePath, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(basePath, 0o755);
  return basePath;
}

export function runSelfOptimizeCompareBinaryenAcceptedInvalidBaselineTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-binaryen-accepted-invalid-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
  fs.writeFileSync(inputPath, "input");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
fs.writeFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(process.argv.slice(2), null, 2));
process.exit(0);
`,
  );

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:duplicate-function-elimination elapsed_us=1000 total_us=1000\\n");
fs.writeFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(args, null, 2));
const outIndex = args.indexOf("--out");
if (outIndex === -1 || outIndex + 1 >= args.length) {
  process.stderr.write("missing --out\\n");
  process.exit(1);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "starshine-wasm");
`,
  );

  const fakeWasmOpt = makeExecutable(
    path.join(tmpdir, "fake-wasm-opt"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_BINARYEN_LOG, JSON.stringify(args) + "\\n");
const outIndex = args.indexOf("-o");
if (outIndex === -1 || outIndex + 1 >= args.length) {
  process.stderr.write("missing -o\\n");
  process.exit(1);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], "(module)\\n");
  process.exit(0);
}
process.stderr.write("[PassRunner] passes took 0.001000 seconds.\\n");
fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
fs.writeFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(process.argv.slice(2), null, 2));
process.stderr.write("validation failed: too many locals\\n");
process.exit(1);
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
      "--duplicate-function-elimination",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_BINARYEN_LOG: binaryenLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`expected compare run to continue when Binaryen accepts the baseline:\n${result.stderr}`);
  }

  const wasmToolsArgs = JSON.parse(fs.readFileSync(wasmToolsLog, "utf8")) as string[];
  const starshineArgs = JSON.parse(fs.readFileSync(starshineLog, "utf8")) as string[];
  const binaryenLogs = fs
    .readFileSync(binaryenLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);

  assert(
    JSON.stringify(wasmToolsArgs) === JSON.stringify(["validate", inputPath]),
    `unexpected wasm-tools args:\n${JSON.stringify(wasmToolsArgs, null, 2)}`,
  );
  assert(
    JSON.stringify(starshineArgs) === JSON.stringify([
      "--duplicate-function-elimination",
      "--out",
      path.join(outDir, "starshine.raw.wasm"),
      inputPath,
    ]),
    `unexpected Starshine args:\n${JSON.stringify(starshineArgs, null, 2)}`,
  );
  assert(binaryenLogs.length >= 4, `expected Binaryen acceptance and compare invocations, got ${binaryenLogs.length}`);
  assert(
    JSON.stringify(binaryenLogs[0]) === JSON.stringify([
      inputPath,
      "--all-features",
      "-o",
      path.join(outDir, "binaryen.acceptance.wasm"),
    ]),
    `unexpected Binaryen acceptance args:\n${JSON.stringify(binaryenLogs[0], null, 2)}`,
  );
}

if (import.meta.main) {
  runSelfOptimizeCompareBinaryenAcceptedInvalidBaselineTest();
}
