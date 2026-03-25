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

export function runSelfOptimizeCompareCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
  fs.writeFileSync(inputPath, "input");

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const start = Date.now();
while (Date.now() - start < 40) {}
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:duplicate-function-elimination elapsed_us=40000 total_us=40000\\n");
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
const start = Date.now();
while (Date.now() - start < 10) {}
fs.appendFileSync(process.env.FAKE_BINARYEN_LOG, JSON.stringify(args) + "\\n");
const outIndex = args.indexOf("-o");
if (outIndex === -1 || outIndex + 1 >= args.length) {
  process.stderr.write("missing -o\\n");
  process.exit(1);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  const input = args[0];
  if (input.endsWith("starshine.wasm")) {
    fs.writeFileSync(args[outIndex + 1], "(module ;; canonical normalized)\\n");
  } else if (input.endsWith("binaryen.wasm")) {
    fs.writeFileSync(args[outIndex + 1], "(module ;; canonical normalized)\\n");
  } else {
    fs.writeFileSync(args[outIndex + 1], "(module ;; unknown normalized)\\n");
  }
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
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.writeFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(args, null, 2));
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
      "--starshine-bin",
      fakeStarshine,
      "--wasm-opt-bin",
      fakeWasmOpt,
      "--wasm-tools-bin",
      fakeWasmTools,
      "--duplicate-function-elimination",
      "--dead-code-elimination",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
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
    fail(`self-optimize-compare failed:\n${result.stderr}`);
  }

  const starshineArgs = JSON.parse(fs.readFileSync(starshineLog, "utf8")) as string[];
  const wasmToolsArgs = JSON.parse(fs.readFileSync(wasmToolsLog, "utf8")) as string[];
  assert(
    JSON.stringify(wasmToolsArgs) === JSON.stringify(["validate", inputPath]),
    `unexpected wasm-tools args:\n${JSON.stringify(wasmToolsArgs, null, 2)}`,
  );
  assert(
    JSON.stringify(starshineArgs) === JSON.stringify([
      "--duplicate-function-elimination",
      "--dead-code-elimination",
      "--out",
      path.join(outDir, "starshine.raw.wasm"),
      inputPath,
    ]),
    `unexpected Starshine args:\n${JSON.stringify(starshineArgs, null, 2)}`,
  );

  const binaryenLogs = fs
    .readFileSync(binaryenLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);
  assert(binaryenLogs.length === 4, `expected 4 wasm-opt invocations, got ${binaryenLogs.length}`);
  assert(
    JSON.stringify(binaryenLogs[0]) === JSON.stringify([
      inputPath,
      "--all-features",
      "--duplicate-function-elimination",
      "--dce",
      "--debug",
      "-o",
      path.join(outDir, "binaryen.raw.wasm"),
    ]),
    `unexpected Binaryen compare args:\n${JSON.stringify(binaryenLogs[0], null, 2)}`,
  );
  assert(
    JSON.stringify(binaryenLogs[1]) === JSON.stringify([
      path.join(outDir, "starshine.raw.wasm"),
      "--all-features",
      "--strip-debug",
      "-o",
      path.join(outDir, "starshine.wasm"),
    ]),
    `unexpected Starshine canonicalization args:\n${JSON.stringify(binaryenLogs[1], null, 2)}`,
  );
  assert(binaryenLogs[2].includes("-S"), "expected Starshine normalization text invocation");
  assert(binaryenLogs[3].includes("-S"), "expected Binaryen normalization text invocation");

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    passFlags: string[];
    binaryenPassFlags: string[];
    starshineSize: number;
    binaryenSize: number;
    wasmEqual: boolean;
    starshineElapsedMs: number;
    binaryenElapsedMs: number;
    starshineAtLeastAsFast: boolean;
    starshinePassElapsedMs: number;
    binaryenPassElapsedMs: number;
    starshinePassAtLeastAsFast: boolean;
    normalizedWatEqual: boolean;
  };
  assert(
    JSON.stringify(summary.passFlags) === JSON.stringify([
      "--duplicate-function-elimination",
      "--dead-code-elimination",
    ]),
    `unexpected summary pass flags:\n${JSON.stringify(summary, null, 2)}`,
  );
  assert(
    JSON.stringify(summary.binaryenPassFlags) === JSON.stringify([
      "--duplicate-function-elimination",
      "--dce",
    ]),
    `unexpected summary Binaryen pass flags:\n${JSON.stringify(summary, null, 2)}`,
  );
  assert(summary.starshineSize === "binaryen-wasm".length, `unexpected Starshine size: ${summary.starshineSize}`);
  assert(summary.binaryenSize === "binaryen-wasm".length, `unexpected Binaryen size: ${summary.binaryenSize}`);
  assert(summary.wasmEqual === true, "expected canonical wasm equality");
  assert(summary.starshineElapsedMs >= 30, `expected measured Starshine runtime, got ${summary.starshineElapsedMs}`);
  assert(summary.binaryenElapsedMs >= 5, `expected measured Binaryen runtime, got ${summary.binaryenElapsedMs}`);
  assert(summary.starshineAtLeastAsFast === false, "expected Starshine runtime parity flag to report slower");
  assert(summary.starshinePassElapsedMs === 40, `expected parsed Starshine pass runtime, got ${summary.starshinePassElapsedMs}`);
  assert(summary.binaryenPassElapsedMs === 10, `expected parsed Binaryen pass runtime, got ${summary.binaryenPassElapsedMs}`);
  assert(summary.starshinePassAtLeastAsFast === false, "expected Starshine pass parity flag to report slower");
  assert(summary.normalizedWatEqual === true, "expected normalized WAT equality");
  assert(
    fs.readFileSync(path.join(outDir, "starshine.wasm"), "utf8") ===
      fs.readFileSync(path.join(outDir, "binaryen.wasm"), "utf8"),
    "expected canonical wasm outputs to match exactly",
  );
  assert(
    fs.readFileSync(path.join(outDir, "starshine.raw.wasm"), "utf8") === "starshine-wasm",
    "expected preserved raw Starshine wasm output",
  );
  assert(
    fs.readFileSync(path.join(outDir, "binaryen.raw.wasm"), "utf8") === "binaryen-wasm",
    "expected preserved raw Binaryen wasm output",
  );
  assert(
    fs.readFileSync(path.join(outDir, "starshine.print.wat"), "utf8").includes("canonical normalized"),
    "expected Starshine normalized WAT output",
  );
  assert(
    fs.readFileSync(path.join(outDir, "binaryen.print.wat"), "utf8").includes("canonical normalized"),
    "expected Binaryen normalized WAT output",
  );
  assert(result.stdout.includes("Starshine runtime (ms):"), `expected Starshine runtime in stdout:\n${result.stdout}`);
  assert(result.stdout.includes("Binaryen runtime (ms):"), `expected Binaryen runtime in stdout:\n${result.stdout}`);
  assert(
    result.stdout.includes("Starshine at least as fast: no"),
    `expected runtime parity verdict in stdout:\n${result.stdout}`,
  );
  assert(result.stdout.includes("Starshine pass runtime (ms): 40.000"), `expected Starshine pass runtime in stdout:\n${result.stdout}`);
  assert(result.stdout.includes("Binaryen pass runtime (ms): 10.000"), `expected Binaryen pass runtime in stdout:\n${result.stdout}`);
  assert(
    result.stdout.includes("Starshine pass at least as fast: no"),
    `expected pass parity verdict in stdout:\n${result.stdout}`,
  );
}

if (import.meta.main) {
  runSelfOptimizeCompareCommandTest();
}
