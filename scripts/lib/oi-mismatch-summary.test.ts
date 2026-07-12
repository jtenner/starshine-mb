import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, test } from "bun:test";

import { formatOiMismatchSummary, summarizeOiMismatchRun } from "./oi-mismatch-summary";

function writeFailure(
  runDir: string,
  caseIndex: number,
  starshineWat: string,
  binaryenWat: string,
): void {
  const failureDir = path.join(runDir, "failures", `case-${String(caseIndex).padStart(6, "0")}-gen-valid`);
  fs.mkdirSync(failureDir, { recursive: true });
  fs.writeFileSync(path.join(failureDir, "starshine.wat"), starshineWat);
  fs.writeFileSync(path.join(failureDir, "binaryen.wat"), binaryenWat);
}

describe("OI aggregate mismatch summary", () => {
  test("groups mismatch artifacts by selected profile, case label, and normalized diff signature", () => {
    const runDir = fs.mkdtempSync(path.join(os.tmpdir(), "oi-mismatch-summary-"));
    fs.writeFileSync(path.join(runDir, "result.json"), JSON.stringify({
      requestedCount: 4,
      comparedCount: 4,
      normalizedMatchCount: 1,
      mismatchCount: 3,
    }));
    fs.writeFileSync(path.join(runDir, "cases.jsonl"), [
      JSON.stringify({ caseIndex: 0, status: "mismatch", genValidSelectedProfile: "pass-oi-default-scalar", genValidProfileCaseLabel: "oi-default-scalar:direct" }),
      JSON.stringify({ caseIndex: 1, status: "mismatch", genValidSelectedProfile: "pass-oi-default-scalar", genValidProfileCaseLabel: "oi-default-scalar:direct" }),
      JSON.stringify({ caseIndex: 2, status: "mismatch", genValidSelectedProfile: "pass-oi-tuple", genValidProfileCaseLabel: "oi-tuple:direct-selected-lane" }),
      JSON.stringify({ caseIndex: 3, status: "match", genValidSelectedProfile: "pass-oi-tuple", genValidProfileCaseLabel: "oi-tuple:direct-selected-lane" }),
    ].join("\n") + "\n");

    const scalarStarshine = "(module\n (func $0\n  (i32.const 1)\n )\n)\n";
    const scalarBinaryen = "(module\n (func $99\n  (drop (i32.const 1))\n )\n)\n";
    writeFailure(runDir, 0, scalarStarshine, scalarBinaryen);
    writeFailure(runDir, 1, scalarStarshine.replace("$0", "$7"), scalarBinaryen.replace("$99", "$8"));
    writeFailure(runDir, 2, "(module\n (func $0 (nop))\n)\n", "(module\n (func $1)\n)\n");

    const summary = summarizeOiMismatchRun(runDir);

    expect(summary.mismatchRecords).toBe(3);
    expect(summary.missingFailureArtifacts).toEqual([]);
    expect(summary.groups).toHaveLength(2);
    expect(summary.groups[0]).toMatchObject({
      selectedProfile: "pass-oi-default-scalar",
      caseLabel: "oi-default-scalar:direct",
      count: 2,
      representativeCaseIndex: 0,
    });
    expect(summary.groups[0].diffSignature).toMatch(/^sha256:/);
    expect(summary.groups[0].removedPreview.some((line) => line.includes("i32.const"))).toBe(true);
    expect(summary.groups[0].addedPreview.some((line) => line.includes("drop"))).toBe(true);

    const text = formatOiMismatchSummary(summary);
    expect(text).toContain("mismatch records: 3");
    expect(text).toContain("pass-oi-default-scalar / oi-default-scalar:direct: 2");
    expect(text).toContain("agent classification: required; grouping is triage evidence only");
  });

  test("reports mismatch records whose saved WAT artifacts are missing", () => {
    const runDir = fs.mkdtempSync(path.join(os.tmpdir(), "oi-mismatch-summary-missing-"));
    fs.writeFileSync(path.join(runDir, "cases.jsonl"), JSON.stringify({
      caseIndex: 42,
      status: "mismatch",
      genValidSelectedProfile: "pass-oi-ref-gc",
      genValidProfileCaseLabel: "oi-ref-gc:sample",
    }) + "\n");

    const summary = summarizeOiMismatchRun(runDir);

    expect(summary.groups).toEqual([]);
    expect(summary.missingFailureArtifacts).toEqual([42]);
  });
});
