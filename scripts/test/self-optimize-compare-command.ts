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
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
  const orderLog = path.join(tmpdir, "order.log");
  fs.writeFileSync(inputPath, "input");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
fs.writeFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(process.argv.slice(2), null, 2));
fs.appendFileSync(process.env.FAKE_ORDER_LOG, "moon\\n");
process.exit(0);
`,
  );

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const start = Date.now();
while (Date.now() - start < 40) {}
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:duplicate-function-elimination elapsed_us=40000 total_us=40000\\n");
fs.writeFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(args, null, 2));
fs.appendFileSync(process.env.FAKE_ORDER_LOG, "starshine\\n");
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
const start = Date.now();
while (Date.now() - start < 10) {}
fs.appendFileSync(process.env.FAKE_BINARYEN_LOG, JSON.stringify(args) + "\\n");
const outIndex = args.indexOf("-o");
if (outIndex === -1 || outIndex + 1 >= args.length) {
  process.stderr.write("missing -o\\n");
  process.exit(1);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  const input = args[0];
  if (input.endsWith("starshine.wasm")) {
    fs.writeFileSync(args[outIndex + 1], "(module ;; canonical normalized)\\n");
  } else if (input.endsWith("binaryen.wasm")) {
    fs.writeFileSync(args[outIndex + 1], "(module ;; canonical normalized)\\n");
  } else {
    fs.writeFileSync(args[outIndex + 1], "(module ;; unknown normalized)\\n");
  }
  process.exit(0);
}
if (args.includes("--strip-debug")) {
  fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
  process.exit(0);
}
process.stderr.write("[PassRunner] passes took 0.010000 seconds.\\n");
fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.writeFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(args, null, 2));
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
      "--duplicate-function-elimination",
      "--dead-code-elimination",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_STARSHINE_LOG: starshineLog,
        FAKE_BINARYEN_LOG: binaryenLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
        FAKE_ORDER_LOG: orderLog,
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

  const moonArgs = JSON.parse(fs.readFileSync(moonLog, "utf8")) as string[];
  const starshineArgs = JSON.parse(fs.readFileSync(starshineLog, "utf8")) as string[];
  const wasmToolsArgs = JSON.parse(fs.readFileSync(wasmToolsLog, "utf8")) as string[];
  const order = fs.readFileSync(orderLog, "utf8").trim().split("\n").filter(Boolean);
  assert(
    JSON.stringify(moonArgs) === JSON.stringify([
      "build",
      "--target",
      "native",
      "--release",
      "--package",
      "jtenner/starshine/cmd",
    ]),
    `unexpected moon compile args:\n${JSON.stringify(moonArgs, null, 2)}`,
  );
  assert(order[0] === "moon", `expected compile to run first, got order ${JSON.stringify(order)}`);
  assert(order.includes("starshine"), `expected Starshine invocation in order log ${JSON.stringify(order)}`);
  assert(
    JSON.stringify(wasmToolsArgs) === JSON.stringify(["validate", inputPath]),
    `unexpected wasm-tools args:\n${JSON.stringify(wasmToolsArgs, null, 2)}`,
  );
  assert(
    JSON.stringify(starshineArgs) === JSON.stringify([
      "--duplicate-function-elimination",
      "--dead-code-elimination",
      "--out",
      path.join(outDir, "starshine.raw.wasm"),
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
  assert(binaryenLogs.length === 4, `expected 4 wasm-opt invocations, got ${binaryenLogs.length}`);
  assert(
    JSON.stringify(binaryenLogs[0]) === JSON.stringify([
      inputPath,
      "--all-features",
      "--duplicate-function-elimination",
      "--dce",
      "--debug",
      "-o",
      path.join(outDir, "binaryen.raw.wasm"),
    ]),
    `unexpected Binaryen compare args:\n${JSON.stringify(binaryenLogs[0], null, 2)}`,
  );
  assert(
    JSON.stringify(binaryenLogs[1]) === JSON.stringify([
      path.join(outDir, "starshine.raw.wasm"),
      "--all-features",
      "--strip-debug",
      "-o",
      path.join(outDir, "starshine.wasm"),
    ]),
    `unexpected Starshine canonicalization args:\n${JSON.stringify(binaryenLogs[1], null, 2)}`,
  );
  assert(binaryenLogs[2].includes("-S"), "expected Starshine normalization text invocation");
  assert(binaryenLogs[3].includes("-S"), "expected Binaryen normalization text invocation");

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    passFlags: string[];
    binaryenPassFlags: string[];
    starshineSize: number;
    binaryenSize: number;
    wasmEqual: boolean;
    starshineElapsedMs: number;
    binaryenElapsedMs: number;
    starshineAtLeastAsFast: boolean;
    starshinePassElapsedMs: number;
    starshinePassSkippedRaw: boolean;
    binaryenPassElapsedMs: number;
    starshinePassAtLeastAsFast: boolean;
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
  assert(summary.starshineSize === "binaryen-wasm".length, `unexpected Starshine size: ${summary.starshineSize}`);
  assert(summary.binaryenSize === "binaryen-wasm".length, `unexpected Binaryen size: ${summary.binaryenSize}`);
  assert(summary.wasmEqual === true, "expected canonical wasm equality");
  assert(summary.starshineElapsedMs >= 30, `expected measured Starshine runtime, got ${summary.starshineElapsedMs}`);
  assert(summary.binaryenElapsedMs >= 5, `expected measured Binaryen runtime, got ${summary.binaryenElapsedMs}`);
  assert(summary.starshineAtLeastAsFast === false, "expected Starshine runtime parity flag to report slower");
  assert(summary.starshinePassElapsedMs === 40, `expected parsed Starshine pass runtime, got ${summary.starshinePassElapsedMs}`);
  assert(summary.starshinePassSkippedRaw === false, "expected traced pass run not to report raw skip");
  assert(summary.binaryenPassElapsedMs === 10, `expected parsed Binaryen pass runtime, got ${summary.binaryenPassElapsedMs}`);
  assert(summary.starshinePassAtLeastAsFast === false, "expected Starshine pass parity flag to report slower");
  assert(summary.normalizedWatEqual === true, "expected normalized WAT equality");
  assert(
    fs.readFileSync(path.join(outDir, "starshine.wasm"), "utf8") ===
      fs.readFileSync(path.join(outDir, "binaryen.wasm"), "utf8"),
    "expected canonical wasm outputs to match exactly",
  );
  assert(
    fs.readFileSync(path.join(outDir, "starshine.raw.wasm"), "utf8") === "starshine-wasm",
    "expected preserved raw Starshine wasm output",
  );
  assert(
    fs.readFileSync(path.join(outDir, "binaryen.raw.wasm"), "utf8") === "binaryen-wasm",
    "expected preserved raw Binaryen wasm output",
  );
  assert(
    fs.readFileSync(path.join(outDir, "starshine.print.wat"), "utf8").includes("canonical normalized"),
    "expected Starshine normalized WAT output",
  );
  assert(
    fs.readFileSync(path.join(outDir, "binaryen.print.wat"), "utf8").includes("canonical normalized"),
    "expected Binaryen normalized WAT output",
  );
  assert(result.stdout.includes("Starshine runtime (ms):"), `expected Starshine runtime in stdout:\n${result.stdout}`);
  assert(result.stdout.includes("Binaryen runtime (ms):"), `expected Binaryen runtime in stdout:\n${result.stdout}`);
  assert(
    result.stdout.includes("Starshine at least as fast: no"),
    `expected runtime parity verdict in stdout:\n${result.stdout}`,
  );
  assert(result.stdout.includes("Starshine pass runtime (ms): 40.000"), `expected Starshine pass runtime in stdout:\n${result.stdout}`);
  assert(result.stdout.includes("Starshine pass skipped raw: no"), `expected raw-skip status in stdout:\n${result.stdout}`);
  assert(result.stdout.includes("Binaryen pass runtime (ms): 10.000"), `expected Binaryen pass runtime in stdout:\n${result.stdout}`);
  assert(
    result.stdout.includes("Starshine pass at least as fast: no"),
    `expected pass parity verdict in stdout:\n${result.stdout}`,
  );
}

export function runSelfOptimizeCompareBinaryenAliasPassFlagTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-alias-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
  fs.writeFileSync(inputPath, "input");

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
const path = require("node:path");
const args = process.argv.slice(2);
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:global-struct-inference elapsed_us=20000 total_us=20000\\n");
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
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], "(module)\\n");
  process.exit(0);
}
if (args.includes("--strip-debug")) {
  fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
  process.exit(0);
}
process.stderr.write("[PassRunner] passes took 0.010000 seconds.\\n");
fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
fs.writeFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(process.argv.slice(2), null, 2));
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
      "--gsi",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
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
    fail(`self-optimize-compare alias flag run failed:\n${result.stderr}`);
  }

  const starshineArgs = JSON.parse(fs.readFileSync(starshineLog, "utf8")) as string[];
  assert(
    JSON.stringify(starshineArgs) === JSON.stringify([
      "--global-struct-inference",
      "--out",
      path.join(outDir, "starshine.raw.wasm"),
      inputPath,
    ]),
    `unexpected Starshine alias-normalized args:\n${JSON.stringify(starshineArgs, null, 2)}`,
  );

  const binaryenLogs = fs
    .readFileSync(binaryenLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);
  assert(
    JSON.stringify(binaryenLogs[0]) === JSON.stringify([
      inputPath,
      "--all-features",
      "--gsi",
      "--debug",
      "-o",
      path.join(outDir, "binaryen.raw.wasm"),
    ]),
    `unexpected Binaryen alias args:\n${JSON.stringify(binaryenLogs[0], null, 2)}`,
  );
}

export function runSelfOptimizeComparePresetFlagTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-preset-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
  fs.writeFileSync(inputPath, "input");

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
const path = require("node:path");
const args = process.argv.slice(2);
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:optimize elapsed_us=20000 total_us=20000\\n");
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
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], "(module)\\n");
  process.exit(0);
}
if (args.includes("--strip-debug")) {
  fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
  process.exit(0);
}
process.stderr.write("[PassRunner] passes took 0.010000 seconds.\\n");
fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
fs.writeFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(process.argv.slice(2), null, 2));
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
      "--optimize",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
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
    fail(`self-optimize-compare preset flag run failed:\n${result.stderr}`);
  }

  const starshineArgs = JSON.parse(fs.readFileSync(starshineLog, "utf8")) as string[];
  assert(
    JSON.stringify(starshineArgs) === JSON.stringify([
      "--optimize",
      "--out",
      path.join(outDir, "starshine.raw.wasm"),
      inputPath,
    ]),
    `unexpected Starshine preset args:\n${JSON.stringify(starshineArgs, null, 2)}`,
  );

  const binaryenLogs = fs
    .readFileSync(binaryenLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);
  assert(
    JSON.stringify(binaryenLogs[0]) === JSON.stringify([
      inputPath,
      "--all-features",
      "-O",
      "--debug",
      "-o",
      path.join(outDir, "binaryen.raw.wasm"),
    ]),
    `unexpected Binaryen preset args:\n${JSON.stringify(binaryenLogs[0], null, 2)}`,
  );
}

export function runSelfOptimizeCompareTimingOnlyTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-timing-only-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const binaryenLog = path.join(tmpdir, "binaryen.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
  fs.writeFileSync(inputPath, "input");

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
const path = require("node:path");
const args = process.argv.slice(2);
process.stderr.write("[trace] input fixture:opt perf:timer name=pass:dead-argument-elimination-optimizing elapsed_us=25000 total_us=25000\\n");
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
if (args.includes("-S")) {
  process.stderr.write("timing-only mode should not print normalized WAT\\n");
  process.exit(2);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("--strip-debug")) {
  fs.writeFileSync(args[outIndex + 1], "canonical-wasm");
  process.exit(0);
}
process.stderr.write("[PassRunner] passes took 0.012000 seconds.\\n");
fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
fs.writeFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(process.argv.slice(2), null, 2));
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
      "--timing-only",
      "--dae-optimizing",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
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
    fail(`self-optimize-compare timing-only run failed:\n${result.stderr}`);
  }

  const starshineArgs = JSON.parse(fs.readFileSync(starshineLog, "utf8")) as string[];
  assert(
    JSON.stringify(starshineArgs) === JSON.stringify([
      "--dead-argument-elimination-optimizing",
      "--out",
      path.join(outDir, "starshine.raw.wasm"),
      inputPath,
    ]),
    `unexpected Starshine timing-only args:\n${JSON.stringify(starshineArgs, null, 2)}`,
  );

  const binaryenLogs = fs
    .readFileSync(binaryenLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);
  assert(binaryenLogs.length === 2, `expected compare plus Starshine canonicalization calls, got ${binaryenLogs.length}`);
  assert(!fs.existsSync(path.join(outDir, "starshine.print.wat")), "timing-only mode should skip Starshine WAT output");
  assert(!fs.existsSync(path.join(outDir, "binaryen.print.wat")), "timing-only mode should skip Binaryen WAT output");

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    timingOnly: boolean;
    normalizedWatTextEqual: boolean | null;
    canonicalFuncPrettyEqual: boolean | null;
    normalizedWatEqual: boolean | null;
    firstDifferingFuncDefinedIndex: number | null;
    firstDifferingFuncAbsIndex: number | null;
    starshinePassElapsedMs: number;
    binaryenPassElapsedMs: number;
  };
  assert(summary.timingOnly === true, `expected timingOnly summary flag:\n${JSON.stringify(summary, null, 2)}`);
  assert(summary.normalizedWatTextEqual === null, "expected timing-only normalized text equality to be null");
  assert(summary.canonicalFuncPrettyEqual === null, "expected timing-only canonical function equality to be null");
  assert(summary.normalizedWatEqual === null, "expected timing-only normalized equality to be null");
  assert(summary.firstDifferingFuncDefinedIndex === null, "expected timing-only first diff defined index to be null");
  assert(summary.firstDifferingFuncAbsIndex === null, "expected timing-only first diff abs index to be null");
  assert(summary.starshinePassElapsedMs === 25, `expected Starshine pass timing, got ${summary.starshinePassElapsedMs}`);
  assert(summary.binaryenPassElapsedMs === 12, `expected Binaryen pass timing, got ${summary.binaryenPassElapsedMs}`);
}

export function runSelfOptimizeCompareDefaultStarshineInvocationTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-default-"));
  const inputPath = path.join(tmpdir, "input.wasm");
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const starshineLog = path.join(tmpdir, "starshine.log");
  fs.writeFileSync(inputPath, "input");

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "fake-moon"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_MOON_LOG, JSON.stringify(args) + "\\n");
if (args[0] === "build") {
  const repoRoot = process.cwd();
  const builtBin = path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd.exe");
  fs.mkdirSync(path.dirname(builtBin), { recursive: true });
  fs.writeFileSync(
    builtBin,
    '#!/usr/bin/env node\\n' +
      'const fs = require("node:fs");\\n' +
      'const path = require("node:path");\\n' +
      'const args = process.argv.slice(2);\\n' +
      'fs.writeFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(args, null, 2));\\n' +
      'const outIndex = args.indexOf("--out");\\n' +
      'if (outIndex === -1 || outIndex + 1 >= args.length) {\\n' +
      '  process.stderr.write("missing --out\\\\n");\\n' +
      '  process.exit(1);\\n' +
      '}\\n' +
      'fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });\\n' +
      'fs.writeFileSync(args[outIndex + 1], "starshine-wasm");\\n' +
      'process.stderr.write("[trace] input fixture:opt perf:timer name=pass:pick-load-signs elapsed_us=40000 total_us=40000\\\\n");\\n',
  );
  fs.chmodSync(builtBin, 0o755);
}
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
if (outIndex === -1 || outIndex + 1 >= args.length) {
  process.stderr.write("missing -o\\n");
  process.exit(1);
}
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], "(module)\\n");
  process.exit(0);
}
if (args.includes("--strip-debug")) {
  fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
  process.exit(0);
}
process.stderr.write("[PassRunner] passes took 0.010000 seconds.\\n");
fs.writeFileSync(args[outIndex + 1], "binaryen-wasm");
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
fs.writeFileSync(process.env.FAKE_WASM_TOOLS_LOG, JSON.stringify(process.argv.slice(2), null, 2));
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
      "--wasm-opt-bin",
      fakeWasmOpt,
      "--wasm-tools-bin",
      fakeWasmTools,
      "--pick-load-signs",
    ],
    {
      cwd: tmpdir,
      env: {
        ...process.env,
        FAKE_MOON_LOG: moonLog,
        FAKE_WASM_TOOLS_LOG: wasmToolsLog,
        FAKE_WASM_OPT_LOG: wasmOptLog,
        FAKE_STARSHINE_LOG: starshineLog,
      },
      encoding: "utf8",
    },
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`self-optimize-compare default starshine invocation failed:\n${result.stderr}`);
  }

  const moonLogs = fs
    .readFileSync(moonLog, "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as string[]);
  assert(moonLogs.length === 1, `expected only compile moon invocation, got ${moonLogs.length}`);
  assert(
    JSON.stringify(moonLogs[0]) === JSON.stringify([
      "build",
      "--target",
      "native",
      "--release",
      "--package",
      "jtenner/starshine/cmd",
    ]),
    `unexpected default compile invocation:\n${JSON.stringify(moonLogs[0], null, 2)}`,
  );
  const starshineArgs = JSON.parse(fs.readFileSync(starshineLog, "utf8")) as string[];
  assert(
    JSON.stringify(starshineArgs) === JSON.stringify([
      "--pick-load-signs",
      "--out",
      path.join(outDir, "starshine.raw.wasm"),
      inputPath,
    ]),
    `expected default invocation to use built Starshine binary, got ${JSON.stringify(starshineArgs, null, 2)}`,
  );
}

if (import.meta.main) {
  runSelfOptimizeCompareCommandTest();
  runSelfOptimizeCompareBinaryenAliasPassFlagTest();
  runSelfOptimizeComparePresetFlagTest();
  runSelfOptimizeCompareDefaultStarshineInvocationTest();
}
