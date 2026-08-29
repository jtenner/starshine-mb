import { describe, expect, test } from "bun:test";
import { buildThresholdCliffGroup, optimizerThresholdsFromMoonReport, thresholdRelationGroupId, type OptimizerThresholdDescriptor } from "./optimizer-thresholds";

const descriptor: OptimizerThresholdDescriptor = { schema: "starshine.optimizer-threshold.v1", id: "inlining.always-inline-max-size", ownerPass: "inlining", decisionName: "always_inline_max_size", value: 2, unit: "instructions", sourceOwner: "InliningOptions.default", generatorRecipe: "function-size", neighborhoods: [-1, 0, 1], correctnessConcern: true, notes: "" };

describe("optimizer threshold registry", () => {
  test("creates deterministic N-1/N/N+1 groups", () => {
    const group = buildThresholdCliffGroup(descriptor, "0x5eed");
    expect(group.values).toEqual([1, 2, 3]);
    expect(group.relationGroupId).toBe(thresholdRelationGroupId(descriptor.id, 2, "0x5eed"));
  });

  test("converts Moon-owned threshold output without TypeScript defaults", () => {
    const descriptors = optimizerThresholdsFromMoonReport({
      schema: "starshine.optimizer-threshold-registry.v1",
      source: "moonbit-resolved-options",
      thresholds: [
        { schema: "starshine.optimizer-threshold.v1", name: "always-inline-max-function-size", value: 3, source: "moon" },
        { schema: "starshine.optimizer-threshold.v1", name: "monomorphize-min-benefit", value: 7, source: "moon" },
        { schema: "starshine.optimizer-threshold.v1", name: "low-memory-bound", value: 2048, source: "moon" },
      ],
    });

    expect(descriptors.map((entry) => [entry.id, entry.value, entry.ownerPass])).toEqual([
      ["inlining.always-inline-max-size", 3, "inlining"],
      ["monomorphize.min-benefit", 7, "monomorphize"],
      ["memory.low-memory-bound", 2048, "memory-packing"],
    ]);
  });

  test("reads the supplied source-of-truth value instead of copying it", () => {
    const changed = { ...descriptor, value: 7 };
    expect(buildThresholdCliffGroup(changed, "s").values).toEqual([6, 7, 8]);
  });
});
