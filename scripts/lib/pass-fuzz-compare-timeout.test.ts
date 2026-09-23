import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const SUBPROCESS_TIMEOUT_MS = 75;
const HARNESS_TIMEOUT_MS = 2_000;

function executable(file: string, source: string): string {
  fs.writeFileSync(file, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(file, 0o755);
  return file;
}

function syntheticTools(root: string) {
  const starshine = executable(path.join(root, "starshine"), `
const fs = require("node:fs");
if (process.env.HANG_SURFACE === "starshine") setInterval(() => {}, 1000);
const args = process.argv.slice(2);
fs.copyFileSync(args[args.length - 1], args[args.indexOf("--out") + 1]);
`);
  const wasmTools = executable(path.join(root, "wasm-tools"), `
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args.includes("--version")) {
  console.log("wasm-tools 1.0.0");
  process.exit(0);
} else if (args[0] === "smith") {
  if (process.env.HANG_SURFACE === "wasm-smith") {
    setInterval(() => {}, 1000);
  } else {
    fs.writeFileSync(args[args.indexOf("-o") + 1], Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]));
    process.exit(0);
  }
} else if (args[0] === "validate") {
  process.exit(0);
} else if (args[0] === "print") {
  const outputIndex = args.indexOf("-o");
  if (outputIndex >= 0) fs.writeFileSync(args[outputIndex + 1], "(module)\\n");
  else process.stdout.write("(module)\\n");
  process.exit(0);
} else {
  process.exit(1);
}
`);
  const wasmOpt = executable(path.join(root, "wasm-opt"), `
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args.includes("--version")) {
  if (process.env.HANG_SURFACE === "binaryen-version") {
    setInterval(() => {}, 1000);
  } else {
    console.log("wasm-opt version 132 (version_132)");
    process.exit(0);
  }
} else {
  const outputIndex = args.indexOf("-o");
  if (args.includes("-S")) fs.writeFileSync(args[outputIndex + 1], "(module)\\n");
  else fs.copyFileSync(args[0], args[outputIndex + 1]);
}
`);
  const externalValidator = executable(path.join(root, "external-validator"), `
if (process.env.HANG_SURFACE === "external-validator") {
  setInterval(() => {}, 1000);
} else {
  process.exit(0);
}
`);
  const genValid = executable(path.join(root, "gen-valid"), `
if (process.env.HANG_SURFACE === "gen-valid") {
  setInterval(() => {}, 1000);
} else {
  process.exit(1);
}
`);
  return { starshine, wasmTools, wasmOpt, externalValidator, genValid };
}

function runHarness(
  repoRoot: string,
  root: string,
  tools: ReturnType<typeof syntheticTools>,
  surface: "starshine" | "external-validator" | "wasm-smith" | "gen-valid" | "binaryen-version",
) {
  const outDir = path.join(root, `out-${surface}`);
  const generatorArgs = surface === "gen-valid"
    ? ["--gen-valid-bin", tools.genValid]
    : ["--wasm-smith"];
  const externalValidatorArgs = surface === "external-validator"
    ? ["--external-validator", "wabt", "--wabt-validate-bin", tools.externalValidator]
    : [];
  const startedAt = performance.now();
  const result = spawnSync("bun", [
    path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
    "--count", "1",
    "--out-dir", outDir,
    "--report-only",
    "--no-cache",
    "--jobs", "1",
    "--pass", "vacuum",
    "--starshine-bin", tools.starshine,
    "--wasm-opt-bin", tools.wasmOpt,
    "--wasm-tools-bin", tools.wasmTools,
    "--subprocess-timeout-ms", String(SUBPROCESS_TIMEOUT_MS),
    ...generatorArgs,
    ...externalValidatorArgs,
  ], {
    cwd: repoRoot,
    env: { ...process.env, HANG_SURFACE: surface },
    encoding: "utf8",
    timeout: HARNESS_TIMEOUT_MS,
  });
  return { result, elapsedMs: performance.now() - startedAt, outDir };
}

describe("pass-fuzz subprocess deadlines", () => {
  test("reports a hanging Starshine optimizer as a bounded command failure", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-timeout-optimizer-"));
    try {
      const run = runHarness(repoRoot, root, syntheticTools(root), "starshine");
      expect(run.result.error, String(run.result.error)).toBeUndefined();
      expect(run.elapsedMs).toBeLessThan(HARNESS_TIMEOUT_MS);
      expect(run.result.status, `${run.result.stdout}\n${run.result.stderr}`).toBe(0);
      const summary = JSON.parse(fs.readFileSync(path.join(run.outDir, "result.json"), "utf8"));
      expect(summary.commandFailureCount).toBe(1);
      expect(fs.readFileSync(path.join(run.outDir, "cases.jsonl"), "utf8")).toContain(
        `command timed out after ${SUBPROCESS_TIMEOUT_MS} ms`,
      );
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  }, 5_000);

  test("terminates a hanging configured external validator", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-timeout-validator-"));
    try {
      const run = runHarness(repoRoot, root, syntheticTools(root), "external-validator");
      expect(run.result.error, String(run.result.error)).toBeUndefined();
      expect(run.elapsedMs).toBeLessThan(HARNESS_TIMEOUT_MS);
      expect(run.result.status).not.toBe(0);
      expect(run.result.stderr).toContain(`command timed out after ${SUBPROCESS_TIMEOUT_MS} ms`);
      expect(run.result.stderr).toContain(toolsPath(root, "external-validator"));
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  }, 5_000);

  test("terminates a hanging wasm-smith generator at the configured deadline", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-timeout-smith-"));
    try {
      const run = runHarness(repoRoot, root, syntheticTools(root), "wasm-smith");
      expect(run.result.error, String(run.result.error)).toBeUndefined();
      expect(run.elapsedMs).toBeLessThan(HARNESS_TIMEOUT_MS);
      expect(run.result.status).not.toBe(0);
      expect(run.result.stderr).toContain(`command timed out after ${SUBPROCESS_TIMEOUT_MS} ms`);
      expect(run.result.stderr).toContain(toolsPath(root, "wasm-tools"));
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  }, 5_000);

  test("terminates a hanging synchronous GenValid generator at the configured deadline", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-timeout-gen-valid-"));
    try {
      const run = runHarness(repoRoot, root, syntheticTools(root), "gen-valid");
      expect(run.result.error, String(run.result.error)).toBeUndefined();
      expect(run.elapsedMs).toBeLessThan(HARNESS_TIMEOUT_MS);
      expect(run.result.status).not.toBe(0);
      expect(run.result.stderr).toContain(`command timed out after ${SUBPROCESS_TIMEOUT_MS} ms`);
      expect(run.result.stderr).toContain(toolsPath(root, "gen-valid"));
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  }, 5_000);

  test("terminates a hanging synchronous Binaryen version probe at the configured deadline", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-timeout-version-probe-"));
    try {
      const run = runHarness(repoRoot, root, syntheticTools(root), "binaryen-version");
      expect(run.result.error, String(run.result.error)).toBeUndefined();
      expect(run.elapsedMs).toBeLessThan(HARNESS_TIMEOUT_MS);
      expect(run.result.status).not.toBe(0);
      expect(run.result.stderr).toContain(`timed out after ${SUBPROCESS_TIMEOUT_MS} ms`);
      expect(run.result.stderr).toContain(toolsPath(root, "wasm-opt"));
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  }, 5_000);
});

function toolsPath(root: string, name: string): string {
  return path.join(root, name);
}
