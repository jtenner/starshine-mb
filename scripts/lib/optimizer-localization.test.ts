import { describe, expect, test } from "bun:test";

import { localizeFirstSemanticDivergence } from "./optimizer-localization";

function runner(options: {
  invalidPrefixes?: Set<number>;
  divergentPrefixes?: Set<number>;
  standalone?: "equal" | "different" | "blocked";
  baseline?: "equal" | "different" | "blocked";
  indivisible?: Set<number>;
}) {
  return {
    runPrefix: async (length: number) => `prefix-${length}`,
    validate: async (module: string) => !options.invalidPrefixes?.has(Number(module.split("-")[1])),
    semanticCompare: async (_original: string, module: string) => {
      const length = Number(module.split("-")[1]);
      if (length === 0 && options.baseline) return options.baseline;
      return options.divergentPrefixes?.has(length) ? "different" as const : "equal" as const;
    },
    hash: async (module: string) => `hash:${module}`,
    size: async (module: string) => module.length,
    runStandalone: async () => "standalone",
    semanticCompareStandalone: async () => options.standalone ?? "equal" as const,
    persist: async (name: string, module: string) => ({ name, module }),
    isIndivisibleComposite: (index: number) => options.indivisible?.has(index) ?? false,
  };
}

describe("first-divergent pass-prefix localization", () => {
  test("checks every prefix, finds boundary three, and records recovery at five", async () => {
    const report = await localizeFirstSemanticDivergence("input", ["p1", "p2", "p3", "p4", "p5"], runner({
      divergentPrefixes: new Set([3, 4]),
      standalone: "different",
    }));
    expect(report.classification).toBe("first-divergent-top-level-pass-boundary");
    expect(report.passSequenceSource).toBe("requested-flags");
    expect(report.firstDivergentBoundary).toEqual({ index: 3, pass: "p3" });
    expect(report.laterRecoveries).toEqual([5]);
    expect(report.prefixes.map((entry) => entry.prefixLength)).toEqual([0, 1, 2, 3, 4, 5]);
    expect(report.standaloneReproduction).toBe("reproduced");
  });

  test("preserves repeated slots from a Moon-expanded sequence", async () => {
    const report = await localizeFirstSemanticDivergence(
      "input",
      ["precompute", "vacuum", "vacuum"],
      runner({ divergentPrefixes: new Set([3]), standalone: "different" }),
      "moon-expanded-queue",
    );
    expect(report.passSequenceSource).toBe("moon-expanded-queue");
    expect(report.passSequence).toEqual(["precompute", "vacuum", "vacuum"]);
    expect(report.firstDivergentBoundary).toEqual({ index: 3, pass: "vacuum" });
  });

  test("classifies decode/encode baseline divergence", async () => {
    const report = await localizeFirstSemanticDivergence("input", ["p1"], runner({ baseline: "different" }));
    expect(report.classification).toBe("decode-encode-baseline-divergence");
    expect(report.firstDivergentBoundary).toBeNull();
  });

  test("records standalone context dependence", async () => {
    const report = await localizeFirstSemanticDivergence("input", ["p1", "p2"], runner({
      divergentPrefixes: new Set([2]),
      standalone: "equal",
    }));
    expect(report.standaloneReproduction).toBe("context-dependent");
  });

  test("reports invalid predecessor and indivisible composite boundaries", async () => {
    const invalid = await localizeFirstSemanticDivergence("input", ["p1", "p2"], runner({ invalidPrefixes: new Set([1]) }));
    expect(invalid.classification).toBe("candidate-invalid-before-boundary");

    const composite = await localizeFirstSemanticDivergence("input", ["p1", "composite"], runner({
      divergentPrefixes: new Set([2]),
      indivisible: new Set([2]),
    }));
    expect(composite.classification).toBe("internal-composite-boundary-not-divisible");
  });
});
