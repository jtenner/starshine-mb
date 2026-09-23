import { describe, expect, test } from "bun:test";

import {
  buildInvocationPlanV2,
  compareRuntimeObservationsV2,
  normalizeRuntimeTrap,
  classifyThreeWaySemanticComparison,
  type RuntimeInterfaceV1,
  type RuntimeObservationV2,
  type TypedRuntimeValue,
} from "./optimizer-runtime";

const i32 = (signed: number): TypedRuntimeValue => ({
  type: "i32",
  signed,
  bits: `0x${(signed >>> 0).toString(16).padStart(8, "0")}`,
});

function observation(overrides: Partial<RuntimeObservationV2> = {}): RuntimeObservationV2 {
  return {
    schema: "starshine.optimizer-runtime-observation.v2",
    runtime: { identity: "node-test", timeoutMs: 1000 },
    mode: "stateful",
    compilation: { status: "succeeded" },
    instantiation: { status: "succeeded" },
    completeness: "complete",
    blockedReasons: [],
    steps: [],
    resources: { globals: [], memories: [], tables: [] },
    ...overrides,
  };
}

function returned(value: TypedRuntimeValue): RuntimeObservationV2 {
  return observation({
    steps: [{
      stepIndex: 0,
      exportName: "run",
      phase: "exported-call",
      arguments: [],
      importTraceStart: 0,
      importTraceEnd: 0,
      stateBefore: { globals: [], memories: [], tables: [] },
      outcome: { kind: "returned", values: [value] },
      stateAfter: { globals: [], memories: [], tables: [] },
      stateDelta: [],
      firstChangedResource: null,
    }],
  });
}

