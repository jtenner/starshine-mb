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
  fs.writeFileSync(basePath, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(basePath, 0o755);
  return basePath;
}

const runtimeInterfaceScript = `
if (args.includes("--emit-runtime-interface-json")) { console.log(JSON.stringify({ schema:"starshine.optimizer-runtime-interface.v1", moduleHash:"fixture", interfaceHash:"fixture", features:[], hasStart:false, imports:{functions:[],globals:[],memories:[],tables:[],tags:[]}, exports:[{name:"g",kind:"global",index:0,globalType:{valueType:"i32",mutable:true},support:"directly-constructible"},{name:"memory",kind:"memory",index:0,support:"directly-constructible"},{name:"run",kind:"function",index:0,signature:{params:["i32"],results:["i32"]},support:"directly-constructible"}] })); process.exit(0); }
if (args.includes("--emit-expanded-pass-queue-json")) { console.log(JSON.stringify({ schema:"starshine.optimizer-expanded-pass-queue.v1", requested:["vacuum","remove-unused-brs"], optimizeLevel:0, shrinkLevel:0, passes:[{ordinal:0,name:"vacuum"},{ordinal:1,name:"vacuum"},{ordinal:2,name:"remove-unused-brs"}] })); process.exit(0); }
`;

export function runPassFuzzCompareSemanticV2CommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-pass-fuzz-semantic-v2-"));
  const outDir = path.join(tmpdir, "out");
  const watPath = path.join(tmpdir, "input.wat");
  const fixturePath = path.join(tmpdir, "input.wasm");
  fs.writeFileSync(watPath, `(module
    (global $g (export "g") (mut i32) (i32.const 0))
    (memory (export "memory") 2)
    (func (export "run") (param i32) (result i32)
      local.get 0
      global.set $g
      i32.const 70000
      global.get $g
      i32.store8
      global.get $g))`);
  const parse = spawnSync("wasm-tools", ["parse", watPath, "-o", fixturePath], { encoding: "utf8" });
  if (parse.error) throw parse.error;
  if (parse.status !== 0) fail(parse.stderr || parse.stdout || "fixture parse failed");

  const fakeStarshine = makeExecutable(path.join(tmpdir, "fake-starshine"), `
const fs = require("node:fs"); const path = require("node:path");
const args = process.argv.slice(2); ${runtimeInterfaceScript}
const out = args[args.indexOf("--out") + 1];
fs.mkdirSync(path.dirname(out), { recursive: true }); fs.copyFileSync(args[args.length - 1], out);
`);
  const wasmToolsWrapper = makeExecutable(path.join(tmpdir, "wasm-tools-wrapper"), `
const fs = require("node:fs"); const path = require("node:path"); const cp = require("node:child_process");
const args = process.argv.slice(2);
if (args[0] === "smith") { const out = args[args.indexOf("-o") + 1]; fs.mkdirSync(path.dirname(out), { recursive: true }); fs.copyFileSync(process.env.FIXTURE_WASM, out); process.exit(0); }
const result = cp.spawnSync(process.env.REAL_WASM_TOOLS, args, { stdio: "inherit" }); process.exit(result.status ?? 1);
`);
  const realWasmTools = spawnSync("which", ["wasm-tools"], { encoding: "utf8" }).stdout.trim();

  const result = spawnSync("bun", [
    path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
    "--count", "1",
    "--wasm-smith",
    "--no-cache",
    "--out-dir", outDir,
    "--starshine-bin", fakeStarshine,
    "--wasm-tools-bin", wasmToolsWrapper,
    "--semantic-oracle", "node-v2",
    "--semantic-policy", "strict",
    "--observation-mode", "stateful",
    "--observation-memory-cap-bytes", String(256 * 1024),
    "--observation-table-entry-cap", "16",
    "--runtime-timeout-ms", "1000",
    "--pass", "remove-unused-brs",
  ], {
    cwd: repoRoot,
    env: { ...process.env, FIXTURE_WASM: fixturePath, REAL_WASM_TOOLS: realWasmTools },
    encoding: "utf8",
    timeout: 120000,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) fail(`semantic-v2 compare command failed:\n${result.stdout}\n${result.stderr}`);

  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8"));
  assert(summary.semanticOracle === "node-v2", `unexpected semantic oracle ${summary.semanticOracle}`);
  assert(summary.semanticV2CheckedCount === 1, `expected one v2 check: ${JSON.stringify(summary, null, 2)}`);
  assert(summary.semanticV2MatchCount === 1, `expected one v2 match: ${JSON.stringify(summary, null, 2)}`);
  assert(summary.semanticV2BlockedCount === 0, `unexpected blocked v2 count: ${JSON.stringify(summary, null, 2)}`);
  assert(summary.semanticV2MismatchCount === 0, `unexpected v2 mismatch count: ${JSON.stringify(summary, null, 2)}`);
  assert(summary.semanticV2ThreeWayPatterns["all-equal"] === 1, `expected all-equal pattern: ${JSON.stringify(summary, null, 2)}`);

  const reportPath = path.join(outDir, "semantic-observations", "case-000001.json");
  assert(fs.existsSync(reportPath), `missing persisted semantic report ${reportPath}`);
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  assert(report.schema === "starshine.optimizer-three-way-runtime-report.v1", `unexpected report schema ${report.schema}`);
  assert(report.runtimeInterface.schema === "starshine.optimizer-runtime-interface.v1", "missing runtime interface");
  assert(report.plan.schema === "starshine.optimizer-invocation-plan.v2", "missing invocation plan");
  assert(report.original.schema === "starshine.optimizer-runtime-observation.v2", "missing original observation");
  assert(report.starshine.schema === "starshine.optimizer-runtime-observation.v2", "missing Starshine observation");
  assert(report.binaryen.schema === "starshine.optimizer-runtime-observation.v2", "missing Binaryen observation");

  const wrongWatPath = path.join(tmpdir, "wrong.wat");
  const wrongWasmPath = path.join(tmpdir, "wrong.wasm");
  fs.writeFileSync(wrongWatPath, `(module
    (global $g (export "g") (mut i32) (i32.const 0))
    (memory (export "memory") 2)
    (func (export "run") (param i32) (result i32)
      local.get 0
      i32.const 1
      i32.add))`);
  const wrongParse = spawnSync("wasm-tools", ["parse", wrongWatPath, "-o", wrongWasmPath], { encoding: "utf8" });
  if (wrongParse.error) throw wrongParse.error;
  if (wrongParse.status !== 0) fail(wrongParse.stderr || wrongParse.stdout || "wrong fixture parse failed");
  const wrongStarshine = makeExecutable(path.join(tmpdir, "wrong-starshine"), `
const fs = require("node:fs"); const path = require("node:path");
const args = process.argv.slice(2); ${runtimeInterfaceScript}
const out = args[args.indexOf("--out") + 1];
fs.mkdirSync(path.dirname(out), { recursive: true }); fs.copyFileSync(process.env.WRONG_WASM, out);
`);
  const wrongOutDir = path.join(tmpdir, "wrong-out");
  const wrongResult = spawnSync("bun", [
    path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
    "--count", "1", "--wasm-smith", "--no-cache", "--out-dir", wrongOutDir,
    "--starshine-bin", wrongStarshine, "--wasm-tools-bin", wasmToolsWrapper,
    "--semantic-oracle", "node-v2", "--semantic-policy", "strict",
    "--observation-mode", "independent", "--observation-memory-cap-bytes", String(256 * 1024),
    "--observation-table-entry-cap", "16", "--runtime-timeout-ms", "1000",
    "--pass", "remove-unused-brs",
  ], {
    cwd: repoRoot,
    env: { ...process.env, FIXTURE_WASM: fixturePath, REAL_WASM_TOOLS: realWasmTools, WRONG_WASM: wrongWasmPath },
    encoding: "utf8",
    timeout: 120000,
  });
  if (wrongResult.error) throw wrongResult.error;
  if (wrongResult.status !== 0) fail(`controlled semantic mismatch command failed:\n${wrongResult.stdout}\n${wrongResult.stderr}`);
  const wrongSummary = JSON.parse(fs.readFileSync(path.join(wrongOutDir, "result.json"), "utf8"));
  assert(wrongSummary.semanticV2MismatchCount === 1, `expected one semantic mismatch: ${JSON.stringify(wrongSummary, null, 2)}`);
  assert(wrongSummary.propertyFailureClasses["semantic-self-v2"] === 1, "missing semantic-self-v2 failure class");
  const failureDir = wrongSummary.failureDirs[0];
  const fingerprintPath = path.join(failureDir, "semantic-fingerprint.json");
  assert(fs.existsSync(fingerprintPath), `missing semantic fingerprint ${fingerprintPath}`);
  const fingerprint = JSON.parse(fs.readFileSync(fingerprintPath, "utf8"));
  assert(fingerprint.schema === "starshine.optimizer-semantic-fingerprint.v1", `unexpected fingerprint schema ${fingerprint.schema}`);
  assert(fingerprint.propertyKind === "semantic-self-v2", `unexpected fingerprint property ${fingerprint.propertyKind}`);
  assert(fingerprint.firstDifferenceCategory === "result-value", `unexpected difference category ${fingerprint.firstDifferenceCategory}`);
  assert(fingerprint.invocationPlanHash === JSON.parse(fs.readFileSync(path.join(failureDir, "semantic-v2.json"), "utf8")).plan.hash, "fingerprint did not retain plan hash");

  const localizedStarshine = makeExecutable(path.join(tmpdir, "localized-starshine"), `
const fs = require("node:fs"); const path = require("node:path"); const args = process.argv.slice(2); ${runtimeInterfaceScript}
const out = args[args.indexOf("--out") + 1]; fs.mkdirSync(path.dirname(out), { recursive: true });
const hasBoundary = args.includes("--remove-unused-brs"); fs.copyFileSync(hasBoundary ? process.env.WRONG_WASM : args[args.length - 1], out);
`);
  const localizedOutDir = path.join(tmpdir, "localized-out");
  const localizedResult = spawnSync("bun", [
    path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
    "--count", "1", "--wasm-smith", "--no-cache", "--out-dir", localizedOutDir,
    "--starshine-bin", localizedStarshine, "--wasm-tools-bin", wasmToolsWrapper,
    "--semantic-oracle", "node-v2", "--semantic-policy", "strict",
    "--localize-first-divergence",
    "--pass", "vacuum", "--pass", "remove-unused-brs",
  ], {
    cwd: repoRoot,
    env: { ...process.env, FIXTURE_WASM: fixturePath, REAL_WASM_TOOLS: realWasmTools, WRONG_WASM: wrongWasmPath },
    encoding: "utf8",
    timeout: 120000,
  });
  if (localizedResult.error) throw localizedResult.error;
  if (localizedResult.status !== 0) fail(`localized semantic mismatch command failed:\n${localizedResult.stdout}\n${localizedResult.stderr}`);
  const localizedSummary = JSON.parse(fs.readFileSync(path.join(localizedOutDir, "result.json"), "utf8"));
  assert(localizedSummary.localizationCheckedCount === 1, "localization was not counted");
  assert(localizedSummary.localizationReproducedCount === 1, "standalone boundary did not reproduce");
  const localizedFailure = localizedSummary.failureDirs[0];
  const localization = JSON.parse(fs.readFileSync(path.join(localizedFailure, "pass-localization.json"), "utf8"));
  assert(localization.schema === "starshine.optimizer-pass-localization.v1", "wrong localization schema");
  assert(localization.passSequenceSource === "moon-expanded-queue", `unexpected sequence source ${localization.passSequenceSource}`);
  assert(localization.passSequence.join(",") === "vacuum,vacuum,remove-unused-brs", `expanded queue was not retained: ${JSON.stringify(localization.passSequence)}`);
  assert(localization.prefixes.length === 4, `expected all expanded prefixes including zero, got ${localization.prefixes.length}`);
  assert(localization.firstDivergentBoundary.index === 3, `unexpected boundary ${JSON.stringify(localization.firstDivergentBoundary)}`);
  assert(localization.firstDivergentBoundary.pass === "remove-unused-brs", `unexpected boundary pass ${JSON.stringify(localization.firstDivergentBoundary)}`);
  assert(localization.standaloneReproduction === "reproduced", `unexpected standalone result ${localization.standaloneReproduction}`);
  const localizedFingerprint = JSON.parse(fs.readFileSync(path.join(localizedFailure, "semantic-fingerprint.json"), "utf8"));
  assert(localizedFingerprint.passSequence.join(",") === "vacuum,vacuum,remove-unused-brs", `fingerprint lost expanded pass slots: ${JSON.stringify(localizedFingerprint.passSequence)}`);
}

if (import.meta.main) runPassFuzzCompareSemanticV2CommandTest();
