import crypto from "node:crypto";

export type SemanticPolicy = "strict" | "canonical-nan" | "trap-aware";
export type ObservationMode = "independent" | "stateful";
export type RuntimeSupportClassification =
  | "directly-constructible"
  | "retained-fixture"
  | "scalar-adapter"
  | "unsupported";

export type WasmRuntimeValueType =
  | "i32"
  | "i64"
  | "f32"
  | "f64"
  | "v128"
  | "funcref"
  | "externref"
  | "anyref"
  | "eqref"
  | "i31ref"
  | "structref"
  | "arrayref"
  | "exnref"
  | "contref"
  | string;

export type RuntimeFunctionSignature = {
  params: WasmRuntimeValueType[];
  results: WasmRuntimeValueType[];
};

export type RuntimeInterfaceV1 = {
  schema: "starshine.optimizer-runtime-interface.v1";
  moduleHash: string;
  interfaceHash: string;
  features: string[];
  hasStart: boolean;
  imports: {
    functions: Array<{ module: string; field: string; index: number; signature: RuntimeFunctionSignature; support: RuntimeSupportClassification }>;
    globals: Array<{ module: string; field: string; index: number; valueType: WasmRuntimeValueType; mutable: boolean; support: RuntimeSupportClassification }>;
    memories: Array<{ module: string; field: string; index: number; indexType: "i32" | "i64"; minimum: string; maximum: string | null; shared: boolean; memory64: boolean; support: RuntimeSupportClassification }>;
    tables: Array<{ module: string; field: string; index: number; elementType: WasmRuntimeValueType; nullable: boolean; minimum: string; maximum: string | null; support: RuntimeSupportClassification }>;
    tags?: Array<{ module: string; field: string; index: number; signature: RuntimeFunctionSignature; support: RuntimeSupportClassification }>;
  };
  exports: Array<{
    name: string;
    kind: "function" | "global" | "memory" | "table" | "tag";
    index: number;
    signature?: RuntimeFunctionSignature;
    globalType?: { valueType: WasmRuntimeValueType; mutable: boolean };
    support: RuntimeSupportClassification;
  }>;
};

export type TypedRuntimeValue =
  | { type: "i32"; signed: number; bits: string }
  | { type: "i64"; signed: string; bits: string }
  | { type: "f32" | "f64"; bits: string; class: "zero" | "subnormal" | "normal" | "infinity" | "nan"; sign: "+" | "-"; quiet?: boolean; payload?: string }
  | { type: "v128"; bits: string }
  | { type: "reference"; relation: string; wasmType: string };

export type InvocationPlanStepV2 = {
  stepIndex: number;
  exportName: string;
  signature: RuntimeFunctionSignature;
  arguments: TypedRuntimeValue[];
  source: "default" | "boundary" | "pairwise" | "targeted";
};

export type InvocationPlanV2 = {
  schema: "starshine.optimizer-invocation-plan.v2";
  seed: string;
  interfaceHash: string;
  hash: string;
  steps: InvocationPlanStepV2[];
  blockedExports: Array<{ exportName: string; reason: string }>;
};

export type RuntimeStateSnapshotV2 = {
  globals: Array<{ index: number; names: string[]; value: TypedRuntimeValue }>;
  memories: Array<RuntimeMemoryObservationV2>;
  tables: Array<RuntimeTableObservationV2>;
};

export type RuntimeMemoryObservationV2 = {
  index: number;
  names: string[];
  byteLength: number;
  complete: boolean;
  hash: string;
  chunkHashes: string[];
  diagnosticSamples: Array<{ offset: number; bytes: string }>;
};

export type RuntimeTableObservationV2 = {
  index: number;
  names: string[];
  length: number;
  complete: boolean;
  entries: Array<{ index: number; relation: string }>;
};

export type RuntimeImportEventV2 = {
  module: string;
  field: string;
  ordinal: number;
  phase: "instantiation" | "start" | "exported-call";
  stepIndex: number | null;
  arguments: TypedRuntimeValue[];
  results: TypedRuntimeValue[];
};

export type RuntimeStepOutcomeV2 =
  | { kind: "returned"; values: TypedRuntimeValue[] }
  | { kind: "trapped"; trapClass: string; rawText: string }
  | { kind: "timed-out"; timeoutMs: number }
  | { kind: "unsupported"; reason: string };

