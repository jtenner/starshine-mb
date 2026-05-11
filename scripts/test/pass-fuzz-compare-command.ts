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

function readJsonlLog(pathname: string): string[][] {
  if (!fs.existsSync(pathname)) {
    return [];
  }
  return fs.readFileSync(pathname, "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line) as string[]);
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

  const moonLogs = readJsonlLog(moonLog);
  assert(moonLogs.length === 1, `expected gen-valid-only moon invocation, got ${moonLogs.length}`);
  assert(
    moonLogs[0].includes("--emit-gen-valid-batch"),
    `expected gen-valid batch invocation, got ${JSON.stringify(moonLogs[0], null, 2)}`,
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
  assert(result.stdout.includes("heap2local"), `expected heap2local in list output:\n${result.stdout}`);
  assert(result.stdout.includes("reorder-locals"), `expected reorder-locals in list output:\n${result.stdout}`);
  assert(result.stdout.includes("directize"), `expected directize in list output:\n${result.stdout}`);
  assert(result.stdout.includes("untee"), `expected untee in list output:\n${result.stdout}`);
  assert(result.stdout.includes("dead-code-elimination"), `expected dead-code-elimination in list output:\n${result.stdout}`);
  assert(result.stdout.includes("precompute"), `expected precompute in list output:\n${result.stdout}`);
  assert(result.stdout.includes("code-pushing"), `expected code-pushing in list output:\n${result.stdout}`);
  assert(result.stdout.includes("tuple-optimization"), `expected tuple-optimization in list output:\n${result.stdout}`);
  assert(result.stdout.includes("dae-optimizing"), `expected dae-optimizing in list output:\n${result.stdout}`);
  assert(result.stdout.includes("simplify-locals-notee-nostructure"), `expected simplify-locals-notee-nostructure in list output:\n${result.stdout}`);
  assert(!result.stdout.includes("--remove-unused-brs"), `expected canonical names without -- prefix:\n${result.stdout}`);
}

export function runPassFuzzCompareListFailureClassesCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const result = spawnSync(
    "bun",
    [path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"), "--list-failure-classes"],
    {
      cwd: repoRoot,
      encoding: "utf8",
    },
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare --list-failure-classes failed:\n${result.stderr}`);
  }
  assert(result.stdout.includes("starshine-invalid-limits"), `expected starshine-invalid-limits in list output:\n${result.stdout}`);
  assert(result.stdout.includes("starshine-invalid-range-for-limits"), `expected starshine-invalid-range-for-limits in list output:\n${result.stdout}`);
  assert(result.stdout.includes("binaryen-rec-group-zero"), `expected binaryen-rec-group-zero in list output:\n${result.stdout}`);
  assert(result.stdout.includes("binaryen-invalid-wasm-type-neg64"), `expected binaryen-invalid-wasm-type-neg64 in list output:\n${result.stdout}`);
  assert(result.stdout.includes("binaryen-initializer-expression-not-constant"), `expected binaryen-initializer-expression-not-constant in list output:\n${result.stdout}`);
  assert(result.stdout.includes("binaryen-table-index-out-of-range"), `expected binaryen-table-index-out-of-range in list output:\n${result.stdout}`);
  assert(result.stdout.includes("binaryen-bad-section-size"), `expected binaryen-bad-section-size in list output:\n${result.stdout}`);
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
      "heap2local",
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
    JSON.stringify(summary.passFlags) === JSON.stringify(["--heap2local"]),
    `expected --pass alias to normalize to flag, got ${JSON.stringify(summary.passFlags)}`,
  );
}

export function runPassFuzzCompareTupleOptimizationPassAliasCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-tuple-pass-alias-"));
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
      "tuple-optimization",
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
    fail(`pass-fuzz-compare with tuple-optimization --pass failed:\n${result.stderr}`);
  }
  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    passFlags: string[];
    binaryenPassFlags: string[];
  };
  assert(
    JSON.stringify(summary.passFlags) === JSON.stringify(["--tuple-optimization"]),
    `expected tuple-optimization --pass alias to normalize to flag, got ${JSON.stringify(summary.passFlags)}`,
  );
  assert(
    JSON.stringify(summary.binaryenPassFlags) === JSON.stringify(["--tuple-optimization"]),
    `expected tuple-optimization binaryen flags to stay canonical, got ${JSON.stringify(summary.binaryenPassFlags)}`,
  );
}

export function runPassFuzzCompareWasmSmithOnlyCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-wasm-smith-only-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
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
      "2",
      "--generator",
      "wasm-smith",
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
    fail(`pass-fuzz-compare with wasm-smith-only failed:\n${result.stderr}`);
  }

  const moonLogs = readJsonlLog(moonLog);
  assert(moonLogs.length === 0, `expected no moon invocations for wasm-smith-only with explicit starshine bin, got ${moonLogs.length}`);

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    comparedCount: number;
    normalizedMatchCount: number;
    generatorCounts: { wasmSmith: number; genValid: number };
  };
  assert(summary.comparedCount === 2, `unexpected compared count ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 2, `unexpected normalized match count ${summary.normalizedMatchCount}`);
  assert(summary.generatorCounts.wasmSmith === 2, `unexpected wasm-smith count ${summary.generatorCounts.wasmSmith}`);
  assert(summary.generatorCounts.genValid === 0, `unexpected gen-valid count ${summary.generatorCounts.genValid}`);
}

export function runPassFuzzCompareCommandFailureAccumulationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-command-failure-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
  for (let i = 1; i <= 10; i += 1) {
    fs.writeFileSync(path.join(outDir, "gen-valid-" + String(i).padStart(6, "0") + ".wasm"), "gen-valid-" + i);
  }
}
process.exit(0);
`,
  );

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(args) + "\\n");
process.stderr.write("synthetic starshine failure\\n");
process.exit(1);
`,
  );

  const fakeWasmOpt = makeExecutable(
    path.join(tmpdir, "fake-wasm-opt"),
    `
process.exit(0);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "10",
      "--generator",
      "gen-valid",
      "--max-failures",
      "3",
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
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare command-failure accumulation failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    commandFailureCount: number;
    commandFailureClasses: Record<string, number>;
    maxFailuresHit: boolean;
    failureDirs: string[];
  };
  assert(summary.requestedCount === 10, `unexpected requested count ${summary.requestedCount}`);
  assert(summary.comparedCount === 0, `expected 0 compared cases, got ${summary.comparedCount}`);
  assert(summary.commandFailureCount === 3, `expected 3 command failures, got ${summary.commandFailureCount}`);
  assert(summary.commandFailureClasses["starshine-command-failed"] === 3, `expected 3 Starshine command failures, got ${JSON.stringify(summary.commandFailureClasses)}`);
  assert(summary.maxFailuresHit, "expected maxFailuresHit for repeated command failures");
  assert(summary.failureDirs.length === 3, `expected 3 failure dirs, got ${summary.failureDirs.length}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 3, `expected 3 recorded cases, got ${cases.length}`);
  for (const line of cases) {
    const entry = JSON.parse(line) as { status: string; detail: string };
    assert(entry.status === "command-failure", `expected command-failure status, got ${entry.status}`);
    assert(entry.detail.includes("synthetic starshine failure"), `expected command stderr in detail, got ${entry.detail}`);
  }

  const metadataPath = path.join(outDir, "failures", "case-000001-gen-valid", "failure-metadata.json");
  assert(fs.existsSync(metadataPath), `expected persisted failure metadata at ${metadataPath}`);
  const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8")) as {
    caseIndex: number;
    generator: string;
    detail: string;
    artifacts: string[];
    replay: { input: string; passFlags: string[] };
  };
  assert(metadata.caseIndex === 1, `unexpected failure metadata case index ${metadata.caseIndex}`);
  assert(metadata.generator === "gen-valid", `unexpected failure metadata generator ${metadata.generator}`);
  assert(metadata.detail.includes("synthetic starshine failure"), `expected failure detail in metadata, got ${metadata.detail}`);
  assert(metadata.artifacts.includes("input.wasm"), `expected input.wasm in artifact manifest, got ${metadata.artifacts.join(",")}`);
  assert(metadata.replay.input === "input.wasm", `expected relative replay input, got ${metadata.replay.input}`);
  assert(JSON.stringify(metadata.replay.passFlags) === JSON.stringify(["--remove-unused-brs"]), `unexpected replay pass flags ${JSON.stringify(metadata.replay.passFlags)}`);

  const starshineLogs = fs.readFileSync(starshineLog, "utf8").trim().split("\n").filter(Boolean);
  assert(starshineLogs.length === 3, `expected 3 Starshine runs before cutoff, got ${starshineLogs.length}`);
}

