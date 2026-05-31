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

function numericMap(value: unknown): NumericCounterMap {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return {};
  const out: NumericCounterMap = {};
  for (const [key, raw] of Object.entries(value)) {
    if (typeof raw === "number" && Number.isFinite(raw)) out[key] = raw;
  }
  return out;
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
