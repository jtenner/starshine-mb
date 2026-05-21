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
if (process.argv[2] === "run" && process.argv.includes("src/fuzz")) {
  const args = process.argv.slice(2);
  const outDir = args[args.indexOf("--out-dir") + 1];
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "gen-valid-000001.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000002.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000003.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000004.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000005.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000006.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000007.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000008.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000009.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000010.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000011.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000012.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000013.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000014.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000015.wasm"), "x");
  fs.writeFileSync(path.join(outDir, "gen-valid-000016.wasm"), "x");
  process.exit(0);
}
process.exit(0);
`,
  );
  const fakeStarshinePath = makeExecutable(
    path.join(tmpdir, "starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const outIndex = args.indexOf("--out");
if (outIndex !== -1) {
  fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
  fs.writeFileSync(args[outIndex + 1], "starshine");
}
process.exit(0);
`,
  );
  const fakeWasmOptPath = makeExecutable(
    path.join(tmpdir, "wasm-opt"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const outIndex = args.indexOf("-o");
if (outIndex !== -1) {
  fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
  if (args.includes("-S")) {
    fs.writeFileSync(args[outIndex + 1], "(module)\\n");
  } else {
    fs.writeFileSync(args[outIndex + 1], "binaryen");
  }
}
process.exit(0);
`,
  );
  const fakeWasmToolsPath = makeExecutable(
    path.join(tmpdir, "wasm-tools"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
if (args[0] === "smith") {
  const outIndex = args.indexOf("-o");
  fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
  fs.writeFileSync(args[outIndex + 1], "smith");
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
    WASM_OPT_BIN: fakeWasmOptPath,
    WASM_TOOLS_BIN: fakeWasmToolsPath,
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
  runBun(
    repoRoot,
    ["fuzz", "run", "--suite=cmd-harness", "--seed=0xfeed", "--output=jsonl", "--target", "wasm"],
    env,
  );
  const actualFuzzAlias = fs.readFileSync(logPath, "utf8").trim();
  assert(
    actualFuzzAlias === "run --target wasm src/fuzz -- cmd-harness smoke --seed 0xfeed --output jsonl",
    `unexpected fuzz alias command log:\n${actualFuzzAlias}`,
  );

  fs.writeFileSync(logPath, "");
  const fuzzReportPath = path.join(tmpdir, "fuzz-report.json");
  runBun(
    repoRoot,
    [
      "fuzz",
      "run",
      "--suite=cmd-harness",
      "--seed=0x10",
      "--seed-count=5",
      "--shard-index",
      "1",
      "--shard-count",
      "2",
      "--report-json",
      fuzzReportPath,
      "--target",
      "wasm",
    ],
    env,
  );
  const actualFuzzSweep = fs.readFileSync(logPath, "utf8").trim();
  assert(
    actualFuzzSweep === `run --target wasm src/fuzz -- cmd-harness smoke --seed 0x10 --seed-count 5 --shard-index 1 --shard-count 2 --report-json ${fuzzReportPath}`,
    `unexpected fuzz sweep command log:\n${actualFuzzSweep}`,
  );

  fs.writeFileSync(logPath, "");
  runBun(
    repoRoot,
    ["fuzz", "run", "--suite=cmd-harness", "--seed=0xcafe", "--target=wasm", `--moon=${fakeMoonPath}`],
    env,
  );
  const actualFuzzTargetAlias = fs.readFileSync(logPath, "utf8").trim();
  assert(
    actualFuzzTargetAlias === "run --target wasm src/fuzz -- cmd-harness smoke --seed 0xcafe",
    `unexpected fuzz target/moon alias command log:\n${actualFuzzTargetAlias}`,
  );

  fs.writeFileSync(logPath, "");
  runBun(
    repoRoot,
    ["fuzz", "run", "--suite=cmd-harness", "--profile=stress", "--seed=0x5eed", "--target=wasm"],
    env,
  );
  const actualFuzzSuiteProfileAlias = fs.readFileSync(logPath, "utf8").trim();
  assert(
    actualFuzzSuiteProfileAlias === "run --target wasm src/fuzz -- cmd-harness stress --seed 0x5eed",
    `unexpected fuzz suite/profile alias command log:\n${actualFuzzSuiteProfileAlias}`,
  );

  fs.writeFileSync(logPath, "");
  const fuzzBatchOutDir = path.join(tmpdir, "fuzz-batch-out");
  const fuzzBatchManifestPath = path.join(fuzzBatchOutDir, "manifest.json");
  runBun(
    repoRoot,
    [
      "fuzz",
      "run",
      "--emit-gen-valid-batch",
      "--count",
      "3",
      "--seed",
      "0x5eed",
      "--out-dir",
      fuzzBatchOutDir,
      "--gen-valid-profile",
      "coverage-forced",
      "--require-feature=v128",
      "--exclude-feature",
      "imports",
      "--max-attempts=12",
      "--manifest",
      fuzzBatchManifestPath,
    ],
    env,
  );
  const actualFuzzBatch = fs.readFileSync(logPath, "utf8").trim();
  assert(
    actualFuzzBatch === `run --target wasm-gc src/fuzz -- --emit-gen-valid-batch --count 3 --seed 0x5eed --out-dir ${fuzzBatchOutDir} --gen-valid-profile coverage-forced --require-feature v128 --exclude-feature imports --max-attempts 12 --manifest ${fuzzBatchManifestPath}`,
    `unexpected fuzz batch command log:\n${actualFuzzBatch}`,
  );

  fs.writeFileSync(logPath, "");
  const comparePassOutDir = path.join(tmpdir, "compare-pass-out");
  runBun(
    repoRoot,
    [
      "fuzz",
      "compare-pass",
      "--count",
      "32",
      "--seed",
      "0x5eed",
      "--pass",
      "remove-unused-brs",
      "--starshine-bin",
      fakeStarshinePath,
      "--out-dir",
      comparePassOutDir,
      "--moon",
      fakeMoonPath,
    ],
    env,
  );
  const actualComparePass = fs.readFileSync(logPath, "utf8").trim();
  const comparePassGenValidDir = path.relative(
    repoRoot,
    path.join(comparePassOutDir, "inputs", "gen-valid"),
  );
  assert(
    actualComparePass === `run --target native --release src/fuzz -- --emit-gen-valid-batch --count 16 --seed 0x5eed --out-dir ${comparePassGenValidDir} --manifest ${path.join(comparePassGenValidDir, "manifest.json")}`,
    `unexpected compare-pass command log:\n${actualComparePass}`,
  );

  fs.writeFileSync(logPath, "");
  const coverageOutput = runBun(repoRoot, ["validate", "coverage", "--top", "2", "--baseline", baselinePath], env);
  assert(coverageOutput.includes("Coverage summary: total uncovered lines=16, files=2"), `unexpected coverage summary:\n${coverageOutput}`);
  assert(coverageOutput.includes(`Coverage delta vs baseline (${baselinePath}): lines +6, files +1`), `unexpected coverage delta:\n${coverageOutput}`);

  fs.writeFileSync(logPath, "");
  runBun(repoRoot, ["fuzz", "run", "--help"], env);
  const actualFuzzHelp = fs.readFileSync(logPath, "utf8").trim();
  assert(
    actualFuzzHelp === "run --target wasm-gc src/fuzz -- --help",
    `unexpected fuzz help command log:\n${actualFuzzHelp}`,
  );

  fs.writeFileSync(logPath, "");
  runBun(repoRoot, ["fuzz", "run", "--list-suites"], env);
  const actualFuzzListSuites = fs.readFileSync(logPath, "utf8").trim();
  assert(
    actualFuzzListSuites === "run --target wasm-gc src/fuzz -- --list-suites",
    `unexpected fuzz list-suites command log:\n${actualFuzzListSuites}`,
  );

  fs.writeFileSync(logPath, "");
  runBun(repoRoot, ["fuzz", "run", "--list-profiles"], env);
  const actualFuzzListProfiles = fs.readFileSync(logPath, "utf8").trim();
  assert(
    actualFuzzListProfiles === "run --target wasm-gc src/fuzz -- --list-profiles",
    `unexpected fuzz list-profiles command log:\n${actualFuzzListProfiles}`,
  );

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