export function runPassFuzzCompareKeepGoingAfterCommandFailuresTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-keep-going-command-failure-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
  for (let i = 1; i <= 3; i += 1) {
    fs.writeFileSync(path.join(outDir, "gen-valid-" + String(i).padStart(6, "0") + ".wasm"), "gen-valid-" + i);
  }
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
process.stderr.write("[parse exception: invalid type index: 0 (at 0:13)]\\n");
process.exit(1);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "3",
      "--generator",
      "gen-valid",
      "--max-failures",
      "1",
      "--keep-going-after-command-failures",
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
      "remove-unused-module-elements",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare keep-going-after-command-failures failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    commandFailureCount: number;
    commandFailureClasses: Record<string, number>;
    commandFailuresCountTowardMaxFailures: boolean;
    maxFailuresHit: boolean;
    failureDirs: string[];
  };
  assert(summary.requestedCount === 3, `unexpected requested count ${summary.requestedCount}`);
  assert(summary.comparedCount === 0, `expected 0 compared cases, got ${summary.comparedCount}`);
  assert(summary.commandFailureCount === 3, `expected 3 command failures, got ${summary.commandFailureCount}`);
  assert(summary.commandFailureClasses["binaryen-invalid-type-index"] === 3, `expected 3 invalid-type-index failures, got ${JSON.stringify(summary.commandFailureClasses)}`);
  assert(!summary.commandFailuresCountTowardMaxFailures, "expected command failures to be excluded from max-failures cutoff");
  assert(!summary.maxFailuresHit, "did not expect maxFailuresHit when only command failures were recorded");
  assert(summary.failureDirs.length === 3, `expected 3 failure dirs, got ${summary.failureDirs.length}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 3, `expected 3 recorded cases, got ${cases.length}`);
  const starshineLogs = fs.readFileSync(starshineLog, "utf8").trim().split("\n").filter(Boolean);
  assert(starshineLogs.length === 3, `expected 3 Starshine runs when command failures do not stop the batch, got ${starshineLogs.length}`);
}

export function runPassFuzzCompareBinaryenFailureClassificationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-binaryen-failure-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
const args = process.argv.slice(2);
if (args.includes("-S")) {
  process.stdout.write("");
  process.exit(0);
}
process.stderr.write("[parse exception: invalid type index: 0 (at 0:13)]\\n");
process.exit(1);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--generator",
      "gen-valid",
      "--max-failures",
      "1",
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
      "remove-unused-names",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare Binaryen failure classification failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    commandFailureCount: number;
    commandFailureClasses: Record<string, number>;
  };
  assert(summary.commandFailureCount === 1, `expected 1 command failure, got ${summary.commandFailureCount}`);
  assert(summary.commandFailureClasses["binaryen-invalid-type-index"] === 1, `expected invalid-type-index classification, got ${JSON.stringify(summary.commandFailureClasses)}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 recorded case, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { status: string; failureClass?: string };
  assert(entry.status === "command-failure", `expected command-failure status, got ${entry.status}`);
  assert(entry.failureClass === "binaryen-invalid-type-index", `expected classified case record, got ${JSON.stringify(entry)}`);
}

