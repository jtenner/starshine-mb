import { afterEach, describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  moonTestJobsForParallelism,
  parseValidateTestArgs,
  runValidateCoverage,
  runValidateFull,
  runValidateTest,
  runValidateSelfOptFull,
  runValidateSelfOptSmoke,
} from "./validate-task";

const roots: string[] = [];
afterEach(() => {
  for (const root of roots.splice(0)) fs.rmSync(root, { recursive: true, force: true });
});

function testWorkspace(): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-validate-launch-"));
  roots.push(root);
  fs.mkdirSync(path.join(root, "src/example"), { recursive: true });
  for (const file of ["inline.mbt", "panic_wbtest.mbt", "guide.mbt.md"]) {
    fs.writeFileSync(path.join(root, "src/example", file), "");
  }
  return root;
}

describe("native Moon validation launch", () => {
  test("parses the test-only lane without adding fuzz or filtering options", () => {
    expect(parseValidateTestArgs(["--target", "native", "--moon", "custom-moon"])).toEqual({ target: "native", moonBin: "custom-moon" });
    expect(parseValidateTestArgs([]).target).toBe("wasm-gc");
    expect(() => parseValidateTestArgs(["--filter", "pass"])).toThrow("unknown option");
    expect(() => parseValidateTestArgs(["--target", "invalid"])).toThrow("invalid target");
  });

  test("launches every file once through Moon and caps its workers at sixteen", () => {
    const repoRoot = testWorkspace();
    const calls: Array<{ command: string; args: string[]; cwd: string | undefined }> = [];
    runValidateTest({ target: "wasm-gc", moonBin: "custom-moon" }, {
      repoRoot,
      parallelism: 64,
      run(command, args, options) {
        calls.push({ command, args, cwd: options?.cwd });
        return { stdout: "", stderr: "" };
      },
    });
    expect(calls).toEqual([{
      command: "custom-moon",
      args: ["test", "--target", "wasm-gc", "--jobs", "16", "src/example/guide.mbt.md", "src/example/inline.mbt", "src/example/panic_wbtest.mbt"],
      cwd: repoRoot,
    }]);
  });

  test("full validation reuses the same launch and stops before fuzz on a Moon failure", () => {
    const repoRoot = testWorkspace();
    const calls: string[][] = [];
    const failure = new Error("Moon test failed");
    let fuzzCalls = 0;
    expect(() => runValidateFull({ target: "native", moonBin: "custom-moon", profile: "ci", seed: null }, {
      repoRoot,
      parallelism: 2,
      run(_command, args) {
        calls.push(args);
        if (args[0] === "test") throw failure;
        return { stdout: "", stderr: "" };
      },
      runFuzz() { fuzzCalls++; },
    })).toThrow(failure);
    expect(calls).toEqual([
      ["info"], ["fmt"], ["check", "--target", "native"],
      ["test", "--target", "native", "--jobs", "2", "src/example/guide.mbt.md", "src/example/inline.mbt", "src/example/panic_wbtest.mbt"],
    ]);
    expect(fuzzCalls).toBe(0);
  });

  test("coverage uses one analyze call with the complete test selection and propagates failure", () => {
    const repoRoot = testWorkspace();
    const calls: string[][] = [];
    const failure = new Error("coverage test failed");
    expect(() => runValidateCoverage({ top: 10, baselineFile: null, updateBaseline: false, moonBin: "custom-moon" }, {
      repoRoot,
      run(_command, args, options) {
        calls.push(args);
        expect(options?.cwd).toBe(repoRoot);
        expect(options?.stdio).toBe("pipe");
        throw failure;
      },
    })).toThrow(failure);
    expect(calls).toEqual([["coverage", "analyze", "--test-flag=src/example/guide.mbt.md", "--test-flag=src/example/inline.mbt", "--test-flag=src/example/panic_wbtest.mbt"]]);
  });
});

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
