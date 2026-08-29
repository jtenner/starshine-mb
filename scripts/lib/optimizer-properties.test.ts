import { describe, expect, test } from "bun:test";

import {
  runCommutatorProperty,
  runConvergenceProperty,
  runMetamorphicEquivalenceProperty,
  runSemanticIdempotenceProperty,
  type PropertyHarness,
} from "./optimizer-properties";

function harness(options: {
  apply: (module: string, passes: string[]) => string;
  invalid?: Set<string>;
  semanticClass?: (original: string, candidate: string) => "equal" | "different" | "blocked";
  structural?: (module: string) => string;
}): PropertyHarness<string> {
  return {
    apply: async (module, passes) => options.apply(module, passes),
    validate: async (module) => !options.invalid?.has(module),
    semanticCompare: async (original, candidate) => options.semanticClass?.(original, candidate) ?? (original.split("|")[0] === candidate.split("|")[0] ? "equal" : "different"),
    structuralHash: async (module) => options.structural?.(module) ?? module,
    encodedSize: async (module) => module.length,
    persist: async (_name, module) => ({ module }),
  };
}

describe("semantic idempotence", () => {
  test("passes with semantic equality despite structural drift", async () => {
    let generation = 0;
    const result = await runSemanticIdempotenceProperty("M", ["p"], harness({
      apply: (module) => `${module.split("|")[0]}|${++generation}`,
      structural: (module) => module,
    }));
    expect(result.status).toBe("pass");
    expect(result.classification).toBe("semantic-equality-with-structural-drift");
  });

  test("detects second-application divergence", async () => {
    let calls = 0;
    const result = await runSemanticIdempotenceProperty("M", ["p"], harness({
      apply: () => ++calls === 1 ? "M|first" : "BROKEN|second",
    }));
    expect(result.status).toBe("fail");
    expect(result.classification).toBe("second-application-semantic-mismatch");
  });
});

describe("convergence", () => {
  test("reaches a fixed point", async () => {
    const result = await runConvergenceProperty("M0", ["p"], harness({
      apply: (module) => module === "M0" ? "M1" : "M1",
      semanticClass: () => "equal",
    }), { maxGenerations: 8 });
    expect(result.status).toBe("pass");
    expect(result.classification).toBe("fixed-point");
    expect(result.fixedPointGeneration).toBe(2);
  });

  test("detects a two-state cycle and records the full cycle", async () => {
    const result = await runConvergenceProperty("A", ["p"], harness({
      apply: (module) => module === "A" ? "B" : "A",
      semanticClass: () => "equal",
    }), { maxGenerations: 8 });
    expect(result.status).toBe("fail");
    expect(result.classification).toBe("structural-cycle");
    expect(result.cycle?.hashes).toEqual(["A", "B", "A"]);
  });

  test("detects late validation and semantic failures", async () => {
    const lateInvalid = await runConvergenceProperty("M0", ["p"], harness({
      apply: (module) => `${module}x`,
      invalid: new Set(["M0xxx"]),
      semanticClass: () => "equal",
    }), { maxGenerations: 5 });
    expect(lateInvalid.classification).toBe("late-validation-failure");
    expect(lateInvalid.firstFailure?.generation).toBe(3);

    const lateSemantic = await runConvergenceProperty("M0", ["p"], harness({
      apply: (module) => `${module}x`,
      semanticClass: (_original, candidate) => candidate.length >= 5 ? "different" : "equal",
    }), { maxGenerations: 5 });
    expect(lateSemantic.classification).toBe("late-semantic-divergence");
  });

  test("reports bounded nonconvergence and persistent growth", async () => {
    const result = await runConvergenceProperty("M", ["p"], harness({
      apply: (module) => `${module}x`,
      semanticClass: () => "equal",
    }), { maxGenerations: 4 });
    expect(result.status).toBe("fail");
    expect(result.classification).toBe("persistent-growth");
    expect(result.generations.map((entry) => entry.size)).toEqual([1, 2, 3, 4, 5]);
  });
});

describe("commutator", () => {
  test("passes when orders differ structurally but remain semantic", async () => {
    const result = await runCommutatorProperty("M", "p", "q", harness({
      apply: (module, passes) => `M|${module}|${passes.join("+")}`,
      semanticClass: () => "equal",
    }));
    expect(result.status).toBe("pass");
    expect(result.classification).toBe("semantic-orders-structurally-different");
  });

  test("detects only-left-then-right and only-right-then-left failures", async () => {
    const leftFailure = await runCommutatorProperty("M", "p", "q", harness({
      apply: (module, passes) => module === "M|q" && passes[0] === "p" ? "BROKEN" : `${module}|${passes[0]}`,
      semanticClass: (_original, candidate) => candidate === "BROKEN" ? "different" : "equal",
    }));
    expect(leftFailure.classification).toBe("only-left-then-right-fails");

    const rightFailure = await runCommutatorProperty("M", "p", "q", harness({
      apply: (module, passes) => module === "M|p" && passes[0] === "q" ? "BROKEN" : `${module}|${passes[0]}`,
      semanticClass: (_original, candidate) => candidate === "BROKEN" ? "different" : "equal",
    }));
    expect(rightFailure.classification).toBe("only-right-then-left-fails");
  });

  test("detects a pass that fails alone", async () => {
    const result = await runCommutatorProperty("M", "p", "q", harness({
      apply: (module, passes) => module === "M" && passes[0] === "p" ? "BROKEN" : `${module}|${passes[0]}`,
      semanticClass: (_original, candidate) => candidate === "BROKEN" ? "different" : "equal",
    }));
    expect(result.classification).toBe("left-pass-fails-alone");
  });
});

describe("metamorphic equivalence", () => {
  test("does not blame the optimizer when the input relation is false", async () => {
    const result = await runMetamorphicEquivalenceProperty("A", "TWIN", ["p"], harness({
      apply: (module) => module,
      semanticClass: (left, right) => left === right ? "equal" : "different",
    }), { relationId: "r", compareRelation: async (left, right) => left === right ? "equal" : "different" });
    expect(result.status).toBe("generator-failure");
    expect(result.classification).toBe("input-relation-contract-failure");
  });

  test("separates base, twin, and optimized-pair failures", async () => {
    const baseFailure = await runMetamorphicEquivalenceProperty("A", "A'", ["p"], harness({
      apply: (module) => module === "A" ? "BROKEN" : module,
      semanticClass: (left, right) => right === "BROKEN" ? "different" : "equal",
    }), { relationId: "r", compareRelation: async () => "equal" });
    expect(baseFailure.classification).toBe("base-optimization-failure");

    const twinFailure = await runMetamorphicEquivalenceProperty("A", "A'", ["p"], harness({
      apply: (module) => module === "A'" ? "BROKEN" : module,
      semanticClass: (left, right) => right === "BROKEN" ? "different" : "equal",
    }), { relationId: "r", compareRelation: async () => "equal" });
    expect(twinFailure.classification).toBe("twin-optimization-failure");

    const pairFailure = await runMetamorphicEquivalenceProperty("A", "A'", ["p"], harness({
      apply: (module) => `${module}|optimized`,
      semanticClass: () => "equal",
    }), { relationId: "r", compareRelation: async (left, right) => left.includes("optimized") && right.includes("optimized") ? "different" : "equal" });
    expect(pairFailure.classification).toBe("optimized-twins-diverge");
  });
});
