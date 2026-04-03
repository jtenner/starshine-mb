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

export function runSelfOptimizeCompareBinaryenRoundtripCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(
    path.join(os.tmpdir(), "starshine-self-opt-compare-roundtrip-"),
  );
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
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
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:reorder-locals elapsed_us=250 total_us=250\\n");
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
  process.stderr.write("[PassRunner] passes took 0.020000 seconds.\\n");
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
      "--binaryen-nop-roundtrips",
      "2",
      "--reorder-locals",
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
    fail(`self-optimize-compare with Binaryen roundtrips failed:\n${result.stderr}`);
  }

  const starshineArgs = JSON.parse(fs.readFileSync(starshineLog, "utf8")) as string[];
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
  const effectiveInputPath = path.join(outDir, "binaryen.nop2.wasm");

  assert(binaryenLogs.length === 6, `expected 6 wasm-opt invocations, got ${binaryenLogs.length}`);
  assert(
    JSON.stringify(binaryenLogs[0]) === JSON.stringify([
      inputPath,
      "--all-features",
      "-o",
      path.join(outDir, "binaryen.nop1.wasm"),
    ]),
    `unexpected first Binaryen no-pass args:\n${JSON.stringify(binaryenLogs[0], null, 2)}`,
  );
  assert(
    JSON.stringify(binaryenLogs[1]) === JSON.stringify([
      path.join(outDir, "binaryen.nop1.wasm"),
      "--all-features",
      "-o",
      effectiveInputPath,
    ]),
    `unexpected second Binaryen no-pass args:\n${JSON.stringify(binaryenLogs[1], null, 2)}`,
  );
  assert(
    JSON.stringify(binaryenLogs[2]) === JSON.stringify([
      effectiveInputPath,
      "--all-features",
      "--reorder-locals",
      "--debug",
      "-o",
      path.join(outDir, "binaryen.raw.wasm"),
    ]),
    `unexpected Binaryen compare args after roundtrips:\n${JSON.stringify(binaryenLogs[2], null, 2)}`,
  );
  assert(
    JSON.stringify(starshineArgs) === JSON.stringify([
      "--reorder-locals",
      "--out",
      path.join(outDir, "starshine.raw.wasm"),
      effectiveInputPath,
    ]),
    `unexpected Starshine args after roundtrips:\n${JSON.stringify(starshineArgs, null, 2)}`,
  );
  assert(
    JSON.stringify(wasmToolsLogs) === JSON.stringify([
      ["validate", inputPath],
      ["validate", effectiveInputPath],
    ]),
    `unexpected wasm-tools validate calls:\n${JSON.stringify(wasmToolsLogs, null, 2)}`,
  );

  const summary = JSON.parse(
    fs.readFileSync(path.join(outDir, "result.json"), "utf8"),
  ) as {
    inputPath: string;
    effectiveInputPath: string;
    binaryenNopRoundtrips: number;
    starshinePassElapsedMs: number;
    binaryenPassElapsedMs: number;
    normalizedWatEqual: boolean;
    wasmEqual: boolean;
  };
  assert(summary.inputPath === inputPath, `unexpected summary inputPath: ${summary.inputPath}`);
  assert(
    summary.effectiveInputPath === effectiveInputPath,
    `unexpected summary effectiveInputPath: ${summary.effectiveInputPath}`,
  );
  assert(
    summary.binaryenNopRoundtrips === 2,
    `unexpected summary binaryenNopRoundtrips: ${summary.binaryenNopRoundtrips}`,
  );
  assert(
    summary.starshinePassElapsedMs === 0.25,
    `unexpected parsed Starshine pass runtime: ${summary.starshinePassElapsedMs}`,
  );
  assert(
    summary.binaryenPassElapsedMs === 20,
    `unexpected parsed Binaryen pass runtime: ${summary.binaryenPassElapsedMs}`,
  );
  assert(summary.wasmEqual === true, "expected canonical wasm equality");
  assert(summary.normalizedWatEqual === true, "expected normalized WAT equality");
  assert(
    result.stdout.includes("Binaryen no-pass roundtrips: 2"),
    `expected Binaryen roundtrip count in stdout:\n${result.stdout}`,
  );
  assert(
    result.stdout.includes(`Effective input wasm: ${effectiveInputPath}`),
    `expected effective input path in stdout:\n${result.stdout}`,
  );
}

if (import.meta.main) {
  runSelfOptimizeCompareBinaryenRoundtripCommandTest();
}
