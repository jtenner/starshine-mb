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
  fs.writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify({ records: [
    { file_name: "gen-valid-000001.wasm", transform_id: "add-non-name-custom-section" },
    { file_name: "gen-valid-000002.wasm", transform_id: "add-non-name-custom-section" },
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
      "--jobs",
      "2",
      "--gen-valid-profile",
      "relaxed-simd",
      "--require-feature",
      "v128",
      "--exclude-feature=imports",
      "--gen-valid-metamorphic-transform",
      "add-non-name-custom-section",
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
  assert(
    JSON.stringify(moonLogs[0]).includes('"--gen-valid-profile","relaxed-simd"'),
    `expected gen-valid profile forwarding, got ${JSON.stringify(moonLogs[0], null, 2)}`,
  );
  assert(
    JSON.stringify(moonLogs[0]).includes('"--require-feature","v128"'),
    `expected gen-valid required feature forwarding, got ${JSON.stringify(moonLogs[0], null, 2)}`,
  );
  assert(
    JSON.stringify(moonLogs[0]).includes('"--exclude-feature","imports"'),
    `expected gen-valid excluded feature forwarding, got ${JSON.stringify(moonLogs[0], null, 2)}`,
  );
  assert(
    JSON.stringify(moonLogs[0]).includes('"--metamorphic-transform","add-non-name-custom-section"'),
    `expected gen-valid metamorphic transform forwarding, got ${JSON.stringify(moonLogs[0], null, 2)}`,
  );

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    normalizedMatchCount: number;
    validationFailureCount: number;
    jobs: number;
    generatorCounts: { wasmSmith: number; genValid: number };
    genValidProfile: string | null;
    genValidRequiredFeatures: string[];
    genValidExcludedFeatures: string[];
    genValidMetamorphicTransforms: string[];
    genValidManifestPath: string | null;
    genValidTransformCounts: Record<string, number>;
    inputEffectTrapCounts: Record<string, number>;
    runtimeExecutionMatrix: {
      summary: {
        total: number;
        semanticMismatches: number;
      };
      outcome: string;
      semanticMismatchSamples: unknown[];
    };
    passFlags: string[];
    binaryenPassFlags: string[];
  };
  assert(summary.requestedCount === 4, `unexpected requested count ${summary.requestedCount}`);
  assert(summary.comparedCount === 4, `unexpected compared count ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 4, `unexpected normalized match count ${summary.normalizedMatchCount}`);
  assert(summary.validationFailureCount === 0, `unexpected validation failure count ${summary.validationFailureCount}`);
  assert(summary.jobs === 2, `expected 2 parallel jobs, got ${summary.jobs}`);
  assert(summary.generatorCounts.wasmSmith === 2, `unexpected wasm-smith count ${summary.generatorCounts.wasmSmith}`);
  assert(summary.generatorCounts.genValid === 2, `unexpected gen-valid count ${summary.generatorCounts.genValid}`);
  assert(summary.genValidProfile === "relaxed-simd", `unexpected gen-valid profile ${summary.genValidProfile}`);
  assert(JSON.stringify(summary.genValidRequiredFeatures) === JSON.stringify(["v128"]), `unexpected required features ${JSON.stringify(summary.genValidRequiredFeatures)}`);
  assert(JSON.stringify(summary.genValidExcludedFeatures) === JSON.stringify(["imports"]), `unexpected excluded features ${JSON.stringify(summary.genValidExcludedFeatures)}`);
  assert(JSON.stringify(summary.genValidMetamorphicTransforms) === JSON.stringify(["add-non-name-custom-section"]), `unexpected metamorphic transforms ${JSON.stringify(summary.genValidMetamorphicTransforms)}`);
  assert(summary.genValidManifestPath === path.join("inputs", "gen-valid", "manifest.json"), `unexpected manifest path ${summary.genValidManifestPath}`);
  assert(
    summary.genValidTransformCounts["add-non-name-custom-section"] === 2,
    `expected per-transform gen-valid count, got ${JSON.stringify(summary.genValidTransformCounts)}`,
  );
  assert(
    summary.inputEffectTrapCounts.mayTrap === 4,
    `expected four may-trap fake byte-stream inputs, got ${JSON.stringify(summary.inputEffectTrapCounts)}`,
  );
  assert(
    summary.inputEffectTrapCounts.hasUnreachable === 0,
    `unexpected unreachable count ${JSON.stringify(summary.inputEffectTrapCounts)}`,
  );
  assert(
    summary.runtimeExecutionMatrix.outcome === "not-run",
    `expected runtime matrix to be persisted as not-run by default, got ${JSON.stringify(summary.runtimeExecutionMatrix)}`,
  );
  assert(
    summary.runtimeExecutionMatrix.summary.total === 0 && summary.runtimeExecutionMatrix.semanticMismatchSamples.length === 0,
    `expected empty default runtime matrix summary/samples, got ${JSON.stringify(summary.runtimeExecutionMatrix)}`,
  );
  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").map((line) => JSON.parse(line) as { generator: string; transformId?: string; genValidFeatureFacts?: Record<string, unknown>; inputEffectTrapFacts?: Record<string, boolean> });
  assert(cases.length === 4, `expected 4 case records, got ${cases.length}`);
  assert(
    cases.every((record) => record.inputEffectTrapFacts && typeof record.inputEffectTrapFacts.mayTrap === "boolean"),
    `expected per-case effect/trap facts in cases.jsonl, got ${JSON.stringify(cases, null, 2)}`,
  );
  const genValidCases = cases.filter((record) => record.generator === "gen-valid");
  assert(
    genValidCases.length === 2 && genValidCases.every((record) => record.transformId === "add-non-name-custom-section"),
    `expected gen-valid case metadata to preserve transform ids, got ${JSON.stringify(cases, null, 2)}`,
  );
  assert(
    genValidCases.every((record) => record.genValidFeatureFacts && record.genValidFeatureFacts.mode === "coverage-forced"),
    `expected gen-valid case metadata to preserve manifest feature facts, got ${JSON.stringify(cases, null, 2)}`,
  );
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
  assert(
    validateCalls.every((args) => JSON.stringify(args.slice(0, 3)) === JSON.stringify(["validate", "--features", "all"])),
    `expected wasm-tools validation to enable all features, got ${JSON.stringify(validateCalls, null, 2)}`,
  );
}

export function runPassFuzzCompareDropConstsNormalizerCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-drop-consts-"));
  const outDir = path.join(tmpdir, "out");

export function runPassFuzzCompareIdempotencePropertyTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-idempotence-"));
  const outDir = path.join(tmpdir, "out");
  const starshineLog = path.join(tmpdir, "starshine.log");

  const fakeMoon = makeExecutable(path.join(tmpdir, "fake-moon"), `process.exit(0);`);
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

fs.appendFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(args) + "\\n");
const outIndex = args.indexOf("--out");
if (outIndex === -1) process.exit(1);
const input = fs.readFileSync(args[args.length - 1], "utf8");
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], input.startsWith("starshine:") ? input : "starshine:" + input);
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
const output = args[outIndex + 1];
if (args.includes("-S")) {
  if (args[0].endsWith("binaryen.wasm")) {
    fs.writeFileSync(output, '(module\\n (func $0\\n  (drop\\n   (i32.eq\\n    (i32.const 11)\\n    (i32.const 3)\\n   )\\n  )\\n  (unreachable)\\n )\\n)\\n');
  } else {
    fs.writeFileSync(output, '(module\\n (func $0\\n  (unreachable)\\n )\\n)\\n');
  }
} else {
  fs.writeFileSync(output, "wasm:" + path.basename(args[0]));
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], fs.readFileSync(args[0], "utf8") + "\\n");
} else {
  fs.copyFileSync(args[0], args[outIndex + 1]);
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
      "--seed",
      "0x5eed",
      "--out-dir",
      outDir,
      "2",
      "--generator",
      "wasm-smith",
      "--property",
      "idempotence",
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
      "--generator",
      "wasm-smith",
      "--normalize",
      "drop-consts",
      "--pass",
      "dae-optimizing",
    ],
    { cwd: repoRoot, encoding: "utf8" },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    fail(`pass-fuzz-compare drop-consts normalizer failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    normalizedMatchCount: number;
    cleanupNormalizedMatchCount: number;
    mismatchCount: number;
    normalizers: string[];
  };
  assert(summary.normalizedMatchCount === 0, `expected no exact matches, got ${summary.normalizedMatchCount}`);
  assert(
    summary.cleanupNormalizedMatchCount === 1,
    `expected one drop-consts compare-normalized match, got ${summary.cleanupNormalizedMatchCount}`,
  );
  assert(summary.mismatchCount === 0, `expected no mismatches, got ${summary.mismatchCount}`);
  assert(JSON.stringify(summary.normalizers) === JSON.stringify(["drop-consts"]), `unexpected normalizers ${JSON.stringify(summary.normalizers)}`);
}

export function runPassFuzzCompareUnreachableControlDebrisNormalizerCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-unreachable-control-debris-"));
  const outDir = path.join(tmpdir, "out");

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
const output = args[outIndex + 1];
if (args.includes("-S")) {
  if (args[0].endsWith("binaryen.wasm")) {
    fs.writeFileSync(output, \`(module
 (func $0
  (block $block
   (br_table $block $block
    (i32.const 1)
   )
  )
  (unreachable)
 )
)
\`);
  } else {
    fs.writeFileSync(output, \`(module
 (func $0
  (unreachable)
 )
)
\`);
  }
} else {
  fs.writeFileSync(output, "wasm:" + path.basename(args[0]));
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
      "--seed",
      "0x5eed",
      "--out-dir",
      outDir,
      "--starshine-bin",
      fakeStarshine,
      "--wasm-opt-bin",
      fakeWasmOpt,
      "--wasm-tools-bin",
      fakeWasmTools,
      "--generator",
      "wasm-smith",
      "--normalize",
      "unreachable-control-debris",
      "--pass",
      "dae-optimizing",
    ],
    { cwd: repoRoot, encoding: "utf8" },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    fail(`pass-fuzz-compare unreachable-control-debris normalizer failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    normalizedMatchCount: number;
    cleanupNormalizedMatchCount: number;
    mismatchCount: number;
    normalizers: string[];
  };
  assert(summary.normalizedMatchCount === 0, `expected no exact matches, got ${summary.normalizedMatchCount}`);
  assert(
    summary.cleanupNormalizedMatchCount === 1,
    `expected one unreachable-control-debris compare-normalized match, got ${summary.cleanupNormalizedMatchCount}`,
  );
  assert(summary.mismatchCount === 0, `expected no mismatches, got ${summary.mismatchCount}`);
  assert(JSON.stringify(summary.normalizers) === JSON.stringify(["unreachable-control-debris"]), `unexpected normalizers ${JSON.stringify(summary.normalizers)}`);
      "--remove-unused-brs",
    ],
    { cwd: repoRoot, env: { ...process.env, FAKE_STARSHINE_LOG: starshineLog }, encoding: "utf8" },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) fail(`pass-fuzz-compare idempotence failed:\n${result.stderr}`);

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    propertyMode: string;
    propertyFailureCount: number;
    idempotenceCheckedCount: number;
    idempotenceMatchCount: number;
  };
  assert(summary.propertyMode === "idempotence", `unexpected property mode ${summary.propertyMode}`);
  assert(summary.propertyFailureCount === 0, `unexpected property failures ${summary.propertyFailureCount}`);
  assert(summary.idempotenceCheckedCount === 2, `unexpected idempotence checks ${summary.idempotenceCheckedCount}`);
  assert(summary.idempotenceMatchCount === 2, `unexpected idempotence matches ${summary.idempotenceMatchCount}`);
  const starshineLogs = fs.readFileSync(starshineLog, "utf8").trim().split("\n").filter(Boolean);
  assert(starshineLogs.length === 4, `expected first and second Starshine runs for 2 cases, got ${starshineLogs.length}`);
}

export function runPassFuzzCompareCompositionPropertyTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-composition-"));
  const outDir = path.join(tmpdir, "out");
  const starshineLog = path.join(tmpdir, "starshine.log");

  const fakeMoon = makeExecutable(path.join(tmpdir, "fake-moon"), `process.exit(0);`);
  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(args) + "\\n");
const outIndex = args.indexOf("--out");
if (outIndex === -1) process.exit(1);
const input = fs.readFileSync(args[args.length - 1], "utf8");
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "normalized-output");
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
  fs.writeFileSync(args[outIndex + 1], "(module ;; normalized)\\n");
} else {
  fs.copyFileSync(args[0], args[outIndex + 1]);
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
      "wasm-smith",
      "--property",
      "composition",
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
      "--vacuum",
    ],
    { cwd: repoRoot, env: { ...process.env, FAKE_STARSHINE_LOG: starshineLog }, encoding: "utf8" },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) fail(`pass-fuzz-compare composition failed:\n${result.stderr}`);

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    propertyMode: string;
    propertyFailureCount: number;
    compositionCheckedCount: number;
    compositionMatchCount: number;
  };
  assert(summary.propertyMode === "composition", `unexpected property mode ${summary.propertyMode}`);
  assert(summary.propertyFailureCount === 0, `unexpected property failures ${summary.propertyFailureCount}`);
  assert(summary.compositionCheckedCount === 1, `unexpected composition checks ${summary.compositionCheckedCount}`);
  assert(summary.compositionMatchCount === 1, `unexpected composition matches ${summary.compositionMatchCount}`);
  const starshineLogs = fs.readFileSync(starshineLog, "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line) as string[]);
  assert(starshineLogs.length === 3, `expected combined plus two sequential Starshine runs, got ${starshineLogs.length}`);
  assert(starshineLogs[1].includes("--remove-unused-brs") && !starshineLogs[1].includes("--vacuum"), `expected first sequential pass only, got ${JSON.stringify(starshineLogs[1])}`);
  assert(starshineLogs[2].includes("--vacuum") && !starshineLogs[2].includes("--remove-unused-brs"), `expected second sequential pass only, got ${JSON.stringify(starshineLogs[2])}`);
}

