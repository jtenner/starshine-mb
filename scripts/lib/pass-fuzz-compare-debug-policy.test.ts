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

describe("name and debug sensitive pass comparison", () => {
  test("preserves names while comparing strip-debug outputs", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-debug-policy-"));
    try {
      const namedWat = path.join(root, "named.wat");
      const namedWasm = path.join(root, "named.wasm");
      const strippedWat = path.join(root, "stripped.wat");
      const strippedWasm = path.join(root, "stripped.wasm");
      fs.writeFileSync(namedWat, `(module (func $candidate_name (export "run") (result i32) i32.const 7))`);
      fs.writeFileSync(strippedWat, `(module (func (export "run") (result i32) i32.const 7))`);
      for (const [wat, wasm] of [[namedWat, namedWasm], [strippedWat, strippedWasm]]) {
        const parsed = spawnSync("wasm-tools", ["parse", wat, "-o", wasm], { encoding: "utf8" });
        expect(parsed.status, parsed.stderr || parsed.stdout).toBe(0);
      }
      const printedNamed = spawnSync("wasm-tools", ["print", namedWasm], { encoding: "utf8" });
      expect(printedNamed.stdout).toContain("$candidate_name");

      const starshine = executable(path.join(root, "starshine"), `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
const out = args[args.indexOf("--out") + 1];
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.copyFileSync(args[args.length - 1], out);
`);
      const realWasmTools = spawnSync("which", ["wasm-tools"], { encoding: "utf8" }).stdout.trim();
      const wasmTools = executable(path.join(root, "wasm-tools"), `
const fs = require("node:fs");
const cp = require("node:child_process");
const args = process.argv.slice(2);
if (args[0] === "smith") {
  fs.copyFileSync(process.env.NAMED_WASM, args[args.indexOf("-o") + 1]);
  process.exit(0);
}
const result = cp.spawnSync(process.env.REAL_WASM_TOOLS, args, { stdio: "inherit" });
process.exit(result.status ?? 1);
`);
      const invocationLog = path.join(root, "wasm-opt-calls.jsonl");
      const wasmOpt = executable(path.join(root, "wasm-opt"), `
const fs = require("node:fs");
const cp = require("node:child_process");
const args = process.argv.slice(2);
if (args.includes("--version")) {
  console.log("wasm-opt version 132 (version_132)");
  process.exit(0);
}
fs.appendFileSync(process.env.INVOCATION_LOG, JSON.stringify(args) + "\\n");
const input = args[0];
const output = args[args.indexOf("-o") + 1];
const source = args.includes("--strip-debug") ? process.env.STRIPPED_WASM : input;
if (args.includes("-S")) {
  const printed = cp.spawnSync(process.env.REAL_WASM_TOOLS, ["print", source, "-o", output], { stdio: "inherit" });
  process.exit(printed.status ?? 1);
}
fs.copyFileSync(source, output);
`);
      const outDir = path.join(root, "out");
      const cacheDir = path.join(root, "cache");
      const result = spawnSync("bun", [
        path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
        "--count", "1",
        "--wasm-smith",
        "--out-dir", outDir,
        "--report-only",
        "--cache-dir", cacheDir,
        "--jobs", "1",
        "--pass", "strip-debug",
        "--starshine-bin", starshine,
        "--wasm-opt-bin", wasmOpt,
        "--wasm-tools-bin", wasmTools,
      ], {
        cwd: repoRoot,
        env: {
          ...process.env,
          INVOCATION_LOG: invocationLog,
          NAMED_WASM: namedWasm,
          STRIPPED_WASM: strippedWasm,
          REAL_WASM_TOOLS: realWasmTools,
        },
        encoding: "utf8",
        timeout: 30_000,
      });

      expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
      const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8"));
      expect(summary.comparisonDebugPolicy).toBe("preserve");
      expect(summary.comparedCount).toBe(1);
      expect(summary.normalizedMatchCount).toBe(0);
      expect(summary.mismatchCount).toBe(1);
      expect(summary.cache.binaryenMisses).toBe(1);
      expect(fs.existsSync(path.join(cacheDir, "binaryen", "schema-v2-debug-preserving"))).toBeTrue();
      const record = JSON.parse(fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8"));
      expect(record).toMatchObject({ status: "mismatch", generator: "wasm-smith" });

      const invocations = fs.readFileSync(invocationLog, "utf8").trim().split("\n").map((line) => JSON.parse(line) as string[]);
      const outputOf = (args: string[]) => args[args.indexOf("-o") + 1];
      const passInvocation = invocations.find((args) =>
        args.includes("--strip-debug") && outputOf(args).endsWith("binaryen.raw.wasm")
      );
      expect(passInvocation).toBeDefined();
      const comparisonProjectionInvocations = invocations.filter((args) =>
        /(?:starshine|binaryen)\.(?:wasm|wat)$/.test(outputOf(args)) &&
        !outputOf(args).endsWith("binaryen.raw.wasm")
      );
      expect(comparisonProjectionInvocations).toHaveLength(4);
      for (const args of comparisonProjectionInvocations) {
        expect(args).not.toContain("--strip-debug");
      }

      const findDone = (directory: string): string | null => {
        for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
          const candidate = path.join(directory, entry.name);
          if (entry.isDirectory()) {
            const nested = findDone(candidate);
            if (nested !== null) return nested;
          } else if (entry.name === "done.json") {
            return candidate;
          }
        }
        return null;
      };
      const done = findDone(cacheDir);
      expect(done).not.toBeNull();
      fs.writeFileSync(path.join(path.dirname(done!), "binaryen.wasm"), "corrupt canonical output");
      const secondOutDir = path.join(root, "out-after-corruption");
      const second = spawnSync("bun", [
        path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
        "--count", "1", "--wasm-smith", "--out-dir", secondOutDir,
        "--report-only", "--cache-dir", cacheDir, "--jobs", "1",
        "--pass", "strip-debug", "--starshine-bin", starshine,
        "--wasm-opt-bin", wasmOpt, "--wasm-tools-bin", wasmTools,
      ], {
        cwd: repoRoot,
        env: {
          ...process.env,
          INVOCATION_LOG: invocationLog,
          NAMED_WASM: namedWasm,
          STRIPPED_WASM: strippedWasm,
          REAL_WASM_TOOLS: realWasmTools,
        },
        encoding: "utf8",
        timeout: 30_000,
      });
      expect(second.status, `${second.stdout}\n${second.stderr}`).toBe(0);
      const secondSummary = JSON.parse(fs.readFileSync(path.join(secondOutDir, "result.json"), "utf8"));
      expect(secondSummary.cache.binaryenMisses).toBe(1);
      expect(secondSummary.cache.binaryenHits).toBe(0);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});
