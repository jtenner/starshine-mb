import { describe, expect, test } from "bun:test";

import {
  createSemanticFailureFingerprint,
  fingerprintMatches,
  semanticFingerprintHash,
  runFingerprintPreservingReduction,
} from "./optimizer-failure-fingerprint";

const base = createSemanticFailureFingerprint({
  propertyKind: "semantic-idempotence",
  primaryFailureClass: "semantic-mismatch",
  semanticPolicy: "trap-aware",
  observationCompleteness: "complete",
  passSequence: ["p", "q"],
  firstDivergentPassBoundary: "q",
  firstDifferenceCategory: "memory",
  exportName: "run",
  invocationStep: 2,
  stateResourceKind: "memory",
  stateResourceIndex: 0,
  memoryOrTableOffset: 70000,
  originalOutcomeKind: "trapped",
  candidateOutcomeKind: "trapped",
  originalTrapClass: "out-of-bounds-memory-access",
  candidateTrapClass: "out-of-bounds-memory-access",
  importCommonPrefixLength: 1,
  firstDifferingImportModule: "starshine_observe",
  firstDifferingImportField: "event",
  originalInterfaceHash: "a",
  candidateInterfaceHash: "b",
  invocationPlanHash: "plan",
});

describe("semantic failure fingerprints", () => {
  test("supports exact and family equality", () => {
    const moved = { ...base, memoryOrTableOffset: 70001 };
    expect(fingerprintMatches(base, structuredClone(base), "exact")).toBe(true);
    expect(fingerprintMatches(base, moved, "exact")).toBe(false);
    expect(fingerprintMatches(base, moved, "family")).toBe(true);
  });

  test("has deterministic canonical JSON hashing", () => {
    expect(semanticFingerprintHash(base)).toBe(semanticFingerprintHash({ ...base }));
    expect(semanticFingerprintHash(base)).toMatch(/^sha256:/);
  });
});

describe("fingerprint-preserving reduction", () => {
  test("rejects invalid, timeout-substitution, and moved-offset exact candidates", async () => {
    const report = await runFingerprintPreservingReduction({
      original: "noise:TRIGGER:tail",
      fingerprint: base,
      candidates: ["invalid", "timeout", "moved", "TRIGGER"],
      evaluate: async (candidate) => {
        if (candidate === "invalid") return { valid: false, deterministic: true, fingerprint: null };
        if (candidate === "timeout") return { valid: true, deterministic: true, fingerprint: { ...base, primaryFailureClass: "timeout" } };
        if (candidate === "moved") return { valid: true, deterministic: true, fingerprint: { ...base, memoryOrTableOffset: 4 } };
        return { valid: true, deterministic: true, fingerprint: base };
      },
      size: (candidate) => candidate.length,
      allowFamilyRelaxation: false,
    });
    expect(report.final).toBe("TRIGGER");
    expect(report.accepted).toHaveLength(1);
    expect(report.rejected.map((entry) => entry.reason)).toEqual(expect.arrayContaining(["invalid-candidate", "fingerprint-mismatch"]));
  });

  test("records an explicit relaxation to family matching", async () => {
    const report = await runFingerprintPreservingReduction({
      original: "large",
      fingerprint: base,
      candidates: ["tiny"],
      evaluate: async () => ({ valid: true, deterministic: true, fingerprint: { ...base, memoryOrTableOffset: 9 } }),
      size: (candidate) => candidate.length,
      allowFamilyRelaxation: true,
    });
    expect(report.final).toBe("tiny");
    expect(report.relaxation).toEqual({ from: "exact", to: "family", reason: "exact reducer made no progress" });
  });

  test("rejects nondeterministic predicates", async () => {
    const report = await runFingerprintPreservingReduction({
      original: "large",
      fingerprint: base,
      candidates: ["tiny"],
      evaluate: async () => ({ valid: true, deterministic: false, fingerprint: base }),
      size: (candidate) => candidate.length,
      allowFamilyRelaxation: false,
    });
    expect(report.final).toBe("large");
    expect(report.rejected[0].reason).toBe("nondeterministic-predicate");
  });
});
