import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import { describe, expect, test } from "bun:test";

import { parseSelfOptArtifactOptimizerCompareArgs, parseSelfOptCheckArgs, runSelfOptArtifactOptimizerCompare, runSelfOptCheck } from "./self-opt-task";
import { parseStarshinePerfTimingSummary } from "./self-optimize-compare-task";

describe("self-optimize compare timing parsing", () => {
  test("separates raw pass timers from pass-local timers", () => {
    const summary = parseStarshinePerfTimingSummary([
      "perf:timer name=raw:ssa-nomerge:func:5539 elapsed_us=61000000 total_us=61000000",
      "perf:timer name=pass:ssa-nomerge elapsed_us=367 total_us=367",
      "perf:timer name=validate:final-module elapsed_us=5000 total_us=5000",
      "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
    ].join("\n"));

    expect(summary.passElapsedMs).toBe(0.367);
    expect(summary.rawElapsedMs).toBe(61000);
    expect(summary.otherTimedElapsedMs).toBe(5);
    expect(summary.passSkippedRaw).toBe(true);
  });
});

describe("self-opt artifact check lane", () => {
  test("defaults to a fast spec smoke while still selecting the generated self-optimized artifact", () => {
    const parsed = parseSelfOptCheckArgs([]);

    expect(parsed).toEqual({
      limit: 1,
      onlyFiles: [],
      wasmPath: null,
    });
  });

  test("can request a full spec run explicitly", () => {
    const parsed = parseSelfOptCheckArgs(["--full-spec"]);

    expect(parsed).toEqual({
      limit: null,
      onlyFiles: [],
      wasmPath: null,
    });
  });

  test("rejects mixing an explicit limit with the full spec workload", () => {
    expect(() => parseSelfOptCheckArgs(["--limit", "2", "--full-spec"])).toThrow("--full-spec cannot be combined with --limit");
    expect(() => parseSelfOptCheckArgs(["--full-spec", "--limit", "2"])).toThrow("--limit cannot be combined with --full-spec");
  });

  test("validates, runtime-smokes with observable help output, then runs the selected spec workload", async () => {
    const calls: string[] = [];
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-check-"));
    const wasmPath = path.join(repoRoot, "tests", "node", "dist", "starshine-self-optimized-wasi.wasm");

    await runSelfOptCheck([], {
      repoRoot,
      validateWasmArtifact(args) {
        calls.push(`validate:${args.label}:${args.wasmPath}`);
      },
      async runWasmStart(args) {
        calls.push(`runtime:${args.wasmPath}:${args.args.join(" ")}:${typeof args.stdoutFd}`);
        fs.writeSync(args.stdoutFd as number, "Usage: starshine\n");
        return 0;
      },
      async runSelfOptimizedSpecSuite(args) {
        calls.push(`spec:${args.wasmPath}:${String(args.limit)}:${args.onlyFiles.join(",")}`);
        return {
          selectedFileCount: 1,
          runnerWasm: args.wasmPath,
          exitCode: 0,
          stdout: "spec suite summary: total=1 passed=0 skipped=1 failed=0\n",
          stderr: "",
        };
      },
      prepareSpecRunnerWasm(_repoRoot, sourceWasmPath) {
        calls.push(`copy:${sourceWasmPath}`);
        return {
          wasmPath: path.join(repoRoot, ".tmp", "self-opt-check-runner.wasm"),
          cleanup() {
            calls.push("cleanup");
          },
        };
      },
      writeStdout() {},
    });

    expect(calls).toEqual([
      `validate:self-optimized wasm artifact:${wasmPath}`,
      `runtime:${wasmPath}:--help:number`,
      `copy:${wasmPath}`,
      `spec:${path.join(repoRoot, ".tmp", "self-opt-check-runner.wasm")}:1:`,
      "cleanup",
    ]);
  });

  test("fails the lane when the runtime smoke exits nonzero before the spec suite", async () => {
    const calls: string[] = [];
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-check-"));

    await expect(runSelfOptCheck([], {
      repoRoot,
      validateWasmArtifact() {
        calls.push("validate");
      },
      async runWasmStart() {
        calls.push("runtime");
        return 7;
      },
      async runSelfOptimizedSpecSuite() {
        calls.push("spec");
        return {
          selectedFileCount: 1,
          runnerWasm: path.join(repoRoot, "out.wasm"),
          exitCode: 0,
          stdout: "spec suite summary: total=1 passed=0 skipped=1 failed=0\n",
          stderr: "",
        };
      },
      writeStdout() {},
    })).rejects.toThrow("self-optimized wasm --help smoke failed with exit code 7");

    expect(calls).toEqual(["validate", "runtime"]);
  });

  test("fails the lane when the runtime smoke exits zero without printing help", async () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-check-"));

    await expect(runSelfOptCheck([], {
      repoRoot,
      validateWasmArtifact() {},
      async runWasmStart() {
        return 0;
      },
      async runSelfOptimizedSpecSuite() {
        return {
          selectedFileCount: 1,
          runnerWasm: path.join(repoRoot, "out.wasm"),
          exitCode: 0,
          stdout: "spec suite summary: total=1 passed=0 skipped=1 failed=0\n",
          stderr: "",
        };
      },
      writeStdout() {},
    })).rejects.toThrow("self-optimized wasm --help smoke produced no Usage output");
  });

  test("fails the lane when the spec smoke exits zero without an expected summary", async () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-check-"));

    await expect(runSelfOptCheck([], {
      repoRoot,
      validateWasmArtifact() {},
      async runWasmStart(args) {
        fs.writeSync(args.stdoutFd as number, "Usage: starshine\n");
        return 0;
      },
      async runSelfOptimizedSpecSuite() {
        return {
          selectedFileCount: 1,
          runnerWasm: path.join(repoRoot, "out.wasm"),
          exitCode: 0,
          stdout: "Usage: starshine\n",
          stderr: "",
        };
      },
      prepareSpecRunnerWasm(_repoRoot, sourceWasmPath) {
        return { wasmPath: sourceWasmPath };
      },
      writeStdout() {},
    })).rejects.toThrow("self-optimized wasm spec smoke produced no summary for 1 selected file(s)");
  });

  test("fails the lane when the spec smoke summary counts are inconsistent", async () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-check-"));

    await expect(runSelfOptCheck([], {
      repoRoot,
      validateWasmArtifact() {},
      async runWasmStart(args) {
        fs.writeSync(args.stdoutFd as number, "Usage: starshine\n");
        return 0;
      },
      async runSelfOptimizedSpecSuite() {
        return {
          selectedFileCount: 1,
          runnerWasm: path.join(repoRoot, "out.wasm"),
          exitCode: 0,
          stdout: "spec suite summary: total=1 passed=262012 skipped=248812 failed=0\n",
          stderr: "",
        };
      },
      prepareSpecRunnerWasm(_repoRoot, sourceWasmPath) {
        return { wasmPath: sourceWasmPath };
      },
      writeStdout() {},
    })).rejects.toThrow("self-optimized wasm spec smoke summary counts are inconsistent");
  });
});

