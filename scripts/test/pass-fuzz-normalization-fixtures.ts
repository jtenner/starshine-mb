import fs from "node:fs";
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

function readJson(pathname: string): Record<string, unknown> {
  return JSON.parse(fs.readFileSync(pathname, "utf8")) as Record<string, unknown>;
}

function runFixtureCase(repoRoot: string, tmpdir: string, fixture: { name: string; starshine: string; binaryen: string; normalizedStarshine: string; normalizedBinaryen: string; expectMatch: boolean }): void {
  const outDir = path.join(tmpdir, fixture.name);

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, `starshine-${fixture.name}`),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const out = args[args.indexOf("--out") + 1];
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, ${JSON.stringify(fixture.starshine)});
process.exit(0);
`,
  );

  const fakeWasmOpt = makeExecutable(
    path.join(tmpdir, `wasm-opt-${fixture.name}`),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const out = args[args.indexOf("-o") + 1];
fs.mkdirSync(path.dirname(out), { recursive: true });
if (args.includes("-S")) {
  const input = fs.readFileSync(args[0], "utf8");
  if (input === ${JSON.stringify(fixture.starshine)}) fs.writeFileSync(out, ${JSON.stringify(fixture.normalizedStarshine)});
  else if (input === ${JSON.stringify(fixture.binaryen)}) fs.writeFileSync(out, ${JSON.stringify(fixture.normalizedBinaryen)});
  else fs.writeFileSync(out, input);
} else {
  const input = fs.existsSync(args[0]) ? fs.readFileSync(args[0], "utf8") : "";
  if (input === ${JSON.stringify(fixture.starshine)}) fs.writeFileSync(out, ${JSON.stringify(fixture.starshine)});
  else if (input === ${JSON.stringify(fixture.binaryen)}) fs.writeFileSync(out, ${JSON.stringify(fixture.binaryen)});
  else fs.writeFileSync(out, ${JSON.stringify(fixture.binaryen)});
}
process.exit(0);
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, `wasm-tools-${fixture.name}`),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
if (args[0] === "smith") {
  const out = args[args.indexOf("-o") + 1];
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, "smith-input");
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
      "wasm-smith",
      "--out-dir",
      outDir,
      "--starshine-bin",
      fakeStarshine,
      "--wasm-opt-bin",
      fakeWasmOpt,
      "--wasm-tools-bin",
      fakeWasmTools,
      "--remove-unused-brs",
    ],
    { cwd: repoRoot, encoding: "utf8" },
  );
  if (result.error) throw result.error;
  assert(result.status === 0, `${fixture.name}: expected compare command to complete, got ${result.status}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
  const summary = readJson(path.join(outDir, "result.json"));
  assert(summary.comparedCount === 1, `${fixture.name}: expected one compared case`);
  assert(
    summary.normalizedMatchCount === (fixture.expectMatch ? 1 : 0),
    `${fixture.name}: unexpected normalized match count ${summary.normalizedMatchCount}`,
  );
}

export function runPassFuzzNormalizationFixtureMatrixTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpRoot = path.join(repoRoot, ".tmp", "script-tests");
  fs.mkdirSync(tmpRoot, { recursive: true });
  const tmpdir = fs.mkdtempSync(path.join(tmpRoot, "pass-fuzz-normalization-"));
  const fixtures = [
    { name: "debug-stripped-equality", starshine: "debug-a", binaryen: "debug-b", normalizedStarshine: "(module (func))\n", normalizedBinaryen: "(module (func))\n", expectMatch: true },
    { name: "default-local-inequality", starshine: "default-local-a", binaryen: "default-local-b", normalizedStarshine: "(module (func (local i32)))\n", normalizedBinaryen: "(module (func (local i32) (local.set 0 (i32.const 0))))\n", expectMatch: false },
    { name: "nan-format-inequality", starshine: "nan-a", binaryen: "nan-b", normalizedStarshine: "(module (func (f32.const nan:0x1) drop))\n", normalizedBinaryen: "(module (func (f32.const nan:0x2) drop))\n", expectMatch: false },
    { name: "block-wrapper-inequality", starshine: "block-a", binaryen: "block-b", normalizedStarshine: "(module (func block end))\n", normalizedBinaryen: "(module (func))\n", expectMatch: false },
    { name: "local-name-stripped-equality", starshine: "name-a", binaryen: "name-b", normalizedStarshine: "(module (func (local i32) local.get 0 drop))\n", normalizedBinaryen: "(module (func (local i32) local.get 0 drop))\n", expectMatch: true },
    { name: "custom-section-stripped-equality", starshine: "custom-a", binaryen: "custom-b", normalizedStarshine: "(module (func))\n", normalizedBinaryen: "(module (func))\n", expectMatch: true },
    { name: "section-order-inequality", starshine: "section-a", binaryen: "section-b", normalizedStarshine: "(module (func) (memory 1))\n", normalizedBinaryen: "(module (memory 1) (func))\n", expectMatch: false },
  ];
  for (const fixture of fixtures) {
    runFixtureCase(repoRoot, tmpdir, fixture);
  }
}

if (import.meta.main) {
  runPassFuzzNormalizationFixtureMatrixTest();
}
