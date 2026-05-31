import { describe, expect, test } from "bun:test";

import { classifyFuzzCaseTimeout, defaultFuzzCaseTimeoutMs, withFuzzCaseTimeout } from "./fuzz-timeouts";

describe("fuzz timeouts", () => {
  test("classifies ordinary fuzz cases against per-case budget", () => {
    expect(classifyFuzzCaseTimeout({ elapsedMs: 10, timeoutMs: 20, runner: "ordinary" })).toEqual({
      runner: "ordinary",
      timedOut: false,
      classification: "completed",
      elapsedMs: 10,
      timeoutMs: 20,
    });
    expect(classifyFuzzCaseTimeout({ elapsedMs: 25, timeoutMs: 20, runner: "ordinary" }).classification).toBe("timeout");
  });

  test("classifies pass-fuzz cases against per-case budget", async () => {
    expect(defaultFuzzCaseTimeoutMs("pass-fuzz")).toBeGreaterThan(defaultFuzzCaseTimeoutMs("ordinary"));
    const result = await withFuzzCaseTimeout("pass-fuzz", 20, async () => "match");

    expect(result).toMatchObject({ ok: true, value: "match", timeout: { runner: "pass-fuzz", classification: "completed" } });
  });

  test("wraps ordinary async fuzz work with timeout classification", async () => {
    const result = await withFuzzCaseTimeout("ordinary", 20, async () => "ok");

    expect(result).toMatchObject({ ok: true, value: "ok", timeout: { runner: "ordinary", classification: "completed" } });
  });
});