export function runPassFuzzCompareStarshineInvalidLimitsClassificationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-starshine-invalid-limits-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
process.stderr.write("error: decode failed for /tmp/input.wasm: DecodeAt(InvalidLimits, 11, 17)\\n");
process.exit(1);
`,
  );
  const fakeWasmOpt = makeExecutable(
    path.join(tmpdir, "fake-wasm-opt"),
    `
process.exit(0);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--generator",
      "gen-valid",
      "--max-failures",
      "1",
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
      "remove-unused-module-elements",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare Starshine invalid-limits classification failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    commandFailureCount: number;
    commandFailureClasses: Record<string, number>;
  };
  assert(summary.commandFailureCount === 1, `expected 1 command failure, got ${summary.commandFailureCount}`);
  assert(summary.commandFailureClasses["starshine-invalid-limits"] === 1, `expected starshine-invalid-limits classification, got ${JSON.stringify(summary.commandFailureClasses)}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 recorded case, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { status: string; failureClass?: string };
  assert(entry.status === "command-failure", `expected command-failure status, got ${entry.status}`);
  assert(entry.failureClass === "starshine-invalid-limits", `expected classified case record, got ${JSON.stringify(entry)}`);
}

export function runPassFuzzCompareStarshineInvalidRangeForLimitsClassificationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-starshine-invalid-range-for-limits-"));
  const replayDir = path.join(tmpdir, "saved");
  const replayFailureDir = path.join(replayDir, "failures", "case-000073-wasm-smith");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

  fs.mkdirSync(replayFailureDir, { recursive: true });
  fs.writeFileSync(
    path.join(replayDir, "cases.jsonl"),
    JSON.stringify({
      caseIndex: 73,
      generator: "wasm-smith",
      status: "command-failure",
      detail: "Starshine command failed: error: final module validate: Invalid range for limits",
    }) + "\n",
  );
  fs.writeFileSync(path.join(replayFailureDir, "input.wasm"), "saved-invalid-range-for-limits");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
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
fs.writeFileSync(args[outIndex + 1], args.includes("-S") ? "(module)\\n" : "binaryen");
process.exit(0);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
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
      "--replay-failures-from",
      replayDir,
      "--failure-class",
      "starshine-invalid-range-for-limits",
      "--pass",
      "remove-unused-module-elements",
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
    fail(`pass-fuzz-compare Starshine invalid-range-for-limits replay failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    normalizedMatchCount: number;
    mismatchCount: number;
  };
  assert(summary.requestedCount === 1, `expected 1 replayed case, got ${summary.requestedCount}`);
  assert(summary.comparedCount === 1, `expected 1 compared replay case, got ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 1, `expected replayed match, got ${summary.normalizedMatchCount}`);
  assert(summary.mismatchCount === 0, `expected 0 replay mismatches, got ${summary.mismatchCount}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 replay case record, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { caseIndex: number; status: string };
  assert(entry.caseIndex === 73, `expected original case index 73, got ${entry.caseIndex}`);
  assert(entry.status === "match", `expected replayed match status, got ${entry.status}`);

  const moonLogs = readJsonlLog(moonLog);
  assert(moonLogs.length === 0, `expected no moon invocations during replay with explicit starshine bin, got ${moonLogs.length}`);
}

