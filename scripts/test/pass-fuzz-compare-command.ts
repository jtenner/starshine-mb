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

export function runPassFuzzCompareCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-compare-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
if (args[0] === "run" && args.includes("src/fuzz")) {
  const outDir = args[args.indexOf("--out-dir") + 1];
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "gen-valid-000001.wasm"), "gen-valid-1");
  fs.writeFileSync(path.join(outDir, "gen-valid-000002.wasm"), "gen-valid-2");
}
process.exit(0);
`,
  );

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(args) + "\\n");
const outIndex = args.indexOf("--out");
if (outIndex === -1) process.exit(1);
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "starshine:" + path.basename(args[args.length - 1]));
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
if (outIndex === -1) process.exit(1);
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], "(module ;; normalized)\\n");
} else {
  fs.writeFileSync(args[outIndex + 1], "binaryen:" + path.basename(args[0]));
}
process.exit(0);
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(args) + "\\n");
if (args[0] === "smith") {
  const outIndex = args.indexOf("-o");
  fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
  fs.writeFileSync(args[outIndex + 1], "smith");
}
process.exit(0);
`,
  );

  const result = spawnSync(
    "bun",
    [
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "4",
      "--seed",
      "0x5eed",
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
      "--remove-unused-brs",
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
  if (result.status !== 0) {
    fail(`pass-fuzz-compare failed:\n${result.stderr}`);
  }

  const moonLogs = fs.readFileSync(moonLog, "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line) as string[]);
  assert(moonLogs.length === 2, `expected compile and gen-valid moon invocations, got ${moonLogs.length}`);
  assert(
    JSON.stringify(moonLogs[0]) === JSON.stringify([
      "build",
      "--target",
      "native",
      "--release",
      "--package",
      "jtenner/starshine/cmd",
    ]),
    `unexpected compile invocation:\n${JSON.stringify(moonLogs[0], null, 2)}`,
  );
  assert(
    moonLogs[1].includes("--emit-gen-valid-batch"),
    `expected gen-valid batch invocation, got ${JSON.stringify(moonLogs[1], null, 2)}`,
  );

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    normalizedMatchCount: number;
    validationFailureCount: number;
    generatorCounts: { wasmSmith: number; genValid: number };
    passFlags: string[];
    binaryenPassFlags: string[];
  };
  assert(summary.requestedCount === 4, `unexpected requested count ${summary.requestedCount}`);
  assert(summary.comparedCount === 4, `unexpected compared count ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 4, `unexpected normalized match count ${summary.normalizedMatchCount}`);
  assert(summary.validationFailureCount === 0, `unexpected validation failure count ${summary.validationFailureCount}`);
  assert(summary.generatorCounts.wasmSmith === 2, `unexpected wasm-smith count ${summary.generatorCounts.wasmSmith}`);
  assert(summary.generatorCounts.genValid === 2, `unexpected gen-valid count ${summary.generatorCounts.genValid}`);
  assert(
    JSON.stringify(summary.passFlags) === JSON.stringify(["--remove-unused-brs"]),
    `unexpected pass flags ${JSON.stringify(summary.passFlags)}`,
  );
  assert(
    JSON.stringify(summary.binaryenPassFlags) === JSON.stringify(["--remove-unused-brs"]),
    `unexpected Binaryen pass flags ${JSON.stringify(summary.binaryenPassFlags)}`,
  );

  const starshineLogs = fs.readFileSync(starshineLog, "utf8").trim().split("\n").filter(Boolean);
  assert(starshineLogs.length === 4, `expected 4 Starshine runs, got ${starshineLogs.length}`);

  const wasmToolsLogs = fs.readFileSync(wasmToolsLog, "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line) as string[]);
  const smithCalls = wasmToolsLogs.filter((args) => args[0] === "smith");
  const validateCalls = wasmToolsLogs.filter((args) => args[0] === "validate");
  assert(smithCalls.length === 2, `expected 2 wasm-smith generations, got ${smithCalls.length}`);
  assert(validateCalls.length === 8, `expected baseline and Starshine validation for 4 cases, got ${validateCalls.length}`);
}

export function runPassFuzzCompareListPassesCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const result = spawnSync(
    "bun",
    [path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"), "--list-passes"],
    {
      cwd: repoRoot,
      encoding: "utf8",
    },
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare --list-passes failed:\n${result.stderr}`);
  }
  assert(result.stdout.includes("remove-unused-brs"), `expected remove-unused-brs in list output:\n${result.stdout}`);
  assert(result.stdout.includes("dead-code-elimination"), `expected dead-code-elimination in list output:\n${result.stdout}`);
  assert(!result.stdout.includes("--remove-unused-brs"), `expected canonical names without -- prefix:\n${result.stdout}`);
}

export function runPassFuzzComparePassAliasCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-pass-alias-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
if (args[0] === "run" && args.includes("src/fuzz")) {
  const outDir = args[args.indexOf("--out-dir") + 1];
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "gen-valid-000001.wasm"), "gen-valid-1");
}
process.exit(0);
`,
  );
  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(args) + "\\n");
const outIndex = args.indexOf("--out");
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "starshine");
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
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], "(module)\\n");
} else {
  fs.writeFileSync(args[outIndex + 1], "binaryen");
}
process.exit(0);
`,
  );
  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(args) + "\\n");
if (args[0] === "smith") {
  const outIndex = args.indexOf("-o");
  fs.writeFileSync(args[outIndex + 1], "smith");
}
process.exit(0);
`,
  );

  const result = spawnSync(
    "bun",
    [
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--seed",
      "0x5eed",
      "--generator",
      "gen-valid",
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
      "--pass",
      "remove-unused-brs",
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
  if (result.status !== 0) {
    fail(`pass-fuzz-compare with --pass failed:\n${result.stderr}`);
  }
  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    passFlags: string[];
  };
  assert(
    JSON.stringify(summary.passFlags) === JSON.stringify(["--remove-unused-brs"]),
    `expected --pass alias to normalize to flag, got ${JSON.stringify(summary.passFlags)}`,
  );
}

if (import.meta.main) {
  runPassFuzzCompareCommandTest();
  runPassFuzzCompareListPassesCommandTest();
  runPassFuzzComparePassAliasCommandTest();
}
