import { describe, expect, test } from "bun:test";

import { parseFuzzRunArgs, runFuzz } from "./fuzz-task";

describe("fuzz task recipes", () => {
  test("parses recipe flags without collapsing to wrapper defaults", () => {
    const parsed = parseFuzzRunArgs(["--recipe", "default-ci", "--moon", "moon-test"]);

    expect(parsed.recipeName).toBe("default-ci");
    expect(parsed.suiteExplicit).toBe(false);
    expect(parsed.profileExplicit).toBe(false);
  });

  test("passes checked-in recipes through to the Moon fuzz runner", () => {
    const parsed = parseFuzzRunArgs([
      "--recipe=default-smoke",
      "--seed-count=2",
      "--moon=moon-test",
    ]);
    const calls: Array<{ bin: string; args: string[] }> = [];

    runFuzz(parsed, ".", (bin, args) => {
      calls.push({ bin, args });
    });

    expect(calls).toHaveLength(1);
    expect(calls[0].bin).toBe("moon-test");
    expect(calls[0].args).toEqual([
      "run",
      "--target",
      "wasm-gc",
      "src/fuzz",
      "--",
      "--recipe",
      "default-smoke",
      "--seed-count",
      "2",
    ]);
  });
});
