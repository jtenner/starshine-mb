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

export function runPassFuzzCompareNoReduceMismatchesTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-no-reduce-"));
  const outDir = path.join(tmpdir, "out");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
if (args[0] === "run" && args.includes("src/fuzz")) {
  const outDir = args[args.indexOf("--out-dir") + 1];
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "gen-valid-000001.wasm"), "noiseTRIGGERtail");
  fs.writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify({ records: [
    { file_name: "gen-valid-000001.wasm", feature_facts: { has_trigger: true } },
  ] }));
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
const outIndex = args.indexOf("--out");
if (outIndex === -1) process.exit(1);
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
const outIndex = args.indexOf("-o");
if (outIndex === -1) process.exit(1);
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], fs.readFileSync(args[0], "utf8") + "\\n");
} else if (args.includes("--remove-unused-brs")) {
  fs.writeFileSync(args[outIndex + 1], "binaryen");
} else {
  fs.copyFileSync(args[0], args[outIndex + 1]);
}
process.exit(0);
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
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--generator",
      "gen-valid",
      "--max-failures",
      "1",
      "--no-reduce-mismatches",
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
    { cwd: repoRoot, encoding: "utf8" },
  );

  if (result.error) throw result.error;
  if (result.status !== 0) {
    fail(`pass-fuzz-compare --no-reduce-mismatches failed:\n${result.stderr}`);
  }

  const resultJson = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    reduceMismatches?: boolean;
    mismatchCount: number;
  };
  assert(resultJson.reduceMismatches === false, `expected reduceMismatches=false, got ${JSON.stringify(resultJson)}`);
  assert(resultJson.mismatchCount === 1, `expected one mismatch, got ${JSON.stringify(resultJson)}`);

  const failureDir = path.join(outDir, "failures", "case-000001-gen-valid");
  assert(fs.existsSync(path.join(failureDir, "input.wasm")), "expected mismatch input artifact");
  assert(!fs.existsSync(path.join(failureDir, "reduced-input.wasm")), "did not expect reduced input artifact");
  assert(!fs.existsSync(path.join(failureDir, "reduction.txt")), "did not expect reduction log artifact");

  const metadata = JSON.parse(fs.readFileSync(path.join(failureDir, "failure-metadata.json"), "utf8")) as {
    reduction: unknown | null;
  };
  assert(metadata.reduction === null, `expected null reduction metadata, got ${JSON.stringify(metadata)}`);
}

if (import.meta.main) {
  runPassFuzzCompareNoReduceMismatchesTest();
}
