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
  fs.writeFileSync(inputPath, "input");

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
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
if (args.includes("--print")) {
  const input = args[0];
  if (input.endsWith("starshine.wasm")) {
    process.stdout.write("(module ;; starshine normalized)\\n");
  } else if (input.endsWith("binaryen.wasm")) {
    process.stdout.write("(module ;; binaryen normalized)\\n");
  } else {
    process.stdout.write("(module ;; unknown normalized)\\n");
  }
  process.exit(0);
}
const outIndex = args.indexOf("-o");
if (outIndex === -1 || outIndex + 1 >= args.length) {
  process.stderr.write("missing -o\\n");
  process.exit(1);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
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
      "--duplicate-function-elimination",
      "--dead-code-elimination",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_BINARYEN_LOG: binaryenLog,
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
  assert(
    JSON.stringify(starshineArgs) === JSON.stringify([
      "--duplicate-function-elimination",
      "--dead-code-elimination",
      "--out",
      path.join(outDir, "starshine.wasm"),
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
  assert(binaryenLogs.length === 3, `expected 3 wasm-opt invocations, got ${binaryenLogs.length}`);
  assert(
    JSON.stringify(binaryenLogs[0]) === JSON.stringify([
      inputPath,
      "--all-features",
      "--duplicate-function-elimination",
      "--dce",
      "-o",
      path.join(outDir, "binaryen.wasm"),
    ]),
    `unexpected Binaryen compare args:\n${JSON.stringify(binaryenLogs[0], null, 2)}`,
  );
  assert(binaryenLogs[1].includes("--print"), "expected Starshine normalization print invocation");
  assert(binaryenLogs[2].includes("--print"), "expected Binaryen normalization print invocation");

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    passFlags: string[];
    binaryenPassFlags: string[];
    starshineSize: number;
    binaryenSize: number;
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
  assert(summary.starshineSize === "starshine-wasm".length, `unexpected Starshine size: ${summary.starshineSize}`);
  assert(summary.binaryenSize === "binaryen-wasm".length, `unexpected Binaryen size: ${summary.binaryenSize}`);
  assert(summary.normalizedWatEqual === false, "expected normalized WAT mismatch");
  assert(
    fs.readFileSync(path.join(outDir, "starshine.print.wat"), "utf8").includes("starshine normalized"),
    "expected Starshine normalized WAT output",
  );
  assert(
    fs.readFileSync(path.join(outDir, "binaryen.print.wat"), "utf8").includes("binaryen normalized"),
    "expected Binaryen normalized WAT output",
  );
}

if (import.meta.main) {
  runSelfOptimizeCompareCommandTest();
}
