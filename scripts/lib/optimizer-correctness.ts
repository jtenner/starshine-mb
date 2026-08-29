import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { Worker } from "node:worker_threads";

export type SemanticComparisonPolicy = "strict" | "canonical-nan" | "trap-aware";
export type SemanticFailureClass =
  | "semantic-self"
  | "semantic-binaryen"
  | "validation-failure"
  | "optimizer-nondeterminism"
  | "optimizer-idempotence"
  | "codec-idempotence"
  | "composition"
  | "runtime-tool-failure"
  | "unsupported-runtime"
  | "unsupported-feature"
  | "non-comparable";

export type NumericValueType = "i32" | "i64" | "f32" | "f64";
export type RuntimeValueType = NumericValueType | "v128" | "ref" | "unknown";
export type RuntimeBitValue = { type: RuntimeValueType; bits: string };
export type RuntimeInvocationArgument = number | bigint | RuntimeBitValue;

export type InvocationPlanStep = {
  exportName: string;
  parameterTypes: string[];
  resultTypes: string[];
  args: RuntimeInvocationArgument[];
};

export type InvocationPlan = {
  schema: "starshine.invocation-plan.v1";
  seed: string;
  runtime: "node";
  steps: InvocationPlanStep[];
  unsupportedExports: { exportName: string; reason: string }[];
};

export type RuntimeCallOutcome =
  | { kind: "return"; values: RuntimeBitValue[] }
  | { kind: "trap"; class: string; detail?: string }
  | { kind: "unsupported"; reason: string }
  | { kind: "tool-failure"; detail: string };

export type RuntimeObservation = {
  schema: "starshine.runtime-observation.v1";
  instantiation:
    | { kind: "instantiated" }
    | { kind: "trap"; class: string; detail?: string }
    | { kind: "unsupported"; reason: string }
    | { kind: "tool-failure"; detail: string };
  calls: {
    stepIndex: number;
    exportName: string;
    args: RuntimeBitValue[];
    outcome: RuntimeCallOutcome;
  }[];
  globals: { exportName: string; value: RuntimeBitValue | { type: "unsupported"; detail: string } }[];
  memories: { exportName: string; byteLength: number; digest: string; selectedRanges: { offset: number; bytes: string }[] }[];
  tables: { exportName: string; length: number; entries: string[]; complete: boolean }[];
  importTrace: { module: string; name: string; args: RuntimeBitValue[] }[];
};

export type RuntimeObservationComparison = {
  classification:
    | "equal-result"
    | "equal-trap"
    | "semantic-mismatch"
    | "trap-mismatch"
    | "unsupported-runtime"
    | "unsupported-feature"
    | "non-comparable"
    | "runtime-tool-failure";
  firstDifference: { path: string; before: unknown; after: unknown } | null;
};

export type SelfSemanticOracleReport = RuntimeObservationComparison & {
  schema: "starshine.semantic-self-report.v1";
  policy: SemanticComparisonPolicy;
  plan: InvocationPlan;
  before: RuntimeObservation;
  after: RuntimeObservation;
};

export type OptimizerDeterminismClassification =
  | "byte-stable"
  | "canonical-stable-only"
  | "optimizer-nondeterminism";

export type OptimizerPassRegistryEntry = {
  name: string;
  category: "hot-pass" | "module-pass" | "preset" | "boundary-only" | "removed" | string;
  executable: boolean;
  compatible: boolean;
};

export type PassSequenceReductionStep = {
  kind: "delete-pass-range";
  start: number;
  length: number;
  beforeSize: number;
  afterSize: number;
};

export type PassSequenceReductionReport = {
  passes: string[];
  failureClass: SemanticFailureClass;
  predicateEvaluations: number;
  steps: PassSequenceReductionStep[];
};

export type OptionalWasmReduceResult =
  | { status: "unavailable"; detail: string }
  | { status: "reduced"; outputPath: string; log: string }
  | { status: "failed"; detail: string; log: string };

const NUMERIC_TYPES = new Set(["i32", "i64", "f32", "f64"]);
const SUPPORTED_PARAMETER_TYPES = new Set(["i32", "i64", "f32", "f64"]);
const SUPPORTED_RESULT_TYPES = new Set(["i32", "i64", "f32", "f64"]);

function hex32(value: number): string {
  return (value >>> 0).toString(16).padStart(8, "0");
}