export type RuntimeObservationStepV2 = {
  stepIndex: number;
  exportName: string | null;
  phase: "instantiation" | "start" | "exported-call";
  arguments: TypedRuntimeValue[];
  importTraceStart: number;
  importTraceEnd: number;
  stateBefore: RuntimeStateSnapshotV2;
  outcome: RuntimeStepOutcomeV2;
  stateAfter: RuntimeStateSnapshotV2;
  stateDelta: Array<{ path: string; before: unknown; after: unknown }>;
  firstChangedResource: { kind: "global" | "memory" | "table"; index: number; offset?: number } | null;
};

export type RuntimeCompilationOutcomeV2 =
  | { status: "not-attempted" | "succeeded" | "unknown" }
  | { status: "failed"; error: string };

export type RuntimeInstantiationOutcomeV2 =
  | { status: "not-attempted" | "succeeded" | "unknown" }
  | { status: "trapped"; trapClass: string; rawText: string }
  | { status: "failed"; error: string }
  | { status: "timed-out"; timeoutMs: number };

export type RuntimeObservationV2 = {
  schema: "starshine.optimizer-runtime-observation.v2";
  runtime: { identity: string; timeoutMs: number };
  mode: ObservationMode;
  compilation: RuntimeCompilationOutcomeV2;
  instantiation: RuntimeInstantiationOutcomeV2;
  completeness: "complete" | "incomplete";
  blockedReasons: string[];
  steps: RuntimeObservationStepV2[];
  importTrace?: RuntimeImportEventV2[];
  resources: RuntimeStateSnapshotV2;
};

export type SemanticComparisonV2 = {
  schema: "starshine.optimizer-semantic-comparison.v2";
  classification: "semantic-match" | "semantic-mismatch" | "blocked";
  completeness: "complete" | "incomplete";
  policy: SemanticPolicy;
  firstDifferenceCategory: string | null;
  firstDifferencePath: string | null;
  expected: unknown;
  actual: unknown;
  commonImportEventPrefixLength: number;
  firstDifferingImportEvent: { expected: RuntimeImportEventV2 | null; actual: RuntimeImportEventV2 | null } | null;
  resourceKind: "global" | "memory" | "table" | null;
  resourceIndex: number | null;
  offset: number | null;
  originalOutcomeKind: RuntimeStepOutcomeV2["kind"] | null;
  candidateOutcomeKind: RuntimeStepOutcomeV2["kind"] | null;
  originalTrapClass: string | null;
  candidateTrapClass: string | null;
  diagnostics: string[];
};

const EMPTY_STATE = (): RuntimeStateSnapshotV2 => ({ globals: [], memories: [], tables: [] });

function stableValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value !== null && typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      const child = (value as Record<string, unknown>)[key];
      if (child !== undefined) result[key] = stableValue(child);
    }
    return result;
  }
  if (typeof value === "bigint") return `bigint:${value}`;
  return value;
}

export function stableRuntimeJson(value: unknown): string {
  return JSON.stringify(stableValue(value));
}

export function sha256RuntimeValue(value: unknown): string {
  return `sha256:${crypto.createHash("sha256").update(stableRuntimeJson(value)).digest("hex")}`;
}

function i32Value(value: number): TypedRuntimeValue {
  const signed = value | 0;
  return { type: "i32", signed, bits: `0x${(signed >>> 0).toString(16).padStart(8, "0")}` };
}

function i64Value(value: bigint): TypedRuntimeValue {
  const signed = BigInt.asIntN(64, value);
  return { type: "i64", signed: signed.toString(), bits: `0x${BigInt.asUintN(64, signed).toString(16).padStart(16, "0")}` };
}

