import fs from "node:fs";
import { createHash } from "node:crypto";

export type CostArtifact = { path: string; representation: "input" | "raw" | "canonical"; bytes: number; sha256: string };
export type CostTool = { command: string; version: string | null; sha256: string | null };
export type CostNormalization = { applied: boolean; policy: "identity" | "binaryen-strip-debug-v1"; inputHash: string; outputHash: string; elapsedMs: number; tool: CostTool | null; args: string[] };
export type CostComparison = {
  schema: "starshine.encoded-cost-provenance.v1";
  input: CostArtifact; effectiveInput: CostArtifact;
  starshineRaw: CostArtifact; binaryenRaw: CostArtifact;
  starshineMetric: CostArtifact; binaryenMetric: CostArtifact;
  starshineNormalization: CostNormalization; binaryenNormalization: CostNormalization;
};

export function measureCostArtifact(filename: string, representation: CostArtifact["representation"]): CostArtifact {
  if (!fs.statSync(filename).isFile()) throw new Error("cost artifact must be a regular file");
  const descriptor = fs.openSync(filename, "r"), scratch = Buffer.allocUnsafe(65536), digest = createHash("sha256");
  let bytes = 0;
  try {
    for (;;) {
      const count = fs.readSync(descriptor, scratch, 0, scratch.length, null);
      if (count === 0) break;
      digest.update(scratch.subarray(0, count)); bytes += count;
    }
  } finally { fs.closeSync(descriptor); }
  return { path: filename, representation, bytes, sha256: digest.digest("hex") };
}

// This qualifies the runner's byte-bound provenance, not the optimizer's semantics
// or independent attestation that a hostile tool consumed a particular file.
export function qualifyCostComparison(comparison: CostComparison) {
  const reasons: string[] = [];
  const hash = (value: string | null) => typeof value === "string" && /^[a-f0-9]{64}$/.test(value);
  if (comparison.schema !== "starshine.encoded-cost-provenance.v1") reasons.push("unknown cost schema");
  for (const [name, artifact] of Object.entries({ input: comparison.input, effectiveInput: comparison.effectiveInput, starshineRaw: comparison.starshineRaw, binaryenRaw: comparison.binaryenRaw, starshineMetric: comparison.starshineMetric, binaryenMetric: comparison.binaryenMetric })) {
    if (!Number.isSafeInteger(artifact.bytes) || artifact.bytes < 0 || !hash(artifact.sha256)) reasons.push(`${name}: invalid byte identity`);
    if ((name === "input" || name === "effectiveInput") && artifact.representation !== "input") reasons.push(`${name}: mislabeled input`);
    if (name.endsWith("Raw") && artifact.representation !== "raw") reasons.push(`${name}: mislabeled raw output`);
    try {
      const current = measureCostArtifact(artifact.path, artifact.representation);
      if (current.bytes !== artifact.bytes || current.sha256 !== artifact.sha256) reasons.push(`${name}: stale artifact identity`);
    } catch { reasons.push(`${name}: unavailable artifact`); }
  }
  for (const side of ["starshine", "binaryen"] as const) {
    const raw = comparison[`${side}Raw`], metric = comparison[`${side}Metric`], normalization = comparison[`${side}Normalization`];
    if (normalization.inputHash !== raw.sha256 || normalization.outputHash !== metric.sha256) reasons.push(`${side}: normalization artifact substitution`);
    if (!Number.isFinite(normalization.elapsedMs) || normalization.elapsedMs < 0) reasons.push(`${side}: invalid normalization timing`);
    if (normalization.applied) {
      if (metric.representation !== "canonical" || normalization.policy !== "binaryen-strip-debug-v1") reasons.push(`${side}: canonical metric lacks the canonical projection`);
      if (!normalization.tool || !hash(normalization.tool.sha256) || !/^wasm-opt version 133\b/.test(normalization.tool.version ?? "")) reasons.push(`${side}: unqualified normalizer identity/version`);
      if (JSON.stringify(normalization.args) !== JSON.stringify([raw.path, "--all-features", "--strip-debug", "-o", metric.path])) reasons.push(`${side}: differing normalization settings`);
    } else if (metric.representation !== "raw" || normalization.policy !== "identity" || normalization.args.length !== 0 || normalization.tool !== null || metric.sha256 !== raw.sha256 || metric.bytes !== raw.bytes) reasons.push(`${side}: raw metric mislabeled or changed`);
  }
  const a = comparison.starshineNormalization, b = comparison.binaryenNormalization;
  const comparable = a.applied && b.applied && a.policy === b.policy && a.tool?.sha256 === b.tool?.sha256 && a.tool?.version === b.tool?.version;
  return {
    status: reasons.length ? "blocked" as const : comparable ? "qualified" as const : "asymmetric" as const,
    reasons,
    rawDeltaBytes: reasons.length ? null : comparison.starshineRaw.bytes - comparison.binaryenRaw.bytes,
    canonicalDeltaBytes: reasons.length || !comparable ? null : comparison.starshineMetric.bytes - comparison.binaryenMetric.bytes,
  };
}