function hex64(value: bigint): string {
  return BigInt.asUintN(64, value).toString(16).padStart(16, "0");
}

function f32Bits(value: number): string {
  const bytes = new ArrayBuffer(4);
  const view = new DataView(bytes);
  view.setFloat32(0, value, false);
  return view.getUint32(0, false).toString(16).padStart(8, "0");
}

function f64Bits(value: number): string {
  const bytes = new ArrayBuffer(8);
  const view = new DataView(bytes);
  view.setFloat64(0, value, false);
  return view.getBigUint64(0, false).toString(16).padStart(16, "0");
}

function numberFromF32Bits(bits: string): number {
  const bytes = new ArrayBuffer(4);
  const view = new DataView(bytes);
  view.setUint32(0, Number.parseInt(bits, 16), false);
  return view.getFloat32(0, false);
}

function numberFromF64Bits(bits: string): number {
  const bytes = new ArrayBuffer(8);
  const view = new DataView(bytes);
  view.setBigUint64(0, BigInt(`0x${bits}`), false);
  return view.getFloat64(0, false);
}

function argumentToJs(value: RuntimeInvocationArgument): unknown {
  if (typeof value === "number" || typeof value === "bigint") return value;
  switch (value.type) {
    case "i32":
      return Number(BigInt.asIntN(32, BigInt(`0x${value.bits}`)));
    case "i64":
      return BigInt.asIntN(64, BigInt(`0x${value.bits}`));
    case "f32":
      return numberFromF32Bits(value.bits);
    case "f64":
      return numberFromF64Bits(value.bits);
    default:
      return null;
  }
}

function runtimeValue(value: unknown, type: string = "unknown"): RuntimeBitValue {
  if (type === "i32") return { type: "i32", bits: hex32(Number(value) | 0) };
  if (type === "i64") return { type: "i64", bits: hex64(BigInt(value as bigint)) };
  if (type === "f32") return { type: "f32", bits: f32Bits(Number(value)) };
  if (type === "f64") return { type: "f64", bits: f64Bits(Number(value)) };
  if (typeof value === "bigint") return { type: "i64", bits: hex64(value) };
  if (typeof value === "number") return { type: "f64", bits: f64Bits(value) };
  if (value === null) return { type: "ref", bits: "null" };
  return { type: "unknown", bits: `${typeof value}:${String(value)}` };
}

function normalizeTrap(error: unknown): { class: string; detail: string } {
  const detail = error instanceof Error ? error.message : String(error);
  const lower = detail.toLowerCase();
  if (lower.includes("unreachable")) return { class: "unreachable", detail };
  if (lower.includes("divide by zero") || lower.includes("division by zero")) {
    return { class: "integer-divide-by-zero", detail };
  }
  if (lower.includes("out of bounds") && lower.includes("memory")) return { class: "memory-out-of-bounds", detail };
  if (lower.includes("out of bounds") && lower.includes("table")) return { class: "table-out-of-bounds", detail };
  if (lower.includes("null") && lower.includes("reference")) return { class: "null-reference", detail };
  if (lower.includes("integer overflow") || lower.includes("unrepresentable")) return { class: "integer-overflow", detail };
  if (lower.includes("signature") || lower.includes("indirect call")) return { class: "indirect-call-type-mismatch", detail };
  return { class: "runtime-trap", detail };
}

function splitTopLevelForms(text: string): string[] {
  const forms: string[] = [];
  let depth = 0;
  let start = -1;
  let inString = false;
  let escaped = false;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    if (inString) {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === '"') inString = false;
      continue;
    }
    if (char === '"') {
      inString = true;
      continue;
    }
    if (char === "(") {
      if (depth === 1) start = index;
      depth += 1;
    } else if (char === ")") {
      depth -= 1;
      if (depth === 1 && start >= 0) {
        forms.push(text.slice(start, index + 1));
        start = -1;
      }
    }
  }
  return forms;
}

function typeTokens(form: string, field: "param" | "result"): string[] {
  const out: string[] = [];
  const regex = new RegExp(`\\(${field}\\s+([^)]*)\\)`, "g");
  for (const match of form.matchAll(regex)) {
    for (const token of match[1].trim().split(/\s+/)) {
      if (NUMERIC_TYPES.has(token) || token === "v128" || token.endsWith("ref") || token.startsWith("(ref")) {
        out.push(token);
      }
    }
  }
  return out;
}

