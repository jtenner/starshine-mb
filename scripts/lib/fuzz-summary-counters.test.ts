import { describe, expect, test } from "bun:test";

import { ensureCoverageDeltaCounters } from "./fuzz-summary-counters";

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
});