export function runPassFuzzCompareHelpMentionsExternalValidatorsTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const result = spawnSync(
    "bun",
    [path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"), "--help"],
    { cwd: repoRoot, encoding: "utf8" },
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare --help failed:\n${result.stderr}`);
  }
  assert(
    result.stdout.includes("--external-validator <id>") &&
      result.stdout.includes("wasm-tools | binaryen | wabt"),
    `expected external validator help, got:\n${result.stdout}`,
  );
  assert(
    result.stdout.includes("--runtime-execution <mode>") && result.stdout.includes("off | node"),
    `expected runtime execution help, got:\n${result.stdout}`,
  );
}

export function runPassFuzzCompareRuntimeExecutionNodeTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-runtime-"));
  const outDir = path.join(tmpdir, "out");
  // (module (func (export "foo") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))
  const wasmBase64 = "AGFzbQEAAAABBwFgAn9/AX8DAgEABwcBA2ZvbwAACgkBBwAgACABags=";

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const outIndex = args.indexOf("--out");
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.copyFileSync(args[args.length - 1], args[outIndex + 1]);
`,
  );
  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
if (args[0] === "smith") {
  const outIndex = args.indexOf("-o");
  fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
  fs.writeFileSync(args[outIndex + 1], Buffer.from("${wasmBase64}", "base64"));
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
const outIndex = args.indexOf("-o");
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], "(module (func (export \\\"foo\\\")))\\n");
} else {
  fs.copyFileSync(args[0], args[outIndex + 1]);
}
`,
  );

  const result = spawnSync(
    "bun",
    [
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "1",
      "--out-dir",
      outDir,
      "--starshine-bin",
      fakeStarshine,
      "--wasm-opt-bin",
      fakeWasmOpt,
      "--wasm-tools-bin",
      fakeWasmTools,
      "--generator",
      "wasm-smith",
      "--runtime-execution",
      "node",
      "--remove-unused-brs",
    ],
    { cwd: repoRoot, encoding: "utf8" },
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare runtime execution failed:\n${result.stderr}`);
  }
  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    runtimeExecution: string;
    runtimeExecutionCounts: { checked: number; unsupported: number; failed: number };
  };
  assert(summary.runtimeExecution === "node", `unexpected runtime mode ${summary.runtimeExecution}`);
  assert(
    summary.runtimeExecutionCounts.checked === 1 &&
      summary.runtimeExecutionCounts.unsupported === 0 &&
      summary.runtimeExecutionCounts.failed === 0,
    `unexpected runtime counts ${JSON.stringify(summary.runtimeExecutionCounts)}`,
  );
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
  assert(result.stdout.includes("simplify-globals-optimizing"), `expected simplify-globals-optimizing in list output:\n${result.stdout}`);
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
  const records = [];
  for (let i = 1; i <= 10; i += 1) {
    const fileName = "gen-valid-" + String(i).padStart(6, "0") + ".wasm";
    fs.writeFileSync(path.join(outDir, fileName), "gen-valid-" + i);
    records.push({
      file_name: fileName,
      seed: "0x5eed",
      index: i,
      config_label: "fake-coverage",
      feature_facts: { mode: "coverage-forced", has_v128: i === 1 },
      transform_id: "add-non-name-custom-section",
    });
  }
  const manifestIndex = args.indexOf("--manifest");
  if (manifestIndex !== -1) {
    fs.writeFileSync(args[manifestIndex + 1], JSON.stringify({ generator: "gen-valid", records }, null, 2));
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

  assert(
    summary.failureDirs[0].endsWith("case-000001-gen-valid-transform-add-non-name-custom-section"),
    `expected transformed gen-valid failure dir to include transform id, got ${summary.failureDirs[0]}`,
  );
  const metadataPath = path.join(outDir, "failures", "case-000001-gen-valid-transform-add-non-name-custom-section", "failure-metadata.json");
  assert(fs.existsSync(metadataPath), `expected persisted failure metadata at ${metadataPath}`);
  const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8")) as {
    caseIndex: number;
    generator: string;
    detail: string;
    artifacts: string[];
    replay: { input: string; passFlags: string[] };
    status: string;
    genValidManifestEntry: { file_name: string; feature_facts: { has_v128: boolean }; transform_id: string } | null;
    transformId: string | null;
  };
  assert(metadata.caseIndex === 1, `unexpected failure metadata case index ${metadata.caseIndex}`);
  assert(metadata.generator === "gen-valid", `unexpected failure metadata generator ${metadata.generator}`);
  assert(metadata.detail.includes("synthetic starshine failure"), `expected failure detail in metadata, got ${metadata.detail}`);
  assert(metadata.artifacts.includes("input.wasm"), `expected input.wasm in artifact manifest, got ${metadata.artifacts.join(",")}`);
  assert(metadata.status === "command-failure", `expected command-failure metadata status, got ${metadata.status}`);
  assert(metadata.genValidManifestEntry?.file_name === "gen-valid-000001.wasm", `expected copied gen-valid manifest entry, got ${JSON.stringify(metadata.genValidManifestEntry)}`);
  assert(metadata.genValidManifestEntry?.feature_facts.has_v128 === true, `expected copied gen-valid feature facts, got ${JSON.stringify(metadata.genValidManifestEntry)}`);
  assert(metadata.transformId === "add-non-name-custom-section", `expected transform id in metadata, got ${JSON.stringify(metadata)}`);
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

