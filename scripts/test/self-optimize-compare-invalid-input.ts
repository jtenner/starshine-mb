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

export function runSelfOptimizeCompareInvalidInputTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-invalid-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  fs.writeFileSync(inputPath, "not-wasm");

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
process.exit(0);
`,
  );

  const fakeWasmOpt = makeExecutable(
    path.join(tmpdir, "fake-wasm-opt"),
    `
const fs = require("node:fs");
fs.appendFileSync(process.env.FAKE_BINARYEN_LOG, JSON.stringify(process.argv.slice(2)) + "\\n");
process.exit(0);
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
process.stderr.write("validation failed: bad baseline\\n");
process.exit(1);
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
      "--duplicate-function-elimination",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_BINARYEN_LOG: binaryenLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  assert(result.status !== 0, "expected invalid baseline compare run to fail");
  assert(
    result.stderr.includes("input baseline is invalid and cannot be compared"),
    `expected invalid baseline error, got:\n${result.stderr}`,
  );
  assert(
    result.stderr.includes("validation failed: bad baseline"),
    `expected wasm-tools validation details, got:\n${result.stderr}`,
  );
  assert(fs.existsSync(moonLog), "expected compare harness to compile before validation");
  assert(!fs.existsSync(starshineLog), "expected Starshine not to run on invalid input");
  assert(!fs.existsSync(binaryenLog), "expected Binaryen not to run on invalid input");
}

if (import.meta.main) {
  runSelfOptimizeCompareInvalidInputTest();
}
