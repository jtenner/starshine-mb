import { describe, expect, test } from "bun:test";
import crypto from "node:crypto";

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
  raw?: (module: string) => string | null;
}): PropertyHarness<string> {
  return {
    apply: async (module, passes) => options.apply(module, passes),
    validate: async (module) => !options.invalid?.has(module),
    semanticCompare: async (original, candidate) => options.semanticClass?.(original, candidate) ?? (original.split("|")[0] === candidate.split("|")[0] ? "equal" : "different"),
    structuralHash: async (module) => options.structural?.(module) ?? module,
    rawHash: async (module) => options.raw === undefined ? module : options.raw(module),
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

  test("confirms an input projection alias with a second optimizer application", async () => {
    const result = await runConvergenceProperty("M0", ["p"], harness({
      apply: (module) => module === "M0" ? "M1" : module === "M1" ? "M2" : "M2",
      semanticClass: () => "equal",
      structural: (module) => module === "M0" || module === "M1" ? "projection-a" : "projection-b",
    }), { maxGenerations: 4 });
    expect(result.status).toBe("pass");
    expect(result.classification).toBe("fixed-point");
    expect(result.fixedPointGeneration).toBe(3);
    expect(result.generations.map((entry) => entry.hash)).toEqual([
      "projection-a",
      "projection-a",
      "projection-b",
      "projection-b",
    ]);
  });

  test("does not treat three distinct raw aliases as a canonical fixed point", async () => {
    const result = await runConvergenceProperty("M0", ["p"], harness({
      apply: (module) =>
        module === "M0" ? "M1" : module === "M1" ? "M2" : module === "M2" ? "M3" : "M3",
      semanticClass: () => "equal",
      structural: (module) => module === "M3" ? "projection-b" : "projection-a",
    }), { maxGenerations: 5 });
    expect(result.status).toBe("pass");
    expect(result.classification).toBe("fixed-point");
    expect(result.fixedPointGeneration).toBe(4);
    expect(result.generations.map((entry) => entry.hash)).toEqual([
      "projection-a",
      "projection-a",
      "projection-a",
      "projection-b",
      "projection-b",
    ]);
  });

  test("stays bounded nonconvergence when exact raw identity is unavailable", async () => {
    const result = await runConvergenceProperty("M", ["p"], harness({
      apply: () => "M",
      semanticClass: () => "equal",
      structural: () => "projection",
      raw: () => null,
    }), { maxGenerations: 2 });
    expect(result.status).toBe("fail");
    expect(result.classification).toBe("nonconvergence");
    expect(result.fixedPointGeneration).toBeNull();
    expect(result.generations.map((entry) => entry.rawHash)).toEqual([null, null, null]);
  });

  test("detects a two-state cycle and records the full cycle", async () => {
    const result = await runConvergenceProperty("A", ["p"], harness({
      apply: (module) => module === "A" ? "B" : "A",
      semanticClass: () => "equal",
    }), { maxGenerations: 8 });
    expect(result.status).toBe("fail");
    expect(result.classification).toBe("structural-cycle");
    expect(result.cycle?.hashes).toEqual(["A", "B", "A"]);
    expect(result.cycle?.rawHashes).toEqual(["A", "B", "A"]);
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

  test("does not let a blocked order comparison hide a definite pass failure", async () => {
    const result = await runCommutatorProperty("M", "p", "q", harness({
      apply: (module, passes) => module === "M" && passes[0] === "p"
        ? "BROKEN"
        : `${module}|${passes[0]}`,
      semanticClass: (original, candidate) => original !== "M"
        ? "blocked"
        : candidate.startsWith("BROKEN") ? "different" : "equal",
    }));
    expect(result.status).toBe("fail");
    expect(result.classification).toBe("left-pass-fails-alone");
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


describe("paired optimization size diagnostics", () => {
  test("records size skew only after semantic checks pass", async () => {
    const result = await runMetamorphicEquivalenceProperty("AAAA", "BBBBBB", ["p"], harness({
      apply: (module) => module === "AAAA" ? "A" : "BBB",
      semanticClass: () => "equal",
    }), { relationId: "local-transfer", compareRelation: async () => "equal" });
    expect(result.status).toBe("pass");
    expect(result.classification).toBe("metamorphic-equivalence");
    expect(result.structuralDiagnostics).toEqual({
      kind: "paired-encoded-size",
      inputBytes: { base: 4, twin: 6 },
      optimizedBytes: { base: 1, twin: 3 },
      optimizedDeltaBytes: 2,
      classification: "size-skew-candidate",
      smallerVariant: "base",
      optimizedHashes: { base: "A", twin: "BBB" },
      evidence: "observed-semantic-equality",
    });
  });

  test("does not report canonical-equal encoding skew as an optimization candidate", async () => {
    const result = await runMetamorphicEquivalenceProperty("A", "A|metadata", ["p"], harness({
      apply: (module) => module,
      semanticClass: () => "equal",
      structural: () => "same-canonical-module",
    }), { relationId: "custom-section", compareRelation: async () => "equal" });
    expect(result.structuralDiagnostics).toMatchObject({
      classification: "canonical-equal-encoding-difference", smallerVariant: null,
    });
  });

  test("keeps raw fallback hashes inconclusive when canonicalization failed", async () => {
    const result = await runMetamorphicEquivalenceProperty("A", "BBB", ["p"], harness({
      apply: (module) => module, semanticClass: () => "equal",
      structural: (module) => `raw-sha256:${module}`,
    }), { relationId: "unsupported-canonicalization", compareRelation: async () => "equal" });
    expect(result.status).toBe("pass");
    expect(result.structuralDiagnostics).toMatchObject({ classification: "structural-comparison-unavailable", smallerVariant: null });
  });

  test("does not compute size evidence for a blocked semantic relation", async () => {
    const h = harness({ apply: (module) => module, semanticClass: () => "blocked" });
    h.encodedSize = async () => { throw new Error("must not measure blocked pair"); };
    const result = await runMetamorphicEquivalenceProperty("A", "B", ["p"], h,
      { relationId: "blocked", compareRelation: async () => "blocked" });
    expect(result.status).toBe("blocked");
    expect(result.structuralDiagnostics).toBeNull();
  });

  for (const invalidVariant of ["A", "B"]) {
    test(`rejects invalid optimized ${invalidVariant} before runtime comparison`, async () => {
      const h = harness({ apply: (module) => `${module}|out`, invalid: new Set([`${invalidVariant}|out`]) });
      h.semanticCompare = async () => { throw new Error("invalid output must not reach runtime comparison"); };
      const result = await runMetamorphicEquivalenceProperty("A", "B", ["p"], h,
        { relationId: "valid-inputs", compareRelation: async () => "equal" });
      expect(result.status).toBe("fail");
      expect(result.classification).toBe(invalidVariant === "A" ? "base-output-validation-failure" : "twin-output-validation-failure");
      expect(result.firstFailure?.stage).toBe("validation");
      expect(result.structuralDiagnostics).toBeNull();
    });
  }

  test("detects the baseline typed-if propagation gap with independent Wasm execution", async () => {
    // Exact baseline a61c3e4 --precompute-propagate output. The local-transfer
    // form folds the add; the typed-if form retains it. This preserves the
    // opportunity as a fixture; size skew alone does not prove a missed rule.
    // Both arms write the exported global before returning 8.
    const base = Uint8Array.from(Buffer.from("0061736d0100000001060160017f017f030201000606017f0141000b070b02016703000372756e00000a21011f01017f2000044041012400410721010541022400410721010b200141016a0b", "hex"));
    const twin = Uint8Array.from(Buffer.from("0061736d0100000001060160017f017f030201000606017f0141000b070b02016703000372756e00000a1f011d01017f2000047f410124004107054102240041070b2101200141016a0b", "hex"));
    const optimizedBase = Uint8Array.from(Buffer.from("0061736d0100000001060160017f017f030201000606017f0141000b070b02016703000372756e00000a1e011c01017f2000044041012400410721010541022400410721010b41080b", "hex"));
    const optimizedTwin = Uint8Array.from(Buffer.from("0061736d0100000001060160017f017f030201000606017f0141000b070b02016703000372756e00000a1f011d01017f2000047f410124004107054102240041070b2101200141016a0b", "hex"));
    const observe = (bytes: Uint8Array) => {
      const instance = new WebAssembly.Instance(new WebAssembly.Module(bytes));
      const run = instance.exports.run as (arg: number) => number;
      const g = instance.exports.g as WebAssembly.Global;
      return [-2147483648, -1, 0, 1, 2, 2147483647].map((arg) => [run(arg), g.value]);
    };
    const compare = async (left: Uint8Array, right: Uint8Array) =>
      JSON.stringify(observe(left)) === JSON.stringify(observe(right)) ? "equal" as const : "different" as const;
    const h: PropertyHarness<Uint8Array> = {
      apply: async (module) => module === base ? optimizedBase : optimizedTwin,
      validate: async (module) => WebAssembly.validate(module),
      semanticCompare: compare,
      structuralHash: async (module) => crypto.createHash("sha256").update(module).digest("hex"),
      rawHash: async (module) => crypto.createHash("sha256").update(module).digest("hex"),
      encodedSize: async (module) => module.byteLength,
      persist: async (_name, module) => Buffer.from(module).toString("hex"),
    };
    expect(observe(base)).toEqual([[8, 1], [8, 1], [8, 2], [8, 1], [8, 1], [8, 1]]);
    const result = await runMetamorphicEquivalenceProperty(base, twin, ["precompute-propagate"], h,
      { relationId: "equal-arm-local-versus-typed-if", compareRelation: compare });
    expect(result.status).toBe("pass");
    expect(result.structuralDiagnostics).toMatchObject({
      inputBytes: { base: 76, twin: 74 }, optimizedBytes: { base: 73, twin: 74 },
      optimizedDeltaBytes: 1, classification: "size-skew-candidate", smallerVariant: "base",
    });
  });
});