describe("optimizer runtime observation v2", () => {
  test("detects a wrong scalar return", () => {
    const comparison = compareRuntimeObservationsV2(returned(i32(1)), returned(i32(2)), "strict");
    expect(comparison.classification).toBe("semantic-mismatch");
    expect(comparison.firstDifferencePath).toBe("steps[0].outcome.values[0]");
  });

  test("keeps definite result and trap mismatches visible when unrelated surfaces are blocked", () => {
    const original = returned(i32(1));
    original.completeness = "incomplete";
    original.blockedReasons = ["memory-over-cap: memory[0]"];
    const wrongResult = returned(i32(2));
    wrongResult.completeness = "incomplete";
    wrongResult.blockedReasons = ["memory-over-cap: memory[0]"];

    const resultComparison = compareRuntimeObservationsV2(original, wrongResult, "strict");
    expect(resultComparison.classification).toBe("semantic-mismatch");
    expect(resultComparison.completeness).toBe("incomplete");
    expect(resultComparison.firstDifferencePath).toBe("steps[0].outcome.values[0]");
    expect(resultComparison.diagnostics).toContain("memory-over-cap: memory[0]");
    expect(compareRuntimeObservationsV2(original, structuredClone(original), "strict").classification).toBe("blocked");

    const relaxedResult = returned(i32(2));
    relaxedResult.completeness = "incomplete";
    relaxedResult.blockedReasons = ["relaxed-simd-allowed-result-oracle-unavailable"];
    expect(compareRuntimeObservationsV2(original, relaxedResult, "strict").classification).toBe("blocked");

    const trapped = returned(i32(1));
    trapped.completeness = "incomplete";
    trapped.blockedReasons = ["blocked-export:unobserved:unsupported direct JavaScript signature type: contref"];
    trapped.steps[0].outcome = {
      kind: "trapped",
      trapClass: "explicit-unreachable",
      rawText: "unreachable",
    };
    const trapComparison = compareRuntimeObservationsV2(original, trapped, "strict");
    expect(trapComparison.classification).toBe("semantic-mismatch");
    expect(trapComparison.firstDifferenceCategory).toBe("outcome-kind");
    expect(trapComparison.originalOutcomeKind).toBe("returned");
    expect(trapComparison.candidateOutcomeKind).toBe("trapped");

    const differentTrap = structuredClone(trapped);
    if (differentTrap.steps[0].outcome.kind === "trapped") {
      differentTrap.steps[0].outcome.trapClass = "integer-divide-by-zero";
    }
    const trapClassComparison = compareRuntimeObservationsV2(trapped, differentTrap, "strict");
    expect(trapClassComparison.classification).toBe("semantic-mismatch");
    expect(trapClassComparison.firstDifferenceCategory).toBe("trap-class");
  });

  test("preserves signed zero and canonical NaN policy", () => {
    const plusZero = returned({ type: "f64", bits: "0x0000000000000000", class: "zero", sign: "+" });
    const minusZero = returned({ type: "f64", bits: "0x8000000000000000", class: "zero", sign: "-" });
    expect(compareRuntimeObservationsV2(plusZero, minusZero, "strict").classification).toBe("semantic-mismatch");

    const nanA = returned({ type: "f32", bits: "0x7fc00001", class: "nan", sign: "+", quiet: true, payload: "0x400001" });
    const nanB = returned({ type: "f32", bits: "0x7fc01234", class: "nan", sign: "+", quiet: true, payload: "0x401234" });
    expect(compareRuntimeObservationsV2(nanA, nanB, "strict").classification).toBe("semantic-mismatch");
    expect(compareRuntimeObservationsV2(nanA, nanB, "canonical-nan").classification).toBe("semantic-match");
  });

  test("compares the exact event prefix and committed state at a trap", () => {
    const base = observation({
      steps: [{
        stepIndex: 0,
        exportName: "run",
        phase: "exported-call",
        arguments: [],
        importTraceStart: 0,
        importTraceEnd: 1,
        stateBefore: { globals: [], memories: [], tables: [] },
        outcome: { kind: "trapped", trapClass: "integer-divide-by-zero", rawText: "divide by zero" },
        stateAfter: { globals: [], memories: [], tables: [] },
        stateDelta: [],
        firstChangedResource: null,
      }],
      importTrace: [{ module: "starshine_observe", field: "event", ordinal: 0, phase: "exported-call", stepIndex: 0, arguments: [i32(1), { type: "i64", signed: "7", bits: "0x0000000000000007" }], results: [] }],
    });
    const changed = structuredClone(base);
    changed.importTrace![0].arguments[1] = { type: "i64", signed: "8", bits: "0x0000000000000008" };
    const comparison = compareRuntimeObservationsV2(base, changed, "trap-aware");
    expect(comparison.classification).toBe("semantic-mismatch");
    expect(comparison.commonImportEventPrefixLength).toBe(0);
    expect(comparison.originalOutcomeKind).toBe("trapped");
    expect(comparison.candidateOutcomeKind).toBe("trapped");
  });

  test("detects full-memory changes beyond 64 KiB and blocks incomplete memory", () => {
    const memory = (hash: string, complete = true): RuntimeObservationV2 => observation({
      completeness: complete ? "complete" : "incomplete",
      blockedReasons: complete ? [] : ["memory-over-cap: memory[0]"],
      resources: {
        globals: [],
        tables: [],
        memories: [{ index: 0, names: ["memory"], byteLength: 131072, complete, hash, chunkHashes: ["a", hash], diagnosticSamples: [] }],
      },
    });
    const mismatch = compareRuntimeObservationsV2(memory("full-a"), memory("full-b"), "strict");
    expect(mismatch.classification).toBe("semantic-mismatch");
    expect(mismatch.resourceKind).toBe("memory");
    expect(compareRuntimeObservationsV2(memory("same", false), memory("same", false), "strict").classification).toBe("blocked");
  });

  test("compares table alias relations rather than cross-instance objects", () => {
    const table = (relations: string[]): RuntimeObservationV2 => observation({
      resources: {
        globals: [], memories: [],
        tables: [{ index: 0, names: ["table"], length: relations.length, complete: true, entries: relations.map((relation, index) => ({ index, relation })) }],
      },
    });
    expect(compareRuntimeObservationsV2(table(["class:0", "null", "class:0"]), table(["class:0", "null", "class:1"]), "strict").classification).toBe("semantic-mismatch");
  });

  test("normalizes stable trap classes", () => {
    expect(normalizeRuntimeTrap("integer divide by zero").class).toBe("integer-divide-by-zero");
    expect(normalizeRuntimeTrap("remainder by zero").class).toBe("integer-divide-by-zero");
    expect(normalizeRuntimeTrap("memory access out of bounds").class).toBe("out-of-bounds-memory-access");
    expect(normalizeRuntimeTrap("call stack exhausted").class).toBe("stack-exhaustion");
  });
});

