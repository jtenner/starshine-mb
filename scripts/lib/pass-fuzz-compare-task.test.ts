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
  passFuzzReductionLogTextForTest,
  passFuzzSummaryCoverageReport,
  applyCompareNormalizersForTest,
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

describe("pass-fuzz mismatch reduction metadata", () => {
  test("FUZ1043K records shared reducer deletion steps in reduction logs", () => {
    const text = passFuzzReductionLogTextForTest("mismatch", {
      reducedBytes: Uint8Array.from([0x00, 0x61, 0x73, 0x6d]),
      originalSize: 16,
      finalSize: 4,
      predicateEvaluations: 7,
      steps: [
        { kind: "delete-byte-slice", start: 4, length: 8, beforeSize: 16, afterSize: 8 },
      ],
    });

    expect(text).toContain("status=mismatch\n");
    expect(text).toContain("original_size=16\n");
    expect(text).toContain("final_size=4\n");
    expect(text).toContain("predicate_evaluations=7\n");
    expect(text).toContain("reduced_wasm_path=reduced-input.wasm\n");
    expect(text).toContain("step=delete-byte-slice|start=4|len=8|before=16|after=8\n");
  });
});

describe("pass-fuzz compare normalizers", () => {
  test("local-cleanup-debris erases unused local declarations and standalone nops after safe dropped const cleanup", () => {
    const binaryenWat = `(module
 (func $0
  (local $1 i32)
  (local $2 i64)
  (drop
   (i32.const 0)
  )
  (if
   (i32.const 1)
   (then)
   (else
    (nop)
   )
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (if
   (i32.const 1)
   (then)
   (else
   )
  )
 )
)
`;

    expect(applyCompareNormalizersForTest(binaryenWat, ["drop-consts", "local-cleanup-debris"])).toBe(
      applyCompareNormalizersForTest(starshineWat, ["drop-consts", "local-cleanup-debris"]),
    );
  });

  test("local-cleanup-debris keeps local declarations referenced by local operations", () => {
    const wat = `(module
 (func $0
  (local $1 i32)
  (local.set $1
   (i32.const 1)
  )
 )
)
`;

    const normalized = applyCompareNormalizersForTest(wat, ["local-cleanup-debris"]);
    expect(normalized).toContain("(local $local0 i32)");
    expect(normalized).toContain("local.set $local0");
  });

  test("local-cleanup-debris canonicalizes local names after unused local deletion", () => {
    const binaryenWat = `(module
 (func $0 (param $0 i64) (result f32)
  (local $1 i32)
  (local $2 f32)
  (local.get $2)
 )
)
`;
    const starshineWat = `(module
 (func $0 (param $0 i64) (result f32)
  (local $1 f32)
  (local.get $1)
 )
)
`;

    expect(applyCompareNormalizersForTest(binaryenWat, ["local-cleanup-debris"])).toBe(
      applyCompareNormalizersForTest(starshineWat, ["local-cleanup-debris"]),
    );
  });

  test("unreachable-control-debris normalizes constant self-branch blocks and loops", () => {
    const binaryenWat = `(module
 (func $0
  (loop $label
   (br $label)
  )
  (unreachable)
 )
 (func $1
  (loop
  )
  (nop)
 )
)
`;
    const starshineWat = `(module
 (func $0
  (loop $label
   (br_if $label
    (i32.const 1)
   )
  )
  (block $block
   (br_if $block
    (i32.const 0)
   )
  )
  (block $block1
   (br $block1)
  )
  (f32.const 29)
 )
 (func $1
  (loop $label
   (br_if $label
    (i32.const 0)
   )
  )
 )
)
`;

    expect(applyCompareNormalizersForTest(binaryenWat, ["unreachable-control-debris", "local-cleanup-debris"])).toBe(
      applyCompareNormalizersForTest(starshineWat, ["unreachable-control-debris", "local-cleanup-debris"]),
    );
  });

  test("unreachable-control-debris erases void branch-unreachable wrapper blocks", () => {
    const binaryenWat = `(module
 (func $0
  (drop
   (f64.const 1.5)
  )
  (block $block
   (block
    (br $block)
   )
   (unreachable)
  )
  (loop
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (drop
   (f64.const 1.5)
  )
  (loop
  )
 )
)
`;

    expect(applyCompareNormalizersForTest(binaryenWat, ["unreachable-control-debris"])).toBe(
      applyCompareNormalizersForTest(starshineWat, ["unreachable-control-debris"]),
    );
  });

  test("unreachable-control-debris erases drop-unreachable before an adjacent unreachable", () => {
    const binaryenWat = `(module
 (export "run" (func $0))
 (func $0
  (drop
   (f64.const 7.52804e-317)
  )
  (unreachable)
 )
)
`;
    const starshineWat = `(module
 (export "run" (func $0))
 (func $0
  (drop
   (f64.const 7.52804e-317)
  )
  (drop
   (unreachable)
  )
  (unreachable)
 )
)
`;

    expect(applyCompareNormalizersForTest(binaryenWat, ["unreachable-control-debris"])).toBe(
      applyCompareNormalizersForTest(starshineWat, ["unreachable-control-debris"]),
    );
  });

  test("drop-consts erases exponent float constants before local nop cleanup", () => {
    const binaryenWat = `(module
 (func $0 (result f64)
  (nop)
  (unreachable)
 )
)
`;
    const starshineWat = `(module
 (func $0 (result f64)
  (drop
   (f32.const 1.5046326793694263e-36)
  )
  (unreachable)
 )
)
`;

    expect(applyCompareNormalizersForTest(binaryenWat, ["drop-consts", "local-cleanup-debris"])).toBe(
      applyCompareNormalizersForTest(starshineWat, ["drop-consts", "local-cleanup-debris"]),
    );
  });

  test("ssa-local-allocation-debris normalizes equivalent fresh temp vs reused straight-line islands", () => {
    const binaryenWat = `(module
 (func $0
  (local $6 i32)
  (local.set $6
   (i32.const 1)
  )
  (drop
   (local.get $6)
  )
  (local.set $7
   (i32.const 2)
  )
  (drop
   (local.get $7)
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (local $1 i32)
  (local.set $1
   (i32.const 1)
  )
  (drop
   (local.get $1)
  )
  (local.set $1
   (i32.const 2)
  )
  (drop
   (local.get $1)
  )
 )
)
`;

    expect(
      applyCompareNormalizersForTest(binaryenWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    ).toBe(
      applyCompareNormalizersForTest(starshineWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    );
  });

  test("ssa-local-allocation-debris normalizes independent tee islands", () => {
    const binaryenWat = `(module
 (func $0
  (drop
   (local.tee $8
    (i32.const 7)
   )
  )
  (drop
   (local.get $8)
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (drop
   (local.tee $1
    (i32.const 7)
   )
  )
  (drop
   (local.get $1)
  )
 )
)
`;

    expect(
      applyCompareNormalizersForTest(binaryenWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    ).toBe(
      applyCompareNormalizersForTest(starshineWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    );
  });

  test("ssa-local-allocation-debris normalizes pre-if condition carriers only", () => {
    const binaryenWat = `(module
 (func $0
  (local $1 i32)
  (local.set $9
   (i32.const 0)
  )
  (if
   (local.get $9)
   (then
    (local.set $1
     (i32.const 1)
    )
   )
   (else
    (local.set $1
     (i32.const 2)
    )
   )
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (local $1 i32)
  (local.set $1
   (i32.const 0)
  )
  (if
   (local.get $1)
   (then
    (local.set $1
     (i32.const 1)
    )
   )
   (else
    (local.set $1
     (i32.const 2)
    )
   )
  )
 )
)
`;

    expect(
      applyCompareNormalizersForTest(binaryenWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    ).toBe(
      applyCompareNormalizersForTest(starshineWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    );
  });

  test("ssa-local-allocation-debris normalizes case-000001 straight-line prefix", () => {
    const binaryenWat = `(module
 (func $0 (param $0 i32)
  (local $6 i32)
  (local $7 i32)
  (local $8 i32)
  (local.set $6
   (i32.const 1)
  )
  (drop
   (local.get $6)
  )
  (local.set $7
   (i32.const 2)
  )
  (drop
   (local.get $7)
  )
  (drop
   (local.tee $8
    (i32.const 7)
   )
  )
  (drop
   (local.get $8)
  )
  (local.set $0
   (i32.const 9)
  )
  (drop
   (local.get $0)
  )
 )
)
`;
    const starshineWat = `(module
 (func $0 (param $0 i32)
  (local $1 i32)
  (local.set $1
   (i32.const 1)
  )
  (drop
   (local.get $1)
  )
  (local.set $1
   (i32.const 2)
  )
  (drop
   (local.get $1)
  )
  (drop
   (local.tee $1
    (i32.const 7)
   )
  )
  (drop
   (local.get $1)
  )
  (local.set $0
   (i32.const 9)
  )
  (drop
   (local.get $0)
  )
 )
)
`;

    expect(
      applyCompareNormalizersForTest(binaryenWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    ).toBe(
      applyCompareNormalizersForTest(starshineWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    );
  });

  test("ssa-local-allocation-debris rejects incompatible local types", () => {
    const binaryenWat = `(module
 (func $0
  (local $6 i32)
  (local.set $6
   (i32.const 1)
  )
  (drop
   (local.get $6)
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (local $1 i64)
  (local.set $1
   (i64.const 1)
  )
  (drop
   (local.get $1)
  )
 )
)
`;

    expect(
      applyCompareNormalizersForTest(binaryenWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    ).not.toBe(
      applyCompareNormalizersForTest(starshineWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    );
  });

  test("ssa-local-allocation-debris rejects missing local.set", () => {
    const binaryenWat = `(module
 (func $0
  (local.set $6
   (i32.const 1)
  )
  (drop
   (local.get $6)
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (drop
   (local.get $1)
  )
 )
)
`;

    expect(
      applyCompareNormalizersForTest(binaryenWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    ).not.toBe(
      applyCompareNormalizersForTest(starshineWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    );
  });

  test("ssa-local-allocation-debris rejects reordered local traffic", () => {
    const binaryenWat = `(module
 (func $0
  (local.set $6
   (i32.const 1)
  )
  (drop
   (local.get $6)
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (drop
   (local.get $1)
  )
  (local.set $1
   (i32.const 1)
  )
 )
)
`;

    expect(
      applyCompareNormalizersForTest(binaryenWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    ).not.toBe(
      applyCompareNormalizersForTest(starshineWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    );
  });

  test("ssa-local-allocation-debris rejects changed branch structure", () => {
    const binaryenWat = `(module
 (func $0
  (local $1 i32)
  (local.set $9
   (i32.const 0)
  )
  (if
   (local.get $9)
   (then
    (local.set $1
     (i32.const 1)
    )
   )
   (else
    (local.set $1
     (i32.const 2)
    )
   )
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (local $1 i32)
  (local.set $1
   (i32.const 0)
  )
  (if
   (local.get $1)
   (then
    (local.set $1
     (i32.const 1)
    )
   )
  )
 )
)
`;

    expect(
      applyCompareNormalizersForTest(binaryenWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    ).not.toBe(
      applyCompareNormalizersForTest(starshineWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    );
  });

  test("ssa-local-allocation-debris rejects block join local allocation drift", () => {
    const binaryenWat = `(module
 (func $0
  (local $10 i32)
  (local $11 i32)
  (local.set $10
   (i32.const 0)
  )
  (block $block
   (local.set $11
    (i32.const 7)
   )
   (br $block)
  )
  (drop
   (local.get $11)
  )
 )
)
`;
    const starshineWat = `(module
 (func $0
  (local $1 i32)
  (local.set $1
   (i32.const 0)
  )
  (block $block
   (local.set $1
    (i32.const 7)
   )
   (br $block)
  )
  (drop
   (local.get $1)
  )
 )
)
`;

    expect(
      applyCompareNormalizersForTest(binaryenWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    ).not.toBe(
      applyCompareNormalizersForTest(starshineWat, ["ssa-local-allocation-debris", "local-cleanup-debris"]),
    );
  });

  test("drop-consts erases pure reinterpret numeric trees", () => {
    const binaryenWat = `(module
 (func $0
  (try_table
   (nop)
  )
  (unreachable)
 )
)
`;
    const starshineWat = `(module
 (func $0
  (try_table
   (drop
    (f32.reinterpret_i32
     (i32.extend16_s
      (i32.trunc_sat_f32_s
       (f32.const -1.9999998807907104)
      )
     )
    )
   )
  )
  (unreachable)
 )
)
`;

    expect(applyCompareNormalizersForTest(binaryenWat, ["drop-consts", "local-cleanup-debris"])).toBe(
      applyCompareNormalizersForTest(starshineWat, ["drop-consts", "local-cleanup-debris"]),
    );
  });
});

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