describe("self-opt artifact optimizer exact compare", () => {
  test("defaults to comparing the wasm artifact optimizer against a native baseline", () => {
    const parsed = parseSelfOptArtifactOptimizerCompareArgs([]);

    expect(parsed).toEqual({
      optimizerWasmPath: null,
      inputWasmPath: null,
      expectedWasmPath: null,
      nativeBin: null,
      outDir: ".tmp/self-opt-artifact-optimizer-compare",
    });
  });

  test("runs native and wasm artifact optimizers then compares exact bytes", async () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-"));
    const distDir = path.join(repoRoot, "tests", "node", "dist");
    fs.mkdirSync(distDir, { recursive: true });
    const optimizerWasm = path.join(distDir, "starshine-self-optimized-wasi.wasm");
    const inputWasm = path.join(distDir, "starshine-debug-wasi.wasm");
    fs.writeFileSync(optimizerWasm, "optimizer");
    fs.writeFileSync(inputWasm, "debug");

    const calls: string[] = [];
    const result = await runSelfOptArtifactOptimizerCompare([], {
      repoRoot,
      validateWasmArtifact(args) {
        calls.push(`validate:${path.basename(args.wasmPath)}:${args.label}`);
      },
      runNativeOptimizer(_command, args) {
        calls.push(`native:${args.join(" ")}`);
        fs.writeFileSync(args[args.indexOf("--out") + 1], "same-output");
      },
      async runWasmStart(args) {
        calls.push(`wasm:${args.args.join(" ")}`);
        fs.writeFileSync(args.args[args.args.indexOf("--out") + 1], "same-output");
        return 0;
      },
      writeStdout() {},
    });

    expect(result.exactMatch).toBe(true);
    expect(result.size).toBe("same-output".length);
    expect(calls).toContain(`validate:${path.basename(optimizerWasm)}:self-optimized wasm optimizer artifact`);
    expect(calls).toContain(`validate:${path.basename(inputWasm)}:debug wasm input artifact`);
    expect(calls.some((call) => call.startsWith("native:--debug-serial-passes --optimize -O4z --out"))).toBe(true);
    expect(calls.some((call) => call.startsWith("wasm:--debug-serial-passes --optimize -O4z --out"))).toBe(true);
  });

  test("reports the first differing byte when exact compare fails", async () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-"));
    const distDir = path.join(repoRoot, "tests", "node", "dist");
    fs.mkdirSync(distDir, { recursive: true });
    fs.writeFileSync(path.join(distDir, "starshine-self-optimized-wasi.wasm"), "optimizer");
    fs.writeFileSync(path.join(distDir, "starshine-debug-wasi.wasm"), "debug");

    await expect(runSelfOptArtifactOptimizerCompare([], {
      repoRoot,
      validateWasmArtifact() {},
      runNativeOptimizer(_command, args) {
        fs.writeFileSync(args[args.indexOf("--out") + 1], Buffer.from([1, 2, 3]));
      },
      async runWasmStart(args) {
        fs.writeFileSync(args.args[args.args.indexOf("--out") + 1], Buffer.from([1, 9, 3]));
        return 0;
      },
      writeStdout() {},
    })).rejects.toThrow("firstDiffOffset=1");
  });

  test("reports wasm optimizer traps with captured log paths", async () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-"));
    const distDir = path.join(repoRoot, "tests", "node", "dist");
    fs.mkdirSync(distDir, { recursive: true });
    fs.writeFileSync(path.join(distDir, "starshine-self-optimized-wasi.wasm"), "optimizer");
    fs.writeFileSync(path.join(distDir, "starshine-debug-wasi.wasm"), "debug");

    await expect(runSelfOptArtifactOptimizerCompare([], {
      repoRoot,
      validateWasmArtifact() {},
      runNativeOptimizer(_command, args) {
        fs.writeFileSync(args[args.indexOf("--out") + 1], "expected");
      },
      async runWasmStart() {
        throw new WebAssembly.RuntimeError("wasm trap");
      },
      writeStdout() {},
    })).rejects.toThrow("self-optimized wasm optimizer trapped: RuntimeError: wasm trap");
  });

  test("reports a missing wasm optimizer output before byte comparison", async () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-compare-"));
    const distDir = path.join(repoRoot, "tests", "node", "dist");
    fs.mkdirSync(distDir, { recursive: true });
    fs.writeFileSync(path.join(distDir, "starshine-self-optimized-wasi.wasm"), "optimizer");
    fs.writeFileSync(path.join(distDir, "starshine-debug-wasi.wasm"), "debug");

    await expect(runSelfOptArtifactOptimizerCompare([], {
      repoRoot,
      validateWasmArtifact() {},
      runNativeOptimizer(_command, args) {
        fs.writeFileSync(args[args.indexOf("--out") + 1], "expected");
      },
      async runWasmStart() {
        return 0;
      },
      writeStdout() {},
    })).rejects.toThrow("self-optimized wasm optimizer did not produce output");
  });
});
