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

export function runSelfOptimizeCompareZeroPassCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(
    path.join(os.tmpdir(), "starshine-self-opt-compare-zero-pass-"),
  );
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
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
process.stderr.write("[trace] input fixture:opt pass[heap-store-optimization]:skip-raw reason=no-heap-store-candidates count=2\\n");
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
if (args.includes("--strip-debug")) {
  fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
  process.exit(0);
}
process.stderr.write("[PassRunner] passes took 0.010000 seconds.\\n");
fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
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
      "--heap-store-optimization",
    ],
    {
      cwd: repoRoot,
      encoding: "utf8",
    },
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`zero-pass self-optimize-compare failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(
    fs.readFileSync(path.join(outDir, "result.json"), "utf8"),
  ) as {
    starshinePassElapsedMs: number;
    binaryenPassElapsedMs: number;
    starshinePassAtLeastAsFast: boolean;
    normalizedWatEqual: boolean;
    wasmEqual: boolean;
  };
  assert(
    summary.starshinePassElapsedMs === 0,
    `expected zero Starshine pass runtime, got ${summary.starshinePassElapsedMs}`,
  );
  assert(
    summary.binaryenPassElapsedMs === 10,
    `expected parsed Binaryen pass runtime, got ${summary.binaryenPassElapsedMs}`,
  );
  assert(
    summary.starshinePassAtLeastAsFast === true,
    "expected zero-runtime pass parity verdict to report fast enough",
  );
  assert(summary.wasmEqual === true, "expected canonical wasm equality");
  assert(summary.normalizedWatEqual === true, "expected normalized WAT equality");
  assert(
    result.stdout.includes("Starshine pass runtime (ms): 0.000"),
    `expected zero pass runtime in stdout:\n${result.stdout}`,
  );
}

if (import.meta.main) {
  runSelfOptimizeCompareZeroPassCommandTest();
}
