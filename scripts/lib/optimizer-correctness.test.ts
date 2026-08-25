import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import {
  buildBoundaryArgumentValues,
  buildDeterministicInvocationPlan,
  classifyOptimizerDeterminism,
  compareRuntimeObservations,
  generateRandomPassSequence,
  reducePassSequencePreservingFailureClass,
  reducePassSequencePreservingFailureClassAsync,
  runNodeSelfSemanticOracle,
  runOptionalWasmReduce,
  type OptimizerPassRegistryEntry,
  type RuntimeObservation,
} from "./optimizer-correctness";

function wasmFromWat(wat: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-optimizer-correctness-"));
  const watPath = path.join(dir, "case.wat");
  const wasmPath = path.join(dir, "case.wasm");
  fs.writeFileSync(watPath, wat);
  const result = spawnSync("wasm-tools", ["parse", watPath, "-o", wasmPath], { encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || "wasm-tools parse failed");
  }
  return wasmPath;
}

function resultObservation(value: RuntimeObservation["calls"][number]["outcome"]): RuntimeObservation {
  return {
    schema: "starshine.runtime-observation.v1",
    instantiation: { kind: "instantiated" },
    calls: [{ stepIndex: 0, exportName: "run", args: [], outcome: value }],
    globals: [],
    memories: [],
    tables: [],
    importTrace: [],
  };
}

describe("optimizer semantic comparison policy", () => {
  test("distinguishes signed zero under strict exact-bit observation", () => {
    const plusZero = resultObservation({ kind: "return", values: [{ type: "f64", bits: "0000000000000000" }] });
    const minusZero = resultObservation({ kind: "return", values: [{ type: "f64", bits: "8000000000000000" }] });

    expect(compareRuntimeObservations(plusZero, minusZero, "strict").classification).toBe("semantic-mismatch");
  });

  test("canonical-nan policy accepts payload differences but strict does not", () => {
    const left = resultObservation({ kind: "return", values: [{ type: "f32", bits: "7fc00001" }] });
    const right = resultObservation({ kind: "return", values: [{ type: "f32", bits: "7fc01234" }] });

    expect(compareRuntimeObservations(left, right, "strict").classification).toBe("semantic-mismatch");
    expect(compareRuntimeObservations(left, right, "canonical-nan").classification).toBe("equal-result");
  });

  test("classifies equal normalized traps separately from trap mismatches", () => {
    const left = resultObservation({ kind: "trap", class: "unreachable" });
    const same = resultObservation({ kind: "trap", class: "unreachable" });
    const different = resultObservation({ kind: "trap", class: "integer-divide-by-zero" });
    const returned = resultObservation({ kind: "return", values: [{ type: "i32", bits: "00000000" }] });

    expect(compareRuntimeObservations(left, same, "trap-aware").classification).toBe("equal-trap");
    expect(compareRuntimeObservations(left, different, "trap-aware").classification).toBe("trap-mismatch");
    expect(compareRuntimeObservations(left, returned, "trap-aware").classification).toBe("trap-mismatch");
  });
});

describe("deterministic invocation planning", () => {
  test("builds deterministic boundary-oriented scalar values", () => {
    expect(buildBoundaryArgumentValues("i32", 0x5eedn)).toEqual(buildBoundaryArgumentValues("i32", 0x5eedn));
    expect(buildBoundaryArgumentValues("i32", 0x5eedn)).toEqual(expect.arrayContaining([0, 1, -1, -2147483648, 2147483647]));
    expect(buildBoundaryArgumentValues("i64", 0x5eedn)).toEqual(expect.arrayContaining([0n, 1n, -1n, -9223372036854775808n, 9223372036854775807n]));
    expect(buildBoundaryArgumentValues("f32", 0x5eedn)).toEqual(expect.arrayContaining([
      { type: "f32", bits: "00000000" },
      { type: "f32", bits: "80000000" },
      { type: "f32", bits: "7f800000" },
    ]));
  });

  test("persists deterministic multi-call stateful sequences", async () => {
    const wasm = wasmFromWat(`
      (module
        (global (export "g") (mut i32) (i32.const 0))
        (memory (export "memory") 1)
        (func (export "step") (param i32) (result i32)
          global.get 0
          local.get 0
          i32.add
          global.set 0
          i32.const 0
          global.get 0
          i32.store
          global.get 0))
    `);

    const first = await buildDeterministicInvocationPlan(wasm, 0x5eedn, { maxCallsPerExport: 3 });
    const second = await buildDeterministicInvocationPlan(wasm, 0x5eedn, { maxCallsPerExport: 3 });

    expect(first).toEqual(second);
    expect(first.steps.filter((step) => step.exportName === "step").length).toBe(3);
  });
});