function wasmToolsPrint(wasmPath: string): string {
  const result = spawnSync("wasm-tools", ["print", wasmPath], { encoding: "utf8", maxBuffer: 128 * 1024 * 1024 });
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || "wasm-tools print failed");
  return result.stdout;
}

type PrintedModuleShape = {
  functions: Map<number, { params: string[]; results: string[] }>;
  functionExports: { name: string; index: number }[];
};

function parsePrintedModuleShape(text: string): PrintedModuleShape {
  const functions = new Map<number, { params: string[]; results: string[] }>();
  const functionExports: { name: string; index: number }[] = [];
  for (const form of splitTopLevelForms(text)) {
    const exportMatch = /^\(export\s+"((?:\\.|[^"])*)"\s+\(func\s+(\d+)\)\s*\)$/s.exec(form.trim());
    if (exportMatch) {
      functionExports.push({ name: JSON.parse(`"${exportMatch[1]}"`) as string, index: Number(exportMatch[2]) });
      continue;
    }
    if (form.startsWith("(func ")) {
      const indexMatch = /^\(func\s+\(;([0-9]+);\)/s.exec(form);
      if (indexMatch) {
        functions.set(Number(indexMatch[1]), { params: typeTokens(form, "param"), results: typeTokens(form, "result") });
      }
      continue;
    }
    if (form.startsWith("(import ") && form.includes("(func ")) {
      const indexMatch = /\(func\s+\(;([0-9]+);\)/s.exec(form);
      if (indexMatch) {
        functions.set(Number(indexMatch[1]), { params: typeTokens(form, "param"), results: typeTokens(form, "result") });
      }
    }
  }
  return { functions, functionExports };
}

export function buildBoundaryArgumentValues(type: string, seed: bigint): RuntimeInvocationArgument[] {
  const salt = Number(BigInt.asUintN(32, seed));
  switch (type) {
    case "i32": {
      const candidates = [0, 1, -1, -2147483648, 2147483647, 2, 3, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128, 255, 256];
      candidates.push((salt | 0), ((salt ^ 0x80000000) | 0));
      return Array.from(new Set(candidates));
    }
    case "i64": {
      const candidates = [
        0n,
        1n,
        -1n,
        -9223372036854775808n,
        9223372036854775807n,
        2n,
        3n,
        7n,
        8n,
        15n,
        16n,
        31n,
        32n,
        63n,
        64n,
        127n,
        128n,
        255n,
        256n,
        BigInt.asIntN(64, seed),
      ];
      return Array.from(new Set(candidates));
    }
    case "f32":
      return ["00000000", "80000000", "3f800000", "bf800000", "3f000000", "40000000", "7f7fffff", "ff7fffff", "7f800000", "ff800000", "7fc00000"].map(
        (bits) => ({ type: "f32", bits }),
      );
    case "f64":
      return [
        "0000000000000000",
        "8000000000000000",
        "3ff0000000000000",
        "bff0000000000000",
        "3fe0000000000000",
        "4000000000000000",
        "7fefffffffffffff",
        "ffefffffffffffff",
        "7ff0000000000000",
        "fff0000000000000",
        "7ff8000000000000",
      ].map((bits) => ({ type: "f64", bits }));
    default:
      return [];
  }
}

function zeroForType(type: string): RuntimeInvocationArgument {
  switch (type) {
    case "i64":
      return 0n;
    case "f32":
      return { type: "f32", bits: "00000000" };
    case "f64":
      return { type: "f64", bits: "0000000000000000" };
    default:
      return 0;
  }
}

