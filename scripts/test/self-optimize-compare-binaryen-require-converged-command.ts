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

export function runSelfOptimizeCompareBinaryenRequireConvergedCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(
    path.join(os.tmpdir(), "starshine-self-opt-compare-require-converged-"),
  );
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
fs.writeFileSync(process.env.FAKE_STARSHINE_LOG, "unexpected");
process.exit(0);
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
const outPath = args[outIndex + 1];
fs.mkdirSync(path.dirname(outPath), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(outPath, "(module)\\n");
  process.exit(0);
}
if (args.includes("--strip-debug")) {
  fs.writeFileSync(outPath, "binaryen-wasm");
  process.exit(0);
}
if (args.includes("--debug")) {
  process.stderr.write("[PassRunner] passes took 0.010000 seconds.\\n");
  fs.writeFileSync(outPath, "binaryen-wasm");
  process.exit(0);
}
fs.writeFileSync(outPath, "roundtrip:" + path.basename(outPath));
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(args) + "\\n");
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
      "--binaryen-nop-until-stable",
      "4",
      "--require-binaryen-nop-converged",
      "--reorder-locals",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_BINARYEN_LOG: binaryenLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
        FAKE_STARSHINE_LOG: starshineLog,
      },
      encoding: "utf8",
    },
  );
  if (result.error) {
    throw result.error;
  }
  assert(result.status !== 0, "expected require-converged compare to fail");

  const binaryenLogs = fs
    .readFileSync(binaryenLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);
  const wasmToolsLogs = fs
    .readFileSync(wasmToolsLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);

  assert(binaryenLogs.length === 4, `expected only 4 no-pass invocations, got ${binaryenLogs.length}`);
  assert(
    JSON.stringify(binaryenLogs[3]) === JSON.stringify([
      path.join(outDir, "binaryen.nop3.wasm"),
      "--all-features",
      "-o",
      path.join(outDir, "binaryen.nop4.wasm"),
    ]),
    `unexpected fourth Binaryen no-pass args:\n${JSON.stringify(binaryenLogs[3], null, 2)}`,
  );
  assert(
    JSON.stringify(wasmToolsLogs) === JSON.stringify([
      ["validate", inputPath],
      ["validate", path.join(outDir, "binaryen.nop4.wasm")],
    ]),
    `unexpected wasm-tools validate calls:\n${JSON.stringify(wasmToolsLogs, null, 2)}`,
  );
  assert(
    !fs.existsSync(starshineLog),
    "did not expect Starshine to run when convergence was required and not reached",
  );
  assert(
    !fs.existsSync(path.join(outDir, "result.json")),
    "did not expect a result summary on required-convergence failure",
  );
  assert(
    result.stderr.includes("Binaryen no-pass writeback did not converge within 4 roundtrips"),
    `expected convergence failure in stderr:\n${result.stderr}`,
  );
}

if (import.meta.main) {
  runSelfOptimizeCompareBinaryenRequireConvergedCommandTest();
}
