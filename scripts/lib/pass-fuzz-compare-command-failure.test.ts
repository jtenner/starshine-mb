import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function executable(file: string, source: string): string {
  fs.writeFileSync(file, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(file, 0o755);
  return file;
}

describe("Binaryen command failure accounting", () => {
  test("does not count an unavailable Binaryen oracle as a comparison match", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-binaryen-failure-"));
    try {
      const inputWat = path.join(root, "input.wat");
      const inputWasm = path.join(root, "input.wasm");
      fs.writeFileSync(inputWat, `(module (func (export "run") (result i32) i32.const 7))`);
      const parsed = spawnSync("wasm-tools", ["parse", inputWat, "-o", inputWasm], {
        encoding: "utf8",
      });
      expect(parsed.status, parsed.stderr || parsed.stdout).toBe(0);

      const starshine = executable(path.join(root, "starshine"), `
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args.includes("--emit-runtime-interface-json")) {
  console.log(JSON.stringify({
    schema: "starshine.optimizer-runtime-interface.v1",
    moduleHash: "fixture",
    interfaceHash: "fixture",
    features: [],
    hasStart: false,
    imports: { functions: [], globals: [], memories: [], tables: [], tags: [] },
    exports: [{
      name: "run",
      kind: "function",
      index: 0,
      signature: { params: [], results: ["i32"] },
      support: "directly-constructible",
    }],
  }));
  process.exit(0);
}
const out = args[args.indexOf("--out") + 1];
fs.mkdirSync(require("node:path").dirname(out), { recursive: true });
fs.copyFileSync(args[args.length - 1], out);
`);
      const binaryen = executable(path.join(root, "wasm-opt"), `
const args = process.argv.slice(2);
if (args.includes("--version")) {
  console.log("wasm-opt version 132 (version_132)");
  process.exit(0);
}
console.error("synthetic Binaryen optimizer failure");
process.exit(17);
`);
      const realWasmTools = spawnSync("which", ["wasm-tools"], { encoding: "utf8" }).stdout.trim();
      const wasmTools = executable(path.join(root, "wasm-tools"), `
const fs = require("node:fs");
const cp = require("node:child_process");
const args = process.argv.slice(2);
if (args[0] === "smith") {
  fs.copyFileSync(process.env.FIXTURE_WASM, args[args.indexOf("-o") + 1]);
  process.exit(0);
}
const result = cp.spawnSync(process.env.REAL_WASM_TOOLS, args, { stdio: "inherit" });
process.exit(result.status ?? 1);
`);
      const outDir = path.join(root, "out");
      const commandArgs = [
        path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
        "--count", "1",
        "--wasm-smith",
        "--out-dir", outDir,
        "--report-only",
        "--no-cache",
        "--jobs", "1",
        "--pass", "vacuum",
        "--starshine-bin", starshine,
        "--wasm-opt-bin", binaryen,
        "--wasm-tools-bin", wasmTools,
        "--semantic-oracle", "node-v2",
      ];
      const result = spawnSync("bun", commandArgs, {
        cwd: repoRoot,
        env: { ...process.env, FIXTURE_WASM: inputWasm, REAL_WASM_TOOLS: realWasmTools },
        encoding: "utf8",
        timeout: 30_000,
      });

      expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
      const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8"));
      expect(summary.commandFailureCount).toBe(1);
      expect(summary.commandFailureClasses).toEqual({ "binaryen-command-failed": 1 });
      expect(summary.comparedCount).toBe(0);
      expect(summary.normalizedMatchCount).toBe(0);
      expect(summary.cleanupNormalizedMatchCount).toBe(0);
      expect(summary.generatorCounts).toEqual({ wasmSmith: 0, genValid: 0 });
      expect(summary.semanticV2CheckedCount).toBe(1);
      expect(summary.semanticV2MatchCount).toBe(1);
      expect(summary.failureDirs).toHaveLength(1);

      const cases = fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8").trim().split("\n");
      expect(cases).toHaveLength(1);
      expect(JSON.parse(cases[0])).toMatchObject({
        caseIndex: 1,
        generator: "wasm-smith",
        status: "command-failure",
        failureClass: "binaryen-command-failed",
        semanticV2Outcome: { primary: "semantic-match", pattern: "binaryen-discrepancy" },
        binaryenCacheOutcome: "failure-miss",
      });

      fs.writeFileSync(
        path.join(outDir, "cases.jsonl"),
        JSON.stringify({
          caseIndex: 1,
          generator: "wasm-smith",
          status: "match",
          detail: "original-primary semantic match; Binaryen diagnostic unavailable: binaryen-command-failed",
          diagnosticFailureClass: "binaryen-command-failed",
          semanticV2Outcome: { primary: "semantic-match", pattern: "binaryen-discrepancy" },
          binaryenCacheOutcome: "failure-miss",
        }) + "\n",
      );
      const resumed = spawnSync("bun", [...commandArgs, "--resume"], {
        cwd: repoRoot,
        env: { ...process.env, FIXTURE_WASM: inputWasm, REAL_WASM_TOOLS: realWasmTools },
        encoding: "utf8",
        timeout: 30_000,
      });
      expect(resumed.status, `${resumed.stdout}\n${resumed.stderr}`).toBe(0);
      const resumedSummary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8"));
      expect(resumedSummary.commandFailureCount).toBe(1);
      expect(resumedSummary.commandFailureClasses).toEqual({ "binaryen-command-failed": 1 });
      expect(resumedSummary.comparedCount).toBe(0);
      expect(resumedSummary.generatorCounts).toEqual({ wasmSmith: 0, genValid: 0 });
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});
