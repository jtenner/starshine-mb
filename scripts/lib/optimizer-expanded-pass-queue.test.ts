import { describe, expect, test } from "bun:test";

import { loadExpandedPassQueueFromStarshine } from "./optimizer-expanded-pass-queue";

describe("Moon-owned expanded optimizer pass queue", () => {
  test("loads repeated module-aware slots in reported order", () => {
    const calls: Array<{ bin: string; args: string[] }> = [];
    const report = loadExpandedPassQueueFromStarshine(
      "input.wasm",
      "starshine-test",
      ["--optimize", "--vacuum"],
      (bin, args) => {
        calls.push({ bin, args });
        return {
          status: 0,
          stdout: JSON.stringify({
            schema: "starshine.optimizer-expanded-pass-queue.v1",
            requested: ["optimize", "vacuum"],
            optimizeLevel: 2,
            shrinkLevel: 0,
            passes: [
              { ordinal: 0, name: "precompute" },
              { ordinal: 1, name: "vacuum" },
              { ordinal: 2, name: "vacuum" },
            ],
          }),
          stderr: "",
        };
      },
      ["run", "--"],
    );

    expect(calls).toEqual([{
      bin: "starshine-test",
      args: ["run", "--", "--emit-expanded-pass-queue-json", "--optimize", "--vacuum", "input.wasm"],
    }]);
    expect(report.passSequence).toEqual(["precompute", "vacuum", "vacuum"]);
    expect(report.requested).toEqual(["optimize", "vacuum"]);
  });

  test("rejects malformed ordinals instead of silently reordering", () => {
    expect(() => loadExpandedPassQueueFromStarshine(
      "input.wasm",
      "starshine-test",
      ["--optimize"],
      () => ({
        status: 0,
        stdout: JSON.stringify({
          schema: "starshine.optimizer-expanded-pass-queue.v1",
          requested: ["optimize"],
          optimizeLevel: 2,
          shrinkLevel: 0,
          passes: [{ ordinal: 1, name: "vacuum" }],
        }),
        stderr: "",
      }),
    )).toThrow("non-contiguous ordinal");
  });
});