export async function buildDeterministicInvocationPlan(
  wasmPath: string,
  seed: bigint,
  options: { maxExports?: number; maxCallsPerExport?: number } = {},
): Promise<InvocationPlan> {
  const maxExports = Math.max(0, options.maxExports ?? 8);
  const maxCallsPerExport = Math.max(1, options.maxCallsPerExport ?? 4);
  const shape = parsePrintedModuleShape(wasmToolsPrint(wasmPath));
  const steps: InvocationPlanStep[] = [];
  const unsupportedExports: { exportName: string; reason: string }[] = [];
  for (const exported of shape.functionExports.slice(0, maxExports)) {
    const signature = shape.functions.get(exported.index);
    if (!signature) {
      unsupportedExports.push({ exportName: exported.name, reason: "missing printed function signature" });
      continue;
    }
    const unsupportedParam = signature.params.find((type) => !SUPPORTED_PARAMETER_TYPES.has(type));
    const unsupportedResult = signature.results.find((type) => !SUPPORTED_RESULT_TYPES.has(type));
    if (unsupportedParam || unsupportedResult) {
      unsupportedExports.push({
        exportName: exported.name,
        reason: `unsupported signature params=${signature.params.join(",")} results=${signature.results.join(",")}`,
      });
      continue;
    }
    const values = signature.params.map((type, index) => buildBoundaryArgumentValues(type, seed + BigInt(index)));
    for (let callIndex = 0; callIndex < maxCallsPerExport; callIndex += 1) {
      const args = signature.params.map((type, paramIndex) => {
        const candidates = values[paramIndex];
        return candidates.length === 0 ? zeroForType(type) : candidates[(callIndex + paramIndex) % candidates.length];
      });
      steps.push({ exportName: exported.name, parameterTypes: signature.params, resultTypes: signature.results, args });
    }
  }
  return {
    schema: "starshine.invocation-plan.v1",
    seed: `0x${seed.toString(16)}`,
    runtime: "node",
    steps,
    unsupportedExports,
  };
}

function deterministicImports(module: WebAssembly.Module, trace: RuntimeObservation["importTrace"]): WebAssembly.Imports {
  const imports: Record<string, Record<string, unknown>> = {};
  for (const descriptor of WebAssembly.Module.imports(module)) {
    const namespace = (imports[descriptor.module] ??= {});
    switch (descriptor.kind) {
      case "function":
        namespace[descriptor.name] = (...args: unknown[]) => {
          trace.push({ module: descriptor.module, name: descriptor.name, args: args.map((arg) => runtimeValue(arg)) });
          return 0;
        };
        break;
      case "global":
        namespace[descriptor.name] = 0;
        break;
      case "memory":
        namespace[descriptor.name] = new WebAssembly.Memory({ initial: 1, maximum: 1 });
        break;
      case "table":
        namespace[descriptor.name] = new WebAssembly.Table({ element: "anyfunc", initial: 1 });
        break;
      default:
        throw new Error(`unsupported import kind ${descriptor.kind}`);
    }
  }
  return imports;
}

function fnv1a64(bytes: Uint8Array): string {
  let hash = 0xcbf29ce484222325n;
  for (const byte of bytes) {
    hash ^= BigInt(byte);
    hash = BigInt.asUintN(64, hash * 0x100000001b3n);
  }
  return `fnv1a64-${hash.toString(16).padStart(16, "0")}`;
}

function selectedMemoryRanges(bytes: Uint8Array, seed: bigint): { offset: number; bytes: string }[] {
  if (bytes.length === 0) return [];
  const offsets = new Set<number>([0, Math.max(0, bytes.length - 32), Number(seed % BigInt(bytes.length))]);
  return Array.from(offsets)
    .sort((a, b) => a - b)
    .map((offset) => ({ offset, bytes: Buffer.from(bytes.slice(offset, Math.min(bytes.length, offset + 32))).toString("hex") }));
}

function observeExports(instance: WebAssembly.Instance, seed: bigint): Pick<RuntimeObservation, "globals" | "memories" | "tables"> {
  const globals: RuntimeObservation["globals"] = [];
  const memories: RuntimeObservation["memories"] = [];
  const tables: RuntimeObservation["tables"] = [];
  for (const [exportName, value] of Object.entries(instance.exports)) {
    if (value instanceof WebAssembly.Global) {
      try {
        globals.push({ exportName, value: runtimeValue(value.value) });
      } catch (error) {
        globals.push({ exportName, value: { type: "unsupported", detail: error instanceof Error ? error.message : String(error) } });
      }
    } else if (value instanceof WebAssembly.Memory) {
      const bytes = new Uint8Array(value.buffer);
      const digestWindow = bytes.slice(0, Math.min(bytes.length, 64 * 1024));
      memories.push({ exportName, byteLength: bytes.length, digest: fnv1a64(digestWindow), selectedRanges: selectedMemoryRanges(bytes, seed) });
    } else if (value instanceof WebAssembly.Table) {
      const count = Math.min(value.length, 16);
      const entries: string[] = [];
      for (let index = 0; index < count; index += 1) {
        const entry = value.get(index);
        entries.push(entry === null ? "null" : typeof entry === "function" ? "funcref" : `${typeof entry}:${String(entry)}`);
      }
      tables.push({ exportName, length: value.length, entries, complete: count === value.length });
    }
  }
  globals.sort((a, b) => a.exportName.localeCompare(b.exportName));
  memories.sort((a, b) => a.exportName.localeCompare(b.exportName));
  tables.sort((a, b) => a.exportName.localeCompare(b.exportName));
  return { globals, memories, tables };
}

