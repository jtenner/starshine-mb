import { describe, expect, test } from "bun:test";

import {
  formatFuzzSummaryReport,
  parseFuzzSummaryReport,
  ensureCoverageDeltaCounters,
} from "./fuzz-summary-counters";

describe("fuzz summary counters", () => {
  test("ensures required coverage-delta counter groups exist", () => {
    const summary = ensureCoverageDeltaCounters({
      summary: {
        feature_counters: { required_gc: 1 },
      },
    });

    expect(summary.summary.feature_counters.required_gc).toBe(1);
    expect(summary.summary.opcode_counters).toEqual({});
    expect(summary.summary.strategy_counters).toEqual({});
    expect(summary.summary.artifact_counts).toEqual({});
    expect(summary.summary.failure_classes).toEqual({});
    expect(summary.summary.pass_statuses).toEqual({});
    expect(summary.summary.timings).toEqual({});
  });

  test("FUZ1048A formats and parses compact summary report schema", () => {
    const text = formatFuzzSummaryReport({
      suite: "validate-invalid-ast",
      profile: "smoke",
      seed: "0x1048a",
      summary: {
        features: { required_gc: 2, ignored: Number.NaN },
        opcodes: { required_ref_func: 1 },
        strategies: { required_invalid_ast: 3 },
        statuses: { pass: 4, fail: 0 },
        failures: { validation: 0 },
        timings: { wall_ms: 25 },
        artifacts: { repro: 1 },
      },
    });

    const report = parseFuzzSummaryReport(text);
    expect(report.schema).toBe("starshine.fuzz-summary-report.v1");
    expect(report.suite).toBe("validate-invalid-ast");
    expect(report.profile).toBe("smoke");
    expect(report.seed).toBe("0x1048a");
    expect(report.summary.features).toEqual({ required_gc: 2 });
    expect(report.summary.opcodes).toEqual({ required_ref_func: 1 });
    expect(report.summary.strategies).toEqual({ required_invalid_ast: 3 });
    expect(report.summary.statuses).toEqual({ pass: 4, fail: 0 });
    expect(report.summary.failures).toEqual({ validation: 0 });
    expect(report.summary.timings).toEqual({ wall_ms: 25 });
    expect(report.summary.artifacts).toEqual({ repro: 1 });
  });
});