export function runPassFuzzCompareBinaryenInitializerExpressionNotConstantClassificationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-binaryen-init-expr-constant-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
const args = process.argv.slice(2);
if (args.includes("-S")) {
  process.stdout.write("");
  process.exit(0);
}
process.stderr.write("error: final module validate: initializer expression is not constant\\n");
process.exit(1);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--generator",
      "gen-valid",
      "--max-failures",
      "1",
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
      "remove-unused-module-elements",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare Binaryen initializer-expression classification failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    commandFailureCount: number;
    commandFailureClasses: Record<string, number>;
  };
  assert(summary.commandFailureCount === 1, `expected 1 command failure, got ${summary.commandFailureCount}`);
  assert(summary.commandFailureClasses["binaryen-initializer-expression-not-constant"] === 1, `expected initializer-expression classification, got ${JSON.stringify(summary.commandFailureClasses)}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 recorded case, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { status: string; failureClass?: string };
  assert(entry.status === "command-failure", `expected command-failure status, got ${entry.status}`);
  assert(entry.failureClass === "binaryen-initializer-expression-not-constant", `expected classified case record, got ${JSON.stringify(entry)}`);
}

export function runPassFuzzCompareReplayBinaryenInitializerExpressionNotConstantFailureClassTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-replay-init-expr-constant-"));
  const replayDir = path.join(tmpdir, "saved");
  const replayFailureDir = path.join(replayDir, "failures", "case-000103-wasm-smith");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

  fs.mkdirSync(replayFailureDir, { recursive: true });
  fs.writeFileSync(
    path.join(replayDir, "cases.jsonl"),
    JSON.stringify({
      caseIndex: 103,
      generator: "wasm-smith",
      status: "command-failure",
      detail: "Binaryen/canonicalization command failed: error: final module validate: initializer expression is not constant",
    }) + "\n",
  );
  fs.writeFileSync(path.join(replayFailureDir, "input.wasm"), "saved-init-expr-not-constant");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
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
fs.writeFileSync(args[outIndex + 1], args.includes("-S") ? "(module)\\n" : "binaryen");
process.exit(0);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
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
      "--replay-failures-from",
      replayDir,
      "--failure-class",
      "binaryen-initializer-expression-not-constant",
      "--pass",
      "remove-unused-module-elements",
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
    fail(`pass-fuzz-compare replay initializer-expression failure class failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    normalizedMatchCount: number;
    mismatchCount: number;
  };
  assert(summary.requestedCount === 1, `expected 1 replayed case, got ${summary.requestedCount}`);
  assert(summary.comparedCount === 1, `expected 1 compared replay case, got ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 1, `expected replayed match, got ${summary.normalizedMatchCount}`);
  assert(summary.mismatchCount === 0, `expected 0 replay mismatches, got ${summary.mismatchCount}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 replay case record, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { caseIndex: number; status: string };
  assert(entry.caseIndex === 103, `expected original case index 103, got ${entry.caseIndex}`);
  assert(entry.status === "match", `expected replayed match status, got ${entry.status}`);

  const moonLogs = readJsonlLog(moonLog);
  assert(moonLogs.length === 0, `expected no moon invocations during replay with explicit starshine bin, got ${moonLogs.length}`);
}

export function runPassFuzzCompareBinaryenTableIndexOutOfRangeClassificationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-binaryen-table-index-range-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
const args = process.argv.slice(2);
if (args.includes("-S")) {
  process.stdout.write("");
  process.exit(0);
}
process.stderr.write("[parse exception: Table index out of range. (at 0:43)]\\n");
process.exit(1);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--generator",
      "gen-valid",
      "--max-failures",
      "1",
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
      "remove-unused-names",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare Binaryen table-index-out-of-range classification failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    commandFailureCount: number;
    commandFailureClasses: Record<string, number>;
  };
  assert(summary.commandFailureCount === 1, `expected 1 command failure, got ${summary.commandFailureCount}`);
  assert(summary.commandFailureClasses["binaryen-table-index-out-of-range"] === 1, `expected table-index-out-of-range classification, got ${JSON.stringify(summary.commandFailureClasses)}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 recorded case, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { status: string; failureClass?: string };
  assert(entry.status === "command-failure", `expected command-failure status, got ${entry.status}`);
  assert(entry.failureClass === "binaryen-table-index-out-of-range", `expected classified case record, got ${JSON.stringify(entry)}`);
}

export function runPassFuzzCompareReplayBinaryenTableIndexOutOfRangeFailureClassTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-replay-table-index-range-"));
  const replayDir = path.join(tmpdir, "saved");
  const replayFailureDir = path.join(replayDir, "failures", "case-006013-wasm-smith");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

  fs.mkdirSync(replayFailureDir, { recursive: true });
  fs.writeFileSync(
    path.join(replayDir, "cases.jsonl"),
    JSON.stringify({
      caseIndex: 6013,
      generator: "wasm-smith",
      status: "command-failure",
      detail: "Binaryen/canonicalization command failed: [parse exception: Table index out of range. (at 0:43)]",
    }) + "\n",
  );
  fs.writeFileSync(path.join(replayFailureDir, "input.wasm"), "saved-table-index-out-of-range");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
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
fs.writeFileSync(args[outIndex + 1], args.includes("-S") ? "(module)\\n" : "binaryen");
process.exit(0);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
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
      "--replay-failures-from",
      replayDir,
      "--failure-class",
      "binaryen-table-index-out-of-range",
      "--pass",
      "remove-unused-names",
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
    fail(`pass-fuzz-compare replay table-index-out-of-range failure class failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    normalizedMatchCount: number;
    mismatchCount: number;
  };
  assert(summary.requestedCount === 1, `expected 1 replayed case, got ${summary.requestedCount}`);
  assert(summary.comparedCount === 1, `expected 1 compared replay case, got ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 1, `expected replayed match, got ${summary.normalizedMatchCount}`);
  assert(summary.mismatchCount === 0, `expected 0 replay mismatches, got ${summary.mismatchCount}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 replay case record, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { caseIndex: number; status: string };
  assert(entry.caseIndex === 6013, `expected original case index 6013, got ${entry.caseIndex}`);
  assert(entry.status === "match", `expected replayed match status, got ${entry.status}`);

  const moonLogs = readJsonlLog(moonLog);
  assert(moonLogs.length === 0, `expected no moon invocations during replay with explicit starshine bin, got ${moonLogs.length}`);
}