describe("primary self-semantic oracle", () => {
  test("accepts equivalent modules", async () => {
    const before = wasmFromWat(`(module (func (export "run") (param i32) (result i32) local.get 0 i32.const 1 i32.add))`);
    const after = wasmFromWat(`(module (func (export "run") (param i32) (result i32) i32.const 1 local.get 0 i32.add))`);

    const report = await runNodeSelfSemanticOracle(before, after, { seed: 0x5eedn, policy: "strict" });

    expect(report.classification).toBe("equal-result");
  });

  test("rejects a valid controlled miscompilation", async () => {
    const before = wasmFromWat(`(module (func (export "run") (param i32) (result i32) local.get 0 i32.const 1 i32.add))`);
    const after = wasmFromWat(`(module (func (export "run") (param i32) (result i32) local.get 0))`);

    const report = await runNodeSelfSemanticOracle(before, after, { seed: 0x5eedn, policy: "strict" });

    expect(report.classification).toBe("semantic-mismatch");
    expect(report.firstDifference?.path).toContain("calls");
  });

  test("classifies nonterminating runtime execution without hanging the fuzz worker", async () => {
    const wasm = wasmFromWat(`(module (func (export "run") (loop br 0)))`);
    const started = Date.now();

    const report = await runNodeSelfSemanticOracle(wasm, wasm, {
      seed: 0x5eedn,
      policy: "strict",
      runtimeTimeoutMs: 100,
    });

    expect(report.classification).toBe("runtime-tool-failure");
    expect(Date.now() - started).toBeLessThan(2000);
  });

  test("replays identical stateful call sequences on fresh instances", async () => {
    const wasm = wasmFromWat(`
      (module
        (global (export "g") (mut i32) (i32.const 0))
        (memory (export "memory") 1)
        (func (export "step") (param i32) (result i32)
          global.get 0
          local.get 0
          i32.add
          global.set 0
          i32.const 0
          global.get 0
          i32.store
          global.get 0))
    `);

    const report = await runNodeSelfSemanticOracle(wasm, wasm, {
      seed: 0x5eedn,
      policy: "strict",
      planOptions: { maxCallsPerExport: 4 },
    });

    expect(report.classification).toBe("equal-result");
    expect(report.before.calls.length).toBe(4);
    expect(report.before.globals).toEqual(report.after.globals);
    expect(report.before.memories).toEqual(report.after.memories);
  });
});

describe("optimizer determinism", () => {
  test("separates raw byte nondeterminism from canonical equality", () => {
    expect(classifyOptimizerDeterminism(Uint8Array.from([1]), Uint8Array.from([1]))).toBe("byte-stable");
    expect(
      classifyOptimizerDeterminism(Uint8Array.from([1]), Uint8Array.from([2]), {
        canonicalLeft: Uint8Array.from([9]),
        canonicalRight: Uint8Array.from([9]),
      }),
    ).toBe("canonical-stable-only");
    expect(classifyOptimizerDeterminism(Uint8Array.from([1]), Uint8Array.from([2]))).toBe("optimizer-nondeterminism");
  });
});

