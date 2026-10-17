import { expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function executable(file: string, source: string): string {
  fs.writeFileSync(file, `#!/usr/bin/env node\n${source}`, { mode: 0o755 });
  return file;
}

test("Binaryen runtime discrepancies retain all bytes and observations beyond the structural cap", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-oracle-retention-"));
  try {
    fs.writeFileSync(path.join(root, "moon.mod"), "");
    // S6 DAE type-refinement input and verified Binaryen133 output. The latter
    // introduces an exact heap type, which default Node24 cannot compile.
    const original = Buffer.from("0061736d0100000001140450005f004f01005f006000017f60016300017f030403020302070801046d61696e00000a17030700fb010110010b05002000d10b0700fb010110010b", "hex");
    const oracleBytes = Buffer.from("0061736d010000000115046000017f50005f004f01015f006001646202017f030403000300070801046d61696e00000a17030700fb010210010b05002000d10b0700fb010210010b", "hex");
    const input = path.join(root, "input.wasm");
    const binaryenInput = path.join(root, "oracle.wasm");
    fs.writeFileSync(input, original);
    fs.writeFileSync(binaryenInput, oracleBytes);
    const starshine = executable(path.join(root, "starshine"), `
const fs = require("node:fs"), args = process.argv.slice(2);
if (args.includes("--emit-runtime-interface-json")) console.log(JSON.stringify({
  schema: "starshine.optimizer-runtime-interface.v1", moduleHash: "fixture", interfaceHash: "fixture",
  features: [], hasStart: false,
  imports: { functions: [], globals: [], memories: [], tables: [], tags: [] },
  exports: [{ name: "main", kind: "function", index: 0,
    signature: { params: [], results: ["i32"] }, support: "directly-constructible" }],
}));
else fs.copyFileSync(args[args.length - 1], args[args.indexOf("--out") + 1]);
`);
    const wasmTools = executable(path.join(root, "wasm-tools"), `
const fs = require("node:fs"), args = process.argv.slice(2);
if (args[0] === "smith") fs.copyFileSync(process.env.FIXTURE_WASM, args[args.indexOf("-o") + 1]);
else if (args[0] === "print") console.log('(module (func (export "main") (result i32) i32.const 0))');
else if (args[0] === "--version") console.log("wasm-tools fixture");
`);
    const oracle = executable(path.join(root, "wasm-opt"), `
const fs = require("node:fs"), args = process.argv.slice(2);
if (args.includes("--version")) console.log("wasm-opt version 133 (test fixture)");
else {
  const out = args[args.indexOf("-o") + 1];
  if (args.includes("-S")) {
    const different = process.env.STRUCTURAL_DIFF === "1" && fs.readFileSync(args[0]).equals(fs.readFileSync(process.env.ORACLE_WASM));
    fs.writeFileSync(out, '(module (func (export "main") (result i32) i32.const ' + (different ? 1 : 0) + '))');
  } else fs.copyFileSync(out.endsWith("binaryen.raw.wasm") ? process.env.ORACLE_WASM : args[0], out);
}
`);
    for (const [structural, originalBlocked] of [[false, false], [true, false], [false, true]]) {
      const out = path.join(root, originalBlocked ? "original-blocked" : structural ? "structural" : "equal-text");
      const env = { ...process.env, FIXTURE_WASM: originalBlocked ? binaryenInput : input, ORACLE_WASM: binaryenInput,
        STRUCTURAL_DIFF: structural ? "1" : "0", STARSHINE_NODE_CUSTOM_DESCRIPTORS: "0" };
      delete env.NODE_OPTIONS;
      const result = spawnSync("bun", [
        path.resolve(import.meta.dir, "..", "pass-fuzz-compare.ts"),
        "--count", "1", "--wasm-smith", "--out-dir", out, "--jobs", "1",
        "--pass", "dae", "--starshine-bin", starshine, "--wasm-tools-bin", wasmTools,
        "--wasm-opt-bin", oracle, "--require-binaryen-version", "133", "--semantic-oracle", "node-v2",
        "--report-only", "--max-mismatch-artifacts", "0",
      ], { cwd: root, env, encoding: "utf8", timeout: 30_000 });
      expect(result.status, result.stderr || result.stdout).toBe(0);
      const summary = JSON.parse(fs.readFileSync(path.join(out, "result.json"), "utf8"));
      if (originalBlocked) {
        // Unsupported original inputs carry no comparison evidence. Keep their
        // all-blocked cleanup bounded rather than retaining every such case.
        expect(summary.semanticV2ThreeWayPatterns).toEqual({ "original-runtime-blocked": 1 });
        expect(summary.semanticV2BlockedCount).toBe(1);
        expect(summary.failureDirs).toEqual([]);
        expect(fs.existsSync(path.join(out, "semantic-observations", "case-000001.json"))).toBeFalse();
        expect(fs.readdirSync(path.join(root, ".tmp", "codex-tmp"))).toEqual([]);
        continue;
      }
      expect(summary.semanticV2ThreeWayPatterns).toEqual({ "binaryen-discrepancy": 1 });
      expect(summary.semanticV2MatchCount).toBe(1);
      expect(summary.mismatchCount).toBe(structural ? 1 : 0);
      expect(summary.failureDirs).toHaveLength(1);
      const failure = summary.failureDirs[0];
      expect(fs.readFileSync(path.join(failure, "input.wasm"))).toEqual(original);
      expect(fs.readFileSync(path.join(failure, "starshine.raw.wasm"))).toEqual(original);
      expect(fs.readFileSync(path.join(failure, "binaryen.raw.wasm"))).toEqual(oracleBytes);
      const report = JSON.parse(fs.readFileSync(path.join(failure, "semantic-v2.json"), "utf8"));
      expect(report.originalVsStarshine.classification).toBe("semantic-match");
      expect(report.originalVsBinaryen.classification).toBe("blocked");
      expect(report.binaryen.compilation.status).toBe("failed");
      expect(report.binaryen.compilation.error).toContain("experimental-wasm-custom-descriptors");
      expect(fs.existsSync(path.join(out, "semantic-observations", "case-000001.json"))).toBeTrue();
      expect(fs.readdirSync(path.join(root, ".tmp", "codex-tmp"))).toEqual([]);
    }
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}, 30_000);
