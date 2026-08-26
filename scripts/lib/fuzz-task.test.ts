import { describe, expect, test } from "bun:test";

import {
  parseFuzzRunArgs,
  parseOptimizerPromotionArgs,
  parseOptimizerReductionArgs,
  parseOptimizerReplayArgs,
  runFuzz,
} from "./fuzz-task";

describe("fuzz task recipes", () => {
  test("parses recipe flags without collapsing to wrapper defaults", () => {
    const parsed = parseFuzzRunArgs(["--recipe", "default-ci", "--moon", "moon-test"]);

    expect(parsed.recipeName).toBe("default-ci");
    expect(parsed.suiteExplicit).toBe(false);
    expect(parsed.profileExplicit).toBe(false);
  });

  test("profile-only recipe overrides stay named and preserve the recipe suite", () => {
    const parsed = parseFuzzRunArgs([
      "--recipe=optimizer-stress",
      "--profile=smoke+passes=random-mixed+determinism",
      "--moon=moon-test",
    ]);
    const calls: Array<{ bin: string; args: string[] }> = [];
    const logs: string[] = [];

    runFuzz(parsed, ".", (bin, args) => {
      calls.push({ bin, args });
    }, {
      seedFactory: () => "0x1234",
      log: (message) => logs.push(message),
    });

    expect(calls[0].args).toEqual([
      "run",
      "--target",
      "wasm-gc",
      "src/fuzz",
      "--",
      "--recipe",
      "optimizer-stress",
      "--profile",
      "smoke+passes=random-mixed+determinism",
      "--seed",
      "0x1234",
    ]);
    expect(logs).toEqual(["fuzz resolved_seed=0x1234"]);
  });

  test("passes checked-in recipes through to the Moon fuzz runner", () => {
    const parsed = parseFuzzRunArgs([
      "--recipe=default-smoke",
      "--seed-count=2",
      "--moon=moon-test",
    ]);
    const calls: Array<{ bin: string; args: string[] }> = [];
    const logs: string[] = [];

    runFuzz(parsed, ".", (bin, args) => {
      calls.push({ bin, args });
    }, {
      seedFactory: () => "0x5678",
      log: (message) => logs.push(message),
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
      "--seed",
      "0x5678",
      "--seed-count",
      "2",
    ]);
    expect(logs).toEqual(["fuzz resolved_seed=0x5678"]);
  });
});

describe("optimizer replay and promotion task arguments", () => {
  test("parses replay source and Starshine binary", () => {
    expect(
      parseOptimizerReplayArgs([".tmp/failure", "--starshine-bin", "_build/native/release/build/cmd/cmd.exe"]),
    ).toEqual({
      source: ".tmp/failure",
      starshineBin: "_build/native/release/build/cmd/cmd.exe",
      moonBin: "moon",
      wasmToolsBin: "wasm-tools",
    });
  });

  test("parses promotion corpus root and replay tools", () => {
    expect(
      parseOptimizerPromotionArgs([
        ".tmp/failure",
        "--corpus-root",
        "tests/optimizer/regressions",
        "--starshine-bin",
        "starshine",
      ]),
    ).toEqual({
      failureDir: ".tmp/failure",
      corpusRoot: "tests/optimizer/regressions",
      starshineBin: "starshine",
      moonBin: "moon",
      wasmToolsBin: "wasm-tools",
    });
  });

  test("parses optional structural reducer options", () => {
    expect(
      parseOptimizerReductionArgs([
        ".tmp/failure",
        "--out",
        ".tmp/reduced.wasm",
        "--wasm-reduce-bin",
        "wasm-reduce-custom",
      ]),
    ).toEqual({
      source: ".tmp/failure",
      outputPath: ".tmp/reduced.wasm",
      wasmReduceBin: "wasm-reduce-custom",
      starshineBin: undefined,
      moonBin: "moon",
      wasmToolsBin: "wasm-tools",
    });
  });
});
