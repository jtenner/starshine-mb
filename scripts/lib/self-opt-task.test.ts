import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import { describe, expect, test } from "bun:test";

import { normalizeWasiArgs } from "./moonbit-wasi-runner.mjs";
import {
  optimizeDebugWasm,
  runCommandWithProgressTimeout,
} from "./self-optimized-artifacts.mjs";
import {
  parseSelfOptArtifactOptimizerCompareArgs,
  parseSelfOptBuildArgs,
  parseSelfOptCheckArgs,
  parseSelfOptOptimizeArgs,
  runSelfOptArtifactOptimizerCompare,
  runSelfOptCheck,
} from "./self-opt-task";
import {
  extractPipelinePrintEntryPretties,
  parseSelfOptimizeCompareArgs,
  parseStarshinePerfTimingSummary,
} from "./self-optimize-compare-task";

describe("self-optimize compare timing parsing", () => {
  test("parses opt-in paired traced and no-trace wall attribution", () => {
    expect(parseSelfOptimizeCompareArgs([
      "fixture.wasm",
      "--wall-attribution",
      "--dead-code-elimination",
    ])).toMatchObject({ wallAttribution: true });
    expect(parseSelfOptimizeCompareArgs([
      "fixture.wasm",
      "--dead-code-elimination",
    ])).toMatchObject({ wallAttribution: false });
  });

  test("splits batched pipeline print logs into per-entry pretty text", () => {
    const entries = extractPipelinePrintEntryPretties([
      "Log: module.wasm",
      "0: Func[27]",
      "  func code[0] abs[27]",
      "    body_raw:",
      "      (i32.const I32(1))",
      "1: Func[28]",
      "  func code[1] abs[28]",
      "    body_raw:",
      "      (i32.const I32(2))",
      "",
    ].join("\n"));

    expect(entries).toEqual([
      "0: Func[27]\n  func code[0] abs[27]\n    body_raw:\n      (i32.const I32(1))",
      "1: Func[28]\n  func code[1] abs[28]\n    body_raw:\n      (i32.const I32(2))",
    ]);
  });

  test("separates raw pass timers from pass-local timers", () => {
    const summary = parseStarshinePerfTimingSummary([
      "perf:timer name=pipeline elapsed_us=61005400 total_us=61005400",
      "perf:timer name=raw:ssa-nomerge:func:5539 elapsed_us=61000000 total_us=61000000",
      "perf:timer name=pass:ssa-nomerge elapsed_us=367 total_us=367",
      "perf:timer name=guard:vacuum-writeback:func:27 elapsed_us=400 total_us=400",
      "perf:timer name=validate:final-module elapsed_us=5000 total_us=5000",
      "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
    ].join("\n"));

    expect(summary.passElapsedMs).toBe(0.367);
    expect(summary.rawElapsedMs).toBe(61000);
    expect(summary.otherTimedElapsedMs).toBeCloseTo(5.4);
    expect(summary.passSkippedRaw).toBe(true);
  });

  test("attributes command wall time without double-counting nested optimizer timers", () => {
    const summary = parseStarshinePerfTimingSummary([
      "perf:timer name=cmd:input-total elapsed_us=100000 total_us=100000",
      "perf:timer name=cmd:read-input elapsed_us=1000 total_us=1000",
      "perf:timer name=cmd:text-lowering elapsed_us=500 total_us=500",
      "perf:timer name=cmd:decode elapsed_us=10000 total_us=10000",
      "perf:timer name=cmd:pipeline-setup elapsed_us=100 total_us=100",
      "perf:timer name=cmd:main-pipeline elapsed_us=50000 total_us=50000",
      "perf:timer name=cmd:validate:final-module elapsed_us=5000 total_us=5000",
      "perf:timer name=cmd:reuse-input-check elapsed_us=200 total_us=200",
      "perf:timer name=cmd:encode elapsed_us=10000 total_us=10000",
      "perf:timer name=cmd:size-portfolio elapsed_us=15000 total_us=15000",
      "perf:timer name=cmd:candidate-selection elapsed_us=3000 total_us=3000",
      "perf:timer name=cmd:write-output elapsed_us=500 total_us=500",
      "perf:timer name=pipeline elapsed_us=48000 total_us=48000",
      "perf:timer name=stage:hot-pass:code-section elapsed_us=47000 total_us=47000",
      "perf:timer name=stage:hot-pass:function-total elapsed_us=45000 total_us=45000",
      "perf:timer name=stage:hot-pass:pre-pass elapsed_us=0 total_us=1200",
      "perf:timer name=stage:hot-pass:post-pass elapsed_us=0 total_us=300",
      "perf:timer name=stage:hot-pass:module-rebuild elapsed_us=500 total_us=500",
      "perf:timer name=guard:vacuum-writeback-batch elapsed_us=500 total_us=500",
      "perf:timer name=raw:vacuum-preclean elapsed_us=5000 total_us=5000",
      "perf:timer name=lift elapsed_us=10000 total_us=10000",
      "perf:timer name=pass:vacuum elapsed_us=20000 total_us=20000",
      "perf:timer name=lower elapsed_us=8000 total_us=8000",
      "perf:timer name=validate:final-module elapsed_us=5000 total_us=5000",
    ].join("\n"));

    expect(summary.commandInputElapsedMs).toBe(100);
    expect(summary.commandKnownElapsedMs).toBeCloseTo(95.3);
    expect(summary.commandUnattributedElapsedMs).toBeCloseTo(4.7);
    expect(summary.commandPhasesMs).toMatchObject({
      readInput: 1,
      textLowering: 0.5,
      decode: 10,
      pipelineSetup: 0.1,
      mainPipeline: 50,
      finalValidate: 5,
      reuseInputCheck: 0.2,
      encode: 10,
      sizePortfolio: 15,
      candidateSelection: 3,
      postEncodeValidate: 0,
      writeOutput: 0.5,
    });
    expect(summary.optimizerPipelineElapsedMs).toBe(48);
    expect(summary.optimizerPassElapsedMs).toBe(20);
    expect(summary.optimizerRawElapsedMs).toBe(5);
    expect(summary.optimizerLiftElapsedMs).toBe(10);
    expect(summary.optimizerLowerElapsedMs).toBe(8);
    expect(summary.optimizerHotCodeSectionElapsedMs).toBe(47);
    expect(summary.optimizerHotFunctionElapsedMs).toBe(45);
    expect(summary.optimizerHotFunctionOverheadMs).toBe(2);
    expect(summary.optimizerHotPrePassElapsedMs).toBe(1.2);
    expect(summary.optimizerHotPostPassElapsedMs).toBe(0.3);
    expect(summary.optimizerHotFunctionUnattributedElapsedMs).toBe(0.5);
    expect(summary.optimizerHotOuterLoopOverheadMs).toBe(2);
    expect(summary.optimizerHotModuleRebuildElapsedMs).toBe(0.5);
    expect(summary.optimizerWritebackElapsedMs).toBe(0.5);
    expect(summary.optimizerHotCodeSectionOverheadMs).toBe(4);
    expect(summary.optimizerPipelineUnattributedElapsedMs).toBe(0);
    expect(summary.optimizerNonPassElapsedMs).toBe(28);
    expect(summary.totalTimedElapsedMs).toBe(100);
  });
});