export async function executeNodeInvocationPlan(wasmPath: string, plan: InvocationPlan): Promise<RuntimeObservation> {
  const importTrace: RuntimeObservation["importTrace"] = [];
  const observation: RuntimeObservation = {
    schema: "starshine.runtime-observation.v1",
    instantiation: { kind: "instantiated" },
    calls: [],
    globals: [],
    memories: [],
    tables: [],
    importTrace,
  };
  let instance: WebAssembly.Instance;
  try {
    const module = await WebAssembly.compile(fs.readFileSync(wasmPath));
    instance = await WebAssembly.instantiate(module, deterministicImports(module, importTrace));
  } catch (error) {
    const trap = normalizeTrap(error);
    observation.instantiation = error instanceof WebAssembly.RuntimeError
      ? { kind: "trap", class: trap.class, detail: trap.detail }
      : { kind: "unsupported", reason: trap.detail };
    return observation;
  }

  for (let stepIndex = 0; stepIndex < plan.steps.length; stepIndex += 1) {
    const step = plan.steps[stepIndex];
    const exported = instance.exports[step.exportName];
    const args = step.args.map(argumentToJs);
    let outcome: RuntimeCallOutcome;
    if (typeof exported !== "function") {
      outcome = { kind: "unsupported", reason: `missing function export ${step.exportName}` };
    } else {
      try {
        const raw = exported(...args);
        const rawValues = Array.isArray(raw) ? raw : step.resultTypes.length === 0 ? [] : [raw];
        outcome = {
          kind: "return",
          values: rawValues.map((value, index) => runtimeValue(value, step.resultTypes[index] ?? "unknown")),
        };
      } catch (error) {
        const trap = normalizeTrap(error);
        outcome = { kind: "trap", class: trap.class, detail: trap.detail };
      }
    }
    observation.calls.push({
      stepIndex,
      exportName: step.exportName,
      args: step.args.map((arg, index) => runtimeValue(argumentToJs(arg), step.parameterTypes[index] ?? "unknown")),
      outcome,
    });
  }
  Object.assign(observation, observeExports(instance, BigInt(plan.seed)));
  return observation;
}

function isNaNBits(value: RuntimeBitValue): boolean {
  if (value.type === "f32" && /^[0-9a-f]{8}$/i.test(value.bits)) {
    const bits = Number.parseInt(value.bits, 16) >>> 0;
    return (bits & 0x7f800000) === 0x7f800000 && (bits & 0x007fffff) !== 0;
  }
  if (value.type === "f64" && /^[0-9a-f]{16}$/i.test(value.bits)) {
    const bits = BigInt(`0x${value.bits}`);
    return (bits & 0x7ff0000000000000n) === 0x7ff0000000000000n && (bits & 0x000fffffffffffffn) !== 0n;
  }
  return false;
}

function runtimeValuesEqual(left: RuntimeBitValue, right: RuntimeBitValue, policy: SemanticComparisonPolicy): boolean {
  if (left.type !== right.type) return false;
  if (policy === "canonical-nan" && isNaNBits(left) && isNaNBits(right)) return true;
  return left.bits.toLowerCase() === right.bits.toLowerCase();
}

