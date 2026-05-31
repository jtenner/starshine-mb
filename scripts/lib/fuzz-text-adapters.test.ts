import { describe, expect, test } from "bun:test";

import { classifyFakeTextAdapters } from "./fuzz-text-adapters";

describe("fuzz text adapters", () => {
  test("classify n-way fake text adapter results", () => {
    const results = classifyFakeTextAdapters("(module)", [
      { adapter: "local", ok: true, text: "(module)" },
      { adapter: "wabt", ok: false, diagnostic: "parse failed" },
      { adapter: "wasm-tools", ok: true, text: "(module)" },
    ]);

    expect(results.inputHash).toMatch(/^[0-9a-f]{64}$/);
    expect(results.adapters).toEqual([
      { adapter: "local", classification: "accepted", diagnostic: undefined },
      { adapter: "wabt", classification: "parse-error", diagnostic: "parse failed" },
      { adapter: "wasm-tools", classification: "accepted", diagnostic: undefined },
    ]);
    expect(results.summary).toEqual({ accepted: 2, "parse-error": 1 });
  });
});
