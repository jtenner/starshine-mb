import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, test } from "bun:test";

import {
  formatOiParitySweepReport,
  parseOiParitySweepArgs,
  planOiParitySweep,
  readOiParityMatrix,
  runOiParitySweep,
  type OiParityMatrix,
} from "./oi-parity-sweep";

function fixtureMatrix(): OiParityMatrix {
  return {
    schemaVersion: 1,
    kind: "starshine.optimize-instructions.parity-matrix",
    pass: "optimize-instructions",
    binaryenVersion: "version_130",
    rows: [
      {
        id: "OI-D-default-scalar-identities",
        family: "OI-D",
        title: "Default scalar arithmetic and compare identity breadth",
        upstreamOwner: "OptimizeInstructions.cpp::visitBinary",
        binaryenOracleMode: "compare-pass",
        starshineStatus: "mismatch",
        priority: "P0",
        blockerBoundaryReason: "profile under construction",
        lastCheckedEvidence: ["docs/wiki/raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md"],
        genValidProfiles: ["pass-oi-default-scalar"],
        metamorphicTransforms: ["oi-local-carried", "oi-local-tee-wrapped", "oi-commuted-operands", "oi-if-select-shell", "oi-effectful-sibling", "oi-trapping-sibling", "oi-call-ref-target-wrapper", "oi-tuple-selected-lane", "oi-memory-size-boundary", "oi-live-zero-memory-boundary", "oi-live-nonzero-memory-copy-boundary", "oi-live-nonzero-memory-mid-copy-boundary", "oi-live-nonzero-memory-fill-restore-boundary", "oi-live-nonzero-memory-mid-fill-restore-boundary", "oi-live-nonzero-memory-end-fill-restore-boundary", "add-non-name-custom-section"],
        sweep: { enabled: true, count: 17, seed: "0xabc", profile: "pass-oi-default-scalar", blockedUntilProfileExists: true },
      },
      {
        id: "OI-J-descriptor-exactness-trap-modes",
        family: "OI-J",
        title: "Descriptor/exactness/TNH/IIT cast boundary classification",
        upstreamOwner: "OptimizeInstructions.cpp::skipCast",
        binaryenOracleMode: "compare-pass",
        starshineStatus: "blocked-surface",
        priority: "P1",
        blockerBoundaryReason: "trap mode blocker",
        lastCheckedEvidence: ["docs/wiki/raw/research/0818-2026-06-20-optimize-instructions-oi-j-exact-cast-boundary.md"],
        genValidProfiles: ["pass-oi-ref-gc"],
        sweep: { enabled: false, count: 19, seed: "0xdef", profile: "pass-oi-ref-gc", blockedUntilProfileExists: true },
      },
    ],
  };
}

