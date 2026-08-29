import crypto from "node:crypto";

import type { NodeThreeWaySemanticOracleV2Report } from "./optimizer-runtime-executor";

export type FingerprintMatchLevel = "exact" | "family";

export type SemanticFailureFingerprint = {
  schema: "starshine.optimizer-semantic-fingerprint.v1";
  propertyKind: string;
  primaryFailureClass: string;
  semanticPolicy: string;
  observationCompleteness: string;
  passSequence: string[];
  commutatorOrder?: string | null;
  firstDivergentPassBoundary?: string | null;
  metamorphicRelationId?: string | null;
  thresholdId?: string | null;
  originalOutcomeKind?: string | null;
  candidateOutcomeKind?: string | null;
  originalTrapClass?: string | null;
  candidateTrapClass?: string | null;
  firstDifferenceCategory?: string | null;
  exportName?: string | null;
  invocationStep?: number | null;
  resultIndex?: number | null;
  stateResourceKind?: string | null;
  stateResourceIndex?: number | null;
  memoryOrTableOffset?: number | null;
  importCommonPrefixLength?: number | null;
  firstDifferingImportModule?: string | null;
  firstDifferingImportField?: string | null;
  eventKind?: number | null;
  originalInterfaceHash?: string | null;
  candidateInterfaceHash?: string | null;
  invocationPlanHash?: string | null;
};

export function createSemanticFailureFingerprint(
  fields: Omit<SemanticFailureFingerprint, "schema">,
): SemanticFailureFingerprint {
  return { schema: "starshine.optimizer-semantic-fingerprint.v1", ...fields };
}

export function semanticFingerprintFromRuntimeReport(
  report: NodeThreeWaySemanticOracleV2Report,
  options: {
    passSequence: string[];
    firstDivergentPassBoundary?: string | null;
    propertyKind?: string;
    commutatorOrder?: string | null;
    metamorphicRelationId?: string | null;
  },
): SemanticFailureFingerprint {
  const comparison = report.originalVsStarshine;
  const stepMatch = comparison.firstDifferencePath?.match(/^steps\[(\d+)\]/);
  const observationStepIndex = stepMatch ? Number(stepMatch[1]) : null;
  const observationStep = observationStepIndex === null ? null : report.original.steps[observationStepIndex] ?? null;
  const resultMatch = comparison.firstDifferencePath?.match(/\.values\[(\d+)\]/);
  const event = comparison.firstDifferingImportEvent?.expected ?? comparison.firstDifferingImportEvent?.actual ?? null;
  return createSemanticFailureFingerprint({
    propertyKind: options.propertyKind ?? "semantic-self-v2",
    primaryFailureClass: report.classification.primary,
    semanticPolicy: comparison.policy,
    observationCompleteness: comparison.completeness,
    passSequence: options.passSequence,
    commutatorOrder: options.commutatorOrder ?? null,
    firstDivergentPassBoundary: options.firstDivergentPassBoundary ?? null,
    metamorphicRelationId: options.metamorphicRelationId ?? null,
    thresholdId: null,
    originalOutcomeKind: comparison.originalOutcomeKind,
    candidateOutcomeKind: comparison.candidateOutcomeKind,
    originalTrapClass: comparison.originalTrapClass,
    candidateTrapClass: comparison.candidateTrapClass,
    firstDifferenceCategory: comparison.firstDifferenceCategory,
    exportName: observationStep?.exportName ?? null,
    invocationStep: observationStep?.stepIndex ?? null,
    resultIndex: resultMatch ? Number(resultMatch[1]) : null,
    stateResourceKind: comparison.resourceKind,
    stateResourceIndex: comparison.resourceIndex,
    memoryOrTableOffset: comparison.offset,
    importCommonPrefixLength: comparison.commonImportEventPrefixLength,
    firstDifferingImportModule: event?.module ?? null,
    firstDifferingImportField: event?.field ?? null,
    eventKind: event?.ordinal ?? null,
    originalInterfaceHash: report.runtimeInterface.interfaceHash,
    candidateInterfaceHash: null,
    invocationPlanHash: report.plan.hash,
  });
}

function stable(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stable);
  if (value !== null && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      const child = (value as Record<string, unknown>)[key];
      if (child !== undefined) out[key] = stable(child);
    }
    return out;
  }
  return value;
}

export function stableSemanticFingerprintJson(value: unknown): string {
  return `${JSON.stringify(stable(value))}\n`;
}

export function semanticFingerprintHash(fingerprint: SemanticFailureFingerprint): string {
  return `sha256:${crypto.createHash("sha256").update(stableSemanticFingerprintJson(fingerprint)).digest("hex")}`;
}

function trapFamily(value: string | null | undefined): string | null {
  if (value == null) return null;
  if (value.includes("memory") || value.includes("table")) return "bounds";
  if (value.includes("divide") || value.includes("overflow") || value.includes("conversion")) return "numeric";
  if (value.includes("reference") || value.includes("cast") || value.includes("element")) return "reference";
  if (value.includes("timeout")) return "timeout";
  return value;
}

function passFamily(value: SemanticFailureFingerprint): string {
  return value.firstDivergentPassBoundary ?? value.commutatorOrder ?? value.passSequence.at(-1) ?? "none";
}

