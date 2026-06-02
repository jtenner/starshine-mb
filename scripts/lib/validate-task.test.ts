import { describe, expect, test } from "bun:test";

import { runValidateSelfOptFull, runValidateSelfOptSmoke } from "./validate-task";

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