function firstValueDifference(before: RuntimeObservation, after: RuntimeObservation, policy: SemanticComparisonPolicy): RuntimeObservationComparison["firstDifference"] {
  if (before.instantiation.kind !== after.instantiation.kind) {
    return { path: "instantiation.kind", before: before.instantiation, after: after.instantiation };
  }
  if (before.calls.length !== after.calls.length) return { path: "calls.length", before: before.calls.length, after: after.calls.length };
  for (let index = 0; index < before.calls.length; index += 1) {
    const left = before.calls[index];
    const right = after.calls[index];
    if (left.exportName !== right.exportName) return { path: `calls[${index}].exportName`, before: left.exportName, after: right.exportName };
    if (left.outcome.kind !== right.outcome.kind) return { path: `calls[${index}].outcome.kind`, before: left.outcome, after: right.outcome };
    if (left.outcome.kind === "trap" && right.outcome.kind === "trap" && left.outcome.class !== right.outcome.class) {
      return { path: `calls[${index}].outcome.trap`, before: left.outcome, after: right.outcome };
    }
    if (left.outcome.kind === "return" && right.outcome.kind === "return") {
      if (left.outcome.values.length !== right.outcome.values.length) {
        return { path: `calls[${index}].outcome.values.length`, before: left.outcome.values, after: right.outcome.values };
      }
      for (let valueIndex = 0; valueIndex < left.outcome.values.length; valueIndex += 1) {
        if (!runtimeValuesEqual(left.outcome.values[valueIndex], right.outcome.values[valueIndex], policy)) {
          return {
            path: `calls[${index}].outcome.values[${valueIndex}]`,
            before: left.outcome.values[valueIndex],
            after: right.outcome.values[valueIndex],
          };
        }
      }
    }
    if (left.outcome.kind === "unsupported" && right.outcome.kind === "unsupported" && left.outcome.reason !== right.outcome.reason) {
      return { path: `calls[${index}].outcome.unsupported`, before: left.outcome, after: right.outcome };
    }
  }
  const stateFields: ("globals" | "memories" | "tables" | "importTrace")[] = ["globals", "memories", "tables", "importTrace"];
  for (const field of stateFields) {
    if (JSON.stringify(before[field]) !== JSON.stringify(after[field])) return { path: field, before: before[field], after: after[field] };
  }
  return null;
}

function anyTrap(observation: RuntimeObservation): boolean {
  return observation.instantiation.kind === "trap" || observation.calls.some((call) => call.outcome.kind === "trap");
}

function anyUnsupported(observation: RuntimeObservation): boolean {
  return observation.instantiation.kind === "unsupported" || observation.calls.some((call) => call.outcome.kind === "unsupported");
}

export function compareRuntimeObservations(
  before: RuntimeObservation,
  after: RuntimeObservation,
  policy: SemanticComparisonPolicy,
): RuntimeObservationComparison {
  if (before.instantiation.kind === "tool-failure" || after.instantiation.kind === "tool-failure") {
    return { classification: "runtime-tool-failure", firstDifference: firstValueDifference(before, after, policy) };
  }
  if (anyUnsupported(before) || anyUnsupported(after)) {
    return { classification: "unsupported-runtime", firstDifference: firstValueDifference(before, after, policy) };
  }
  const difference = firstValueDifference(before, after, policy);
  if (difference === null) {
    return { classification: anyTrap(before) ? "equal-trap" : "equal-result", firstDifference: null };
  }
  if (anyTrap(before) || anyTrap(after)) return { classification: "trap-mismatch", firstDifference: difference };
  return { classification: "semantic-mismatch", firstDifference: difference };
}

async function executeNodeInvocationPlanWithTimeout(
  wasmPath: string,
  plan: InvocationPlan,
  timeoutMs: number,
): Promise<RuntimeObservation> {
  return await new Promise((resolve) => {
    const worker = new Worker(new URL("./optimizer-runtime-worker.ts", import.meta.url), {
      workerData: { wasmPath, plan },
    });
    worker.unref();
    let settled = false;
    const finish = (observation: RuntimeObservation) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      void worker.terminate();
      resolve(observation);
    };
    const timer = setTimeout(() => {
      finish({
        schema: "starshine.runtime-observation.v1",
        instantiation: { kind: "tool-failure", detail: `runtime timeout after ${timeoutMs}ms` },
        calls: [],
        globals: [],
        memories: [],
        tables: [],
        importTrace: [],
      });
    }, Math.max(1, timeoutMs));
    worker.on("message", (message: { ok: boolean; observation?: RuntimeObservation; detail?: string }) => {
      if (message.ok && message.observation) {
        finish(message.observation);
      } else {
        finish({
          schema: "starshine.runtime-observation.v1",
          instantiation: { kind: "tool-failure", detail: message.detail ?? "runtime worker failed" },
          calls: [],
          globals: [],
          memories: [],
          tables: [],
          importTrace: [],
        });
      }
    });
    worker.on("error", (error) => {
      finish({
        schema: "starshine.runtime-observation.v1",
        instantiation: { kind: "tool-failure", detail: error.message },
        calls: [],
        globals: [],
        memories: [],
        tables: [],
        importTrace: [],
      });
    });
  });
}

