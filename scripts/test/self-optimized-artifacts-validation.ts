import fs from "node:fs";
import os from "node:os";
import path from "node:path";

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

export async function runSelfOptimizedArtifactsValidationTest(): Promise<void> {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-artifacts-"));
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(${JSON.stringify(wasmToolsLog)}, JSON.stringify(args) + "\\n");
process.exit(0);
`,
  );

  const debugSource = path.join(tmpdir, "_build", "wasm", "debug", "build", "cmd", "cmd.wasm");
  const releaseSource = path.join(tmpdir, "_build", "wasm", "release", "build", "cmd", "cmd.wasm");
  fs.mkdirSync(path.dirname(debugSource), { recursive: true });
  fs.mkdirSync(path.dirname(releaseSource), { recursive: true });
  fs.writeFileSync(path.join(tmpdir, "moon.mod.json"), "{}\n");
  fs.writeFileSync(debugSource, "debug-wasm");
  fs.writeFileSync(releaseSource, "release-wasm");

  const modulePath = path.join(repoRoot, "scripts", "lib", "self-optimized-artifacts.mjs");
  const artifacts = (await import(modulePath)) as {
    copyWasmArtifacts: (args: { repoRoot: string }) => {
      debug: { path: string; size: number };
      optimized: { path: string; size: number };
    };
  };

  const prev = process.env.WASM_TOOLS_BIN;
  process.env.WASM_TOOLS_BIN = fakeWasmTools;
  try {
    const copied = artifacts.copyWasmArtifacts({ repoRoot: tmpdir });
    assert(fs.existsSync(copied.debug.path), `expected copied debug artifact: ${copied.debug.path}`);
    assert(fs.existsSync(copied.optimized.path), `expected copied optimized artifact: ${copied.optimized.path}`);
  } finally {
    if (prev === undefined) {
      delete process.env.WASM_TOOLS_BIN;
    } else {
      process.env.WASM_TOOLS_BIN = prev;
    }
  }

  const logLines = fs
    .readFileSync(wasmToolsLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);
  assert(logLines.length === 2, `expected 2 wasm-tools validations, got ${logLines.length}`);
  assert(
    JSON.stringify(logLines[0]) === JSON.stringify([
      "validate",
      path.join(tmpdir, "tests", "node", "dist", "starshine-debug-wasi.wasm"),
    ]),
    `unexpected debug validation args:\n${JSON.stringify(logLines[0], null, 2)}`,
  );
  assert(
    JSON.stringify(logLines[1]) === JSON.stringify([
      "validate",
      path.join(tmpdir, "tests", "node", "dist", "starshine-optimized-wasi.wasm"),
    ]),
    `unexpected optimized validation args:\n${JSON.stringify(logLines[1], null, 2)}`,
  );
}

if (import.meta.main) {
  await runSelfOptimizedArtifactsValidationTest();
}
