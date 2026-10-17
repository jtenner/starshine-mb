import { expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function executable(file: string, source: string): string {
  fs.writeFileSync(file, `#!/usr/bin/env node\n${source}`, { mode: 0o755 });
  return file;
}

test("Node oracle executes Binaryen import modules without compact encoding", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-node-imports-"));
  try {
    fs.writeFileSync(path.join(root, "moon.mod"), "");
    // The same module, written by wasm-tools and by Binaryen v133 with all
    // features. The latter uses compact imports, which Node 24 cannot compile.
    const plain = "0061736d010000000108026000006000017f02120203656e760166000003656e76016d020001030201010707010372756e00010a0601040041070b";
    const compact = "0061736d010000000108026000006000017f02110103656e76007f02016d02000101660000030201010707010372756e00010a0601040041070b";
    const input = path.join(root, "input.wasm");
    fs.writeFileSync(input, Buffer.from(plain, "hex"));
    const starshine = executable(path.join(root, "starshine"), `
const fs = require("node:fs"), args = process.argv.slice(2);
if (args.includes("--emit-runtime-interface-json")) {
  console.log(JSON.stringify({
    schema: "starshine.optimizer-runtime-interface.v1", moduleHash: "fixture", interfaceHash: "fixture",
    features: [], hasStart: false,
    imports: { functions: [{ module: "env", field: "f", kind: "function", index: 0,
      signature: { params: [], results: [] }, support: "directly-constructible" }],
      globals: [], memories: [{ module: "env", field: "m", kind: "memory", index: 0,
        indexType: "i32", minimum: "1", maximum: null, shared: false, memory64: false,
        support: "directly-constructible" }], tables: [], tags: [] },
    exports: [{ name: "run", kind: "function", index: 1,
      signature: { params: [], results: ["i32"] }, support: "directly-constructible" }],
  }));
} else fs.copyFileSync(args[args.length - 1], args[args.indexOf("--out") + 1]);
`);
    const wasmTools = executable(path.join(root, "wasm-tools"), `
const fs = require("node:fs"), args = process.argv.slice(2);
if (args[0] === "smith") fs.copyFileSync(process.env.FIXTURE_WASM, args[args.indexOf("-o") + 1]);
else if (args[0] === "print") console.log('(module (type (;0;) (func)) (type (;1;) (func (result i32))) (import "env" "f" (func (;0;) (type 0))) (import "env" "m" (memory (;0;) 1)) (export "run" (func 1)) (func (;1;) (type 1) (result i32) i32.const 7))');
else if (args[0] === "--version") console.log("wasm-tools fixture");
`);
    const oracle = executable(path.join(root, "wasm-opt"), `
const fs = require("node:fs"), args = process.argv.slice(2);
if (args.includes("--version")) console.log("wasm-opt version 133 (test fixture)");
else {
  const output = args[args.indexOf("-o") + 1];
  if (args.includes("-S")) fs.writeFileSync(output, '(module (import "env" "f" (func)) (import "env" "m" (memory 1)) (func (export "run") (result i32) i32.const 7))');
  else if (output.endsWith("binaryen.raw.wasm")) {
    fs.appendFileSync(process.env.CALL_LOG, JSON.stringify(args) + "\\n");
    fs.writeFileSync(output, Buffer.from(args.includes("--disable-compact-imports") ? ${JSON.stringify(plain)} : ${JSON.stringify(compact)}, "hex"));
  } else fs.copyFileSync(args[0], output);
}
`);
    const log = path.join(root, "calls.jsonl");
    for (const [semantic, runtime] of [["node-v2", "off"], ["off", "off"], ["off", "node"]]) {
      const out = path.join(root, semantic + "-" + runtime);
      const result = spawnSync("bun", [
        path.resolve(import.meta.dir, "..", "pass-fuzz-compare.ts"),
        "--count", "1", "--wasm-smith", "--out-dir", out, "--jobs", "1",
        "--pass", "vacuum", "--starshine-bin", starshine, "--wasm-tools-bin", wasmTools,
        "--wasm-opt-bin", oracle, "--require-binaryen-version", "133", "--semantic-oracle", semantic,
        "--runtime-execution", runtime,
      ], { cwd: root, env: { ...process.env, FIXTURE_WASM: input, CALL_LOG: log }, encoding: "utf8", timeout: 30_000 });
      expect(result.status, result.stderr || result.stdout).toBe(0);
      const summary = JSON.parse(fs.readFileSync(path.join(out, "result.json"), "utf8"));
      expect(summary.comparedCount).toBe(1);
      if (semantic === "node-v2") {
        expect(summary.semanticV2ThreeWayPatterns).toEqual({ "all-equal": 1 });
      } else {
        expect(summary.semanticV2CheckedCount).toBe(0);
      }
      if (runtime === "node") {
        expect(summary.runtimeExecutionCounts.checked, JSON.stringify(summary.runtimeExecutionMatrix)).toBe(1);
        expect(summary.runtimeExecutionCounts.failed).toBe(0);
        expect(summary.runtimeExecutionCounts.unsupported).toBe(0);
      }
    }
    const calls = fs.readFileSync(log, "utf8").trim().split("\n").map(line => JSON.parse(line));
    expect(calls).toHaveLength(3);
    expect(calls[0].indexOf("--disable-compact-imports")).toBeGreaterThan(calls[0].indexOf("--all-features"));
    expect(calls[1]).toContain("--all-features");
    expect(calls[1]).not.toContain("--disable-compact-imports");
    expect(calls[2].indexOf("--disable-compact-imports")).toBeGreaterThan(calls[2].indexOf("--all-features"));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