export function runPassFuzzCompareBinaryenBadSectionSizeClassificationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-binaryen-bad-section-size-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
const args = process.argv.slice(2);
if (args.includes("-S")) {
  process.stdout.write("");
  process.exit(0);
}
process.stderr.write("[parse exception: bad section size, started at 30 plus payload 8 not being equal to new position 34 (at 0:34)]\\n");
process.exit(1);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--generator",
      "gen-valid",
      "--max-failures",
      "1",
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
      "remove-unused-names",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare Binaryen bad-section-size classification failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    commandFailureCount: number;
    commandFailureClasses: Record<string, number>;
  };
  assert(summary.commandFailureCount === 1, `expected 1 command failure, got ${summary.commandFailureCount}`);
  assert(summary.commandFailureClasses["binaryen-bad-section-size"] === 1, `expected bad-section-size classification, got ${JSON.stringify(summary.commandFailureClasses)}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 recorded case, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { status: string; failureClass?: string };
  assert(entry.status === "command-failure", `expected command-failure status, got ${entry.status}`);
  assert(entry.failureClass === "binaryen-bad-section-size", `expected classified case record, got ${JSON.stringify(entry)}`);
}

export function runPassFuzzCompareReplayBinaryenBadSectionSizeFailureClassTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-replay-bad-section-size-"));
  const replayDir = path.join(tmpdir, "saved");
  const replayFailureDir = path.join(replayDir, "failures", "case-003815-wasm-smith");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

  fs.mkdirSync(replayFailureDir, { recursive: true });
  fs.writeFileSync(
    path.join(replayDir, "cases.jsonl"),
    JSON.stringify({
      caseIndex: 3815,
      generator: "wasm-smith",
      status: "command-failure",
      detail: "Binaryen/canonicalization command failed: [parse exception: bad section size, started at 30 plus payload 8 not being equal to new position 34 (at 0:34)]",
    }) + "\n",
  );
  fs.writeFileSync(path.join(replayFailureDir, "input.wasm"), "saved-bad-section-size");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
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
fs.writeFileSync(args[outIndex + 1], args.includes("-S") ? "(module)\\n" : "binaryen");
process.exit(0);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
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
      "--replay-failures-from",
      replayDir,
      "--failure-class",
      "binaryen-bad-section-size",
      "--pass",
      "remove-unused-names",
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
    fail(`pass-fuzz-compare replay bad-section-size failure class failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    normalizedMatchCount: number;
    mismatchCount: number;
  };
  assert(summary.requestedCount === 1, `expected 1 replayed case, got ${summary.requestedCount}`);
  assert(summary.comparedCount === 1, `expected 1 compared replay case, got ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 1, `expected replayed match, got ${summary.normalizedMatchCount}`);
  assert(summary.mismatchCount === 0, `expected 0 replay mismatches, got ${summary.mismatchCount}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 replay case record, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { caseIndex: number; status: string };
  assert(entry.caseIndex === 3815, `expected original case index 3815, got ${entry.caseIndex}`);
  assert(entry.status === "match", `expected replayed match status, got ${entry.status}`);

  const moonLogs = readJsonlLog(moonLog);
  assert(moonLogs.length === 0, `expected no moon invocations during replay with explicit starshine bin, got ${moonLogs.length}`);
}

