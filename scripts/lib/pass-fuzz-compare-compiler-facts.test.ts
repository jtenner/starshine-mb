import { describe, expect, test } from "bun:test";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function executable(file: string, source: string): string {
  fs.writeFileSync(file, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(file, 0o755);
  return file;
}

describe("compare-pass compiler facts journal context", () => {
  test("records the exact input custom section and effective policy while accepting legacy resume rows", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-compiler-facts-journal-"));
    try {
      const fixture = Buffer.from(
        "0061736d01000000001a0e636f6d70696c65722e66616374730100000000000000000000",
        "hex",
      );
      const fixturePath = path.join(root, "compiler-facts.wasm");
      fs.writeFileSync(fixturePath, fixture);
      const invocationLog = path.join(root, "starshine-calls.jsonl");
      const starshine = executable(path.join(root, "starshine"), `
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.INVOCATION_LOG, JSON.stringify(args) + "\\n");
fs.copyFileSync(args[args.length - 1], args[args.indexOf("--out") + 1]);
`);
      const wasmTools = executable(path.join(root, "wasm-tools"), `
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args[0] === "--version") {
  console.log("wasm-tools synthetic");
} else if (args[0] === "smith") {
  fs.copyFileSync(process.env.FIXTURE_WASM, args[args.indexOf("-o") + 1]);
}
`);
      const wasmOpt = executable(path.join(root, "wasm-opt"), `
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args.includes("--version")) {
  console.log("wasm-opt version 132 (version_132)");
  process.exit(0);
}
const output = args[args.indexOf("-o") + 1];
if (args.includes("-S")) fs.writeFileSync(output, "(module)\\n");
else fs.copyFileSync(args[0], output);
`);
      const outDir = path.join(root, "out");
      const args = [
        path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
        "--count", "1",
        "--wasm-smith",
        "--out-dir", outDir,
        "--report-only",
        "--no-cache",
        "--jobs", "1",
        "--pass", "vacuum",
        "--compiler-facts", "trust",
        "--starshine-bin", starshine,
        "--wasm-opt-bin", wasmOpt,
        "--wasm-tools-bin", wasmTools,
      ];
      const env = {
        ...process.env,
        FIXTURE_WASM: fixturePath,
        INVOCATION_LOG: invocationLog,
      };
      const result = spawnSync("bun", args, {
        cwd: repoRoot,
        env,
        encoding: "utf8",
        timeout: 30_000,
      });

      expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
      const record = JSON.parse(fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8"));
      const rawSection = fixture.subarray(8);
      expect(record.compilerFactsContext).toEqual({
        present: true,
        sectionCount: 1,
        rawSectionsByteLength: rawSection.byteLength,
        rawSectionsSha256: `sha256:${crypto.createHash("sha256").update(rawSection).digest("hex")}`,
        scanStatus: "complete",
        effectivePolicy: "trust",
      });
      const invocations = fs.readFileSync(invocationLog, "utf8").trim().split("\n")
        .map((line) => JSON.parse(line) as string[]);
      expect(invocations[0]).toContain("--compiler-facts=trust");

      delete record.compilerFactsContext;
      fs.writeFileSync(path.join(outDir, "cases.jsonl"), `${JSON.stringify(record)}\n`);
      const resumed = spawnSync("bun", [...args, "--resume"], {
        cwd: repoRoot,
        env,
        encoding: "utf8",
        timeout: 30_000,
      });
      expect(resumed.status, `${resumed.stdout}\n${resumed.stderr}`).toBe(0);
      const resumedRecord = JSON.parse(fs.readFileSync(path.join(outDir, "cases.jsonl"), "utf8"));
      expect(resumedRecord.compilerFactsContext).toBeUndefined();
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});