function floatValue(type: "f32" | "f64", bits: string): TypedRuntimeValue {
  const hex = bits.toLowerCase().replace(/^0x/, "").padStart(type === "f32" ? 8 : 16, "0");
  const raw = BigInt(`0x${hex}`);
  const width = type === "f32" ? 32n : 64n;
  const exponentBits = type === "f32" ? 8n : 11n;
  const fractionBits = width - exponentBits - 1n;
  const exponentMask = (1n << exponentBits) - 1n;
  const fractionMask = (1n << fractionBits) - 1n;
  const sign = ((raw >> (width - 1n)) & 1n) === 0n ? "+" : "-";
  const exponent = (raw >> fractionBits) & exponentMask;
  const fraction = raw & fractionMask;
  let klass: "zero" | "subnormal" | "normal" | "infinity" | "nan";
  if (exponent === 0n) klass = fraction === 0n ? "zero" : "subnormal";
  else if (exponent === exponentMask) klass = fraction === 0n ? "infinity" : "nan";
  else klass = "normal";
  if (klass === "nan") {
    const quietMask = 1n << (fractionBits - 1n);
    return { type, bits: `0x${hex}`, class: klass, sign, quiet: (fraction & quietMask) !== 0n, payload: `0x${fraction.toString(16)}` };
  }
  return { type, bits: `0x${hex}`, class: klass, sign };
}

function defaultValue(type: WasmRuntimeValueType): TypedRuntimeValue | null {
  switch (type) {
    case "i32": return i32Value(0);
    case "i64": return i64Value(0n);
    case "f32": return floatValue("f32", "00000000");
    case "f64": return floatValue("f64", "0000000000000000");
    case "v128": return { type: "v128", bits: "0x00000000000000000000000000000000" };
    case "externref": return { type: "reference", relation: "fixture:externref:0", wasmType: "externref" };
    case "funcref": return { type: "reference", relation: "null", wasmType: "funcref" };
    case "anyref":
    case "eqref":
    case "i31ref":
    case "structref":
    case "arrayref":
      return { type: "reference", relation: "null", wasmType: type };
    default:
      if (type.includes("ref null")) return { type: "reference", relation: "null", wasmType: type };
      return null;
  }
}

function boundaryValues(type: WasmRuntimeValueType): TypedRuntimeValue[] {
  switch (type) {
    case "i32": return [0, 1, -1, -2147483648, 2147483647].map(i32Value);
    case "i64": return [0n, 1n, -1n, -(1n << 63n), (1n << 63n) - 1n].map(i64Value);
    case "f32": return ["00000000", "80000000", "3f800000", "bf800000", "00000001", "007fffff", "00800000", "7f800000", "ff800000", "7fc00001", "7fc01234"].map((bits) => floatValue("f32", bits));
    case "f64": return ["0000000000000000", "8000000000000000", "3ff0000000000000", "bff0000000000000", "0000000000000001", "000fffffffffffff", "0010000000000000", "7ff0000000000000", "fff0000000000000", "7ff8000000000001", "7ff8000000001234"].map((bits) => floatValue("f64", bits));
    case "v128": return [
      "00000000000000000000000000000000",
      "ffffffffffffffffffffffffffffffff",
      "00000000000000017fffffffffffffff",
      "8000000000000000ffffffffffffffff",
    ].map((bits) => ({ type: "v128" as const, bits: `0x${bits}` }));
    default: {
      const value = defaultValue(type);
      return value === null ? [] : [value];
    }
  }
}

