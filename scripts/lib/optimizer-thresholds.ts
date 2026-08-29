import crypto from "node:crypto";

export type OptimizerThresholdUnit = "instructions" | "functions" | "locals" | "bytes" | "predecessors" | "uses" | "types" | "iterations";
export type OptimizerThresholdDescriptor = { schema: "starshine.optimizer-threshold.v1"; id: string; ownerPass: string; decisionName: string; value: number; unit: OptimizerThresholdUnit; sourceOwner: string; generatorRecipe: string; neighborhoods: number[]; correctnessConcern: boolean; notes: string };

export type MoonOptimizerThresholdReport = {
  schema: "starshine.optimizer-threshold-registry.v1";
  source: string;
  thresholds: Array<{
    schema: "starshine.optimizer-threshold.v1";
    name: string;
    value: number;
    source: string;
  }>;
};

const MOON_THRESHOLD_METADATA: Record<string, Omit<OptimizerThresholdDescriptor, "schema" | "value" | "sourceOwner">> = {
  "always-inline-max-function-size": { id: "inlining.always-inline-max-size", ownerPass: "inlining", decisionName: "always_inline_max_size", unit: "instructions", generatorRecipe: "function-size", neighborhoods: [-1, 0, 1], correctnessConcern: true, notes: "boundary changes unconditional inlining selection" },
  "one-caller-inline-max-function-size": { id: "inlining.one-caller-inline-max-size", ownerPass: "inlining", decisionName: "one_caller_inline_max_size", unit: "instructions", generatorRecipe: "function-size", neighborhoods: [-1, 0, 1], correctnessConcern: true, notes: "-1 admits all one-caller function sizes" },
  "flexible-inline-max-function-size": { id: "inlining.flexible-inline-max-size", ownerPass: "inlining", decisionName: "flexible_inline_max_size", unit: "instructions", generatorRecipe: "function-size", neighborhoods: [-1, 0, 1], correctnessConcern: true, notes: "boundary changes lightweight-function inlining selection" },
  "inline-max-combined-binary-size": { id: "inlining.max-combined-binary-size", ownerPass: "inlining", decisionName: "max_combined_binary_size", unit: "bytes", generatorRecipe: "combined-binary-size", neighborhoods: [-1, 0, 1], correctnessConcern: false, notes: "aggregate caller/callee size guard" },
  "partial-inlining-ifs": { id: "inlining.partial-inlining-ifs", ownerPass: "inlining", decisionName: "partial_inlining_ifs", unit: "instructions", generatorRecipe: "partial-inlining-guards", neighborhoods: [-1, 0, 1], correctnessConcern: true, notes: "boundary changes accepted leading guard count" },
  "monomorphize-min-benefit": { id: "monomorphize.min-benefit", ownerPass: "monomorphize", decisionName: "monomorphize_min_benefit", unit: "uses", generatorRecipe: "monomorphize-benefit", neighborhoods: [-1, 0, 1], correctnessConcern: true, notes: "boundary changes specialization selection" },
  "low-memory-bound": { id: "memory.low-memory-bound", ownerPass: "memory-packing", decisionName: "low_memory_bound", unit: "bytes", generatorRecipe: "low-memory-bound", neighborhoods: [-1, 0, 1], correctnessConcern: true, notes: "boundary changes low-memory address classification" },
};

export function optimizerThresholdsFromMoonReport(report: MoonOptimizerThresholdReport): OptimizerThresholdDescriptor[] {
  if (report.schema !== "starshine.optimizer-threshold-registry.v1") throw new Error(`unsupported optimizer threshold report schema ${report.schema}`);
  return report.thresholds.map((entry) => {
    if (entry.schema !== "starshine.optimizer-threshold.v1") throw new Error(`unsupported optimizer threshold schema ${entry.schema}`);
    const metadata = MOON_THRESHOLD_METADATA[entry.name];
    if (metadata == null) throw new Error(`unknown Moon optimizer threshold ${entry.name}`);
    if (!Number.isSafeInteger(entry.value)) throw new Error(`invalid Moon optimizer threshold value for ${entry.name}`);
    return { schema: "starshine.optimizer-threshold.v1", ...metadata, value: entry.value, sourceOwner: entry.source };
  });
}

export function thresholdRelationGroupId(id: string, value: number, seed: string): string {
  return `threshold:${crypto.createHash("sha256").update(JSON.stringify({ id, value, seed })).digest("hex")}`;
}

export function buildThresholdCliffGroup(descriptor: OptimizerThresholdDescriptor, seed: string) {
  const values = descriptor.neighborhoods.map((delta) => descriptor.value + delta).filter((value) => value >= 0);
  return { schema: "starshine.optimizer-threshold-cliff-group.v1" as const, descriptor, relationGroupId: thresholdRelationGroupId(descriptor.id, descriptor.value, seed), values, cases: values.map((value) => ({ thresholdId: descriptor.id, value, relationPosition: value - descriptor.value })) };
}

export function builtinOptimizerThresholds(defaults: { alwaysInlineMaxSize: number; oneCallerInlineMaxSize: number; flexibleInlineMaxSize: number; maxCombinedBinarySize: number; partialInliningIfs: number }): OptimizerThresholdDescriptor[] {
  const descriptor = (id: string, decisionName: string, value: number, unit: OptimizerThresholdUnit, correctnessConcern: boolean): OptimizerThresholdDescriptor => ({ schema: "starshine.optimizer-threshold.v1", id, ownerPass: "inlining", decisionName, value, unit, sourceOwner: "InliningOptions.default", generatorRecipe: unit === "bytes" ? "combined-binary-size" : "function-size", neighborhoods: [-1, 0, 1], correctnessConcern, notes: correctnessConcern ? "boundary can change selected transform" : "heuristic selection boundary" });
  return [
    descriptor("inlining.always-inline-max-size", "always_inline_max_size", defaults.alwaysInlineMaxSize, "instructions", true),
    descriptor("inlining.one-caller-inline-max-size", "one_caller_inline_max_size", defaults.oneCallerInlineMaxSize, "instructions", true),
    descriptor("inlining.flexible-inline-max-size", "flexible_inline_max_size", defaults.flexibleInlineMaxSize, "instructions", true),
    descriptor("inlining.max-combined-binary-size", "max_combined_binary_size", defaults.maxCombinedBinarySize, "bytes", false),
    descriptor("inlining.partial-inlining-ifs", "partial_inlining_ifs", defaults.partialInliningIfs, "instructions", true),
  ];
}
