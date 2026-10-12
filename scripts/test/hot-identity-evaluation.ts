import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { runNodeThreeWaySemanticOracleV2 } from "../lib/optimizer-runtime-executor.ts";

const sha256 = (filename: string) => crypto.createHash("sha256").update(fs.readFileSync(filename)).digest("hex");

function run(command: string, args: string[], timeout = 15_000) {
  const started = performance.now();
  const result = spawnSync(command, args, { encoding: "utf8", timeout, killSignal: "SIGKILL", maxBuffer: 8 * 1024 * 1024 });
  return { wallMs: performance.now() - started, status: result.status, signal: result.signal, error: result.error?.message ?? null, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
}

function compileWat(wasmTools: string, dir: string, name: string, wat: string) {
  const watPath = path.join(dir, `${name}.wat`), wasmPath = path.join(dir, `${name}.wasm`);
  fs.writeFileSync(watPath, wat);
  const result = run(wasmTools, ["parse", watPath, "-o", wasmPath]);
  if (result.status !== 0) throw new Error(`failed to compile ${name}: ${result.stderr}`);
  return wasmPath;
}

async function compareRuntime(original: string, output: string, starshineBin: string, wasmTools: string) {
  const report = await runNodeThreeWaySemanticOracleV2(original, output, null, {
    seed: 0x5eedn,
    policy: "strict",
    mode: "independent",
    timeoutMs: 2000,
    memoryCapBytes: 128 * 1024,
    tableEntryCap: 64,
    maxPairwise: 2,
    starshineBin,
    wasmToolsBin: wasmTools,
  });
  return {
    classification: report.originalVsStarshine?.classification ?? "missing-comparison",
    comparison: report.originalVsStarshine,
    completeness: { original: report.original.completeness, output: report.starshine.completeness },
    blockedReasons: { original: report.original.blockedReasons, output: report.starshine.blockedReasons },
    interfaceHash: report.runtimeInterface.interfaceHash,
    invocationPlanHash: report.plan.hash,
    steps: report.plan.steps.length,
    importEvents: { original: report.original.importTrace.length, output: report.starshine.importTrace.length },
    timings: report.timings,
  };
}

export async function runHotIdentityEvaluation(options: { probe: string; starshineBin: string; wasmTools: string; outDir: string }) {
  if (fs.existsSync(options.outDir)) throw new Error("HOT identity evaluation output directory must be fresh");
  fs.mkdirSync(options.outDir, { recursive: true });
  const repo = path.resolve(import.meta.dir, "../..");
  const synthetic = compileWat(options.wasmTools, options.outDir, "effectful-typed-if", `(module
    (import "host" "value" (func $value (result i32)))
    (import "host" "condition" (func $condition (result i32)))
    (func (export "run") (result i32)
      call $value call $condition
      if (param i32) (result i32) i32.const 3 i32.add
      else i32.const 2 i32.add end))`);
  const corpora = [
    { name: "effectful-typed-if", path: synthetic, class: "typed-entry-import-effects" },
    { name: "rust-fannkuch", path: path.join(repo, "tests/repros/precompute-propagate-rust-fannkuch-loop-carried-default.wasm"), class: "bounded-loop-carrier" },
    { name: "winch-multivalue", path: path.join(repo, "tests/repros/remove-unused-brs-winch-issue-10613-multivalue.wasm"), class: "multi-value" },
    { name: "eh-observed-write", path: path.join(repo, "tests/repros/simplify-locals-eh-catch-observed-write.wasm"), class: "try-table-handler" },
    { name: "typed-spectest-throw", path: path.join(repo, "tests/repros/optimize-instructions-spectest-throw.wasm"), class: "typed-tag-handler" },
  ];
  const rows = [];
  for (let cohort = 0; cohort < 5; cohort += 1) {
    const baseModes = ["default", "capture", "materialize", "both"];
    const modes = [...baseModes.slice(cohort % baseModes.length), ...baseModes.slice(0, cohort % baseModes.length)];
    for (const corpus of corpora) for (const mode of modes) {
      const dir = path.join(options.outDir, `${corpus.name}-${mode}-${cohort}`); fs.mkdirSync(dir);
      const output = path.join(dir, "output.wasm");
      const identity = sha256(corpus.path);
      const command = run(options.probe, [corpus.path, output, "10", mode], 30_000);
      if (command.status !== 0) throw new Error(`${corpus.name}/${mode}: ${command.stderr}`);
      const report = JSON.parse(command.stdout.trim());
      if (sha256(corpus.path) !== identity) throw new Error(`${corpus.name}: source changed`);
      const validation = run(options.wasmTools, ["validate", "--features", "all", output]);
      if (validation.status !== 0) throw new Error(`${corpus.name}: output invalid: ${validation.stderr}`);
      const semantic = await compareRuntime(corpus.path, output, options.starshineBin, options.wasmTools);
      rows.push({ corpus: corpus.name, class: corpus.class, mode, cohort, sourceHash: identity, outputHash: sha256(output), command, report, validation, semantic });
    }
  }

  const duplicateOriginal = compileWat(options.wasmTools, options.outDir, "duplicate-original", `(module (import "host" "tick" (func (result i32))) (func (export "run") call 0 drop))`);
  const duplicateFault = compileWat(options.wasmTools, options.outDir, "duplicate-fault", `(module (import "host" "tick" (func (result i32))) (func (export "run") call 0 drop call 0 drop))`);
  const labelOriginal = compileWat(options.wasmTools, options.outDir, "label-original", `(module (func (export "run") (result i32) block (result i32) block (result i32) i32.const 7 br 0 end i32.const 1 i32.add end))`);
  const labelFault = compileWat(options.wasmTools, options.outDir, "label-fault", `(module (func (export "run") (result i32) block (result i32) block (result i32) i32.const 7 br 1 end i32.const 1 i32.add end))`);
  const controls = {
    duplicateProducer: await compareRuntime(duplicateOriginal, duplicateFault, options.starshineBin, options.wasmTools),
    labelRetarget: await compareRuntime(labelOriginal, labelFault, options.starshineBin, options.wasmTools),
  };
  if (controls.duplicateProducer.classification !== "semantic-mismatch" || controls.labelRetarget.classification !== "semantic-mismatch") throw new Error("HOT identity semantic fault controls were not detected");
  const result = {
    schema: "starshine.hot-identity-evaluation.v1",
    identities: { probe: { path: path.resolve(options.probe), sha256: sha256(options.probe) }, starshine: { path: path.resolve(options.starshineBin), sha256: sha256(options.starshineBin) }, wasmTools: { path: path.resolve(options.wasmTools), sha256: sha256(options.wasmTools), version: run(options.wasmTools, ["--version"]).stdout.trim() }, runner: sha256(import.meta.filename) },
    conditions: { cohorts: 5, probeRepeats: 10, order: "rotating default/capture/materialize/both", runtime: "node-v2 independent strict seed 0x5eed; 2s; 128KiB memory; 64 table entries; max pairwise 2", exclusions: ["relaxed SIMD exact outcome claims", "shared nondeterministic execution", "unsupported direct reference crossings", "unbounded loop arguments"] },
    rows,
    controls,
  };
  fs.writeFileSync(path.join(options.outDir, "result.json"), JSON.stringify(result, null, 2) + "\n");
  return result;
}

if (import.meta.main) {
  const [probe, starshineBin, outDir, wasmTools = "wasm-tools"] = process.argv.slice(2);
  if (!probe || !starshineBin || !outDir) throw new Error("usage: bun scripts/test/hot-identity-evaluation.ts <hot-identity-probe> <native-starshine> <fresh-output-dir> [wasm-tools]");
  const result = await runHotIdentityEvaluation({ probe, starshineBin, outDir, wasmTools });
  process.stdout.write(JSON.stringify({ rows: result.rows.length, controls: Object.fromEntries(Object.entries(result.controls).map(([key, value]) => [key, value.classification])) }) + "\n");
}