export function buildInvocationPlanV2(
  runtimeInterface: RuntimeInterfaceV1,
  options: { seed: bigint; targetedVectors?: Record<string, TypedRuntimeValue[][]>; maxPairwise?: number } = { seed: 0x5eedn },
): InvocationPlanV2 {
  const steps: InvocationPlanStepV2[] = [];
  const blockedExports: InvocationPlanV2["blockedExports"] = [];
  const maxPairwise = Math.max(0, options.maxPairwise ?? 4);
  for (const exported of runtimeInterface.exports) {
    if (exported.kind !== "function" || exported.signature === undefined) continue;
    const signature = exported.signature;
    const unsupported = signature.params.find((type) => defaultValue(type) === null)
      ?? signature.results.find((type) => type !== "v128" && defaultValue(type) === null);
    if (exported.support === "unsupported" || unsupported !== undefined) {
      blockedExports.push({ exportName: exported.name, reason: `unsupported direct JavaScript signature type: ${unsupported ?? "interface-classification"}` });
      continue;
    }
    const defaults = signature.params.map(defaultValue);
    if (defaults.some((value) => value === null)) {
      blockedExports.push({ exportName: exported.name, reason: "unsupported non-null reference fixture" });
      continue;
    }
    const vectors: Array<{ arguments: TypedRuntimeValue[]; source: InvocationPlanStepV2["source"] }> = [
      { arguments: defaults as TypedRuntimeValue[], source: "default" },
    ];
    for (let parameterIndex = 0; parameterIndex < signature.params.length; parameterIndex += 1) {
      for (const value of boundaryValues(signature.params[parameterIndex])) {
        const args = (defaults as TypedRuntimeValue[]).slice();
        args[parameterIndex] = value;
        vectors.push({ arguments: args, source: "boundary" });
      }
    }
    let pairwise = 0;
    for (let left = 0; left < signature.params.length && pairwise < maxPairwise; left += 1) {
      for (let right = left + 1; right < signature.params.length && pairwise < maxPairwise; right += 1) {
        const leftValues = boundaryValues(signature.params[left]);
        const rightValues = boundaryValues(signature.params[right]);
        if (leftValues.length < 2 || rightValues.length < 2) continue;
        const args = (defaults as TypedRuntimeValue[]).slice();
        args[left] = leftValues[(pairwise + 1) % leftValues.length];
        args[right] = rightValues[(pairwise + 2) % rightValues.length];
        vectors.push({ arguments: args, source: "pairwise" });
        pairwise += 1;
      }
    }
    for (const arguments_ of options.targetedVectors?.[exported.name] ?? []) {
      if (arguments_.length === signature.params.length) vectors.push({ arguments: arguments_, source: "targeted" });
    }
    const seen = new Set<string>();
    for (const vector of vectors) {
      const key = stableRuntimeJson(vector.arguments);
      if (seen.has(key)) continue;
      seen.add(key);
      steps.push({ stepIndex: steps.length, exportName: exported.name, signature, arguments: vector.arguments, source: vector.source });
    }
  }
  const planWithoutHash = {
    schema: "starshine.optimizer-invocation-plan.v2" as const,
    seed: `0x${options.seed.toString(16)}`,
    interfaceHash: runtimeInterface.interfaceHash,
    steps,
    blockedExports,
  };
  return { ...planWithoutHash, hash: sha256RuntimeValue(planWithoutHash) };
}

export function normalizeRuntimeTrap(text: string): { class: string; rawText: string } {
  const lower = text.toLowerCase();
  let klass = "unknown-runtime-trap";
  if (lower.includes("unreachable")) klass = "explicit-unreachable";
  else if (lower.includes("divide by zero") || lower.includes("division by zero") || lower.includes("remainder by zero")) klass = "integer-divide-by-zero";
  else if (lower.includes("integer overflow") || lower.includes("divide result unrepresentable")) klass = "signed-integer-division-overflow";
  else if (lower.includes("invalid conversion") || lower.includes("unrepresentable in integer")) klass = "invalid-conversion-to-integer";
  else if (lower.includes("out of bounds") && lower.includes("memory")) klass = "out-of-bounds-memory-access";
  else if (lower.includes("out of bounds") && lower.includes("table")) klass = "out-of-bounds-table-access";
  else if (lower.includes("indirect call") || lower.includes("signature mismatch")) klass = "indirect-call-type-mismatch";
  else if (lower.includes("null") && (lower.includes("reference") || lower.includes("function"))) klass = "null-reference";
  else if (lower.includes("cast") && lower.includes("fail")) klass = "failed-reference-cast";
  else if (lower.includes("uninitialized element")) klass = "uninitialized-element";
  else if (lower.includes("stack") && (lower.includes("exhaust") || lower.includes("overflow"))) klass = "stack-exhaustion";
  else if (lower.includes("exception") || lower.includes("tag")) klass = "user-exception";
  else if (lower.includes("timeout")) klass = "timeout";
  return { class: klass, rawText: text };
}

function typedValuesEqual(left: TypedRuntimeValue, right: TypedRuntimeValue, policy: SemanticPolicy): boolean {
  if (left.type !== right.type) return false;
  if ((left.type === "f32" || left.type === "f64") && (right.type === "f32" || right.type === "f64")) {
    if (policy === "canonical-nan" && left.class === "nan" && right.class === "nan" && left.type === right.type) return true;
    return left.bits.toLowerCase() === right.bits.toLowerCase();
  }
  return stableRuntimeJson(left) === stableRuntimeJson(right);
}