export async function runNodeSelfSemanticOracle(
  beforeWasmPath: string,
  afterWasmPath: string,
  options: {
    seed: bigint;
    policy?: SemanticComparisonPolicy;
    planOptions?: { maxExports?: number; maxCallsPerExport?: number };
    runtimeTimeoutMs?: number;
  },
): Promise<SelfSemanticOracleReport> {
  const policy = options.policy ?? "trap-aware";
  const plan = await buildDeterministicInvocationPlan(beforeWasmPath, options.seed, options.planOptions);
  const timeoutMs = options.runtimeTimeoutMs ?? 1000;
  const before = await executeNodeInvocationPlanWithTimeout(beforeWasmPath, plan, timeoutMs);
  const after = await executeNodeInvocationPlanWithTimeout(afterWasmPath, plan, timeoutMs);
  const comparison = compareRuntimeObservations(before, after, policy);
  return { schema: "starshine.semantic-self-report.v1", policy, plan, before, after, ...comparison };
}

function bytesEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  for (let index = 0; index < left.length; index += 1) if (left[index] !== right[index]) return false;
  return true;
}

export function classifyOptimizerDeterminism(
  left: Uint8Array,
  right: Uint8Array,
  canonical: { canonicalLeft?: Uint8Array; canonicalRight?: Uint8Array } = {},
): OptimizerDeterminismClassification {
  if (bytesEqual(left, right)) return "byte-stable";
  if (canonical.canonicalLeft && canonical.canonicalRight && bytesEqual(canonical.canonicalLeft, canonical.canonicalRight)) {
    return "canonical-stable-only";
  }
  return "optimizer-nondeterminism";
}