describe("randomized compatible pass sequences", () => {
  const registry: OptimizerPassRegistryEntry[] = [
    { name: "vacuum", category: "hot-pass", executable: true, compatible: true },
    { name: "merge-blocks", category: "hot-pass", executable: true, compatible: true },
    { name: "strip-debug", category: "module-pass", executable: true, compatible: true },
    { name: "optimize", category: "preset", executable: false, compatible: true },
    { name: "no-inline", category: "module-pass", executable: true, compatible: false },
  ];

  test("is deterministic per seed and contains only compatible executable passes", () => {
    const a = generateRandomPassSequence(registry, 0x5eedn, "random-medium");
    const b = generateRandomPassSequence(registry, 0x5eedn, "random-medium");

    expect(a).toEqual(b);
    expect(a.length).toBeGreaterThanOrEqual(2);
    expect(a.every((name) => ["vacuum", "merge-blocks", "strip-debug"].includes(name))).toBe(true);
  });

  test("different seeds provide diversity", () => {
    const seen = new Set<string>();
    for (let seed = 1n; seed <= 8n; seed += 1n) {
      seen.add(generateRandomPassSequence(registry, seed, "random-short").join(","));
    }
    expect(seen.size).toBeGreaterThan(1);
  });
});

describe("property-preserving pass reduction", () => {
  test("shrinks a multi-pass semantic failure without accepting an invalid-output class", () => {
    const evaluations: string[] = [];
    const reduced = reducePassSequencePreservingFailureClass(
      ["noise-a", "break-semantics", "noise-b", "invalid-output"],
      "semantic-self",
      (candidate) => {
        evaluations.push(candidate.join(","));
        if (candidate.includes("invalid-output") && !candidate.includes("break-semantics")) {
          return "validation-failure";
        }
        return candidate.includes("break-semantics") ? "semantic-self" : null;
      },
    );

    expect(reduced.passes).toEqual(["break-semantics"]);
    expect(reduced.failureClass).toBe("semantic-self");
    expect(reduced.predicateEvaluations).toBe(evaluations.length);
    expect(reduced.steps.length).toBeGreaterThan(0);
  });

  test("supports async replay predicates used by optimizer subprocesses", async () => {
    const reduced = await reducePassSequencePreservingFailureClassAsync(
      ["setup", "trigger", "cleanup"],
      "optimizer-nondeterminism",
      async (candidate) => candidate.includes("trigger") ? "optimizer-nondeterminism" : null,
    );
    expect(reduced.passes).toEqual(["trigger"]);
    expect(reduced.failureClass).toBe("optimizer-nondeterminism");
  });
});

describe("optional structural reduction", () => {
  test("classifies missing wasm-reduce as unavailable without failing the fuzz result", () => {
    const result = runOptionalWasmReduce({
      wasmReduceBin: path.join(os.tmpdir(), "definitely-missing-wasm-reduce"),
      inputPath: "input.wasm",
      outputPath: "reduced.wasm",
      predicateCommand: ["false"],
    });

    expect(result.status).toBe("unavailable");
  });

  test("uses Binaryen test and working files for the structural reducer", () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-fake-wasm-reduce-"));
    const inputPath = path.join(dir, "input.wasm");
    const outputPath = path.join(dir, "reduced.wasm");
    const logPath = path.join(dir, "args.json");
    const fake = path.join(dir, "wasm-reduce.ts");
    fs.writeFileSync(inputPath, Uint8Array.from([0, 97, 115, 109]));
    fs.writeFileSync(
      fake,
      `#!/usr/bin/env bun\nimport fs from "node:fs";\nconst args=process.argv.slice(2);\nif(args.includes("--help")){process.exit(0)}\nfs.writeFileSync(${JSON.stringify(logPath)}, JSON.stringify(args));\nconst test=args[args.indexOf("--test")+1];\nconst working=args[args.indexOf("--working")+1];\nfs.copyFileSync(test, working);\n`,
    );
    fs.chmodSync(fake, 0o755);

    const result = runOptionalWasmReduce({
      wasmReduceBin: fake,
      inputPath,
      outputPath,
      predicateCommand: ["bun", "fuzz", "replay-optimizer", "failure", "--input", "candidate.wasm"],
    });

    expect(result.status).toBe("reduced");
    const args = JSON.parse(fs.readFileSync(logPath, "utf8")) as string[];
    expect(args).toContain("--test");
    expect(args).toContain("--working");
    expect(fs.existsSync(outputPath)).toBe(true);
  });
});