function outcomeKind(observation: RuntimeObservationV2): RuntimeStepOutcomeV2["kind"] | null {
  return observation.steps.at(-1)?.outcome.kind ?? null;
}

function trapClass(observation: RuntimeObservationV2): string | null {
  const outcome = observation.steps.at(-1)?.outcome;
  return outcome?.kind === "trapped" ? outcome.trapClass : null;
}

function emptyComparison(policy: SemanticPolicy, before: RuntimeObservationV2, after: RuntimeObservationV2): SemanticComparisonV2 {
  return {
    schema: "starshine.optimizer-semantic-comparison.v2",
    classification: "semantic-match",
    completeness: before.completeness === "complete" && after.completeness === "complete" ? "complete" : "incomplete",
    policy,
    firstDifferenceCategory: null,
    firstDifferencePath: null,
    expected: null,
    actual: null,
    commonImportEventPrefixLength: 0,
    firstDifferingImportEvent: null,
    resourceKind: null,
    resourceIndex: null,
    offset: null,
    originalOutcomeKind: outcomeKind(before),
    candidateOutcomeKind: outcomeKind(after),
    originalTrapClass: trapClass(before),
    candidateTrapClass: trapClass(after),
    diagnostics: [],
  };
}

function setDifference(report: SemanticComparisonV2, category: string, path: string, expected: unknown, actual: unknown): SemanticComparisonV2 {
  report.classification = "semantic-mismatch";
  report.firstDifferenceCategory = category;
  report.firstDifferencePath = path;
  report.expected = expected;
  report.actual = actual;
  return report;
}

export function compareRuntimeObservationsV2(before: RuntimeObservationV2, after: RuntimeObservationV2, policy: SemanticPolicy): SemanticComparisonV2 {
  const report = emptyComparison(policy, before, after);
  if (report.completeness === "incomplete" || before.blockedReasons.length > 0 || after.blockedReasons.length > 0) {
    report.classification = "blocked";
    report.diagnostics = [...before.blockedReasons, ...after.blockedReasons];
    return report;
  }
  const beforeEvents = before.importTrace ?? [];
  const afterEvents = after.importTrace ?? [];
  let commonEvents = 0;
  while (commonEvents < beforeEvents.length && commonEvents < afterEvents.length && stableRuntimeJson(beforeEvents[commonEvents]) === stableRuntimeJson(afterEvents[commonEvents])) commonEvents += 1;
  report.commonImportEventPrefixLength = commonEvents;
  if (commonEvents < beforeEvents.length || commonEvents < afterEvents.length) {
    report.firstDifferingImportEvent = { expected: beforeEvents[commonEvents] ?? null, actual: afterEvents[commonEvents] ?? null };
    return setDifference(report, "import-event", `importTrace[${commonEvents}]`, beforeEvents[commonEvents] ?? null, afterEvents[commonEvents] ?? null);
  }
  if (before.steps.length !== after.steps.length) return setDifference(report, "step-count", "steps.length", before.steps.length, after.steps.length);
  for (let index = 0; index < before.steps.length; index += 1) {
    const left = before.steps[index];
    const right = after.steps[index];
    if (left.phase !== right.phase) return setDifference(report, "phase", `steps[${index}].phase`, left.phase, right.phase);
    if (left.exportName !== right.exportName) return setDifference(report, "export", `steps[${index}].exportName`, left.exportName, right.exportName);
    if (left.outcome.kind !== right.outcome.kind) return setDifference(report, "outcome-kind", `steps[${index}].outcome.kind`, left.outcome.kind, right.outcome.kind);
    if (left.outcome.kind === "timed-out" || right.outcome.kind === "timed-out") {
      report.classification = "blocked";
      report.firstDifferenceCategory = "timeout";
      report.firstDifferencePath = `steps[${index}].outcome`;
      return report;
    }
    if (left.outcome.kind === "unsupported" || right.outcome.kind === "unsupported") {
      report.classification = "blocked";
      report.firstDifferenceCategory = "unsupported";
      report.firstDifferencePath = `steps[${index}].outcome`;
      return report;
    }
    if (left.outcome.kind === "trapped" && right.outcome.kind === "trapped" && left.outcome.trapClass !== right.outcome.trapClass) {
      return setDifference(report, "trap-class", `steps[${index}].outcome.trapClass`, left.outcome.trapClass, right.outcome.trapClass);
    }
    if (left.outcome.kind === "returned" && right.outcome.kind === "returned") {
      if (left.outcome.values.length !== right.outcome.values.length) return setDifference(report, "result-count", `steps[${index}].outcome.values.length`, left.outcome.values.length, right.outcome.values.length);
      for (let valueIndex = 0; valueIndex < left.outcome.values.length; valueIndex += 1) {
        if (!typedValuesEqual(left.outcome.values[valueIndex], right.outcome.values[valueIndex], policy)) {
          return setDifference(report, "result-value", `steps[${index}].outcome.values[${valueIndex}]`, left.outcome.values[valueIndex], right.outcome.values[valueIndex]);
        }
      }
    }
    if (stableRuntimeJson(left.stateAfter) !== stableRuntimeJson(right.stateAfter)) return setDifference(report, "state", `steps[${index}].stateAfter`, left.stateAfter, right.stateAfter);
  }
  for (const kind of ["globals", "memories", "tables"] as const) {
    const left = before.resources[kind];
    const right = after.resources[kind];
    if (stableRuntimeJson(left) !== stableRuntimeJson(right)) {
      report.resourceKind = kind === "globals" ? "global" : kind === "memories" ? "memory" : "table";
      const first = Math.max(0, left.findIndex((value, index) => stableRuntimeJson(value) !== stableRuntimeJson(right[index])));
      report.resourceIndex = (left[first] as { index?: number } | undefined)?.index ?? (right[first] as { index?: number } | undefined)?.index ?? first;
      return setDifference(report, `resource-${report.resourceKind}`, `resources.${kind}[${first}]`, left[first], right[first]);
    }
  }
  return report;
}

