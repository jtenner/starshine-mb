import { describe, expect, test } from "bun:test";

import {
  assertBinaryenPerformanceVersion,
  assertFreshPerformanceSweepOutDir,
  assertStarshineBinaryFreshness,
  assertStablePerformanceIdentity,
  buildPassPerformanceSweepPlan,
  median,
  parsePassPerformanceSweepArgs,
  summarizePassPerformanceSamples,
  type PassPerformanceSample,
} from "./pass-performance-sweep";

describe("pass performance sweep", () => {
  test("requires the repository's Binaryen v132 oracle", () => {
    expect(() =>
      assertBinaryenPerformanceVersion("wasm-opt version 132 (version_132)")
    ).not.toThrow();
    expect(() =>
      assertBinaryenPerformanceVersion("wasm-opt version 130 (version_130)")
    ).toThrow("expected Binaryen v132");
  });

  test("rejects an input or executable identity change during a campaign", () => {
    expect(() =>
      assertStablePerformanceIdentity("Starshine binary", "before", "before")
    ).not.toThrow();
    expect(() =>
      assertStablePerformanceIdentity("Starshine binary", "before", "after")
    ).toThrow("Starshine binary changed during the performance sweep");
  });

  test("rejects an existing output root before samples can reuse stale artifacts", () => {
    expect(() =>
      assertFreshPerformanceSweepOutDir(".tmp/already-present", true)
    ).toThrow("performance sweep output directory already exists");
    expect(() =>
      assertFreshPerformanceSweepOutDir(".tmp/new-campaign", false)
    ).not.toThrow();
  });

  test("rejects a native binary older than current compiler sources", () => {
    expect(() => assertStarshineBinaryFreshness(200, 100)).not.toThrow();
    expect(() => assertStarshineBinaryFreshness(100, 200)).toThrow(
      "Starshine binary is older than compiler source",
    );
  });

  test("requires explicit binaries and parses a bounded serial campaign", () => {
    const options = parsePassPerformanceSweepArgs([
      "--input",
      "fixture.wasm",
      "--passes",
      "inlining,duplicate-function-elimination",
      "--starshine-bin",
      "starshine",
      "--wasm-opt-bin",
      "wasm-opt-v132",
      "--out-dir",
      ".tmp/perf",
      "--warmup",
      "1",
      "--samples",
      "3",
      "--baseline-pass",
      "strip-debug",
    ]);

    expect(options.inputPath).toBe("fixture.wasm");
    expect(options.passes).toEqual([
      "inlining",
      "duplicate-function-elimination",
    ]);
    expect(options.warmup).toBe(1);
    expect(options.samples).toBe(3);
    expect(options.baselinePass).toBe("strip-debug");
  });

  test("rejects partially numeric warmup and sample counts", () => {
    const base = [
      "--input",
      "fixture.wasm",
      "--passes",
      "inlining",
      "--starshine-bin",
      "starshine",
      "--wasm-opt-bin",
      "wasm-opt-v132",
    ];
    expect(() =>
      parsePassPerformanceSweepArgs([...base, "--samples", "3x"])
    ).toThrow("--samples must be a positive integer");
    expect(() =>
      parsePassPerformanceSweepArgs([...base, "--warmup", "1.5"])
    ).toThrow("--warmup must be a non-negative integer");
  });

  test("requires a warmup and at least three measured rounds", () => {
    const base = [
      "--input",
      "fixture.wasm",
      "--passes",
      "inlining",
      "--starshine-bin",
      "starshine",
      "--wasm-opt-bin",
      "wasm-opt-v132",
    ];
    expect(() =>
      parsePassPerformanceSweepArgs([...base, "--samples", "2"])
    ).toThrow("--samples must be at least 3");
    expect(() =>
      parsePassPerformanceSweepArgs([...base, "--warmup", "0"])
    ).toThrow("--warmup must be at least 1");
  });

  test("alternates pass order between rounds and keeps the floor in every round", () => {
    const options = parsePassPerformanceSweepArgs([
      "--input",
      "fixture.wasm",
      "--passes",
      "a,b,c",
      "--starshine-bin",
      "starshine",
      "--wasm-opt-bin",
      "wasm-opt-v132",
    ]);
    const plan = buildPassPerformanceSweepPlan(options);

    expect(plan.map((entry) => [entry.round, entry.warmup, entry.pass])).toEqual([
      [0, true, "strip-debug"],
      [0, true, "a"],
      [0, true, "b"],
      [0, true, "c"],
      [0, true, "strip-debug"],
      [1, false, "strip-debug"],
      [1, false, "c"],
      [1, false, "b"],
      [1, false, "a"],
      [1, false, "strip-debug"],
      [2, false, "strip-debug"],
      [2, false, "a"],
      [2, false, "b"],
      [2, false, "c"],
      [2, false, "strip-debug"],
      [3, false, "strip-debug"],
      [3, false, "c"],
      [3, false, "b"],
      [3, false, "a"],
      [3, false, "strip-debug"],
    ]);
    expect(plan[0].outDir).toEndWith("strip-debug-leading");
    expect(plan[4].outDir).toEndWith("strip-debug-trailing");
    expect(plan[0].args).toContain("--wall-attribution");
    expect(plan[0].args).toContain("--timing-only");
    expect(plan[0].args).toContain("--starshine-bin");
    expect(plan[0].args).toContain("--wasm-opt-bin");
  });

  test("reports raw medians, baseline-subtracted costs, ratios, and identity", () => {
    const sample = (
      pass: string,
      round: number,
      starshine: number,
      binaryen: number,
      starshinePass: number,
      binaryenPass: number,
    ): PassPerformanceSample => ({
      pass,
      round,
      resultPath: `${pass}-${round}/result.json`,
      starshineNoTraceElapsedMs: starshine,
      binaryenElapsedMs: binaryen,
      starshinePassElapsedMs: starshinePass,
      binaryenPassElapsedMs: binaryenPass,
      starshineRawSize: 100,
      binaryenRawSize: 100,
      starshineSize: 110,
      binaryenSize: 110,
      wasmEqual: true,
      tracedNoTraceOutputEqual: true,
      starshineRawSha256: "same-raw",
      starshineNoTraceSha256: "same-raw",
      binaryenRawSha256: "same-binaryen-raw",
    });
    const samples = [
      sample("strip-debug", 1, 100, 50, 1, 1),
      sample("strip-debug", 1, 102, 52, 1, 1),
      sample("a", 1, 220, 80, 90, 20),
      sample("strip-debug", 2, 110, 60, 1, 1),
      sample("strip-debug", 2, 112, 62, 1, 1),
      sample("a", 2, 200, 90, 80, 30),
      sample("strip-debug", 3, 105, 55, 1, 1),
      sample("strip-debug", 3, 107, 57, 1, 1),
      sample("a", 3, 210, 85, 85, 25),
    ];

    const summary = summarizePassPerformanceSamples(
      samples,
      ["a"],
      "strip-debug",
    );

    expect(median([3, 1, 2])).toBe(2);
    expect(summary.baseline.starshineCommandMedianMs).toBe(106);
    expect(summary.baseline.binaryenCommandMedianMs).toBe(56);
    expect(summary.passes[0].starshineCommandMedianMs).toBe(210);
    expect(summary.passes[0].starshineCommandMadMs).toBe(10);
    expect(summary.passes[0].binaryenCommandMedianMs).toBe(85);
    expect(summary.passes[0].starshineIncrementMedianMs).toBe(104);
    expect(summary.passes[0].starshineIncrementMadMs).toBe(15);
    expect(summary.passes[0].binaryenIncrementMedianMs).toBe(29);
    expect(summary.passes[0].binaryenIncrementMadMs).toBe(0);
    expect(summary.passes[0].incrementRatio).toBeCloseTo(104 / 29);
    expect(summary.passes[0].passLocalRatio).toBe(3.4);
    expect(summary.passes[0].starshinePassMadMs).toBe(5);
    expect(summary.passes[0].stableStarshineRawOutput).toBe(true);
    expect(summary.passes[0].stableBinaryenRawOutput).toBe(true);
    expect(summary.passes[0].allTracedNoTraceOutputsEqual).toBe(true);
  });

  test("rejects samples whose traced and no-trace outputs differ", () => {
    const bad: PassPerformanceSample = {
      pass: "a",
      round: 1,
      resultPath: "a/result.json",
      starshineNoTraceElapsedMs: 2,
      binaryenElapsedMs: 1,
      starshinePassElapsedMs: 1,
      binaryenPassElapsedMs: 1,
      starshineRawSize: 1,
      binaryenRawSize: 1,
      starshineSize: 1,
      binaryenSize: 1,
      wasmEqual: true,
      tracedNoTraceOutputEqual: false,
      starshineRawSha256: "raw",
      starshineNoTraceSha256: "different",
      binaryenRawSha256: "binaryen-raw",
    };

    expect(() =>
      summarizePassPerformanceSamples([bad], ["a"], "strip-debug")
    ).toThrow("traced/no-trace output mismatch");
  });

  test("rejects unstable Starshine or Binaryen output in every sample group", () => {
    const sample = (
      pass: string,
      round: number,
      starshineHash: string,
      binaryenHash: string,
    ): PassPerformanceSample => ({
      pass,
      round,
      resultPath: `${pass}-${round}/result.json`,
      starshineNoTraceElapsedMs: 10,
      binaryenElapsedMs: 10,
      starshinePassElapsedMs: 1,
      binaryenPassElapsedMs: 1,
      starshineRawSize: 1,
      binaryenRawSize: 1,
      starshineSize: 1,
      binaryenSize: 1,
      wasmEqual: true,
      tracedNoTraceOutputEqual: true,
      starshineRawSha256: starshineHash,
      starshineNoTraceSha256: starshineHash,
      binaryenRawSha256: binaryenHash,
    });
    const stableBaselines = [
      sample("strip-debug", 1, "s-floor", "b-floor"),
      sample("strip-debug", 1, "s-floor", "b-floor"),
      sample("strip-debug", 2, "s-floor", "b-floor"),
      sample("strip-debug", 2, "s-floor", "b-floor"),
      sample("strip-debug", 3, "s-floor", "b-floor"),
      sample("strip-debug", 3, "s-floor", "b-floor"),
    ];
    expect(() =>
      summarizePassPerformanceSamples([
        ...stableBaselines,
        sample("a", 1, "s-a", "b-a"),
        sample("a", 2, "s-a-drift", "b-a"),
        sample("a", 3, "s-a", "b-a"),
      ], ["a"], "strip-debug")
    ).toThrow("unstable Starshine raw output for a");
    expect(() =>
      summarizePassPerformanceSamples([
        stableBaselines[0],
        stableBaselines[1],
        { ...stableBaselines[2], binaryenRawSha256: "b-floor-drift" },
        ...stableBaselines.slice(3),
        sample("a", 1, "s-a", "b-a"),
        sample("a", 2, "s-a", "b-a"),
        sample("a", 3, "s-a", "b-a"),
      ], ["a"], "strip-debug")
    ).toThrow("unstable Binaryen raw output for strip-debug");
  });

  test("reports a negative noise-dominated increment ratio as unavailable", () => {
    const sample = (
      pass: string,
      round: number,
      starshine: number,
      binaryen: number,
    ): PassPerformanceSample => ({
      pass,
      round,
      resultPath: `${pass}-${round}/result.json`,
      starshineNoTraceElapsedMs: starshine,
      binaryenElapsedMs: binaryen,
      starshinePassElapsedMs: 1,
      binaryenPassElapsedMs: 1,
      starshineRawSize: 1,
      binaryenRawSize: 1,
      starshineSize: 1,
      binaryenSize: 1,
      wasmEqual: true,
      tracedNoTraceOutputEqual: true,
      starshineRawSha256: `s-${pass}`,
      starshineNoTraceSha256: `s-${pass}`,
      binaryenRawSha256: `b-${pass}`,
    });
    const samples: PassPerformanceSample[] = [];
    for (const round of [1, 2, 3]) {
      samples.push(sample("strip-debug", round, 100, 50));
      samples.push(sample("strip-debug", round, 100, 50));
      samples.push(sample("a", round, 90, 60));
    }
    const summary = summarizePassPerformanceSamples(
      samples,
      ["a"],
      "strip-debug",
    );
    expect(summary.passes[0].starshineIncrementMedianMs).toBe(-10);
    expect(summary.passes[0].incrementRatio).toBeNull();
  });
});