function relationFamily(value: string | null | undefined): string | null {
  if (value == null) return null;
  return value.split(":", 1)[0].split("/", 1)[0];
}

function familyProjection(value: SemanticFailureFingerprint): unknown {
  return {
    schema: value.schema,
    propertyKind: value.propertyKind,
    primaryFailureClass: value.primaryFailureClass,
    semanticPolicy: value.semanticPolicy,
    observationCompleteness: value.observationCompleteness,
    passFamily: passFamily(value),
    firstDifferenceCategory: value.firstDifferenceCategory ?? null,
    resourceCategory: value.stateResourceKind ?? null,
    originalTrapFamily: trapFamily(value.originalTrapClass),
    candidateTrapFamily: trapFamily(value.candidateTrapClass),
    metamorphicRelationFamily: relationFamily(value.metamorphicRelationId),
    thresholdFamily: relationFamily(value.thresholdId),
  };
}

export function fingerprintMatches(
  expected: SemanticFailureFingerprint,
  actual: SemanticFailureFingerprint,
  level: FingerprintMatchLevel,
): boolean {
  if (level === "exact") return stableSemanticFingerprintJson(expected) === stableSemanticFingerprintJson(actual);
  return stableSemanticFingerprintJson(familyProjection(expected)) === stableSemanticFingerprintJson(familyProjection(actual));
}

export type ReductionEvaluation = {
  valid: boolean;
  deterministic: boolean;
  fingerprint: SemanticFailureFingerprint | null;
};

export type FingerprintReductionReport<Candidate> = {
  schema: "starshine.optimizer-fingerprint-reduction.v1";
  original: Candidate;
  final: Candidate;
  originalFingerprint: SemanticFailureFingerprint;
  finalFingerprint: SemanticFailureFingerprint;
  finalLevel: FingerprintMatchLevel;
  relaxation: { from: "exact"; to: "family"; reason: string } | null;
  candidateCount: number;
  accepted: Array<{ candidate: Candidate; level: FingerprintMatchLevel; sizeBefore: number; sizeAfter: number }>;
  rejected: Array<{ candidate: Candidate; level: FingerprintMatchLevel; reason: string }>;
};

async function tryCandidates<Candidate>(
  current: Candidate,
  candidates: Candidate[],
  level: FingerprintMatchLevel,
  options: {
    fingerprint: SemanticFailureFingerprint;
    evaluate(candidate: Candidate): Promise<ReductionEvaluation>;
    size(candidate: Candidate): number;
  },
  accepted: FingerprintReductionReport<Candidate>["accepted"],
  rejected: FingerprintReductionReport<Candidate>["rejected"],
): Promise<{ current: Candidate; fingerprint: SemanticFailureFingerprint }> {
  let currentFingerprint = options.fingerprint;
  for (const candidate of candidates) {
    if (options.size(candidate) >= options.size(current)) {
      rejected.push({ candidate, level, reason: "not-smaller" });
      continue;
    }
    const evaluation = await options.evaluate(candidate);
    if (!evaluation.valid) {
      rejected.push({ candidate, level, reason: "invalid-candidate" });
      continue;
    }
    if (!evaluation.deterministic) {
      rejected.push({ candidate, level, reason: "nondeterministic-predicate" });
      continue;
    }
    if (evaluation.fingerprint === null || !fingerprintMatches(options.fingerprint, evaluation.fingerprint, level)) {
      rejected.push({ candidate, level, reason: "fingerprint-mismatch" });
      continue;
    }
    const sizeBefore = options.size(current);
    current = candidate;
    currentFingerprint = evaluation.fingerprint;
    accepted.push({ candidate, level, sizeBefore, sizeAfter: options.size(candidate) });
  }
  return { current, fingerprint: currentFingerprint };
}

export async function runFingerprintPreservingReduction<Candidate>(options: {
  original: Candidate;
  fingerprint: SemanticFailureFingerprint;
  candidates: Candidate[];
  evaluate(candidate: Candidate): Promise<ReductionEvaluation>;
  size(candidate: Candidate): number;
  allowFamilyRelaxation: boolean;
}): Promise<FingerprintReductionReport<Candidate>> {
  const accepted: FingerprintReductionReport<Candidate>["accepted"] = [];
  const rejected: FingerprintReductionReport<Candidate>["rejected"] = [];
  const exact = await tryCandidates(options.original, options.candidates, "exact", options, accepted, rejected);
  let final = exact.current;
  let finalFingerprint = exact.fingerprint;
  let finalLevel: FingerprintMatchLevel = "exact";
  let relaxation: FingerprintReductionReport<Candidate>["relaxation"] = null;
  if (accepted.length === 0 && options.allowFamilyRelaxation) {
    relaxation = { from: "exact", to: "family", reason: "exact reducer made no progress" };
    const family = await tryCandidates(options.original, options.candidates, "family", options, accepted, rejected);
    final = family.current;
    finalFingerprint = family.fingerprint;
    finalLevel = "family";
  }
  return {
    schema: "starshine.optimizer-fingerprint-reduction.v1",
    original: options.original,
    final,
    originalFingerprint: options.fingerprint,
    finalFingerprint,
    finalLevel,
    relaxation,
    candidateCount: options.candidates.length,
    accepted,
    rejected,
  };
}