export function runPassFuzzCompareGenValidMismatchReductionArtifactsTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-mismatch-reduction-"));
  const outDir = path.join(tmpdir, "out");
  const moonLog = path.join(tmpdir, "moon.log");

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
const input = fs.readFileSync(args[args.length - 1], "utf8");
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], input.includes("TRIGGER") ? "starshine:TRIGGER" : "same");
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
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
const input = fs.readFileSync(args[0], "utf8");
if (args.includes("-S")) {
  fs.writeFileSync(args[outIndex + 1], input + "\\n");
} else if (args.includes("--remove-unused-brs")) {
  fs.writeFileSync(args[outIndex + 1], input.includes("TRIGGER") ? "binaryen:TRIGGER" : "same");
} else {
  fs.writeFileSync(args[outIndex + 1], input);
}
process.exit(0);
`,
  );

  const fakeWasmTools = makeExecutable(
    path.join(tmpdir, "fake-wasm-tools"),
    `
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args[0] === "print") {
  process.stdout.write(fs.readFileSync(args[1], "utf8"));
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
      "remove-unused-brs",
    ],
    {
      cwd: repoRoot,
      env: { ...process.env, FAKE_MOON_LOG: moonLog },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare gen-valid mismatch reduction failed:\n${result.stderr}`);
  }

  const failureDir = path.join(outDir, "failures", "case-000001-gen-valid");
  const input = fs.readFileSync(path.join(failureDir, "input.wasm"), "utf8");
  const reduced = fs.readFileSync(path.join(failureDir, "reduced-input.wasm"), "utf8");
  const reductionLog = fs.readFileSync(path.join(failureDir, "reduction.txt"), "utf8");
  assert(input === "noiseTRIGGERtail", `expected original input preserved, got ${JSON.stringify(input)}`);
  assert(reduced === "TRIGGER", `expected reduced wasm to keep only trigger bytes, got ${JSON.stringify(reduced)}`);
  assert(reductionLog.includes("status=mismatch"), `expected mismatch status in reduction log, got ${reductionLog}`);
  assert(reductionLog.includes("original_size=16"), `expected original size in reduction log, got ${reductionLog}`);
  assert(reductionLog.includes("final_size=7"), `expected final size in reduction log, got ${reductionLog}`);
  assert(reductionLog.includes("predicate_evaluations="), `expected predicate count in reduction log, got ${reductionLog}`);

  const metadata = JSON.parse(fs.readFileSync(path.join(failureDir, "failure-metadata.json"), "utf8")) as {
    artifacts: string[];
    reduction: null | { originalSize: number; finalSize: number; predicateEvaluations: number };
  };
  assert(metadata.artifacts.includes("input.wasm"), `expected original input artifact, got ${metadata.artifacts.join(",")}`);
  assert(metadata.artifacts.includes("reduced-input.wasm"), `expected reduced input artifact, got ${metadata.artifacts.join(",")}`);
  assert(metadata.artifacts.includes("reduction.txt"), `expected reduction log artifact, got ${metadata.artifacts.join(",")}`);
  assert(metadata.reduction?.originalSize === 16, `expected reduction metadata original size, got ${JSON.stringify(metadata.reduction)}`);
  assert(metadata.reduction?.finalSize === 7, `expected reduction metadata final size, got ${JSON.stringify(metadata.reduction)}`);
  assert((metadata.reduction?.predicateEvaluations ?? 0) > 0, `expected predicate evaluations, got ${JSON.stringify(metadata.reduction)}`);
}

export function runPassFuzzCompareReplayMismatchStatusTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-replay-mismatch-status-"));
  const replayDir = path.join(tmpdir, "saved");
  const replayFailureDir = path.join(replayDir, "failures", "case-000042-gen-valid");
  const outDir = path.join(tmpdir, "out");
  const starshineLog = path.join(tmpdir, "starshine.log");

  fs.mkdirSync(replayFailureDir, { recursive: true });
  fs.writeFileSync(
    path.join(replayDir, "cases.jsonl"),
    JSON.stringify({
      caseIndex: 42,
      generator: "gen-valid",
      status: "mismatch",
      detail: "normalized outputs differed",
    }) + "\n",
  );
  fs.writeFileSync(path.join(replayFailureDir, "input.wasm"), "saved-mismatch-input");

  const fakeStarshine = makeExecutable(
    path.join(tmpdir, "fake-starshine"),
    `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_STARSHINE_LOG, JSON.stringify(args) + "\\n");