describe("invocation plan v2", () => {
  const runtimeInterface: RuntimeInterfaceV1 = {
    schema: "starshine.optimizer-runtime-interface.v1",
    moduleHash: "sha256:test",
    interfaceHash: "sha256:iface",
    features: [],
    hasStart: false,
    imports: { functions: [], globals: [], memories: [], tables: [] },
    exports: [{ name: "run", kind: "function", index: 0, signature: { params: ["i32", "f64"], results: ["i32"] }, support: "directly-constructible" }],
  };

  test("is deterministic and bounded without a Cartesian product", () => {
    const first = buildInvocationPlanV2(runtimeInterface, { seed: 0x5eedn });
    const second = buildInvocationPlanV2(runtimeInterface, { seed: 0x5eedn });
    expect(first).toEqual(second);
    expect(first.schema).toBe("starshine.optimizer-invocation-plan.v2");
    expect(first.hash).toMatch(/^sha256:/);
    expect(first.steps.length).toBeGreaterThan(2);
    expect(first.steps.length).toBeLessThan(30);
    expect(first.steps[0].arguments).toEqual([i32(0), { type: "f64", bits: "0x0000000000000000", class: "zero", sign: "+" }]);
  });

  test("uses the recorded seed to diversify non-boundary scalar arguments", () => {
    const first = buildInvocationPlanV2(runtimeInterface, { seed: 0x5eedn });
    const again = buildInvocationPlanV2(runtimeInterface, { seed: 0x5eedn });
    const different = buildInvocationPlanV2(runtimeInterface, { seed: 0x5eeen });
    const seeded = (plan: ReturnType<typeof buildInvocationPlanV2>) =>
      plan.steps.filter((step) => (step.source as string) === "seeded").map((step) => step.arguments);
    expect(seeded(first)).toEqual(seeded(again));
    expect(seeded(first).length).toBe(2);
    expect(seeded(first)).not.toEqual(seeded(different));
    const i32Boundaries = new Set([0, 1, -1, -2147483648, 2147483647]);
    expect(seeded(first).some((args) => args[0].type === "i32" && !i32Boundaries.has(args[0].signed))).toBe(true);
  });

  test("plans nullable GC references with retained null fixtures", () => {
    const iface = structuredClone(runtimeInterface);
    iface.exports[0].signature = { params: ["anyref", "structref", "arrayref"], results: ["i32"] };
    iface.exports[0].support = "retained-fixture";
    const plan = buildInvocationPlanV2(iface, { seed: 1n });
    expect(plan.blockedExports).toEqual([]);
    expect(plan.steps[0].arguments).toEqual([
      { type: "reference", relation: "null", wasmType: "anyref" },
      { type: "reference", relation: "null", wasmType: "structref" },
      { type: "reference", relation: "null", wasmType: "arrayref" },
    ]);

    iface.exports[0].signature = { params: ["exnref"], results: [] };
    iface.exports[0].support = "unsupported";
    const blocked = buildInvocationPlanV2(iface, { seed: 1n });
    expect(blocked.blockedExports[0].reason).toBe(
      "unsupported JavaScript reference crossing: exnref",
    );

    iface.exports[0].signature = { params: ["contref"], results: [] };
    const blockedContinuation = buildInvocationPlanV2(iface, { seed: 1n });
    expect(blockedContinuation.blockedExports[0].reason).toBe(
      "unsupported JavaScript reference crossing: contref",
    );
  });

  test("plans non-null aggregate GC arguments from matching retained exports", () => {
    const iface = structuredClone(runtimeInterface);
    iface.exports = [
      {
        name: "make_struct",
        kind: "function",
        index: 0,
        signature: { params: [], results: ["(ref type[0])"] },
        support: "retained-fixture",
      },
      {
        name: "read_struct",
        kind: "function",
        index: 1,
        signature: { params: ["(ref type[0])"], results: ["i32"] },
        support: "retained-fixture",
      },
    ];

    const plan = buildInvocationPlanV2(iface, { seed: 1n });

    expect(plan.blockedExports).toEqual([]);
    expect(plan.steps.find((step) => step.exportName === "read_struct")?.arguments)
      .toEqual([{
        type: "reference",
        relation: "fixture:export:make_struct",
        wasmType: "(ref type[0])",
      }]);
  });

  test("plans v128 calls through a lossless two-lane scalar adapter", () => {
    const iface = structuredClone(runtimeInterface);
    iface.exports[0].signature = { params: ["v128"], results: ["v128"] };
    iface.exports[0].support = "scalar-adapter";
    const plan = buildInvocationPlanV2(iface, { seed: 1n });
    expect(plan.blockedExports).toEqual([]);
    expect(plan.steps.length).toBeGreaterThan(1);
    expect(plan.steps[0].arguments[0]).toEqual({
      type: "v128",
      bits: "0x00000000000000000000000000000000",
    });
  });

  test("plans bounded non-null i31ref function arguments", () => {
    const iface = structuredClone(runtimeInterface);
    iface.exports[0].signature = { params: ["i31ref"], results: ["i31ref"] };
    iface.exports[0].support = "directly-constructible";
    const plan = buildInvocationPlanV2(iface, { seed: 1n });

    expect(plan.blockedExports).toEqual([]);
    expect(plan.steps.map((step) => step.arguments[0])).toEqual([
      { type: "reference", relation: "null", wasmType: "i31ref" },
      { type: "i31ref", signed: 0, bits: "0x00000000" },
      { type: "i31ref", signed: 1, bits: "0x00000001" },
      { type: "i31ref", signed: -1, bits: "0x7fffffff" },
      { type: "i31ref", signed: -1073741824, bits: "0x40000000" },
      { type: "i31ref", signed: 1073741823, bits: "0x3fffffff" },
    ]);
  });
});

describe("three-way semantic classification", () => {
  test("never excuses Starshine when Binaryen has the same mismatch", () => {
    const result = classifyThreeWaySemanticComparison({
      originalVsStarshine: "different",
      originalVsBinaryen: "different",
      starshineVsBinaryen: "equal",
    });
    expect(result.primary).toBe("starshine-semantic-mismatch");
    expect(result.pattern).toBe("both-optimizers-same-difference");
  });

  test("continues original-versus-Starshine when Binaryen fails", () => {
    const result = classifyThreeWaySemanticComparison({
      originalVsStarshine: "equal",
      originalVsBinaryen: "blocked",
      starshineVsBinaryen: "blocked",
      binaryenDiagnostic: "tool-failure",
    });
    expect(result.primary).toBe("semantic-match");
    expect(result.binaryenDiagnostic).toBe("tool-failure");
  });

  test("blocks semantic judgment when the original cannot execute", () => {
    const result = classifyThreeWaySemanticComparison({
      originalVsStarshine: "blocked-original",
      originalVsBinaryen: "blocked-original",
      starshineVsBinaryen: "unknown",
    });
    expect(result.primary).toBe("blocked-original-runtime");
  });
});
