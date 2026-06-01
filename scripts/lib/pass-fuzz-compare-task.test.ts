import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import {
  classifyRuntimeExportInvocationMatrix,
  classifyRuntimeInvocationPair,
  deterministicExportArgumentVector,
  runtimeSemanticMismatchSamples,
  runNodeExportInvocationMatrix,
  smokeExecuteNodeRuntime,
  summarizeRuntimeExportInvocationMatrix,
  passFuzzSummaryCoverageReport,
} from "./pass-fuzz-compare-task";

function wasmFromWat(wat: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-runtime-stubs-"));
  const watPath = path.join(dir, "case.wat");
  const wasmPath = path.join(dir, "case.wasm");
  fs.writeFileSync(watPath, wat);
  const result = spawnSync("wasm-tools", ["parse", watPath, "-o", wasmPath], { encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || "wasm-tools parse failed");
  }
  return wasmPath;
}

describe("pass fuzz summary coverage report", () => {
  test("FUZ1048C maps pass-fuzz result counters into compact summary groups", () => {
    const report = passFuzzSummaryCoverageReport({
      requestedCount: 8,
      minCompared: 4,
      comparedCount: 6,
      normalizedMatchCount: 3,
      cleanupNormalizedMatchCount: 1,
      mismatchCount: 2,
      validationFailureCount: 1,
      generatorFailureCount: 0,
      commandFailureCount: 1,
      commandFailureClasses: { "binaryen-rec-group-zero": 1 },
      commandFailuresCountTowardMaxFailures: false,
      maxFailuresHit: true,
      jobs: 2,
      seed: "0x1048c",
      generator: "both",
      genValidProfile: "smoke",
      genValidRequiredFeatures: ["gc"],
      genValidExcludedFeatures: ["simd"],
      genValidMetamorphicTransforms: ["identity"],
      genValidManifestPath: "inputs/gen-valid/manifest.json",
      genValidTransformCounts: { identity: 2 },
      externalValidators: ["wasm-tools"],
      runtimeExecution: "node",
      propertyMode: "idempotence",
      propertyFailureCount: 1,
      idempotenceCheckedCount: 5,
      idempotenceMatchCount: 4,
      compositionCheckedCount: 0,
      compositionMatchCount: 0,
      runtimeExecutionCounts: { checked: 2, unsupported: 1, failed: 1 },
      runtimeExecutionMatrix: {
        summary: {
          total: 3,
          equalResults: 1,
          equalTraps: 0,
          unsupportedRuntimes: 1,
          nondeterministicImports: 0,
          semanticMismatches: 1,
        },
        outcome: "semantic-mismatch",
        semanticMismatchSamples: [],
      },
      externalValidatorSkipped: { "wasm-tools": 1 },
      generatorCounts: { wasmSmith: 4, genValid: 2 },
      inputEffectTrapCounts: {
        hasCall: 2,
        mutatesMemory: 1,
        mutatesTable: 0,
        mutatesGlobal: 0,
        hasException: 0,
        hasAtomics: 0,
        hasUnreachable: 1,
        mayTrap: 3,
      },
      passFlags: ["--dae-optimizing"],
      binaryenPassFlags: ["--dae-optimizing"],
      normalizers: ["drop-consts"],
      failureDirs: ["failures/case-1", "failures/case-2"],
    });

    expect(report.schema).toBe("starshine.fuzz-summary-report.v1");
    expect(report.suite).toBe("compare-pass");
    expect(report.profile).toBe("dae-optimizing+both");
    expect(report.seed).toBe("0x1048c");
    expect(report.summary.features).toMatchObject({
      optional_input_has_call: 2,
      optional_input_mutates_memory: 1,
      optional_input_has_unreachable: 1,
      optional_input_may_trap: 3,
      optional_runtime_checked: 2,
      optional_runtime_unsupported: 1,
      optional_runtime_failed: 1,
    });
    expect(report.summary.strategies).toMatchObject({
      required_requested_cases: 8,
      required_compared_cases: 6,
      optional_generator_wasm_smith: 4,
      optional_generator_gen_valid: 2,
      optional_gen_valid_transform_identity: 2,
      optional_property_idempotence_checked: 5,
      optional_property_idempotence_matched: 4,
    });
    expect(report.summary.statuses).toMatchObject({
      match: 4,
      mismatch: 2,
      "validation-failure": 1,
      "command-failure": 1,
      "property-failure": 1,
      "max-failures-hit": 1,
    });
    expect(report.summary.failures).toMatchObject({
      mismatch: 2,
      validation: 1,
      command: 1,
      property: 1,
      "command-class.binaryen-rec-group-zero": 1,
      "runtime.semantic-mismatch": 1,
    });
    expect(report.summary.artifacts).toEqual({ failure_dirs: 2, gen_valid_manifest: 1 });
  });
});