export function runPassFuzzCompareBinaryenInvalidTagIndexClassificationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-binaryen-tag-index-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
const args = process.argv.slice(2);
if (args.includes("-S")) {
  process.stdout.write("");
  process.exit(0);
}
process.stderr.write("[parse exception: invalid tag index (at 0:54)]\\n");
process.exit(1);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--generator",
      "gen-valid",
      "--max-failures",
      "1",
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
      "remove-unused-names",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare Binaryen invalid-tag-index classification failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    commandFailureCount: number;
    commandFailureClasses: Record<string, number>;
  };
  assert(summary.commandFailureCount === 1, `expected 1 command failure, got ${summary.commandFailureCount}`);
  assert(summary.commandFailureClasses["binaryen-invalid-tag-index"] === 1, `expected invalid-tag-index classification, got ${JSON.stringify(summary.commandFailureClasses)}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 recorded case, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { status: string; failureClass?: string };
  assert(entry.status === "command-failure", `expected command-failure status, got ${entry.status}`);
  assert(entry.failureClass === "binaryen-invalid-tag-index", `expected classified case record, got ${JSON.stringify(entry)}`);
  const watPath = path.join(outDir, "failures", "case-000001-gen-valid", "input.print.wat");
  assert(fs.existsSync(watPath), `expected saved printed WAT at ${watPath}`);
}

export function runPassFuzzCompareReplayFailureClassTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-replay-failure-class-"));
  const replayDir = path.join(tmpdir, "saved");
  const replayFailureDir = path.join(replayDir, "failures", "case-000009-wasm-smith");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

  fs.mkdirSync(replayFailureDir, { recursive: true });
  fs.writeFileSync(
    path.join(replayDir, "cases.jsonl"),
    [
      JSON.stringify({
        caseIndex: 9,
        generator: "wasm-smith",
        status: "command-failure",
        detail: "Binaryen/canonicalization command failed: parse exception: invalid type index: 0",
        failureClass: "binaryen-invalid-type-index",
      }),
      JSON.stringify({
        caseIndex: 29,
        generator: "wasm-smith",
        status: "command-failure",
        detail: "Binaryen/canonicalization command failed: parse exception: Recursion groups of size zero not supported",
        failureClass: "binaryen-rec-group-zero",
      }),
    ].join("\n") + "\n",
  );
  fs.writeFileSync(path.join(replayFailureDir, "input.wasm"), "saved-invalid-type-index");
  fs.mkdirSync(path.join(replayDir, "failures", "case-000029-wasm-smith"), { recursive: true });
  fs.writeFileSync(
    path.join(replayDir, "failures", "case-000029-wasm-smith", "input.wasm"),
    "saved-rec-group-zero",
  );

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
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
fs.writeFileSync(args[outIndex + 1], args.includes("-S") ? "(module)\\n" : "binaryen");
process.exit(0);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
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
      "--replay-failures-from",
      replayDir,
      "--failure-class",
      "binaryen-invalid-type-index",
      "--pass",
      "remove-unused-names",
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
    fail(`pass-fuzz-compare replay-by-failure-class failed:\n${result.stderr}`);
  }

  const moonLogs = readJsonlLog(moonLog);
  assert(moonLogs.length === 0, `expected no moon invocations during replay with explicit starshine bin, got ${moonLogs.length}`);

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    normalizedMatchCount: number;
    mismatchCount: number;
  };
  assert(summary.requestedCount === 1, `expected 1 replayed case, got ${summary.requestedCount}`);
  assert(summary.comparedCount === 1, `expected 1 compared replay case, got ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 1, `expected replayed match, got ${summary.normalizedMatchCount}`);
  assert(summary.mismatchCount === 0, `expected 0 replay mismatches, got ${summary.mismatchCount}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 replay case record, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { caseIndex: number; status: string };
  assert(entry.caseIndex === 9, `expected original case index 9, got ${entry.caseIndex}`);
  assert(entry.status === "match", `expected replayed match status, got ${entry.status}`);

  const starshineLogs = fs.readFileSync(starshineLog, "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line) as string[]);
  assert(starshineLogs.length === 1, `expected 1 Starshine replay, got ${starshineLogs.length}`);
}

export function runPassFuzzCompareReplayLegacyCaseIndexTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-replay-case-index-"));
  const replayDir = path.join(tmpdir, "saved");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

  fs.mkdirSync(path.join(replayDir, "failures", "case-000662-wasm-smith"), { recursive: true });
  fs.mkdirSync(path.join(replayDir, "failures", "case-000029-wasm-smith"), { recursive: true });
  fs.writeFileSync(
    path.join(replayDir, "cases.jsonl"),
    [
      JSON.stringify({
        caseIndex: 662,
        generator: "wasm-smith",
        status: "command-failure",
        detail: "Binaryen/canonicalization command failed: parse exception: invalid tag index (at 0:54)",
      }),
      JSON.stringify({
        caseIndex: 29,
        generator: "wasm-smith",
        status: "command-failure",
        detail: "Binaryen/canonicalization command failed: parse exception: Recursion groups of size zero not supported",
      }),
    ].join("\n") + "\n",
  );
  fs.writeFileSync(
    path.join(replayDir, "failures", "case-000662-wasm-smith", "input.wasm"),
    "saved-invalid-tag-index",
  );
  fs.writeFileSync(
    path.join(replayDir, "failures", "case-000029-wasm-smith", "input.wasm"),
    "saved-rec-group-zero",
  );

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
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
const args = process.argv.slice(2);
if (args.includes("-S")) {
  process.stdout.write("");
  process.exit(0);
}
process.stderr.write("[parse exception: invalid tag index (at 0:54)]\\n");
process.exit(1);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
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
      "--replay-failures-from",
      replayDir,
      "--case-index",
      "662",
      "--pass",
      "remove-unused-names",
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
    fail(`pass-fuzz-compare replay legacy case-index failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    commandFailureCount: number;
    commandFailureClasses: Record<string, number>;
  };
  assert(summary.requestedCount === 1, `expected 1 replayed legacy case, got ${summary.requestedCount}`);
  assert(summary.commandFailureCount === 1, `expected 1 command failure, got ${summary.commandFailureCount}`);
  assert(summary.commandFailureClasses["binaryen-invalid-tag-index"] === 1, `expected invalid-tag-index replay classification, got ${JSON.stringify(summary.commandFailureClasses)}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 replay case record, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { caseIndex: number; failureClass?: string };
  assert(entry.caseIndex === 662, `expected original case index 662, got ${entry.caseIndex}`);
  assert(entry.failureClass === "binaryen-invalid-tag-index", `expected replayed invalid-tag-index classification, got ${JSON.stringify(entry)}`);
}

export function runPassFuzzCompareMinComparedGateTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-min-compared-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
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
const args = process.argv.slice(2);
if (args.includes("-S")) {
  process.stdout.write("");
  process.exit(0);
}
process.stderr.write("[parse exception: invalid type index: 0 (at 0:13)]\\n");
process.exit(1);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--min-compared",
      "1",
      "--generator",
      "gen-valid",
      "--max-failures",
      "1",
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
      "remove-unused-names",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  assert(result.status !== 0, "expected min-compared gate failure");
  assert(
    result.stderr.includes("below required minimum 1"),
    `expected min-compared failure message, got:\n${result.stderr}`,
  );

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    minCompared: number | null;
    comparedCount: number;
    commandFailureCount: number;
  };
  assert(summary.minCompared === 1, `expected minCompared=1, got ${summary.minCompared}`);
  assert(summary.comparedCount === 0, `expected comparedCount=0, got ${summary.comparedCount}`);
  assert(summary.commandFailureCount === 1, `expected commandFailureCount=1, got ${summary.commandFailureCount}`);
}

export function runPassFuzzCompareDefaultStarshineInvocationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-default-starshine-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const moonEnvLog = path.join(tmpdir, "moon-env.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
fs.appendFileSync(process.env.FAKE_MOON_ENV_LOG, JSON.stringify({
  tmpdir: process.env.TMPDIR ?? null,
  tmp: process.env.TMP ?? null,
  temp: process.env.TEMP ?? null,
}) + "\\n");
if (args[0] === "run" && args.includes("src/fuzz")) {
  const outDir = args[args.indexOf("--out-dir") + 1];
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "gen-valid-000001.wasm"), "gen-valid-1");
  process.exit(0);
}
if (args[0] === "run" && args.includes("src/cmd")) {
  const outIndex = args.indexOf("--out");
  fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
  fs.writeFileSync(args[outIndex + 1], "starshine");
  process.exit(0);
}
process.exit(1);
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
fs.writeFileSync(args[outIndex + 1], args.includes("-S") ? "(module)\\n" : "binaryen");
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
      "1",
      "--generator",
      "gen-valid",
      "--out-dir",
      outDir,
      "--moon",
      fakeMoon,
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
        FAKE_MOON_ENV_LOG: moonEnvLog,
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
    fail(`pass-fuzz-compare default starshine invocation failed:\n${result.stderr}`);
  }

  const moonLogs = readJsonlLog(moonLog);
  assert(moonLogs.length === 2, `expected gen-valid and starshine moon invocations, got ${moonLogs.length}`);
  const moonEnvLogs = fs.readFileSync(moonEnvLog, "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line) as {
    tmpdir: string | null;
    tmp: string | null;
    temp: string | null;
  });
  assert(moonEnvLogs.length === 2, `expected env logs for both moon invocations, got ${moonEnvLogs.length}`);
  assert(
    moonLogs[0].includes("--emit-gen-valid-batch"),
    `expected gen-valid batch invocation first, got ${JSON.stringify(moonLogs[0], null, 2)}`,
  );
  assert(
    JSON.stringify(moonLogs[1].slice(0, 6)) === JSON.stringify(["run", "--target", "native", "--release", "src/cmd", "--"]),
    `expected default starshine invocation via moon run --release, got ${JSON.stringify(moonLogs[1], null, 2)}`,
  );
  assert(
    moonLogs[1].includes("--remove-unused-brs"),
    `expected pass flag in default starshine invocation, got ${JSON.stringify(moonLogs[1], null, 2)}`,
  );
  for (const envLog of moonEnvLogs) {
    const expectedTmp = path.join(repoRoot, ".tmp", "codex-tmp");
    assert(envLog.tmpdir === expectedTmp, `expected TMPDIR=${expectedTmp}, got ${JSON.stringify(envLog)}`);
    assert(envLog.tmp === expectedTmp, `expected TMP=${expectedTmp}, got ${JSON.stringify(envLog)}`);
    assert(envLog.temp === expectedTmp, `expected TEMP=${expectedTmp}, got ${JSON.stringify(envLog)}`);
  }
}

export function runPassFuzzCompareDefaultStarshineInvocationRetriesMissingOutputTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-default-starshine-retry-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineState = path.join(tmpdir, "starshine-state.txt");
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
  process.exit(0);
}
if (args[0] === "run" && args.includes("src/cmd")) {
  const attempt = fs.existsSync(process.env.FAKE_STARSHINE_STATE)
    ? Number(fs.readFileSync(process.env.FAKE_STARSHINE_STATE, "utf8"))
    : 0;
  fs.writeFileSync(process.env.FAKE_STARSHINE_STATE, String(attempt + 1));
  if (attempt === 0) {
    process.exit(0);
  }
  const outIndex = args.indexOf("--out");
  fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
  fs.writeFileSync(args[outIndex + 1], "starshine");
  process.exit(0);
}
process.exit(1);
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
fs.writeFileSync(args[outIndex + 1], args.includes("-S") ? "(module)\\n" : "binaryen");
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
      "1",
      "--generator",
      "gen-valid",
      "--out-dir",
      outDir,
      "--moon",
      fakeMoon,
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
        FAKE_STARSHINE_STATE: starshineState,
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
    fail(`pass-fuzz-compare default starshine retry failed:\n${result.stderr}`);
  }

  const moonLogs = readJsonlLog(moonLog);
  assert(moonLogs.length === 3, `expected gen-valid plus two starshine launcher invocations, got ${moonLogs.length}`);
  assert(
    JSON.stringify(moonLogs[1]) === JSON.stringify(moonLogs[2]),
    `expected retried moon invocations to match, got ${JSON.stringify(moonLogs.slice(1), null, 2)}`,
  );
  assert(
    fs.readFileSync(starshineState, "utf8") === "2",
    `expected exactly two starshine attempts, got ${fs.readFileSync(starshineState, "utf8")}`,
  );

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    comparedCount: number;
    normalizedMatchCount: number;
    validationFailureCount: number;
    commandFailureCount: number;
  };
  assert(summary.comparedCount === 1, `unexpected compared count ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 1, `unexpected normalized match count ${summary.normalizedMatchCount}`);
  assert(summary.validationFailureCount === 0, `unexpected validation failure count ${summary.validationFailureCount}`);
  assert(summary.commandFailureCount === 0, `unexpected command failure count ${summary.commandFailureCount}`);

  const wasmToolsLogs = fs.readFileSync(wasmToolsLog, "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line) as string[]);
  const validateCalls = wasmToolsLogs.filter((args) => args[0] === "validate");
  assert(validateCalls.length === 2, `expected baseline and final starshine validation only, got ${validateCalls.length}`);
}

