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

export function runSelfOptimizeCompareCanonicalBinaryenOutputTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-canonical-bin-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  fs.writeFileSync(inputPath, "input");

  const fakeMoon = makeExecutable(path.join(tmpdir, "fake-moon"), `process.exit(0);\n`);
  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:dead-code-elimination elapsed_us=1000 total_us=1000\\n");
const outIndex = args.indexOf("--out");
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "starshine-raw");
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
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], "(module)\\n");
} else if (args.includes("--strip-debug")) {
  fs.writeFileSync(args[outIndex + 1], "canonical-wasm");
} else {
  process.stderr.write("[PassRunner] passes took 0.002000 seconds.\\n");
  fs.writeFileSync(args[outIndex + 1], "binaryen-raw");
}
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
      "--canonicalize-binaryen-output",
      "--dead-code-elimination",
    ],
    {
      cwd: repoRoot,
      env: { ...process.env, FAKE_BINARYEN_LOG: binaryenLog },
      encoding: "utf8",
    },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) fail(`self-optimize-compare failed:\n${result.stderr}`);

  const binaryenLogs = fs.readFileSync(binaryenLog, "utf8").trim().split("\n").map((line) => JSON.parse(line) as string[]);
  assert(binaryenLogs.length === 5, `expected binaryen output canonicalization, got ${binaryenLogs.length} wasm-opt calls`);
  assert(
    JSON.stringify(binaryenLogs[2]) === JSON.stringify([
      path.join(outDir, "binaryen.raw.wasm"),
      "--all-features",
      "--strip-debug",
      "-o",
      path.join(outDir, "binaryen.wasm"),
    ]),
    `unexpected Binaryen canonicalization args:\n${JSON.stringify(binaryenLogs[2], null, 2)}`,
  );
  assert(fs.readFileSync(path.join(outDir, "binaryen.raw.wasm"), "utf8") === "binaryen-raw", "expected raw Binaryen output preserved");
  assert(fs.readFileSync(path.join(outDir, "binaryen.wasm"), "utf8") === "canonical-wasm", "expected canonical Binaryen compare output");
  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as { canonicalizeBinaryenOutput: boolean };
  assert(summary.canonicalizeBinaryenOutput === true, "expected summary to record canonical Binaryen output mode");
  assert(result.stdout.includes("Canonicalize Binaryen output: yes"), `expected mode in stdout:\n${result.stdout}`);
}

if (import.meta.main) {
  runSelfOptimizeCompareCanonicalBinaryenOutputTest();
}
