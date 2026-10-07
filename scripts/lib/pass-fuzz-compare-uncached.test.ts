import { expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function executable(file: string, source: string): string {
  fs.writeFileSync(file, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(file, 0o755);
  return file;
}

test("fuzz runs execute afresh, clean consumed artifacts, and preserve semantic differences", () => {
  const script = path.resolve(import.meta.dir, "..", "pass-fuzz-compare.ts");
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-uncached-fuzz-"));
  try {
    fs.writeFileSync(path.join(root, "moon.mod"), "");
    const fixture = path.join(root, "input.wasm");
    fs.writeFileSync(fixture, Buffer.from("0061736d010000000105016000017f030201000707010372756e00000a0601040041070b", "hex"));
    const log = path.join(root, "calls.jsonl");
    const starshine = executable(path.join(root, "starshine"), `
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args.includes("--emit-runtime-interface-json")) {
  fs.appendFileSync(process.env.CALL_LOG, JSON.stringify("semantic-interface") + "\\n");
  console.log(JSON.stringify({
    schema: "starshine.optimizer-runtime-interface.v1", moduleHash: "fixture", interfaceHash: "fixture",
    features: [], hasStart: false,
    imports: { functions: [], globals: [], memories: [], tables: [], tags: [] },
    exports: [{ name: "run", kind: "function", index: 0,
      signature: { params: [], results: ["i32"] }, support: "directly-constructible" }],
  }));
} else {
  if (process.env.CHECK_CONSUMED_INPUT) {
    fs.appendFileSync(process.env.CALL_LOG, JSON.stringify("first-input-exists:" + fs.existsSync(process.env.CHECK_CONSUMED_INPUT)) + "\\n");
  }
  fs.copyFileSync(process.env.CHANGE_CANDIDATE === "1" ? process.env.DIFFERENT_WASM : args[args.length - 1], args[args.indexOf("--out") + 1]);
}
`);
    const wasmTools = executable(path.join(root, "wasm-tools"), `
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args[0] === "smith") {
  fs.appendFileSync(process.env.CALL_LOG, JSON.stringify("smith") + "\\n");
  fs.copyFileSync(process.env.FIXTURE_WASM, args[args.indexOf("-o") + 1]);
} else if (args[0] === "print") {
  console.log('(module (func (export "run") (result i32) i32.const 7))');
} else if (args[0] === "--version") {
  console.log("wasm-tools test fixture");
}
`);
    const wasmOpt = executable(path.join(root, "wasm-opt"), `
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args.includes("--version")) {
  console.log("wasm-opt version 133 (test fixture)");
} else {
  const output = args[args.indexOf("-o") + 1];
  if (output.endsWith("binaryen.raw.wasm")) {
    fs.appendFileSync(process.env.CALL_LOG, JSON.stringify("binaryen") + "\\n");
  }
  if (args.includes("-S")) {
    const value = fs.readFileSync(args[0]).at(-2);
    fs.writeFileSync(output, '(module (func (export "run") (result i32) i32.const ' + value + '))');
  } else {
    fs.copyFileSync(process.env.CHANGE_ORACLE === "1" && output.endsWith("binaryen.raw.wasm") ? process.env.DIFFERENT_WASM : args[0], output);
  }
}
`);
    let previousSemanticCalls = 0;
    for (let run = 1; run <= 2; run += 1) {
      const outDir = path.join(root, `out-${run}`);
      const result = spawnSync("bun", [
        script, "--count", "1", "--wasm-smith", "--out-dir", outDir, "--jobs", "1",
        "--pass", "vacuum", "--starshine-bin", starshine, "--wasm-tools-bin", wasmTools,
        "--wasm-opt-bin", wasmOpt, "--require-binaryen-version", "133", "--semantic-oracle", "node-v2",
      ], {
        cwd: root,
        env: { ...process.env, CALL_LOG: log, FIXTURE_WASM: fixture },
        encoding: "utf8",
        timeout: 30_000,
      });
      expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
      const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8"));
      expect(summary.comparedCount).toBe(1);
      expect(summary.semanticV2MatchCount).toBe(1);
      const calls = fs.readFileSync(log, "utf8").trim().split("\n").map((line) => JSON.parse(line));
      expect(calls.filter((call) => call === "smith")).toHaveLength(run);
      expect(calls.filter((call) => call === "binaryen")).toHaveLength(run);
      const semanticCalls = calls.filter((call) => call === "semantic-interface").length;
      expect(semanticCalls).toBeGreaterThan(previousSemanticCalls);
      previousSemanticCalls = semanticCalls;
      expect(fs.existsSync(path.join(root, ".tmp", "pass-fuzz-cache"))).toBeFalse();
      expect(summary).not.toHaveProperty("cache");
      expect(fs.existsSync(path.join(outDir, "semantic-observations", "case-000001.json"))).toBeFalse();
      expect(fs.readdirSync(path.join(root, ".tmp", "codex-tmp"))).toEqual([]);
    }

    const generator = executable(path.join(root, "gen-valid"), `
const fs = require("node:fs"), path = require("node:path");
const args = process.argv.slice(2);
const output = args[args.indexOf("--out-dir") + 1];
fs.mkdirSync(output, { recursive: true });
const records = [1, 2].map(index => {
  const file_name = 'gen-valid-' + String(index).padStart(6, '0') + '.wasm';
  fs.copyFileSync(process.env.FIXTURE_WASM, path.join(output, file_name));
  if (args.includes('--metamorphic-transform')) {
    fs.copyFileSync(process.env.FIXTURE_WASM, path.join(output, 'shared-base.wasm'));
    return { file_name, base_file_name: 'shared-base.wasm', relation_group_id: 'fixture-' + index,
      transform_id: 'add-non-name-custom-section' };
  }
  return { file_name };
});
fs.writeFileSync(args[args.indexOf("--manifest") + 1], JSON.stringify({ records }));
`);
    const genValidOut = path.join(root, "gen-valid-out");
    const genValidArgs = [
      script, "--count", "2", "--gen-valid-bin", generator, "--out-dir", genValidOut,
      "--jobs", "1", "--pass", "vacuum", "--starshine-bin", starshine,
      "--wasm-tools-bin", wasmTools, "--wasm-opt-bin", wasmOpt, "--require-binaryen-version", "133",
    ];
    const genValid = spawnSync("bun", genValidArgs, {
      cwd: root,
      env: { ...process.env, CALL_LOG: log, FIXTURE_WASM: fixture,
        CHECK_CONSUMED_INPUT: path.join(genValidOut, "inputs", "gen-valid", "gen-valid-000001.wasm") },
      encoding: "utf8", timeout: 30_000,
    });
    expect(genValid.status, genValid.stderr).toBe(0);
    const consumed = fs.readFileSync(log, "utf8").trim().split("\n").map(line => JSON.parse(line))
      .filter(call => typeof call === "string" && call.startsWith("first-input-exists:"));
    expect(consumed).toEqual(["first-input-exists:true", "first-input-exists:false"]);
    expect(fs.readdirSync(path.join(genValidOut, "inputs", "gen-valid"))).toEqual(["manifest.json"]);
    const resumed = spawnSync("bun", [...genValidArgs, "--resume"], {
      cwd: root, env: { ...process.env, CALL_LOG: log, FIXTURE_WASM: fixture },
      encoding: "utf8", timeout: 30_000,
    });
    expect(resumed.status, resumed.stderr).toBe(0);
    const resumedSummary = JSON.parse(fs.readFileSync(path.join(genValidOut, "result.json"), "utf8"));
    expect(resumedSummary.resumedCaseCount).toBe(2);
    expect(resumedSummary.comparedCount).toBe(2);

    // Recreate an interrupted-run state: case 1 is journaled and cleaned,
    // while only case 2's unused input remains beside the original manifest.
    const journalPath = path.join(genValidOut, "cases.jsonl");
    const firstRecord = fs.readFileSync(journalPath, "utf8").trim().split("\n")[0];
    fs.writeFileSync(journalPath, firstRecord + "\n");
    fs.copyFileSync(fixture, path.join(genValidOut, "inputs", "gen-valid", "gen-valid-000002.wasm"));
    const pendingResume = spawnSync("bun", [...genValidArgs, "--resume"], {
      cwd: root, env: { ...process.env, CALL_LOG: log, FIXTURE_WASM: fixture },
      encoding: "utf8", timeout: 30_000,
    });
    expect(pendingResume.status, pendingResume.stderr).toBe(0);
    const pendingSummary = JSON.parse(fs.readFileSync(path.join(genValidOut, "result.json"), "utf8"));
    expect(pendingSummary.resumedCaseCount).toBe(1);
    expect(pendingSummary.comparedCount).toBe(2);
    expect(fs.readdirSync(path.join(genValidOut, "inputs", "gen-valid"))).toEqual(["manifest.json"]);

    const pairedOut = path.join(root, "paired-out");
    const paired = spawnSync("bun", [
      ...genValidArgs.map(arg => arg === genValidOut ? pairedOut : arg),
      "--semantic-oracle", "node-v2", "--emit-metamorphic-pairs",
      "--gen-valid-metamorphic-transform", "add-non-name-custom-section",
    ], {
      cwd: root, env: { ...process.env, CALL_LOG: log, FIXTURE_WASM: fixture },
      encoding: "utf8", timeout: 30_000,
    });
    expect(paired.status, paired.stderr).toBe(0);
    const pairedSummary = JSON.parse(fs.readFileSync(path.join(pairedOut, "result.json"), "utf8"));
    expect(pairedSummary.metamorphicCheckedCount).toBe(2);
    expect(pairedSummary.metamorphicMatchCount).toBe(2);
    expect(fs.readdirSync(path.join(pairedOut, "inputs", "gen-valid"))).toEqual(["manifest.json"]);
    expect(fs.readdirSync(path.join(pairedOut, "property-artifacts"))).toEqual([]);

    const different = path.join(root, "different.wasm");
    const differentBytes = fs.readFileSync(fixture);
    differentBytes[differentBytes.length - 2] = 8;
    fs.writeFileSync(different, differentBytes);
    for (const changed of ["CHANGE_CANDIDATE", "CHANGE_ORACLE"]) {
      const outDir = path.join(root, changed);
      const result = spawnSync("bun", [
        script, "--count", "1", "--wasm-smith", "--out-dir", outDir, "--jobs", "1",
        "--pass", "vacuum", "--starshine-bin", starshine, "--wasm-tools-bin", wasmTools,
        "--wasm-opt-bin", wasmOpt, "--require-binaryen-version", "133", "--semantic-oracle", "node-v2",
        "--report-only", "--max-mismatch-artifacts", "0",
      ], {
        cwd: root, env: { ...process.env, CALL_LOG: log, FIXTURE_WASM: fixture,
          DIFFERENT_WASM: different, [changed]: "1" },
        encoding: "utf8", timeout: 30_000,
      });
      expect(result.status, result.stderr).toBe(0);
      const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8"));
      expect(summary.failureDirs).toHaveLength(1);
      if (changed === "CHANGE_ORACLE") {
        expect(summary.mismatchArtifactsPersistedCount).toBe(1);
        expect(summary.mismatchArtifactsSuppressedCount).toBe(0);
      }
      const failure = summary.failureDirs[0];
      expect(fs.readFileSync(path.join(failure, "input.wasm"))).toEqual(fs.readFileSync(fixture));
      expect(fs.readFileSync(path.join(failure, "starshine.raw.wasm"))).toEqual(fs.readFileSync(changed === "CHANGE_CANDIDATE" ? different : fixture));
      expect(fs.readFileSync(path.join(failure, "binaryen.raw.wasm"))).toEqual(fs.readFileSync(changed === "CHANGE_ORACLE" ? different : fixture));
      expect(fs.existsSync(path.join(failure, "semantic-v2.json"))).toBeTrue();
      expect(fs.existsSync(path.join(outDir, "semantic-observations", "case-000001.json"))).toBeTrue();
      expect(fs.readdirSync(path.join(root, ".tmp", "codex-tmp"))).toEqual([]);
    }

    const cutoffOut = path.join(root, "cutoff-out");
    const cutoff = spawnSync("bun", [
      ...genValidArgs.map(arg => arg === genValidOut ? cutoffOut : arg),
      "--semantic-oracle", "node-v2", "--report-only", "--max-failures", "1", "--no-reduce-mismatches",
    ], {
      cwd: root, env: { ...process.env, CALL_LOG: log, FIXTURE_WASM: fixture,
        DIFFERENT_WASM: different, CHANGE_CANDIDATE: "1" },
      encoding: "utf8", timeout: 30_000,
    });
    expect(cutoff.status, cutoff.stderr).toBe(0);
    const cutoffSummary = JSON.parse(fs.readFileSync(path.join(cutoffOut, "result.json"), "utf8"));
    expect(cutoffSummary.maxFailuresHit).toBeTrue();
    expect(cutoffSummary.failureDirs).toHaveLength(1);
    expect(fs.existsSync(path.join(cutoffSummary.failureDirs[0], "input.wasm"))).toBeTrue();
    expect(fs.readdirSync(path.join(cutoffOut, "inputs", "gen-valid"))).toEqual(["manifest.json"]);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}, 30_000);