if (import.meta.main) {
  runPassFuzzCompareCommandTest();
  runPassFuzzCompareListPassesCommandTest();
  runPassFuzzCompareListFailureClassesCommandTest();
  runPassFuzzComparePassAliasCommandTest();
  runPassFuzzCompareTupleOptimizationPassAliasCommandTest();
  runPassFuzzCompareWasmSmithOnlyCommandTest();
  runPassFuzzCompareCommandFailureAccumulationTest();
  runPassFuzzCompareKeepGoingAfterCommandFailuresTest();
  runPassFuzzCompareBinaryenFailureClassificationTest();
  runPassFuzzCompareBinaryenInitializerExpressionNotConstantClassificationTest();
  runPassFuzzCompareReplayBinaryenInitializerExpressionNotConstantFailureClassTest();
  runPassFuzzCompareBinaryenTableIndexOutOfRangeClassificationTest();
  runPassFuzzCompareReplayBinaryenTableIndexOutOfRangeFailureClassTest();
  runPassFuzzCompareBinaryenBadSectionSizeClassificationTest();
  runPassFuzzCompareReplayBinaryenBadSectionSizeFailureClassTest();
  runPassFuzzCompareStarshineInvalidLimitsClassificationTest();
  runPassFuzzCompareStarshineInvalidRangeForLimitsClassificationTest();
  runPassFuzzCompareBinaryenInvalidTagIndexClassificationTest();
  runPassFuzzCompareReplayFailureClassTest();
  runPassFuzzCompareReplayLegacyCaseIndexTest();
  runPassFuzzCompareMinComparedGateTest();
  runPassFuzzCompareDefaultStarshineInvocationTest();
  runPassFuzzCompareDefaultStarshineInvocationRetriesMissingOutputTest();
}