const outIndex = args.indexOf("--out");
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], "starshine-replay");
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
fs.mkdirSync(path.dirname(args[outIndex + 1]), { recursive: true });
fs.writeFileSync(args[outIndex + 1], args.includes("-S") ? "(module ;; replay matched)\\n" : "binary");
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
      "--out-dir",
      outDir,
      "--starshine-bin",
      fakeStarshine,
      "--wasm-opt-bin",
      fakeWasmOpt,
      "--wasm-tools-bin",
      fakeWasmTools,
      "--replay-failures-from",
      replayDir,
      "--failure-status",
      "mismatch",
      "--case-index",
      "42",
      "--pass",
      "remove-unused-brs",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FAKE_STARSHINE_LOG: starshineLog,
      },
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`pass-fuzz-compare replay mismatch status failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    comparedCount: number;
    normalizedMatchCount: number;
    mismatchCount: number;
  };
  assert(summary.requestedCount === 1, `expected 1 replayed mismatch, got ${summary.requestedCount}`);
  assert(summary.comparedCount === 1, `expected 1 compared replay case, got ${summary.comparedCount}`);
  assert(summary.normalizedMatchCount === 1, `expected replayed mismatch to now match, got ${summary.normalizedMatchCount}`);
  assert(summary.mismatchCount === 0, `expected no replay mismatches, got ${summary.mismatchCount}`);

  const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n").filter(Boolean);
  assert(cases.length === 1, `expected 1 replay case record, got ${cases.length}`);
  const entry = JSON.parse(cases[0]) as { caseIndex: number; status: string };
  assert(entry.caseIndex === 42, `expected original case index 42, got ${entry.caseIndex}`);
  assert(entry.status === "match", `expected replayed match status, got ${entry.status}`);

  const starshineLogs = fs.readFileSync(starshineLog, "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line) as string[]);
  assert(starshineLogs.length === 1, `expected 1 Starshine replay, got ${starshineLogs.length}`);
  assert(starshineLogs[0].includes("--remove-unused-brs"), `expected pass flag in replay, got ${JSON.stringify(starshineLogs[0])}`);
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

export function runPassFuzzCompareStarshineBinDefaultsToAutoJobsTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-auto-jobs-"));
  const outDir = path.join(tmpdir, "out");
  const starshineLog = path.join(tmpdir, "starshine.log");
  const wasmOptLog = path.join(tmpdir, "wasm-opt.log");
  const wasmToolsLog = path.join(tmpdir, "wasm-tools.log");

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
      "--seed",
      "0x5eed",
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
      "--pass",
      "remove-unused-brs",
    ],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
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
    fail(`pass-fuzz-compare default auto jobs failed:\n${result.stderr}`);
  }

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    requestedCount: number;
    jobs: number;
  };
  const available = (os as typeof os & { availableParallelism?: () => number }).availableParallelism;
  const expectedJobs = Math.min(Math.max(1, available?.() ?? os.cpus().length ?? 1), summary.requestedCount);
  assert(summary.jobs === expectedJobs, `expected default auto jobs=${expectedJobs}, got ${summary.jobs}`);
}

export function runPassFuzzCompareParallelJobsRequireStarshineBinTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-jobs-guard-"));
  const outDir = path.join(tmpdir, "out");
  const result = spawnSync(
    "bun",
    [
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count",
      "2",
      "--jobs",
      "2",
      "--generator",
      "wasm-smith",
      "--out-dir",
      outDir,
      "--pass",
      "remove-unused-brs",
    ],
    {
      cwd: repoRoot,
      encoding: "utf8",
    },
  );

  if (result.error) {
    throw result.error;
  }
  assert(result.status !== 0, "expected --jobs >1 without --starshine-bin to fail");
  assert(
    result.stderr.includes("--jobs >1 requires --starshine-bin"),
    `expected --starshine-bin guard failure, got:\n${result.stderr}`,
  );
  assert(!fs.existsSync(outDir), `expected guard to fail before creating out dir: ${outDir}`);
}

if (import.meta.main) {
  runPassFuzzCompareCommandTest();
  runPassFuzzCompareDropConstsNormalizerCommandTest();
  runPassFuzzCompareUnreachableControlDebrisNormalizerCommandTest();
  runPassFuzzCompareIdempotencePropertyTest();
  runPassFuzzCompareCompositionPropertyTest();
  runPassFuzzCompareHelpMentionsExternalValidatorsTest();
  runPassFuzzCompareRuntimeExecutionNodeTest();
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
  runPassFuzzCompareReplayMismatchStatusTest();
  runPassFuzzCompareGenValidMismatchReductionArtifactsTest();
  runPassFuzzCompareMinComparedGateTest();
  runPassFuzzCompareStarshineBinDefaultsToAutoJobsTest();
  runPassFuzzCompareParallelJobsRequireStarshineBinTest();
  runPassFuzzCompareDefaultStarshineInvocationTest();
  runPassFuzzCompareDefaultStarshineInvocationRetriesMissingOutputTest();
}