function splitmix64(seed: bigint): () => bigint {
  let state = BigInt.asUintN(64, seed);
  return () => {
    state = BigInt.asUintN(64, state + 0x9e3779b97f4a7c15n);
    let z = state;
    z = BigInt.asUintN(64, (z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n);
    z = BigInt.asUintN(64, (z ^ (z >> 27n)) * 0x94d049bb133111ebn);
    return BigInt.asUintN(64, z ^ (z >> 31n));
  };
}

export function generateRandomPassSequence(
  registry: readonly OptimizerPassRegistryEntry[],
  seed: bigint,
  profile: "random-short" | "random-medium" | "random-long" | "random-mixed",
): string[] {
  const eligible = registry.filter(
    (entry) => entry.executable && entry.compatible && (entry.category === "hot-pass" || entry.category === "module-pass"),
  );
  if (eligible.length === 0) return [];
  const random = splitmix64(seed);
  let length: number;
  switch (profile) {
    case "random-short":
      length = 1 + Number(random() % 5n);
      break;
    case "random-medium":
      length = 2 + Number(random() % 11n);
      break;
    case "random-long":
      length = 12 + Number(random() % 21n);
      break;
    case "random-mixed": {
      const bucket = Number(random() % 100n);
      length = bucket < 55 ? 1 + Number(random() % 5n) : bucket < 90 ? 6 + Number(random() % 7n) : 16 + Number(random() % 17n);
      break;
    }
  }
  const passes: string[] = [];
  for (let index = 0; index < length; index += 1) passes.push(eligible[Number(random() % BigInt(eligible.length))].name);
  return passes;
}

export function reducePassSequencePreservingFailureClass(
  original: readonly string[],
  failureClass: SemanticFailureClass,
  evaluate: (candidate: readonly string[]) => SemanticFailureClass | null,
): PassSequenceReductionReport {
  let current = Array.from(original);
  let chunkSize = 1;
  while (chunkSize * 2 <= current.length) chunkSize *= 2;
  let predicateEvaluations = 0;
  const steps: PassSequenceReductionStep[] = [];
  while (chunkSize >= 1) {
    let changed = false;
    for (let start = 0; start < current.length; ) {
      const end = Math.min(current.length, start + chunkSize);
      if (start === 0 && end === current.length) {
        start = end;
        continue;
      }
      const candidate = current.slice(0, start).concat(current.slice(end));
      predicateEvaluations += 1;
      if (evaluate(candidate) === failureClass) {
        const beforeSize = current.length;
        current = candidate;
        steps.push({ kind: "delete-pass-range", start, length: end - start, beforeSize, afterSize: current.length });
        changed = true;
        continue;
      }
      start = end;
    }
    if (!changed) chunkSize = Math.floor(chunkSize / 2);
  }
  return { passes: current, failureClass, predicateEvaluations, steps };
}

export async function reducePassSequencePreservingFailureClassAsync(
  original: readonly string[],
  failureClass: SemanticFailureClass,
  evaluate: (candidate: readonly string[]) => Promise<SemanticFailureClass | null>,
): Promise<PassSequenceReductionReport> {
  let current = Array.from(original);
  let chunkSize = 1;
  while (chunkSize * 2 <= current.length) chunkSize *= 2;
  let predicateEvaluations = 0;
  const steps: PassSequenceReductionStep[] = [];
  while (chunkSize >= 1) {
    let changed = false;
    for (let start = 0; start < current.length; ) {
      const end = Math.min(current.length, start + chunkSize);
      if (start === 0 && end === current.length) {
        start = end;
        continue;
      }
      const candidate = current.slice(0, start).concat(current.slice(end));
      predicateEvaluations += 1;
      if (await evaluate(candidate) === failureClass) {
        const beforeSize = current.length;
        current = candidate;
        steps.push({ kind: "delete-pass-range", start, length: end - start, beforeSize, afterSize: current.length });
        changed = true;
        continue;
      }
      start = end;
    }
    if (!changed) chunkSize = Math.floor(chunkSize / 2);
  }
  return { passes: current, failureClass, predicateEvaluations, steps };
}

export {
  buildInvocationPlanV2,
  classifyThreeWaySemanticComparison,
  compareRuntimeObservationsV2,
  emptyRuntimeObservationV2,
  normalizeRuntimeTrap,
  sha256RuntimeValue,
  stableRuntimeJson,
  type InvocationPlanV2,
  type RuntimeInterfaceV1,
  type RuntimeObservationV2,
  type SemanticComparisonV2,
  type TypedRuntimeValue,
} from "./optimizer-runtime";

export {
  runCommutatorProperty,
  runConvergenceProperty,
  runMetamorphicEquivalenceProperty,
  runSemanticIdempotenceProperty,
  type OptimizerPropertyResult,
  type PropertyHarness,
} from "./optimizer-properties";

export function runOptionalWasmReduce(options: {
  wasmReduceBin: string;
  inputPath: string;
  outputPath: string;
  predicateCommand: string[];
  cwd?: string;
}): OptionalWasmReduceResult {
  const probe = spawnSync(options.wasmReduceBin, ["--help"], { cwd: options.cwd, encoding: "utf8" });
  if (probe.error && (probe.error as NodeJS.ErrnoException).code === "ENOENT") {
    return { status: "unavailable", detail: `${options.wasmReduceBin} not available` };
  }
  if (probe.error) return { status: "failed", detail: probe.error.message, log: "" };
  const cwd = options.cwd ?? process.cwd();
  const inputPath = path.resolve(cwd, options.inputPath);
  const outputPath = path.resolve(cwd, options.outputPath);
  const testPath = `${outputPath}.test.wasm`;
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.copyFileSync(inputPath, testPath);
  fs.copyFileSync(inputPath, outputPath);
  const predicate = options.predicateCommand.join(" ");
  const args = [
    inputPath,
    "--command",
    predicate,
    "--test",
    testPath,
    "--working",
    outputPath,
    "--all-features",
  ];
  const result = spawnSync(options.wasmReduceBin, args, { cwd, encoding: "utf8", maxBuffer: 128 * 1024 * 1024 });
  const log = `${result.stdout ?? ""}${result.stderr ?? ""}`;
  fs.rmSync(testPath, { force: true });
  if (result.status !== 0 || !fs.existsSync(outputPath)) {
    return { status: "failed", detail: `wasm-reduce exited with ${String(result.status)}`, log };
  }
  return { status: "reduced", outputPath: options.outputPath, log };
}