describe("oi parity sweep", () => {
  test("parses grouped filters and compare-pass passthrough args", () => {
    const parsed = parseOiParitySweepArgs([
      "--family",
      "OI-D,OI-G",
      "--status=mismatch",
      "--priority",
      "P0",
      "--starshine-bin",
      "target/native/release/build/cmd/cmd.exe",
      "--",
      "--max-failures",
      "9",
    ]);

    expect(parsed.families).toEqual(["OI-D", "OI-G"]);
    expect(parsed.statuses).toEqual(["mismatch"]);
    expect(parsed.priorities).toEqual(["P0"]);
    expect(parsed.starshineBin).toBe("target/native/release/build/cmd/cmd.exe");
    expect(parsed.extraCompareArgs).toEqual(["--max-failures", "9"]);
  });

  test("plans compare-pass command shape from matrix rows", () => {
    const options = parseOiParitySweepArgs([
      "--family",
      "OI-D",
      "--include-profile-stubs",
      "--starshine-bin",
      "target/native/release/build/cmd/cmd.exe",
      "--count",
      "23",
      "--seed",
      "0x5eed",
    ]);
    const plans = planOiParitySweep(fixtureMatrix(), options);

    expect(plans).toHaveLength(1);
    expect(plans[0].skipped).toBe(false);
    expect(plans[0].command).toEqual([
      "bun",
      "scripts/pass-fuzz-compare.ts",
      "--count",
      "23",
      "--seed",
      "0x5eed",
      "--pass",
      "optimize-instructions",
      "--out-dir",
      ".tmp/oi-parity-sweep/oi-d/OI-D-default-scalar-identities",
      "--gen-valid-profile",
      "pass-oi-default-scalar",
      "--gen-valid-metamorphic-transform",
      "oi-local-carried",
      "--gen-valid-metamorphic-transform",
      "oi-local-tee-wrapped",
      "--gen-valid-metamorphic-transform",
      "oi-commuted-operands",
      "--gen-valid-metamorphic-transform",
      "oi-if-select-shell",
      "--gen-valid-metamorphic-transform",
      "oi-effectful-sibling",
      "--gen-valid-metamorphic-transform",
      "oi-trapping-sibling",
      "--gen-valid-metamorphic-transform",
      "oi-call-ref-target-wrapper",
      "--gen-valid-metamorphic-transform",
      "oi-tuple-selected-lane",
      "--gen-valid-metamorphic-transform",
      "oi-memory-size-boundary",
      "--gen-valid-metamorphic-transform",
      "oi-live-zero-memory-boundary",
      "--gen-valid-metamorphic-transform",
      "oi-live-nonzero-memory-copy-boundary",
      "--gen-valid-metamorphic-transform",
      "oi-live-nonzero-memory-mid-copy-boundary",
      "--gen-valid-metamorphic-transform",
      "oi-live-nonzero-memory-fill-restore-boundary",
      "--gen-valid-metamorphic-transform",
      "oi-live-nonzero-memory-mid-fill-restore-boundary",
      "--gen-valid-metamorphic-transform",
      "oi-live-nonzero-memory-end-fill-restore-boundary",
      "--gen-valid-metamorphic-transform",
      "add-non-name-custom-section",
      "--starshine-bin",
      "target/native/release/build/cmd/cmd.exe",
      "--jobs",
      "auto",
    ]);
  });

  test("skips disabled rows and profile stubs by default", () => {
    const options = parseOiParitySweepArgs(["--family", "OI-D,OI-J"]);
    const plans = planOiParitySweep(fixtureMatrix(), options);

    expect(plans).toHaveLength(2);
    expect(plans[0].skipped).toBe(true);
    expect(plans[0].skipReason).toContain("profile stub");
    expect(plans[1].skipped).toBe(true);
    expect(plans[1].skipReason).toContain("sweep.enabled is false");
  });

  test("can plan a default GenValid command before row profiles exist", () => {
    const options = parseOiParitySweepArgs(["--family", "OI-D", "--default-gen-valid"]);
    const plans = planOiParitySweep(fixtureMatrix(), options);

    expect(plans).toHaveLength(1);
    expect(plans[0].skipped).toBe(false);
    expect(plans[0].command).not.toContain("--gen-valid-profile");
  });

  test("formats grouped dry-run reports", () => {
    const options = parseOiParitySweepArgs(["--family", "OI-D", "--include-profile-stubs"]);
    const report = runOiParitySweep({ ...options, execute: false });
    const text = formatOiParitySweepReport(report);

    expect(text).toContain("OI parity sweep (optimize-instructions, version_130)");
    expect(text).toContain("- OI-D: 1 row(s), 0 skipped");
    expect(text).toContain("scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-instructions");
  });

  test("summarizes existing result JSON and case-label statuses", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "oi-parity-sweep-test-"));
    const matrixPath = path.join(root, "matrix.json");
    const outDir = path.join(root, "out");
    const rowDir = path.join(outDir, "oi-d", "OI-D-default-scalar-identities");
    fs.writeFileSync(matrixPath, JSON.stringify(fixtureMatrix()));
    fs.mkdirSync(rowDir, { recursive: true });
    fs.writeFileSync(path.join(rowDir, "result.json"), JSON.stringify({
      comparedCount: 3,
      normalizedMatchCount: 1,
      cleanupNormalizedMatchCount: 0,
      mismatchCount: 2,
      validationFailureCount: 0,
      generatorFailureCount: 0,
      propertyFailureCount: 0,
      commandFailureCount: 0,
      genValidProfile: "pass-oi-default-scalar",
      genValidSelectedProfileCounts: { "pass-oi-default-scalar": 3 },
      genValidProfileCaseCounts: {
        "oi-default-scalar:direct": 2,
        "oi-default-scalar:local-carried-add-zero": 1,
      },
      failureDirs: ["case-a", "case-b"],
    }));
    fs.writeFileSync(path.join(rowDir, "cases.jsonl"), [
      JSON.stringify({ status: "mismatch", genValidProfileCaseLabel: "oi-default-scalar:direct" }),
      JSON.stringify({ status: "normalized-match", genValidProfileCaseLabel: "oi-default-scalar:direct" }),
      JSON.stringify({ status: "mismatch", genValidProfileCaseLabel: "oi-default-scalar:local-carried-add-zero" }),
    ].join("\n") + "\n");

    const options = parseOiParitySweepArgs([
      "--matrix",
      matrixPath,
      "--family",
      "OI-D",
      "--include-profile-stubs",
      "--out-dir",
      outDir,
      "--summarize-existing",
    ]);
    const report = runOiParitySweep(options);
    const text = formatOiParitySweepReport(report);

    expect(report.executedRows).toHaveLength(1);
    expect(report.executedRows[0].resultSummary?.caseLabelStatuses).toEqual([
      { label: "oi-default-scalar:direct", total: 2, statuses: { mismatch: 1, "normalized-match": 1 } },
      { label: "oi-default-scalar:local-carried-add-zero", total: 1, statuses: { mismatch: 1 } },
    ]);
    expect(text).toContain("Result summaries:");
    expect(text).toContain("profile cases: oi-default-scalar:direct=2, oi-default-scalar:local-carried-add-zero=1");
    expect(text).toContain("case labels: oi-default-scalar:direct total=2 statuses={\"mismatch\":1,\"normalized-match\":1}; oi-default-scalar:local-carried-add-zero total=1 statuses={\"mismatch\":1}");
  });

  test("summarizes transform ids when profile case labels are absent", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "oi-parity-sweep-test-"));
    const matrixPath = path.join(root, "matrix.json");
    const outDir = path.join(root, "out");
    const rowDir = path.join(outDir, "oi-d", "OI-D-default-scalar-identities");
    fs.writeFileSync(matrixPath, JSON.stringify(fixtureMatrix()));
    fs.mkdirSync(rowDir, { recursive: true });
    fs.writeFileSync(path.join(rowDir, "result.json"), JSON.stringify({
      comparedCount: 2,
      normalizedMatchCount: 0,
      cleanupNormalizedMatchCount: 0,
      mismatchCount: 2,
      validationFailureCount: 0,
      generatorFailureCount: 0,
      propertyFailureCount: 0,
      commandFailureCount: 0,
      genValidProfile: "pass-oi-default-scalar",
      failureDirs: ["case-a", "case-b"],
    }));
    fs.writeFileSync(path.join(rowDir, "cases.jsonl"), [
      JSON.stringify({ status: "mismatch", transformId: "oi-call-ref-target-wrapper" }),
      JSON.stringify({ status: "mismatch", transformId: "oi-effectful-sibling" }),
    ].join("\n") + "\n");

    const options = parseOiParitySweepArgs([
      "--matrix",
      matrixPath,
      "--family",
      "OI-D",
      "--include-profile-stubs",
      "--out-dir",
      outDir,
      "--summarize-existing",
    ]);
    const report = runOiParitySweep(options);
    const text = formatOiParitySweepReport(report);

    expect(report.executedRows[0].resultSummary?.caseLabelStatuses).toEqual([
      { label: "transform:oi-call-ref-target-wrapper", total: 1, statuses: { mismatch: 1 } },
      { label: "transform:oi-effectful-sibling", total: 1, statuses: { mismatch: 1 } },
    ]);
    expect(text).toContain("case labels: transform:oi-call-ref-target-wrapper total=1 statuses={\"mismatch\":1}; transform:oi-effectful-sibling total=1 statuses={\"mismatch\":1}");
  });

  test("checked-in matrix is readable and covers OI-D through OI-M", () => {
    const matrix = readOiParityMatrix("docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json");
    const families = new Set(matrix.rows.map((row) => row.family));

    for (const family of ["OI-D", "OI-E", "OI-F", "OI-G", "OI-H", "OI-I", "OI-J", "OI-K", "OI-L", "OI-M"]) {
      expect(families.has(family)).toBe(true);
    }
  });
});
