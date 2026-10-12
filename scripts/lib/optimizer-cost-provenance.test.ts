import { expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { measureCostArtifact, qualifyCostComparison, type CostComparison } from "./optimizer-cost-provenance";

function fixture(dir: string, canonicalizeBinaryen: boolean): CostComparison {
  const file = (name: string, bytes: string, representation: "input" | "raw" | "canonical") => {
    const filename = path.join(dir, name); fs.writeFileSync(filename, bytes);
    return measureCostArtifact(filename, representation);
  };
  const input = file("input", "named-input", "input");
  const starshineRaw = file("ss.raw", "named-output", "raw");
  const binaryenRaw = file("be.raw", "named-output", "raw");
  const starshineMetric = file("ss.metric", "output", "canonical");
  const binaryenMetric = file("be.metric", canonicalizeBinaryen ? "output" : "named-output", canonicalizeBinaryen ? "canonical" : "raw");
  const normalized = (raw: typeof input, metric: typeof input) => ({ applied: true, policy: "binaryen-strip-debug-v1" as const, inputHash: raw.sha256, outputHash: metric.sha256, elapsedMs: 1, tool: { command: "/test/wasm-opt", version: "wasm-opt version 133 (version_133)", sha256: "a".repeat(64) }, args: [raw.path, "--all-features", "--strip-debug", "-o", metric.path] });
  return { schema: "starshine.encoded-cost-provenance.v1", input, effectiveInput: input, starshineRaw, binaryenRaw, starshineMetric, binaryenMetric,
    starshineNormalization: normalized(starshineRaw, starshineMetric), binaryenNormalization: canonicalizeBinaryen ? normalized(binaryenRaw, binaryenMetric) : { applied: false, policy: "identity", inputHash: binaryenRaw.sha256, outputHash: binaryenMetric.sha256, elapsedMs: 0, tool: null, args: [] } };
}

test("default direct-reference comparison cannot claim a canonical delta", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "cost-provenance-"));
  try { expect(qualifyCostComparison(fixture(dir, false))).toMatchObject({ status: "asymmetric", canonicalDeltaBytes: null, rawDeltaBytes: 0 }); }
  finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test("equal normalization settings qualify actual measured canonical artifacts", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "cost-provenance-"));
  try { expect(qualifyCostComparison(fixture(dir, true))).toMatchObject({ status: "qualified", canonicalDeltaBytes: 0 }); }
  finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test("deliberately mislabeled raw bytes, stale identities and different normalization reject", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "cost-provenance-"));
  try {
    const wrong = fixture(dir, false); wrong.binaryenMetric.representation = "canonical";
    expect(qualifyCostComparison(wrong)).toMatchObject({ status: "blocked" });
    const substituted = fixture(dir, true); substituted.starshineMetric = { ...substituted.starshineRaw, representation: "canonical" };
    expect(qualifyCostComparison(substituted)).toMatchObject({ status: "blocked" });
    const stale = fixture(dir, true); fs.writeFileSync(stale.starshineMetric.path, "replaced");
    expect(qualifyCostComparison(stale)).toMatchObject({ status: "blocked" });
    const flags = fixture(dir, true); flags.binaryenNormalization.args.splice(2, 1);
    expect(qualifyCostComparison(flags)).toMatchObject({ status: "blocked" });
    const version = fixture(dir, true); version.binaryenNormalization.tool!.version = "wasm-opt version 132";
    expect(qualifyCostComparison(version)).toMatchObject({ status: "blocked" });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test("canonicalization may legitimately preserve every raw byte", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "cost-provenance-"));
  try {
    const same = fixture(dir, true);
    for (const side of ["starshine", "binaryen"] as const) {
      fs.copyFileSync(same[`${side}Raw`].path, same[`${side}Metric`].path);
      same[`${side}Metric`] = measureCostArtifact(same[`${side}Metric`].path, "canonical");
      same[`${side}Normalization`].outputHash = same[`${side}Metric`].sha256;
    }
    expect(qualifyCostComparison(same)).toMatchObject({ status: "qualified" });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