export type ThreeWayRelation = "equal" | "different" | "blocked" | "blocked-original" | "unknown";

export function classifyThreeWaySemanticComparison(input: {
  originalVsStarshine: ThreeWayRelation;
  originalVsBinaryen: ThreeWayRelation;
  starshineVsBinaryen: ThreeWayRelation;
  binaryenDiagnostic?: "ok" | "tool-failure" | "timeout" | "unsupported";
}): {
  schema: "starshine.optimizer-three-way-semantic.v1";
  primary: "semantic-match" | "starshine-semantic-mismatch" | "blocked-original-runtime" | "starshine-correctness-failure";
  pattern: string;
  binaryenDiagnostic: string;
} {
  let primary: "semantic-match" | "starshine-semantic-mismatch" | "blocked-original-runtime" | "starshine-correctness-failure";
  let pattern: string;
  if (input.originalVsStarshine === "blocked-original") {
    primary = "blocked-original-runtime";
    pattern = "original-runtime-blocked";
  } else if (input.originalVsStarshine === "blocked") {
    primary = "starshine-correctness-failure";
    pattern = "starshine-runtime-or-interface-failure";
  } else if (input.originalVsStarshine === "equal") {
    primary = "semantic-match";
    pattern = input.originalVsBinaryen === "equal" ? "all-equal" : "binaryen-discrepancy";
  } else {
    primary = "starshine-semantic-mismatch";
    if (input.originalVsBinaryen === "equal") pattern = "only-starshine-differs";
    else if (input.starshineVsBinaryen === "equal") pattern = "both-optimizers-same-difference";
    else if (input.originalVsBinaryen === "different") pattern = "all-three-differ";
    else pattern = "starshine-mismatch-binaryen-unavailable";
  }
  return {
    schema: "starshine.optimizer-three-way-semantic.v1",
    primary,
    pattern,
    binaryenDiagnostic: input.binaryenDiagnostic ?? (input.originalVsBinaryen === "blocked" ? "blocked" : "ok"),
  };
}

export function emptyRuntimeObservationV2(mode: ObservationMode, runtimeIdentity = "unknown", timeoutMs = 1000): RuntimeObservationV2 {
  return {
    schema: "starshine.optimizer-runtime-observation.v2",
    runtime: { identity: runtimeIdentity, timeoutMs },
    mode,
    compilation: { status: "not-attempted" },
    instantiation: { status: "not-attempted" },
    completeness: "complete",
    blockedReasons: [],
    steps: [],
    importTrace: [],
    resources: EMPTY_STATE(),
  };
}
