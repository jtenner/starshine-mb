import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function executable(file: string, source: string): string {
  fs.writeFileSync(file, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(file, 0o755);
  return file;
}

export function runPassFuzzCompareSemanticPropertiesCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-semantic-properties-"));
  const wat = path.join(dir, "input.wat");
  const wasm = path.join(dir, "input.wasm");
  fs.writeFileSync(wat, `(module (func (export "run") (param i32) (result i32) local.get 0))`);
  const parsed = spawnSync("wasm-tools", ["parse", wat, "-o", wasm], { encoding: "utf8" });
  if (parsed.status !== 0) throw new Error(parsed.stderr || "fixture parse failed");
  const starshine = executable(path.join(dir, "starshine"), `
const fs=require("node:fs"),path=require("node:path"); const a=process.argv.slice(2); if(a.includes("--emit-runtime-interface-json")){console.log(JSON.stringify({schema:"starshine.optimizer-runtime-interface.v1",moduleHash:"fixture",interfaceHash:"fixture",features:[],hasStart:false,imports:{functions:[],globals:[],memories:[],tables:[],tags:[]},exports:[{name:"run",kind:"function",index:0,signature:{params:["i32"],results:["i32"]},support:"directly-constructible"}]}));process.exit(0)} const o=a[a.indexOf("--out")+1]; fs.mkdirSync(path.dirname(o),{recursive:true}); fs.copyFileSync(a[a.length-1],o);
`);
  const realWasmTools = spawnSync("which", ["wasm-tools"], { encoding: "utf8" }).stdout.trim();
  const wrapper = executable(path.join(dir, "wasm-tools"), `
const fs=require("node:fs"),path=require("node:path"),cp=require("node:child_process"); const a=process.argv.slice(2); if(a[0]==="smith"){const o=a[a.indexOf("-o")+1];fs.mkdirSync(path.dirname(o),{recursive:true});fs.copyFileSync(process.env.FIXTURE,o);process.exit(0)} const r=cp.spawnSync(process.env.REAL,a,{stdio:"inherit"});process.exit(r.status??1);
`);
  const outDir = path.join(dir, "out");
  const result = spawnSync("bun", [
    path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
    "--count", "1", "--wasm-smith", "--no-cache", "--out-dir", outDir,
    "--starshine-bin", starshine, "--wasm-tools-bin", wrapper,
    "--semantic-oracle", "node-v2", "--semantic-policy", "strict",
    "--property", "semantic-idempotence", "--property", "convergence", "--convergence-max", "4",
    "--commutator-left", "vacuum", "--commutator-right", "remove-unused-brs",
    "--pass", "remove-unused-brs",
  ], {
    cwd: repoRoot,
    env: { ...process.env, FIXTURE: wasm, REAL: realWasmTools },
    encoding: "utf8",
    timeout: 120000,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${result.stdout}\n${result.stderr}`);
  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8"));
  assert(JSON.stringify(summary.propertyModes) === JSON.stringify(["semantic-idempotence", "convergence"]), "property modes were not persisted");
  assert(summary.semanticIdempotenceCheckedCount === 1, `unexpected semantic-idempotence checks ${summary.semanticIdempotenceCheckedCount}`);
  assert(summary.semanticIdempotenceMatchCount === 1, `unexpected semantic-idempotence matches ${summary.semanticIdempotenceMatchCount}`);
  assert(summary.convergenceCheckedCount === 1, `unexpected convergence checks ${summary.convergenceCheckedCount}`);
  assert(summary.convergenceFixedPointCount === 1, `unexpected convergence fixed points ${summary.convergenceFixedPointCount}`);
  assert(summary.commutatorCheckedCount === 1, `unexpected commutator checks ${summary.commutatorCheckedCount}`);
  assert(summary.commutatorMatchCount === 1, `unexpected commutator matches ${summary.commutatorMatchCount}`);
  assert(summary.commutatorClassifications["semantic-orders-structurally-equal"] === 1, `unexpected commutator classifications ${JSON.stringify(summary.commutatorClassifications)}`);
  assert(summary.propertyFailureCount === 0, `unexpected property failures ${summary.propertyFailureCount}`);
  const propertyDir = path.join(outDir, "property-results");
  const semantic = JSON.parse(fs.readFileSync(path.join(propertyDir, "case-000001-semantic-idempotence.json"), "utf8"));
  const convergence = JSON.parse(fs.readFileSync(path.join(propertyDir, "case-000001-convergence.json"), "utf8"));
  const commutator = JSON.parse(fs.readFileSync(path.join(propertyDir, "case-000001-commutator.json"), "utf8"));
  assert(semantic.schema === "starshine.optimizer-property-result.v1", "semantic-idempotence result used wrong schema");
  assert(semantic.classification === "structural-fixed-point", `unexpected semantic-idempotence classification ${semantic.classification}`);
  assert(convergence.schema === "starshine.optimizer-property-result.v1", "convergence result used wrong schema");
  assert(convergence.classification === "fixed-point", `unexpected convergence classification ${convergence.classification}`);
  assert(convergence.fixedPointGeneration === 1, `unexpected fixed-point generation ${convergence.fixedPointGeneration}`);
  assert(commutator.schema === "starshine.optimizer-property-result.v1", "commutator result used wrong schema");
  assert(commutator.classification === "semantic-orders-structurally-equal", `unexpected commutator classification ${commutator.classification}`);
  assert(commutator.generatedArtifacts.length === 5, `commutator did not persist all five modules: ${commutator.generatedArtifacts.length}`);
  assert(commutator.semanticComparisons.length === 5, `commutator did not persist all five comparisons: ${commutator.semanticComparisons.length}`);
}

if (import.meta.main) runPassFuzzCompareSemanticPropertiesCommandTest();
