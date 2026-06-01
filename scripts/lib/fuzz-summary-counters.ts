export type NumericCounterMap = Record<string, number>;

export type CoverageDeltaSummary = {
  feature_counters: NumericCounterMap;
  opcode_counters: NumericCounterMap;
  strategy_counters: NumericCounterMap;
  artifact_counts: NumericCounterMap;
  failure_classes: NumericCounterMap;
  pass_statuses: NumericCounterMap;
  timings: NumericCounterMap;
  [key: string]: unknown;
};

export type CoverageDeltaReport = {
  summary: CoverageDeltaSummary;
  [key: string]: unknown;
};

export const FUZZ_SUMMARY_REPORT_SCHEMA = "starshine.fuzz-summary-report.v1";

export type FuzzSummaryCounterGroups = {
  features: NumericCounterMap;
  opcodes: NumericCounterMap;
  strategies: NumericCounterMap;
  statuses: NumericCounterMap;
  failures: NumericCounterMap;
  timings: NumericCounterMap;
  artifacts: NumericCounterMap;
};

export type FuzzSummaryReport = {
  schema: typeof FUZZ_SUMMARY_REPORT_SCHEMA;
  suite: string;
  profile: string;
  seed: string | null;
  summary: FuzzSummaryCounterGroups;
};

function numericMap(value: unknown): NumericCounterMap {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return {};
  const out: NumericCounterMap = {};
  for (const [key, raw] of Object.entries(value)) {
    if (typeof raw === "number" && Number.isFinite(raw)) out[key] = raw;
  }
  return out;
}

function textField(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function seedField(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

export function normalizeFuzzSummaryReport(report: unknown): FuzzSummaryReport {
  const object = report !== null && typeof report === "object" && !Array.isArray(report)
    ? report as Record<string, unknown>
    : {};
  const rawSummary = object.summary !== null && typeof object.summary === "object" && !Array.isArray(object.summary)
    ? object.summary as Record<string, unknown>
    : {};
  return {
    schema: FUZZ_SUMMARY_REPORT_SCHEMA,
    suite: textField(object.suite),
    profile: textField(object.profile),
    seed: seedField(object.seed),
    summary: {
      features: numericMap(rawSummary.features),
      opcodes: numericMap(rawSummary.opcodes),
      strategies: numericMap(rawSummary.strategies),
      statuses: numericMap(rawSummary.statuses),
      failures: numericMap(rawSummary.failures),
      timings: numericMap(rawSummary.timings),
      artifacts: numericMap(rawSummary.artifacts),
    },
  };
}

export function formatFuzzSummaryReport(report: unknown): string {
  return JSON.stringify(normalizeFuzzSummaryReport(report), null, 2) + "\n";
}

export function parseFuzzSummaryReport(text: string): FuzzSummaryReport {
  return normalizeFuzzSummaryReport(JSON.parse(text));
}

export function ensureCoverageDeltaCounters(report: unknown): CoverageDeltaReport {
  const object = report !== null && typeof report === "object" && !Array.isArray(report)
    ? report as Record<string, unknown>
    : {};
  const rawSummary = object.summary !== null && typeof object.summary === "object" && !Array.isArray(object.summary)
    ? object.summary as Record<string, unknown>
    : {};
  return {
    ...object,
    summary: {
      ...rawSummary,
      feature_counters: numericMap(rawSummary.feature_counters),
      opcode_counters: numericMap(rawSummary.opcode_counters),
      strategy_counters: numericMap(rawSummary.strategy_counters),
      artifact_counts: numericMap(rawSummary.artifact_counts),
      failure_classes: numericMap(rawSummary.failure_classes),
      pass_statuses: numericMap(rawSummary.pass_statuses),
      timings: numericMap(rawSummary.timings),
    },
  };
}
