import { describe, expect, test } from "bun:test";

import {
  moonTestJobsForParallelism,
  runValidateSelfOptFull,
  runValidateSelfOptSmoke,
} from "./validate-task";

describe("validate test parallelism", () => {
  test("uses available CPUs without exceeding the safe full-suite cap", () => {
    expect(moonTestJobsForParallelism(0)).toBe(1);
    expect(moonTestJobsForParallelism(4)).toBe(4);
    expect(moonTestJobsForParallelism(64)).toBe(16);
  });
});

describe("validate self-opt lanes", () => {
  test("smoke lane keeps the fast default self-optimized artifact check", async () => {
    const calls: string[][] = [];

    await runValidateSelfOptSmoke(["--wasm", "candidate.wasm"], {
      runSelfOptCheck(argv) {
        calls.push(argv);
        return Promise.resolve();
      },
    });

    expect(calls).toEqual([["--wasm", "candidate.wasm"]]);
  });

  test("full lane opts into the complete spec workload", async () => {
    const calls: string[][] = [];

    await runValidateSelfOptFull(["--wasm", "candidate.wasm"], {
      runSelfOptCheck(argv) {
        calls.push(argv);
        return Promise.resolve();
      },
    });

    expect(calls).toEqual([["--full-spec", "--wasm", "candidate.wasm"]]);
  });
});
