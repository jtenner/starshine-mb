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

export function runSelfOptimizeCompareMissingStarshineOutputTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-missing-output-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
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
fs.writeFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(process.argv.slice(2), null, 2));
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:optimize-instructions elapsed_us=123 total_us=123\\n");
process.stderr.write("error: final module validate: type mismatch\\n");
process.exit(0);
`,
  );

  const fakeWasmOpt = makeExecutable(
    path.join(tmpdir, "fake-wasm-opt"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_WASM_OPT_LOG, JSON.stringify(args) + "\\n");
const outIndex = args.indexOf("-o");
if (outIndex === -1 || outIndex + 1 >= args.length) {
  process.stderr.write("missing -o\\n");
  process.exit(1);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (!args.includes("--strip-debug") && !args.includes("-S")) {
  process.stderr.write("[PassRunner] passes took 0.010000 seconds.\\n");
}
fs.writeFileSync(args[outIndex + 1], args.includes("-S") ? "(module)\\n" : "binaryen-wasm");
process.exit(0);
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
fs.writeFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(process.argv.slice(2), null, 2));
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
      "--optimize-instructions",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_WASM_OPT_LOG: wasmOptLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  assert(result.status !== 0, "expected compare run to fail when Starshine omits its raw output");
  assert(
    result.stderr.includes("Starshine command reported success but did not create"),
    `expected missing-output failure, got:\n${result.stderr}`,
  );
  assert(
    result.stderr.includes("starshine.raw.wasm"),
    `expected missing-output path in error, got:\n${result.stderr}`,
  );
  assert(
    result.stderr.includes("error: final module validate: type mismatch"),
    `expected captured Starshine stderr, got:\n${result.stderr}`,
  );
  assert(fs.existsSync(moonLog), "expected compare harness to compile before running Starshine");
  assert(fs.existsSync(starshineLog), "expected Starshine invocation to be recorded");
  assert(fs.existsSync(wasmToolsLog), "expected baseline validation to run before the failure");
  assert(fs.existsSync(wasmOptLog), "expected Binaryen acceptance check to run before the failure");
  assert(!fs.existsSync(path.join(outDir, "result.json")), "did not expect a result summary after missing-output failure");
}

if (import.meta.main) {
  runSelfOptimizeCompareMissingStarshineOutputTest();
}
