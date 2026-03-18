import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

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

function runBun(repoRoot: string, args: string[], env: NodeJS.ProcessEnv): string {
  return execFileSync("bun", args, {
    cwd: repoRoot,
    env,
    encoding: "utf8",
  });
}

export function runTaskFamilyCommandsTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-task-family-"));
  const logPath = path.join(tmpdir, "moon.log");
  const fakeMoonPath = makeExecutable(
    path.join(tmpdir, "moon"),
    `
const fs = require("node:fs");
const path = require("node:path");
const logPath = process.env.FAKE_MOON_LOG;
fs.appendFileSync(logPath, process.argv.slice(2).join(" ") + "\\n");
if (process.argv[2] === "coverage" && process.argv[3] === "analyze") {
  process.stdout.write("12 uncovered line(s) in src/lib/module.mbt:\\n");
  process.stdout.write("4 uncovered line(s) in src/cmd/cmd.mbt:\\n");
  process.stdout.write("Total: 16 uncovered line(s) in 2 file(s)\\n");
  process.exit(0);
}
if (process.argv[2] === "run" && process.argv[3] === "src/cmd") {
  let outDir = "";
  let configPath = "";
  const inputs = [];
  let passthrough = false;
  for (const token of process.argv.slice(4)) {
    if (token === "--") {
      passthrough = true;
      continue;
    }
    if (!passthrough) {
      continue;
    }
    if (token === "--out-dir") {
      continue;
    }
  }
  const args = process.argv.slice(4);
  for (let i = 0; i < args.length; i += 1) {
    const token = args[i];
    if (token === "--") {
      continue;
    }
    if (token === "--out-dir") {
      outDir = args[i + 1];
      i += 1;
      continue;
    }
    if (token === "--config") {
      configPath = args[i + 1];
      i += 1;
      continue;
    }
    if (["--target", "native", "--optimize", "--global-effects", "--flatten", "--vacuum"].includes(token)) {
      continue;
    }
    if (token.endsWith(".wat") || token.endsWith(".json")) {
      inputs.push(token);
    }
  }
  fs.mkdirSync(outDir, { recursive: true });
  if (configPath === "examples/config/optimize-release.json") {
    fs.writeFileSync(path.join(outDir, "feature_mix.wasm"), "x");
    fs.writeFileSync(path.join(outDir, "memory64_data.wasm"), "x");
    fs.writeFileSync(path.join(outDir, "simple.wasm"), "x");
  }
  for (const inputPath of inputs) {
    const stem = path.basename(inputPath).replace(/\\.[^.]+$/, "");
    fs.writeFileSync(path.join(outDir, stem + ".wasm"), "x");
  }
  process.exit(0);
}
process.exit(0);
`,
  );

  const baselinePath = path.join(tmpdir, "coverage-baseline.txt");
  fs.writeFileSync(baselinePath, "total=10\nfiles=1\n");

  const env = {
    ...process.env,
    FAKE_MOON_LOG: logPath,
    MOON_BIN: fakeMoonPath,
  };

  fs.writeFileSync(logPath, "");
  runBun(repoRoot, ["validate", "full", "--profile", "ci", "--seed", "0x5eed", "--target", "native"], env);
  const expectedValidate = [
    "info",
    "fmt",
    "check --target native",
    "test --target native",
    "run --target native src/fuzz -- all ci --seed 0x5eed",
  ].join("\n");
  const actualValidate = fs.readFileSync(logPath, "utf8").trim();
  assert(actualValidate === expectedValidate, `unexpected validate command log:\n${actualValidate}`);

  fs.writeFileSync(logPath, "");
  runBun(repoRoot, ["fuzz", "run", "--profile", "stress", "--suite", "cmd-harness", "--seed", "0xbeef", "--target", "wasm"], env);
  const actualFuzz = fs.readFileSync(logPath, "utf8").trim();
  assert(actualFuzz === "run --target wasm src/fuzz -- cmd-harness stress --seed 0xbeef", `unexpected fuzz command log:\n${actualFuzz}`);

  fs.writeFileSync(logPath, "");
  const coverageOutput = runBun(repoRoot, ["validate", "coverage", "--top", "2", "--baseline", baselinePath], env);
  assert(coverageOutput.includes("Coverage summary: total uncovered lines=16, files=2"), `unexpected coverage summary:\n${coverageOutput}`);
  assert(coverageOutput.includes(`Coverage delta vs baseline (${baselinePath}): lines +6, files +1`), `unexpected coverage delta:\n${coverageOutput}`);

  fs.writeFileSync(logPath, "");
  runBun(
    repoRoot,
    ["validate", "trace-benchmark", "--repeat", "2", "--corpus", "deep-control", "--corpus", "ref-func-heavy", "--target", "native"],
    env,
  );
  const actualTraceBenchmark = fs.readFileSync(logPath, "utf8").trim();
  assert(
    actualTraceBenchmark === "run --target native src/validate_trace -- --repeat 2 --corpus deep-control --corpus ref-func-heavy",
    `unexpected validate trace-benchmark command log:\n${actualTraceBenchmark}`,
  );

  const examplesRoot = path.join(tmpdir, "examples-smoke");
  runBun(repoRoot, ["examples", "smoke", "--root", examplesRoot], env);
  for (const expectedPath of [
    path.join(examplesRoot, "optimize-memory64", "memory64_data.wasm"),
    path.join(examplesRoot, "release-config", "feature_mix.wasm"),
    path.join(examplesRoot, "release-config", "memory64_data.wasm"),
    path.join(examplesRoot, "release-config", "simple.wasm"),
    path.join(examplesRoot, "advanced-features", "table_dispatch.wasm"),
    path.join(examplesRoot, "advanced-features", "simd_lane_mix.wasm"),
  ]) {
    assert(fs.existsSync(expectedPath) && fs.statSync(expectedPath).size > 0, `expected smoke output missing: ${expectedPath}`);
  }
}

if (import.meta.main) {
  runTaskFamilyCommandsTest();
}