describe("self-opt subprocess deadlines", () => {
  test("parses explicit total and no-progress deadlines for build and optimize", () => {
    expect(parseSelfOptBuildArgs([
      "--optimize-timeout-seconds",
      "900",
      "--optimize-stall-timeout-seconds",
      "120",
    ])).toMatchObject({
      debugSerialPasses: false,
      optimizeTimeoutSeconds: 900,
      optimizeStallTimeoutSeconds: 120,
    });
    expect(parseSelfOptBuildArgs(["--debug-serial-passes"])).toMatchObject({
      debugSerialPasses: true,
    });
    expect(parseSelfOptOptimizeArgs([
      "--optimize-timeout-seconds",
      "600",
      "--optimize-stall-timeout-seconds",
      "90",
    ])).toMatchObject({
      optimizeTimeoutSeconds: 600,
      optimizeStallTimeoutSeconds: 90,
    });
  });

  test("rejects missing, zero, negative, and nonnumeric deadline values", () => {
    for (const argv of [
      ["--optimize-timeout-seconds"],
      ["--optimize-timeout-seconds", "0"],
      ["--optimize-stall-timeout-seconds", "-1"],
      ["--optimize-stall-timeout-seconds", "later"],
    ]) {
      expect(() => parseSelfOptBuildArgs(argv)).toThrow();
    }
  });

  test("terminates a subprocess promptly after it stops producing progress", async () => {
    const startedAt = Date.now();
    await expect(runCommandWithProgressTimeout(
      process.execPath,
      ["-e", "process.stdout.write('started\\n'); setInterval(() => {}, 1000)"],
      {
        cwd: process.cwd(),
        totalTimeoutMs: 2000,
        stallTimeoutMs: 80,
        killGraceMs: 10,
        writeStdout() {},
        writeStderr() {},
      },
    )).rejects.toThrow("no progress for 80ms");
    expect(Date.now() - startedAt).toBeLessThan(1000);
  });

  test("allows a subprocess that completes within both deadlines", async () => {
    await expect(runCommandWithProgressTimeout(
      process.execPath,
      ["-e", "process.stdout.write('done\\n')"],
      {
        cwd: process.cwd(),
        totalTimeoutMs: 1000,
        stallTimeoutMs: 500,
        writeStdout() {},
        writeStderr() {},
      },
    )).resolves.toMatchObject({ exitCode: 0, timedOut: false });
  });

  test("self-optimizes the release artifact without forced pass tracing", async () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-timeout-"));
    const distDir = path.join(repoRoot, "tests", "node", "dist");
    const nativeBin = path.join(repoRoot, "starshine");
    fs.mkdirSync(distDir, { recursive: true });
    fs.writeFileSync(path.join(distDir, "starshine-optimized-wasi.wasm"), "release");
    fs.writeFileSync(nativeBin, "native");
    const calls: Array<{
      args: string[];
      env: NodeJS.ProcessEnv;
      totalTimeoutMs: number;
      stallTimeoutMs: number;
    }> = [];

    await optimizeDebugWasm({
      repoRoot,
      starshinePath: nativeBin,
      totalTimeoutMs: 1234,
      stallTimeoutMs: 234,
      validateArtifact() {},
      async runOptimizer(_command: string, args: string[], options: {
        env: NodeJS.ProcessEnv;
        totalTimeoutMs: number;
        stallTimeoutMs: number;
      }) {
        calls.push({ args, ...options });
        fs.copyFileSync(
          path.join(distDir, "starshine-optimized-wasi.wasm"),
          args[args.indexOf("--out") + 1],
        );
        return { exitCode: 0, timedOut: false };
      },
    });

    expect(calls).toHaveLength(1);
    expect(calls[0].args).not.toContain("--debug-serial-passes");
    expect(calls[0].args.at(-1)).toBe(path.join(distDir, "starshine-optimized-wasi.wasm"));
    expect(calls[0].env.STARSHINE_TRACING).toBe(
      process.env.STARSHINE_TRACING ?? "phase",
    );
    expect(calls[0].totalTimeoutMs).toBe(1234);
    expect(calls[0].stallTimeoutMs).toBe(234);
  });
});

describe("self-opt artifact check lane", () => {
  test("normalizes CLI arguments with a WASI argv[0] entry", () => {
    expect(normalizeWasiArgs("/tmp/starshine.wasm", ["--help"])).toEqual([
      "/tmp/starshine.wasm",
      "--help",
    ]);
  });

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
    const inputWasm = path.join(repoRoot, "tests", "repros", "merge-blocks-v131-main.wasm");
    fs.mkdirSync(path.dirname(inputWasm), { recursive: true });
    fs.writeFileSync(optimizerWasm, "optimizer");
    fs.writeFileSync(inputWasm, "fixture");

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
    expect(calls).toContain(`validate:${path.basename(inputWasm)}:comparison wasm input artifact`);
    expect(calls.some((call) => call.startsWith("native:--optimize -O4z --out"))).toBe(true);
    expect(calls.some((call) => call.startsWith("wasm:--optimize -O4z --out"))).toBe(true);
    expect(calls.some((call) => call.includes("--debug-serial-passes"))).toBe(false);
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