describe("runtime result classification", () => {
  test("classify equal results, equal traps, unsupported runtime, nondeterminism, and semantic mismatch", () => {
    expect(classifyRuntimeInvocationPair({ kind: "result", value: 1 }, { kind: "result", value: 1 })).toBe("equal-result");
    expect(classifyRuntimeInvocationPair({ kind: "trap", detail: "unreachable" }, { kind: "trap", detail: "unreachable" })).toBe("equal-trap");
    expect(classifyRuntimeInvocationPair({ kind: "unsupported", detail: "externref" }, { kind: "result", value: 0 })).toBe("unsupported-runtime");
    expect(classifyRuntimeInvocationPair({ kind: "nondeterministic-import", detail: "env.now" }, { kind: "result", value: 0 })).toBe("nondeterministic-import");
    expect(classifyRuntimeInvocationPair({ kind: "result", value: 1 }, { kind: "result", value: 2 })).toBe("semantic-mismatch");
  });

  test("summarize matrix outcome and semantic mismatch samples for persistence", () => {
    const reports = [
      {
        exportName: "ok",
        args: [],
        leftResult: { kind: "result" as const, value: 1 },
        rightResult: { kind: "result" as const, value: 1 },
        classification: "equal-result" as const,
      },
      {
        exportName: "blocked",
        args: [],
        leftResult: { kind: "unsupported" as const, detail: "externref import" },
        rightResult: { kind: "result" as const, value: 0 },
        classification: "unsupported-runtime" as const,
      },
      {
        exportName: "bad",
        args: ["number:0"],
        leftResult: { kind: "result" as const, value: 1 },
        rightResult: { kind: "result" as const, value: 2 },
        classification: "semantic-mismatch" as const,
      },
    ];

    const summary = summarizeRuntimeExportInvocationMatrix(reports);

    expect(summary).toEqual({
      total: 3,
      equalResults: 1,
      equalTraps: 0,
      unsupportedRuntimes: 1,
      nondeterministicImports: 0,
      semanticMismatches: 1,
    });
    expect(classifyRuntimeExportInvocationMatrix(summary)).toBe("semantic-mismatch");
    expect(runtimeSemanticMismatchSamples(reports, 1)).toEqual([reports[2]]);
  });
});

describe("runtime export invocation", () => {
  test("choose deterministic zero argument vectors from exported function arity", () => {
    function noArgs() { return 1; }
    function threeArgs(_a: unknown, _b: unknown, _c: unknown) { return 1; }

    expect(deterministicExportArgumentVector(noArgs)).toEqual([]);
    expect(deterministicExportArgumentVector(threeArgs)).toEqual([0, 0, 0]);
  });

  test("invoke simple non-zero-arg exported functions with deterministic arguments", async () => {
    const wasmPath = wasmFromWat(`
      (module
        (func (export "add") (param i32 i32) (result i32)
          local.get 0
          local.get 1
          i32.add))
    `);

    const result = await smokeExecuteNodeRuntime(wasmPath);

    expect(result).toMatchObject({ ok: true, unsupported: false });
    expect(result.detail).toContain("deterministic simple argument vector");
  });

  test("build export invocation matrix rows for matching Starshine and Binaryen outputs", async () => {
    const leftPath = wasmFromWat(`
      (module
        (func (export "add") (param i32 i32) (result i32)
          local.get 0
          local.get 1
          i32.add))
    `);
    const rightPath = wasmFromWat(`
      (module
        (func (export "add") (param i32 i32) (result i32)
          local.get 0
          local.get 1
          i32.add))
    `);

    const reports = await runNodeExportInvocationMatrix(leftPath, rightPath);

    expect(reports).toEqual([
      {
        exportName: "add",
        args: ["number:0", "number:0"],
        leftResult: { kind: "result", value: 0 },
        rightResult: { kind: "result", value: 0 },
        classification: "equal-result",
      },
    ]);
  });

  test("build export invocation matrix rows for semantic runtime mismatches", async () => {
    const leftPath = wasmFromWat(`(module (func (export "answer") (result i32) i32.const 1))`);
    const rightPath = wasmFromWat(`(module (func (export "answer") (result i32) i32.const 2))`);

    const reports = await runNodeExportInvocationMatrix(leftPath, rightPath);

    expect(reports).toMatchObject([
      {
        exportName: "answer",
        args: [],
        leftResult: { kind: "result", value: 1 },
        rightResult: { kind: "result", value: 2 },
        classification: "semantic-mismatch",
      },
    ]);
  });
});

describe("runtime import stubs", () => {
  test("instantiate i64 global imports with deterministic zero BigInt stubs", async () => {
    const wasmPath = wasmFromWat(`
      (module
        (import "env" "seed" (global i64))
        (func (export "read") (result i64)
          global.get 0))
    `);

    const result = await smokeExecuteNodeRuntime(wasmPath);

    expect(result).toMatchObject({ ok: true, unsupported: false });
  });

  test("instantiate externref table imports with a matching deterministic table", async () => {
    const wasmPath = wasmFromWat(`
      (module
        (import "env" "refs" (table 1 externref))
        (func (export "size") (result i32)
          table.size 0))
    `);

    const result = await smokeExecuteNodeRuntime(wasmPath);

    expect(result).toMatchObject({ ok: true, unsupported: false });
  });
});
