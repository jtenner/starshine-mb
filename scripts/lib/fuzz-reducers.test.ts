import { describe, expect, test } from "bun:test";

import { reduceBinaryByByteSlicesWithReportAsync } from "./fuzz-reducers";

describe("async byte-slice reduction", () => {
  test("preserves an asynchronous predicate and ordered deletion metadata", async () => {
    const report = await reduceBinaryByByteSlicesWithReportAsync(
      new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7]),
      async (candidate) => candidate.includes(2) && candidate.includes(5) && !candidate.includes(6),
    );
    expect(Array.from(report.result)).toEqual([2, 5]);
    expect(report.predicateEvaluations).toBeGreaterThan(0);
    expect(report.steps.every((step) => step.kind === "delete-byte-slice")).toBe(true);
  });

  test("keeps the original when no asynchronous candidate matches", async () => {
    const input = new Uint8Array([1, 2, 3]);
    const report = await reduceBinaryByByteSlicesWithReportAsync(input, async () => false);
    expect(Array.from(report.result)).toEqual([1, 2, 3]);
    expect(report.steps).toEqual([]);
  });
});
