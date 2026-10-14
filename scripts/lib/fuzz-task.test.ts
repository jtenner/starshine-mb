import { describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  parseFuzzRunArgs,
  parseOptimizerPromotionArgs,
  parseOptimizerReductionArgs,
  parseOptimizerReplayArgs,
  parseOptimizerProofArgs,
  parseOptimizerExploreArgs,
  optimizerThresholdReport,
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

describe("optimizer threshold and rewrite proof tooling", () => {
  test("reports Moon-owned command thresholds as versioned campaign descriptors", () => {
    const calls: Array<{ bin: string; args: string[] }> = [];
    const report = optimizerThresholdReport("0x5eed", {
      starshineBin: "starshine-test",
      run: (bin, args) => {
        calls.push({ bin, args });
        return {
          status: 0,
          stdout: JSON.stringify({
            schema: "starshine.optimizer-threshold-registry.v1",
            source: "moonbit-resolved-options",
            thresholds: [
              { schema: "starshine.optimizer-threshold.v1", name: "always-inline-max-function-size", value: 2, source: "moon" },
              { schema: "starshine.optimizer-threshold.v1", name: "one-caller-inline-max-function-size", value: -1, source: "moon" },
              { schema: "starshine.optimizer-threshold.v1", name: "flexible-inline-max-function-size", value: 20, source: "moon" },
              { schema: "starshine.optimizer-threshold.v1", name: "inline-max-combined-binary-size", value: 409600, source: "moon" },
              { schema: "starshine.optimizer-threshold.v1", name: "partial-inlining-ifs", value: 0, source: "moon" },
            ],
          }),
          stderr: "",
        };
      },
    });
    expect(calls).toEqual([{ bin: "starshine-test", args: ["--emit-optimizer-thresholds-json"] }]);
    expect(report.schema).toBe("starshine.optimizer-threshold-registry.v1");
    expect(report.thresholds.map((entry) => [entry.id, entry.value])).toEqual([
      ["inlining.always-inline-max-size", 2],
      ["inlining.one-caller-inline-max-size", -1],
      ["inlining.flexible-inline-max-size", 20],
      ["inlining.max-combined-binary-size", 409600],
      ["inlining.partial-inlining-ifs", 0],
    ]);
    expect(report.groups.every((group) => group.schema === "starshine.optimizer-threshold-cliff-group.v1")).toBe(true);
  });

  test("parses strict prove-rewrites options", () => {
    expect(parseOptimizerProofArgs(["contracts.json", "--solver", "z3-custom", "--out-dir", ".tmp/proofs"])).toEqual({
      contractPath: "contracts.json",
      solverBin: "z3-custom",
      outDir: ".tmp/proofs",
    });
    expect(() => parseOptimizerProofArgs(["contracts.json", "--unknown"])).toThrow("unknown prove-rewrites option");
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

  test("parses typed whole-Wasm optimizer neighborhood options", () => {
    expect(parseOptimizerExploreArgs([
      ".tmp/failure",
      "--out-dir", ".tmp/neighbors",
      "--seed", "0x1234",
      "--budget", "12",
      "--wasm-tools-bin", "wasm-tools-custom",
    ])).toEqual({
      source: ".tmp/failure",
      outDir: ".tmp/neighbors",
      seed: 0x1234n,
      budget: 12,
      starshineBin: undefined,
      moonBin: "moon",
      wasmToolsBin: "wasm-tools-custom",
    });
    expect(() => parseOptimizerExploreArgs([".tmp/failure"])).toThrow("requires --out-dir");
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

  test("parses a bounded per-candidate structural reduction timeout", () => {
    const args = [".tmp/failure", "--out", ".tmp/reduced.wasm"];
    expect(parseOptimizerReductionArgs([...args, "--predicate-timeout-seconds", "10"]).predicateTimeoutSeconds).toBe(10);
    expect(parseOptimizerReductionArgs(args).predicateTimeoutSeconds).toBeUndefined();
    for (const value of ["0", "3601", "1.5", "NaN"]) {
      expect(() => parseOptimizerReductionArgs([...args, "--predicate-timeout-seconds", value])).toThrow();
    }
  });

  test("forwards the CLI predicate timeout to wasm-reduce", () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-reduce-cli-"));
    try {
      const input = path.join(dir, "input.wasm");
      const manifest = path.join(dir, "manifest.json");
      const output = path.join(dir, "reduced.wasm");
      const reducer = path.join(dir, "fake-reducer.ts");
      const argsPath = path.join(dir, "args.json");
      fs.writeFileSync(input, Uint8Array.from([0, 97, 115, 109, 1, 0, 0, 0]));
      fs.writeFileSync(manifest, JSON.stringify({ input: { path: "input.wasm" } }));
      fs.writeFileSync(reducer, `#!/usr/bin/env bun\nimport fs from "node:fs";\nconst args = process.argv.slice(2);\nif (args.includes("--help")) process.exit(0);\nfs.writeFileSync(${JSON.stringify(argsPath)}, JSON.stringify(args));\nfs.copyFileSync(args[args.indexOf("--test") + 1], args[args.indexOf("--working") + 1]);\n`);
      fs.chmodSync(reducer, 0o755);
      const result = spawnSync(process.execPath, [
        "scripts/fuzz.ts", "reduce-optimizer", manifest, "--out", output,
        "--wasm-reduce-bin", reducer, "--predicate-timeout-seconds", "10",
      ], { cwd: process.cwd(), encoding: "utf8", timeout: 10_000 });
      expect(result.status).toBe(1); // The fake reducer returns unchanged bytes.
      const reducerArgs = JSON.parse(fs.readFileSync(argsPath, "utf8")) as string[];
      expect(reducerArgs.slice(reducerArgs.indexOf("--timeout"), reducerArgs.indexOf("--timeout") + 2)).toEqual(["--timeout", "10"]);
      expect(fs.existsSync(output)).toBe(false);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
});
