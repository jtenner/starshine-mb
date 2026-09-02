import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { Worker } from "node:worker_threads";

import {
  buildInvocationPlanV2,
  classifyThreeWaySemanticComparison,
  compareRuntimeObservationsV2,
  normalizeRuntimeTrap,
  sha256RuntimeValue,
  stableRuntimeJson,
  type InvocationPlanV2,
  type ObservationMode,
  type RuntimeImportEventV2,
  type RuntimeInterfaceV1,
  type RuntimeMemoryObservationV2,
  type RuntimeObservationStepV2,
  type RuntimeObservationV2,
  type RuntimeStateSnapshotV2,
  type RuntimeSupportClassification,
  type RuntimeTableObservationV2,
  type SemanticComparisonV2,
  type SemanticPolicy,
  type RuntimeFunctionSignature,
  type TypedRuntimeValue,
  type WasmRuntimeValueType,
} from "./optimizer-runtime";

export type NodeObservationV2Options = {
  mode: ObservationMode;
  timeoutMs: number;
  memoryCapBytes: number;
  tableEntryCap: number;
  seed?: bigint;
  wasmToolsBin?: string;
};

export type NodeThreeWaySemanticOracleV2Report = {
  schema: "starshine.optimizer-three-way-runtime-report.v1";
  timings: {
    runtimeInterfaceMs: number;
    invocationPlanMs: number;
    originalObservationMs: number;
    starshineObservationMs: number;
    binaryenObservationMs: number;
    comparisonMs: number;
    totalMs: number;
  };
  runtimeInterface: RuntimeInterfaceV1;
  plan: InvocationPlanV2;
  original: RuntimeObservationV2;
  starshine: RuntimeObservationV2;
  binaryen: RuntimeObservationV2 | null;
  originalVsStarshine: SemanticComparisonV2;
  originalVsBinaryen: SemanticComparisonV2 | null;
  starshineVsBinaryen: SemanticComparisonV2 | null;
  classification: ReturnType<typeof classifyThreeWaySemanticComparison>;
};

type ResourceTypeMaps = {
  functions: Map<number, RuntimeFunctionSignature>;
  globals: Map<number, { valueType: WasmRuntimeValueType; mutable: boolean }>;
  memories: Map<number, { indexType: "i32" | "i64"; minimum: string; maximum: string | null; shared: boolean; memory64: boolean }>;
  tables: Map<number, { elementType: WasmRuntimeValueType; nullable: boolean; minimum: string; maximum: string | null }>;
};

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

function decodedString(raw: string): string {
  return JSON.parse(`"${raw}"`) as string;
}

function numericIndex(form: string): number | null {
  const match = /\(;\s*(\d+)\s*;\)/.exec(form);
  return match ? Number(match[1]) : null;
}

function typeTokens(form: string, field: "param" | "result"): WasmRuntimeValueType[] {
  const out: WasmRuntimeValueType[] = [];
  const regex = new RegExp(`\\(${field}\\s+([^)]*)\\)`, "g");
  for (const match of form.matchAll(regex)) {
    const raw = match[1].trim();
    if (raw.length === 0) continue;
    for (const token of raw.split(/\s+/)) {
      if (token.startsWith("$")) continue;
      out.push(token);
    }
  }
  return out;
}

function signatureFromForm(form: string, types: Map<number, RuntimeFunctionSignature>): RuntimeFunctionSignature {
  const direct = { params: typeTokens(form, "param"), results: typeTokens(form, "result") };
  if (direct.params.length > 0 || direct.results.length > 0) return direct;
  const typeUse = /\(type\s+(\d+)\)/.exec(form);
  return typeUse ? types.get(Number(typeUse[1])) ?? direct : direct;
}

function signatureSupport(signature: RuntimeFunctionSignature): RuntimeSupportClassification {
  const all = [...signature.params, ...signature.results];
  if (all.some((type) => type === "v128")) return "scalar-adapter";
  if (all.some((type) => isUnsupportedReferenceType(type))) return "unsupported";
  if (all.some((type) => isReferenceType(type))) return "retained-fixture";
  return "directly-constructible";
}

function isReferenceType(type: WasmRuntimeValueType): boolean {
  return type.endsWith("ref") || type.includes("(ref") || type === "ref";
}

function isUnsupportedReferenceType(type: WasmRuntimeValueType): boolean {
  if (!isReferenceType(type)) return false;
  if (["funcref", "externref", "anyref", "eqref", "i31ref", "structref", "arrayref"].includes(type)) return false;
  return !type.includes("ref null");
}

function globalTypeFromForm(form: string): { valueType: WasmRuntimeValueType; mutable: boolean } {
  const mutable = /\(mut\s+([^\s)]+)\)/.exec(form);
  if (mutable) return { valueType: mutable[1], mutable: true };
  const tail = /\bglobal\s+(?:\(;\s*\d+\s*;\)\s+)?(?:\$[^\s()]+\s+)?([^\s()]+)/.exec(form);
  return { valueType: tail?.[1] ?? "unknown", mutable: false };
}

function memoryTypeFromForm(form: string): ResourceTypeMaps["memories"] extends Map<number, infer T> ? T : never {
  const header = form.slice(0, form.indexOf("\n") >= 0 ? form.indexOf("\n") : form.length);
  const stripped = header
    .replace(/^\(import\s+"(?:\\.|[^"])*"\s+"(?:\\.|[^"])*"\s+/, "")
    .replace(/^\(memory\s+/, "")
    .replace(/^\(;\s*\d+\s*;\)\s*/, "")
    .replace(/[()]/g, " ");
  const tokens = stripped.trim().split(/\s+/).filter(Boolean);
  const memory64 = tokens.includes("i64");
  const shared = tokens.includes("shared");
  const limits = tokens.filter((token) => /^\d+$/.test(token));
  return {
    indexType: memory64 ? "i64" : "i32",
    minimum: limits[0] ?? "0",
    maximum: limits[1] ?? null,
    shared,
    memory64,
  };
}

function tableTypeFromForm(form: string): ResourceTypeMaps["tables"] extends Map<number, infer T> ? T : never {
  const header = form.slice(0, form.indexOf("\n") >= 0 ? form.indexOf("\n") : form.length);
  const stripped = header
    .replace(/^\(import\s+"(?:\\.|[^"])*"\s+"(?:\\.|[^"])*"\s+/, "")
    .replace(/^\(table\s+/, "")
    .replace(/^\(;\s*\d+\s*;\)\s*/, "")
    .replace(/[()]/g, " ");
  const tokens = stripped.trim().split(/\s+/).filter(Boolean);
  const limits = tokens.filter((token) => /^\d+$/.test(token));
  const elementType = tokens.findLast((token) => token.endsWith("ref")) ?? "funcref";
  return {
    elementType,
    nullable: elementType === "funcref" || elementType === "externref" || form.includes("ref null"),
    minimum: limits[0] ?? "0",
    maximum: limits[1] ?? null,
  };
}

function supportForGlobal(valueType: WasmRuntimeValueType): RuntimeSupportClassification {
  if (valueType === "v128") return "scalar-adapter";
  if (isUnsupportedReferenceType(valueType)) return "unsupported";
  if (isReferenceType(valueType)) return "retained-fixture";
  return ["i32", "i64", "f32", "f64"].includes(valueType) ? "directly-constructible" : "unsupported";
}

function supportForMemory(memory: { memory64: boolean }): RuntimeSupportClassification {
  return memory.memory64 ? "unsupported" : "directly-constructible";
}

function supportForTable(table: { elementType: WasmRuntimeValueType }): RuntimeSupportClassification {
  return ["funcref", "externref", "anyref", "eqref", "i31ref", "structref", "arrayref"].includes(table.elementType)
    ? "directly-constructible"
    : "unsupported";
}

function printedWasm(wasmPath: string, wasmToolsBin: string): string {
  const result = spawnSync(wasmToolsBin, ["print", wasmPath], {
    encoding: "utf8",
    maxBuffer: 128 * 1024 * 1024,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || "wasm-tools print failed");
  return result.stdout;
}

export type RuntimeInterfaceCommandResult = { status: number | null; stdout: string; stderr: string; error?: Error };

export function buildRuntimeInterfaceFromStarshine(
  wasmPath: string,
  starshineBin: string,
  run: (bin: string, args: string[]) => RuntimeInterfaceCommandResult = (bin, args) => {
    const result = spawnSync(bin, args, { encoding: "utf8" });
    return { status: result.status, stdout: result.stdout ?? "", stderr: result.stderr ?? "", error: result.error };
  },
  argsPrefix: string[] = [],
): RuntimeInterfaceV1 {
  const command = run(starshineBin, [...argsPrefix, "--emit-runtime-interface-json", wasmPath]);
  if (command.error != null) throw new Error(`failed to run Starshine runtime-interface report: ${command.error.message}`);
  if (command.status !== 0) throw new Error(`Starshine runtime-interface report failed: ${command.stderr || command.stdout || `exit ${command.status}`}`);
  let report: RuntimeInterfaceV1;
  try {
    report = JSON.parse(command.stdout) as RuntimeInterfaceV1;
  } catch (error) {
    throw new Error(`invalid Starshine runtime-interface JSON: ${error instanceof Error ? error.message : String(error)}`);
  }
  if (report.schema !== "starshine.optimizer-runtime-interface.v1") throw new Error(`unsupported Starshine runtime-interface schema ${(report as { schema?: string }).schema ?? "missing"}`);
  if (!Array.isArray(report.features) || !Array.isArray(report.exports) || report.imports == null) throw new Error("malformed Starshine runtime-interface report");
  return report;
}

export function buildRuntimeInterfaceFromWasm(wasmPath: string, wasmToolsBin = "wasm-tools"): RuntimeInterfaceV1 {
  const bytes = fs.readFileSync(wasmPath);
  const text = printedWasm(wasmPath, wasmToolsBin);
  const forms = splitTopLevelForms(text);
  const types = new Map<number, RuntimeFunctionSignature>();
  for (const form of forms) {
    if (!form.startsWith("(type ") || !form.includes("(func")) continue;
    const index = numericIndex(form);
    if (index !== null) types.set(index, { params: typeTokens(form, "param"), results: typeTokens(form, "result") });
  }

  const resources: ResourceTypeMaps = {
    functions: new Map(),
    globals: new Map(),
    memories: new Map(),
    tables: new Map(),
  };
  const symbolicIndices = {
    function: new Map<string, number>(),
    global: new Map<string, number>(),
    memory: new Map<string, number>(),
    table: new Map<string, number>(),
  };
  for (const form of forms) {
    for (const [printedKind, schemaKind] of [["func", "function"], ["global", "global"], ["memory", "memory"], ["table", "table"]] as const) {
      const match = new RegExp(`\\(${printedKind}\\s+(\\$[^\\s()]+)\\s+\\(;\\s*(\\d+)\\s*;\\)`).exec(form);
      if (match) symbolicIndices[schemaKind].set(match[1], Number(match[2]));
    }
  }
  const imports: RuntimeInterfaceV1["imports"] = { functions: [], globals: [], memories: [], tables: [], tags: [] };

  for (const form of forms) {
    if (form.startsWith("(import ")) {
      const importMatch = /^\(import\s+"((?:\\.|[^"])*)"\s+"((?:\\.|[^"])*)"/.exec(form);
      const index = numericIndex(form);
      if (!importMatch || index === null) continue;
      const module = decodedString(importMatch[1]);
      const field = decodedString(importMatch[2]);
      if (form.includes("(func ")) {
        const signature = signatureFromForm(form, types);
        resources.functions.set(index, signature);
        imports.functions.push({ module, field, index, signature, support: signatureSupport(signature) });
      } else if (form.includes("(global ")) {
        const global = globalTypeFromForm(form.slice(form.indexOf("(global ")));
        resources.globals.set(index, global);
        imports.globals.push({ module, field, index, ...global, support: supportForGlobal(global.valueType) });
      } else if (form.includes("(memory ")) {
        const memory = memoryTypeFromForm(form.slice(form.indexOf("(memory ")));
        resources.memories.set(index, memory);
        imports.memories.push({ module, field, index, ...memory, support: supportForMemory(memory) });
      } else if (form.includes("(table ")) {
        const table = tableTypeFromForm(form.slice(form.indexOf("(table ")));
        resources.tables.set(index, table);
        imports.tables.push({ module, field, index, ...table, support: supportForTable(table) });
      } else if (form.includes("(tag ")) {
        const signature = signatureFromForm(form.slice(form.indexOf("(tag ")), types);
        imports.tags?.push({ module, field, index, signature, support: signatureSupport(signature) });
      }
      continue;
    }
    const index = numericIndex(form);
    if (index === null) continue;
    if (form.startsWith("(func ")) resources.functions.set(index, signatureFromForm(form, types));
    else if (form.startsWith("(global ")) resources.globals.set(index, globalTypeFromForm(form));
    else if (form.startsWith("(memory ")) resources.memories.set(index, memoryTypeFromForm(form));
    else if (form.startsWith("(table ")) resources.tables.set(index, tableTypeFromForm(form));
  }

  const exports: RuntimeInterfaceV1["exports"] = [];
  for (const form of forms) {
    const match = /^\(export\s+"((?:\\.|[^"])*)"\s+\((func|global|memory|table|tag)\s+([^\s)]+)\)\s*\)$/s.exec(form.trim());
    if (!match) continue;
    const name = decodedString(match[1]);
    const printedKind = match[2];
    const kind = (printedKind === "func" ? "function" : printedKind) as RuntimeInterfaceV1["exports"][number]["kind"];
    const reference = match[3];
    const index = /^\d+$/.test(reference)
      ? Number(reference)
      : kind === "tag"
        ? -1
        : symbolicIndices[kind].get(reference) ?? -1;
    if (kind === "function") {
      const signature = resources.functions.get(index) ?? { params: [], results: [] };
      exports.push({ name, kind, index, signature, support: signatureSupport(signature) });
    } else if (kind === "global") {
      const globalType = resources.globals.get(index) ?? { valueType: "unknown", mutable: false };
      exports.push({ name, kind, index, globalType, support: supportForGlobal(globalType.valueType) });
    } else if (kind === "memory") {
      const memory = resources.memories.get(index);
      exports.push({ name, kind, index, support: memory ? supportForMemory(memory) : "unsupported" });
    } else if (kind === "table") {
      const table = resources.tables.get(index);
      exports.push({ name, kind, index, support: table ? supportForTable(table) : "unsupported" });
    } else {
      exports.push({ name, kind, index, support: "unsupported" });
    }
  }

  const features = new Set<string>();
  if (imports.functions.length + imports.globals.length + imports.memories.length + imports.tables.length + (imports.tags?.length ?? 0) > 0) features.add("imports");
  if ((imports.tags?.length ?? 0) > 0) features.add("exceptions");
  if (forms.some((form) => form.startsWith("(start "))) features.add("start");
  if ([...resources.functions.values()].some((signature) => [...signature.params, ...signature.results].includes("v128"))) features.add("simd");
  if ([...resources.memories.values()].some((memory) => memory.memory64)) features.add("memory64");
  if ([...resources.memories.values()].some((memory) => memory.shared)) features.add("threads");
  if (resources.memories.size > 1) features.add("multi-memory");
  if (resources.tables.size > 1) features.add("multi-table");
  if ([...resources.globals.values()].some((global) => isReferenceType(global.valueType)) || [...resources.tables.values()].some((table) => isReferenceType(table.elementType))) features.add("reference-types");

  const interfaceBody = {
    schema: "starshine.optimizer-runtime-interface.v1" as const,
    features: [...features].sort(),
    hasStart: forms.some((form) => form.startsWith("(start ")),
    imports,
    exports,
  };
  return {
    ...interfaceBody,
    moduleHash: `sha256:${crypto.createHash("sha256").update(bytes).digest("hex")}`,
    interfaceHash: sha256RuntimeValue(interfaceBody),
  };
}

function typedI32(value: number): TypedRuntimeValue {
  const signed = value | 0;
  return { type: "i32", signed, bits: `0x${(signed >>> 0).toString(16).padStart(8, "0")}` };
}

function typedI64(value: bigint): TypedRuntimeValue {
  const signed = BigInt.asIntN(64, value);
  return { type: "i64", signed: signed.toString(), bits: `0x${BigInt.asUintN(64, signed).toString(16).padStart(16, "0")}` };
}

function typedFloat(type: "f32" | "f64", value: number): TypedRuntimeValue {
  const buffer = new ArrayBuffer(type === "f32" ? 4 : 8);
  const view = new DataView(buffer);
  if (type === "f32") view.setFloat32(0, value, false);
  else view.setFloat64(0, value, false);
  const raw = type === "f32" ? BigInt(view.getUint32(0, false)) : view.getBigUint64(0, false);
  const width = type === "f32" ? 32n : 64n;
  const exponentBits = type === "f32" ? 8n : 11n;
  const fractionBits = width - exponentBits - 1n;
  const exponentMask = (1n << exponentBits) - 1n;
  const fractionMask = (1n << fractionBits) - 1n;
  const exponent = (raw >> fractionBits) & exponentMask;
  const fraction = raw & fractionMask;
  const sign = ((raw >> (width - 1n)) & 1n) === 0n ? "+" : "-";
  const klass = exponent === 0n
    ? fraction === 0n ? "zero" : "subnormal"
    : exponent === exponentMask
      ? fraction === 0n ? "infinity" : "nan"
      : "normal";
  const bits = `0x${raw.toString(16).padStart(type === "f32" ? 8 : 16, "0")}`;
  if (klass === "nan") {
    const quietMask = 1n << (fractionBits - 1n);
    return { type, bits, class: klass, sign, quiet: (fraction & quietMask) !== 0n, payload: `0x${fraction.toString(16)}` };
  }
  return { type, bits, class: klass, sign };
}

function typedReference(value: unknown, wasmType: string, relations: Map<object, string>): TypedRuntimeValue {
  if (value === null) return { type: "reference", relation: "null", wasmType };
  if ((typeof value === "object" && value !== null) || typeof value === "function") {
    const object = value as object;
    let relation = relations.get(object);
    if (!relation) {
      relation = `${typeof value === "function" ? "funcref" : "externref"}:${relations.size}`;
      relations.set(object, relation);
    }
    return { type: "reference", relation, wasmType };
  }
  return { type: "reference", relation: `primitive:${typeof value}:${String(value)}`, wasmType };
}

function typedFromJs(value: unknown, wasmType: WasmRuntimeValueType, relations: Map<object, string>): TypedRuntimeValue {
  switch (wasmType) {
    case "i32": return typedI32(Number(value));
    case "i64": return typedI64(BigInt(value as bigint));
    case "f32": return typedFloat("f32", Number(value));
    case "f64": return typedFloat("f64", Number(value));
    default: return typedReference(value, wasmType, relations);
  }
}

function jsFromTyped(value: TypedRuntimeValue): unknown {
  if (value.type === "i32") return value.signed;
  if (value.type === "i64") return BigInt(value.signed);
  if (value.type === "reference") return value.relation === "null" ? null : { relation: value.relation };
  const buffer = new ArrayBuffer(value.type === "f32" ? 4 : 8);
  const view = new DataView(buffer);
  if (value.type === "f32") {
    view.setUint32(0, Number(BigInt(value.bits)), false);
    return view.getFloat32(0, false);
  }
  view.setBigUint64(0, BigInt(value.bits), false);
  return view.getFloat64(0, false);
}

function zeroJsValue(type: WasmRuntimeValueType): unknown {
  if (type === "i64") return 0n;
  if (type === "i32" || type === "f32" || type === "f64") return 0;
  return null;
}

function signatureHasV128(signature: RuntimeFunctionSignature): boolean {
  return [...signature.params, ...signature.results].includes("v128");
}

function flattenedTypes(types: WasmRuntimeValueType[]): WasmRuntimeValueType[] {
  return types.flatMap((type) => type === "v128" ? ["i64", "i64"] : [type]);
}

function formatWatTypes(keyword: "param" | "result" | "local", types: WasmRuntimeValueType[]): string {
  return types.length === 0 ? "" : `(${keyword} ${types.join(" ")})`;
}

function scalarAdapterWat(signature: RuntimeFunctionSignature): string {
  const flatParams = flattenedTypes(signature.params);
  const flatResults = flattenedTypes(signature.results);
  const resultLocals = signature.results;
  const lines = [
    "(module",
    `  (import \"host\" \"target\" (func $target ${formatWatTypes("param", signature.params)} ${formatWatTypes("result", signature.results)}))`,
    `  (func (export \"call\") ${formatWatTypes("param", flatParams)} ${formatWatTypes("result", flatResults)}`,
    ...(resultLocals.length === 0 ? [] : [`    ${formatWatTypes("local", resultLocals)}`]),
  ];
  let flatParamIndex = 0;
  for (const type of signature.params) {
    if (type === "v128") {
      lines.push(
        `    local.get ${flatParamIndex}`,
        "    i64x2.splat",
        `    local.get ${flatParamIndex + 1}`,
        "    i64x2.replace_lane 1",
      );
      flatParamIndex += 2;
    } else {
      lines.push(`    local.get ${flatParamIndex}`);
      flatParamIndex += 1;
    }
  }
  lines.push("    call $target");
  const localBase = flatParams.length;
  for (let index = signature.results.length - 1; index >= 0; index -= 1) {
    lines.push(`    local.set ${localBase + index}`);
  }
  for (let index = 0; index < signature.results.length; index += 1) {
    const type = signature.results[index];
    if (type === "v128") {
      lines.push(
        `    local.get ${localBase + index}`,
        "    i64x2.extract_lane 0",
        `    local.get ${localBase + index}`,
        "    i64x2.extract_lane 1",
      );
    } else {
      lines.push(`    local.get ${localBase + index}`);
    }
  }
  lines.push("  )", ")");
  return lines.join("\n");
}

async function instantiateScalarAdapter(
  target: (...args: unknown[]) => unknown,
  signature: RuntimeFunctionSignature,
  wasmToolsBin: string,
): Promise<(...args: unknown[]) => unknown> {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-v128-adapter-"));
  const watPath = path.join(directory, "adapter.wat");
  const wasmPath = path.join(directory, "adapter.wasm");
  try {
    fs.writeFileSync(watPath, scalarAdapterWat(signature));
    const parsed = spawnSync(wasmToolsBin, ["parse", watPath, "--output", wasmPath], {
      encoding: "utf8",
      maxBuffer: 16 * 1024 * 1024,
    });
    if (parsed.error || parsed.status !== 0) {
      throw new Error(parsed.error?.message ?? parsed.stderr ?? parsed.stdout ?? "v128 adapter parse failed");
    }
    const module = await WebAssembly.compile(fs.readFileSync(wasmPath));
    const instance = await WebAssembly.instantiate(module, { host: { target } });
    const call = instance.exports.call;
    if (typeof call !== "function") throw new Error("v128 adapter missing call export");
    return call as (...args: unknown[]) => unknown;
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

function flattenAdapterArguments(values: TypedRuntimeValue[]): unknown[] {
  return values.flatMap((value) => {
    if (value.type !== "v128") return [jsFromTyped(value)];
    const hex = value.bits.replace(/^0x/, "").padStart(32, "0");
    return [BigInt(`0x${hex.slice(0, 16)}`), BigInt(`0x${hex.slice(16)}`)];
  });
}

function importAdapterWat(signature: RuntimeFunctionSignature): string {
  const flatParams = flattenedTypes(signature.params);
  const flatResults = flattenedTypes(signature.results);
  const lines = [
    "(module",
    `  (import \"host\" \"call\" (func $call ${formatWatTypes("param", flatParams)} ${formatWatTypes("result", flatResults)}))`,
    `  (func (export \"target\") ${formatWatTypes("param", signature.params)} ${formatWatTypes("result", signature.results)}`,
    ...(flatResults.length === 0 ? [] : [`    ${formatWatTypes("local", flatResults)}`]),
  ];
  for (let index = 0; index < signature.params.length; index += 1) {
    if (signature.params[index] === "v128") {
      lines.push(
        `    local.get ${index}`,
        "    i64x2.extract_lane 0",
        `    local.get ${index}`,
        "    i64x2.extract_lane 1",
      );
    } else {
      lines.push(`    local.get ${index}`);
    }
  }
  lines.push("    call $call");
  const localBase = signature.params.length;
  for (let index = flatResults.length - 1; index >= 0; index -= 1) {
    lines.push(`    local.set ${localBase + index}`);
  }
  let flatResultIndex = 0;
  for (const type of signature.results) {
    if (type === "v128") {
      lines.push(
        `    local.get ${localBase + flatResultIndex}`,
        "    i64x2.splat",
        `    local.get ${localBase + flatResultIndex + 1}`,
        "    i64x2.replace_lane 1",
      );
      flatResultIndex += 2;
    } else {
      lines.push(`    local.get ${localBase + flatResultIndex}`);
      flatResultIndex += 1;
    }
  }
  lines.push("  )", ")");
  return lines.join("\n");
}

function defaultTypedValue(type: WasmRuntimeValueType): TypedRuntimeValue {
  if (type === "i32") return typedI32(0);
  if (type === "i64") return typedI64(0n);
  if (type === "f32") return typedFloat("f32", 0);
  if (type === "f64") return typedFloat("f64", 0);
  if (type === "v128") return { type: "v128", bits: "0x00000000000000000000000000000000" };
  return { type: "reference", relation: "null", wasmType: type };
}

async function instantiateImportScalarAdapter(
  imported: RuntimeInterfaceV1["imports"]["functions"][number],
  trace: RuntimeImportEventV2[],
  context: TraceContext,
  relations: Map<object, string>,
  wasmToolsBin: string,
): Promise<(...args: unknown[]) => unknown> {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-v128-import-adapter-"));
  const watPath = path.join(directory, "adapter.wat");
  const wasmPath = path.join(directory, "adapter.wasm");
  try {
    fs.writeFileSync(watPath, importAdapterWat(imported.signature));
    const parsed = spawnSync(wasmToolsBin, ["parse", watPath, "--output", wasmPath], {
      encoding: "utf8",
      maxBuffer: 16 * 1024 * 1024,
    });
    if (parsed.error || parsed.status !== 0) {
      throw new Error(parsed.error?.message ?? parsed.stderr ?? parsed.stdout ?? "v128 import adapter parse failed");
    }
    const module = await WebAssembly.compile(fs.readFileSync(wasmPath));
    const hostCall = (...flatArgs: unknown[]): unknown => {
      const argumentsTyped = adapterResultValues(
        flatArgs,
        { params: [], results: imported.signature.params },
        relations,
      );
      const resultsTyped = imported.signature.results.map((type) => {
        const matching = imported.signature.params.findIndex((parameter) => parameter === type);
        return matching >= 0 ? argumentsTyped[matching] : defaultTypedValue(type);
      });
      trace.push({
        module: imported.module,
        field: imported.field,
        ordinal: context.ordinal++,
        phase: context.phase,
        stepIndex: context.stepIndex,
        arguments: argumentsTyped,
        results: resultsTyped,
      });
      const flattened = flattenAdapterArguments(resultsTyped);
      return flattened.length === 0 ? undefined : flattened.length === 1 ? flattened[0] : flattened;
    };
    const instance = await WebAssembly.instantiate(module, { host: { call: hostCall } });
    const target = instance.exports.target;
    if (typeof target !== "function") throw new Error("v128 import adapter missing target export");
    return target as (...args: unknown[]) => unknown;
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

function adapterResultValues(
  raw: unknown,
  signature: RuntimeFunctionSignature,
  relations: Map<object, string>,
): TypedRuntimeValue[] {
  const flatTypes = flattenedTypes(signature.results);
  const flatValues = flatTypes.length === 0 ? [] : flatTypes.length === 1 ? [raw] : raw as unknown[];
  const values: TypedRuntimeValue[] = [];
  let offset = 0;
  for (const type of signature.results) {
    if (type === "v128") {
      const lane0 = BigInt.asUintN(64, BigInt(flatValues[offset] as bigint));
      const lane1 = BigInt.asUintN(64, BigInt(flatValues[offset + 1] as bigint));
      values.push({
        type: "v128",
        bits: `0x${lane0.toString(16).padStart(16, "0")}${lane1.toString(16).padStart(16, "0")}`,
      });
      offset += 2;
    } else {
      values.push(typedFromJs(flatValues[offset], type, relations));
      offset += 1;
    }
  }
  return values;
}

function deterministicResult(signature: RuntimeFunctionSignature, args: unknown[]): unknown {
  const results = signature.results.map((type) => {
    const matching = signature.params.findIndex((parameter) => parameter === type);
    return matching >= 0 ? args[matching] : zeroJsValue(type);
  });
  return results.length === 0 ? undefined : results.length === 1 ? results[0] : results;
}

function mixFuzzInput64(seed: bigint, channel: bigint, salt: bigint): bigint {
  let value = BigInt.asUintN(64, seed ^ (channel * 0x9e3779b97f4a7c15n) ^ salt);
  value = BigInt.asUintN(64, (value ^ (value >> 30n)) * 0xbf58476d1ce4e5b9n);
  value = BigInt.asUintN(64, (value ^ (value >> 27n)) * 0x94d049bb133111ebn);
  return BigInt.asUintN(64, value ^ (value >> 31n));
}

function fuzzAbiResult(
  imported: RuntimeInterfaceV1["imports"]["functions"][number],
  args: unknown[],
  seed: bigint,
): unknown {
  if (imported.module !== "__fuzz" || args.length !== 1 || typeof args[0] !== "number") {
    return deterministicResult(imported.signature, args);
  }
  const channel = BigInt(args[0] >>> 0);
  if (imported.field === "input_i32" && imported.signature.results.length === 1 && imported.signature.results[0] === "i32") {
    return Number(BigInt.asIntN(32, mixFuzzInput64(seed, channel, 0x693332n)));
  }
  if (imported.field === "input_i64" && imported.signature.results.length === 1 && imported.signature.results[0] === "i64") {
    return BigInt.asIntN(64, mixFuzzInput64(seed, channel, 0x693634n));
  }
  return deterministicResult(imported.signature, args);
}

function sha256Bytes(bytes: Uint8Array): string {
  return `sha256:${crypto.createHash("sha256").update(bytes).digest("hex")}`;
}

function memoryObservation(index: number, names: string[], memory: WebAssembly.Memory, cap: number): RuntimeMemoryObservationV2 {
  const bytes = new Uint8Array(memory.buffer);
  if (bytes.byteLength > cap) {
    return {
      index,
      names,
      byteLength: bytes.byteLength,
      complete: false,
      hash: "blocked:memory-over-cap",
      chunkHashes: [],
      diagnosticSamples: [],
    };
  }
  const chunkHashes: string[] = [];
  for (let offset = 0; offset < bytes.byteLength; offset += 64 * 1024) {
    chunkHashes.push(sha256Bytes(bytes.subarray(offset, Math.min(bytes.byteLength, offset + 64 * 1024))));
  }
  const samples = bytes.byteLength === 0
    ? []
    : [...new Set([0, Math.max(0, bytes.byteLength - 32)])].map((offset) => ({
        offset,
        bytes: Buffer.from(bytes.subarray(offset, Math.min(bytes.byteLength, offset + 32))).toString("hex"),
      }));
  return { index, names, byteLength: bytes.byteLength, complete: true, hash: sha256Bytes(bytes), chunkHashes, diagnosticSamples: samples };
}

function tableObservation(
  index: number,
  names: string[],
  table: WebAssembly.Table,
  cap: number,
  relations: Map<object, string>,
  staticRelations: Map<number, string> | undefined,
): RuntimeTableObservationV2 {
  const complete = table.length <= cap;
  const count = complete ? table.length : 0;
  const entries: RuntimeTableObservationV2["entries"] = [];
  for (let entryIndex = 0; entryIndex < count; entryIndex += 1) {
    entries.push({
      index: entryIndex,
      relation: staticRelations?.get(entryIndex) ?? typedReference(table.get(entryIndex), "funcref", relations).relation,
    });
  }
  return { index, names, length: table.length, complete, entries };
}

type RuntimeResources = {
  globals: Map<number, WebAssembly.Global>;
  memories: Map<number, WebAssembly.Memory>;
  tables: Map<number, WebAssembly.Table>;
  staticTableRelations: Map<number, Map<number, string>>;
};

type RuntimeInstance = {
  instance: WebAssembly.Instance;
  resources: RuntimeResources;
};

class RuntimeInstantiationFailure extends Error {
  constructor(
    message: string,
    readonly original: unknown,
    readonly resources: RuntimeResources,
  ) {
    super(message);
    this.name = "RuntimeInstantiationFailure";
  }
}

function staticTableRelationsFromWasm(
  wasmPath: string,
  wasmToolsBin: string,
): Map<number, Map<number, string>> {
  const text = printedWasm(wasmPath, wasmToolsBin);
  if (/\btable\.(?:set|init|copy|fill)\b/.test(text) || /^\s*\(import[^\n]*\(table\b/m.test(text)) {
    return new Map();
  }
  const forms = splitTopLevelForms(text);
  const tableSymbols = new Map<string, number>();
  const functionSymbols = new Map<string, number>();
  const tableIndices: number[] = [];
  for (const form of forms) {
    const index = numericIndex(form);
    if (index === null) continue;
    const table = /^\(table\s+(\$[^\s()]+)\s+/.exec(form);
    if (table) {
      tableSymbols.set(table[1], index);
      tableIndices.push(index);
    }
    const func = /^\(func\s+(\$[^\s()]+)\s+/.exec(form);
    if (func) functionSymbols.set(func[1], index);
  }
  const resolveIndex = (token: string, symbols: Map<string, number>): number | null => {
    if (/^\d+$/.test(token)) return Number(token);
    return symbols.get(token) ?? null;
  };
  const result = new Map<number, Map<number, string>>();
  for (const form of forms) {
    if (!form.startsWith("(elem ")) continue;
    const normalized = form.replace(/\s+/g, " ").trim();
    const explicit = /\(table\s+([^\s)]+)\)\s+\(i32\.const\s+(\d+)\)\s+func\s+(.+)\)$/.exec(normalized);
    const implicit = explicit === null
      ? /\(i32\.const\s+(\d+)\)\s+func\s+(.+)\)$/.exec(normalized)
      : null;
    const tableIndex = explicit !== null
      ? resolveIndex(explicit[1], tableSymbols)
      : tableIndices.length === 1 ? tableIndices[0] : 0;
    const offset = Number(explicit?.[2] ?? implicit?.[1] ?? NaN);
    const rawFunctions = explicit?.[3] ?? implicit?.[2];
    if (tableIndex === null || !Number.isInteger(offset) || rawFunctions === undefined) continue;
    const entries = result.get(tableIndex) ?? new Map<number, string>();
    const tokens = rawFunctions.split(/\s+/).filter(Boolean);
    for (let index = 0; index < tokens.length; index += 1) {
      const functionIndex = resolveIndex(tokens[index], functionSymbols);
      if (functionIndex !== null) entries.set(offset + index, `funcidx:${functionIndex}`);
    }
    result.set(tableIndex, entries);
  }
  return result;
}

type TraceContext = {
  phase: RuntimeImportEventV2["phase"];
  stepIndex: number | null;
  ordinal: number;
};

function exportedNames(runtimeInterface: RuntimeInterfaceV1, kind: "global" | "memory" | "table", index: number): string[] {
  return runtimeInterface.exports.filter((entry) => entry.kind === kind && entry.index === index).map((entry) => entry.name).sort();
}

async function instantiateRuntime(
  module: WebAssembly.Module,
  runtimeInterface: RuntimeInterfaceV1,
  trace: RuntimeImportEventV2[],
  context: TraceContext,
  wasmToolsBin: string,
  staticTableRelations: Map<number, Map<number, string>>,
  seed: bigint,
): Promise<RuntimeInstance> {
  const imports: Record<string, Record<string, unknown>> = {};
  const globals = new Map<number, WebAssembly.Global>();
  const memories = new Map<number, WebAssembly.Memory>();
  const tables = new Map<number, WebAssembly.Table>();
  const relations = new Map<object, string>();
  for (const imported of runtimeInterface.imports.functions) {
    const namespace = (imports[imported.module] ??= {});
    if (signatureHasV128(imported.signature)) {
      namespace[imported.field] = await instantiateImportScalarAdapter(
        imported,
        trace,
        context,
        relations,
        wasmToolsBin,
      );
    } else {
      namespace[imported.field] = (...args: unknown[]) => {
        const rawResult = fuzzAbiResult(imported, args, seed);
        const rawResults = imported.signature.results.length === 0 ? [] : imported.signature.results.length === 1 ? [rawResult] : rawResult as unknown[];
        trace.push({
          module: imported.module,
          field: imported.field,
          ordinal: context.ordinal++,
          phase: context.phase,
          stepIndex: context.stepIndex,
          arguments: args.map((arg, index) => typedFromJs(arg, imported.signature.params[index] ?? "unknown", relations)),
          results: rawResults.map((result, index) => typedFromJs(result, imported.signature.results[index] ?? "unknown", relations)),
        });
        return rawResult;
      };
    }
  }
  for (const imported of runtimeInterface.imports.globals) {
    if (imported.support === "unsupported" || imported.support === "scalar-adapter") throw new Error(`unsupported imported global ${imported.module}.${imported.field}: ${imported.valueType}`);
    const namespace = (imports[imported.module] ??= {});
    const global = new WebAssembly.Global({ value: imported.valueType as WebAssembly.ValueType, mutable: imported.mutable }, zeroJsValue(imported.valueType) as never);
    namespace[imported.field] = global;
    globals.set(imported.index, global);
  }
  for (const imported of runtimeInterface.imports.memories) {
    if (imported.memory64) throw new Error(`unsupported imported memory64 ${imported.module}.${imported.field}`);
    const namespace = (imports[imported.module] ??= {});
    const memory = new WebAssembly.Memory({
      initial: Number(imported.minimum),
      ...(imported.maximum === null ? {} : { maximum: Number(imported.maximum) }),
      ...(imported.shared ? { shared: true } : {}),
    });
    namespace[imported.field] = memory;
    memories.set(imported.index, memory);
  }
  for (const imported of runtimeInterface.imports.tables) {
    if (imported.support === "unsupported") throw new Error(`unsupported imported table ${imported.module}.${imported.field}: ${imported.elementType}`);
    const namespace = (imports[imported.module] ??= {});
    const table = new WebAssembly.Table({
      element: imported.elementType === "funcref" ? "anyfunc" : imported.elementType,
      initial: Number(imported.minimum),
      ...(imported.maximum === null ? {} : { maximum: Number(imported.maximum) }),
    });
    namespace[imported.field] = table;
    tables.set(imported.index, table);
  }
  for (const imported of runtimeInterface.imports.tags ?? []) {
    const namespace = (imports[imported.module] ??= {});
    const Tag = (WebAssembly as unknown as {
      Tag?: new (descriptor: { parameters: string[] }) => unknown;
    }).Tag;
    if (Tag === undefined) throw new Error(`unsupported imported tag ${imported.module}.${imported.field}: WebAssembly.Tag unavailable`);
    namespace[imported.field] = new Tag({ parameters: imported.signature.params });
  }
  for (const descriptor of WebAssembly.Module.imports(module)) {
    const namespace = (imports[descriptor.module] ??= {});
    if (!(descriptor.name in namespace)) throw new Error(`unsupported import ${descriptor.module}.${descriptor.name} kind=${descriptor.kind}`);
  }
  const resources = { globals, memories, tables, staticTableRelations };
  let instance: WebAssembly.Instance;
  try {
    instance = await WebAssembly.instantiate(module, imports);
  } catch (error) {
    throw new RuntimeInstantiationFailure(
      error instanceof Error ? error.message : String(error),
      error,
      resources,
    );
  }
  for (const exported of runtimeInterface.exports) {
    const value = instance.exports[exported.name];
    if (exported.kind === "global" && value instanceof WebAssembly.Global) globals.set(exported.index, value);
    else if (exported.kind === "memory" && value instanceof WebAssembly.Memory) memories.set(exported.index, value);
    else if (exported.kind === "table" && value instanceof WebAssembly.Table) tables.set(exported.index, value);
  }
  return { instance, resources };
}

function snapshotResources(resources: RuntimeResources, runtimeInterface: RuntimeInterfaceV1, options: NodeObservationV2Options): RuntimeStateSnapshotV2 {
  const relations = new Map<object, string>();
  const globals = [...resources.globals.entries()].sort(([left], [right]) => left - right).map(([index, global]) => {
    const type = runtimeInterface.exports.find((entry) => entry.kind === "global" && entry.index === index)?.globalType?.valueType
      ?? runtimeInterface.imports.globals.find((entry) => entry.index === index)?.valueType
      ?? "unknown";
    const names = exportedNames(runtimeInterface, "global", index);
    if (names.length === 0) {
      const imported = runtimeInterface.imports.globals.find((entry) => entry.index === index);
      if (imported) names.push(`${imported.module}.${imported.field}`);
    }
    return { index, names, value: typedFromJs(global.value, type, relations) };
  });
  const memories = [...resources.memories.entries()].sort(([left], [right]) => left - right).map(([index, memory]) => {
    const names = exportedNames(runtimeInterface, "memory", index);
    if (names.length === 0) {
      const imported = runtimeInterface.imports.memories.find((entry) => entry.index === index);
      if (imported) names.push(`${imported.module}.${imported.field}`);
    }
    return memoryObservation(index, names, memory, options.memoryCapBytes);
  });
  const tables = [...resources.tables.entries()].sort(([left], [right]) => left - right).map(([index, table]) => {
    const names = exportedNames(runtimeInterface, "table", index);
    if (names.length === 0) {
      const imported = runtimeInterface.imports.tables.find((entry) => entry.index === index);
      if (imported) names.push(`${imported.module}.${imported.field}`);
    }
    return tableObservation(
      index,
      names,
      table,
      options.tableEntryCap,
      relations,
      resources.staticTableRelations.get(index),
    );
  });
  return { globals, memories, tables };
}

function snapshotState(runtime: RuntimeInstance, runtimeInterface: RuntimeInterfaceV1, options: NodeObservationV2Options): RuntimeStateSnapshotV2 {
  return snapshotResources(runtime.resources, runtimeInterface, options);
}

function emptyState(): RuntimeStateSnapshotV2 {
  return { globals: [], memories: [], tables: [] };
}

function stateChanges(before: RuntimeStateSnapshotV2, after: RuntimeStateSnapshotV2): {
  delta: RuntimeObservationStepV2["stateDelta"];
  first: RuntimeObservationStepV2["firstChangedResource"];
} {
  for (const [kind, valuesBefore, valuesAfter] of [
    ["global", before.globals, after.globals],
    ["memory", before.memories, after.memories],
    ["table", before.tables, after.tables],
  ] as const) {
    const length = Math.max(valuesBefore.length, valuesAfter.length);
    for (let offset = 0; offset < length; offset += 1) {
      if (stableRuntimeJson(valuesBefore[offset]) !== stableRuntimeJson(valuesAfter[offset])) {
        const index = (valuesBefore[offset] as { index?: number } | undefined)?.index ?? (valuesAfter[offset] as { index?: number } | undefined)?.index ?? offset;
        let byteOffset: number | undefined;
        if (kind === "memory" && valuesBefore[offset] && valuesAfter[offset]) {
          const left = valuesBefore[offset] as RuntimeMemoryObservationV2;
          const right = valuesAfter[offset] as RuntimeMemoryObservationV2;
          const chunk = left.chunkHashes.findIndex((hash, chunkIndex) => hash !== right.chunkHashes[chunkIndex]);
          if (chunk >= 0) byteOffset = chunk * 64 * 1024;
        }
        return {
          delta: [{ path: `${kind}[${index}]`, before: valuesBefore[offset] ?? null, after: valuesAfter[offset] ?? null }],
          first: { kind, index, ...(byteOffset === undefined ? {} : { offset: byteOffset }) },
        };
      }
    }
  }
  return { delta: [], first: null };
}

function blockedReasons(state: RuntimeStateSnapshotV2, options: NodeObservationV2Options): string[] {
  const reasons = [
    ...state.memories.filter((memory) => !memory.complete).map((memory) => `memory-over-cap: memory[${memory.index}] bytes=${memory.byteLength} cap=${options.memoryCapBytes}`),
    ...state.tables.filter((table) => !table.complete).map((table) => `table-over-cap: table[${table.index}] entries=${table.length} cap=${options.tableEntryCap}`),
  ];
  const populatedTables = state.tables.filter((table) => table.entries.some((entry) => entry.relation !== "null"));
  if (
    populatedTables.length > 1 &&
    populatedTables.some((table) => table.entries.some((entry) => entry.relation.startsWith("funcref:")))
  ) {
    reasons.push(`cross-table-reference-identity-unavailable: tables=${populatedTables.length}`);
  }
  return reasons;
}

export async function executeNodeObservationV2(
  wasmPath: string,
  runtimeInterface: RuntimeInterfaceV1,
  plan: InvocationPlanV2,
  options: NodeObservationV2Options,
): Promise<RuntimeObservationV2> {
  const trace: RuntimeImportEventV2[] = [];
  const context: TraceContext = {
    phase: runtimeInterface.hasStart ? "start" : "instantiation",
    stepIndex: null,
    ordinal: 0,
  };
  const observation: RuntimeObservationV2 = {
    schema: "starshine.optimizer-runtime-observation.v2",
    runtime: { identity: `node:${process.version}`, timeoutMs: options.timeoutMs },
    mode: options.mode,
    compilation: { status: "not-attempted" },
    instantiation: { status: "not-attempted" },
    completeness: "complete",
    blockedReasons: [...plan.blockedExports.map((entry) => `blocked-export:${entry.exportName}:${entry.reason}`)],
    steps: [],
    importTrace: trace,
    resources: emptyState(),
  };
  let module: WebAssembly.Module;
  try {
    module = await WebAssembly.compile(fs.readFileSync(wasmPath));
    observation.compilation = { status: "succeeded" };
  } catch (error) {
    observation.compilation = {
      status: "failed",
      error: error instanceof Error ? error.message : String(error),
    };
    observation.completeness = "incomplete";
    observation.blockedReasons.push(`compile-failure:${error instanceof Error ? error.message : String(error)}`);
    return observation;
  }

  const staticTableRelations = staticTableRelationsFromWasm(
    wasmPath,
    options.wasmToolsBin ?? "wasm-tools",
  );
  let initial: RuntimeInstance;
  const traceStart = trace.length;
  try {
    initial = await instantiateRuntime(
      module,
      runtimeInterface,
      trace,
      context,
      options.wasmToolsBin ?? "wasm-tools",
      staticTableRelations,
      options.seed ?? 0n,
    );
    const stateAfter = snapshotState(initial, runtimeInterface, options);
    observation.instantiation = { status: "succeeded" };
    observation.steps.push({
      stepIndex: -1,
      exportName: null,
      phase: runtimeInterface.hasStart ? "start" : "instantiation",
      arguments: [],
      importTraceStart: traceStart,
      importTraceEnd: trace.length,
      stateBefore: emptyState(),
      outcome: { kind: "returned", values: [] },
      stateAfter,
      stateDelta: [],
      firstChangedResource: null,
    });
    observation.blockedReasons.push(...blockedReasons(stateAfter, options));
  } catch (error) {
    const originalError = error instanceof RuntimeInstantiationFailure
      ? error.original
      : error;
    const trap = normalizeRuntimeTrap(
      originalError instanceof Error ? originalError.message : String(originalError),
    );
    const stateAfter = error instanceof RuntimeInstantiationFailure
      ? snapshotResources(error.resources, runtimeInterface, options)
      : emptyState();
    observation.instantiation = originalError instanceof WebAssembly.RuntimeError
      ? { status: "trapped", trapClass: trap.class, rawText: trap.rawText }
      : { status: "failed", error: trap.rawText };
    observation.steps.push({
      stepIndex: -1,
      exportName: null,
      phase: runtimeInterface.hasStart ? "start" : "instantiation",
      arguments: [],
      importTraceStart: traceStart,
      importTraceEnd: trace.length,
      stateBefore: emptyState(),
      outcome: originalError instanceof WebAssembly.RuntimeError
        ? { kind: "trapped", trapClass: trap.class, rawText: trap.rawText }
        : { kind: "unsupported", reason: trap.rawText },
      stateAfter,
      stateDelta: [],
      firstChangedResource: null,
    });
    observation.resources = stateAfter;
    observation.completeness = "incomplete";
    observation.blockedReasons.push(
      `instantiation-failure:${trap.class}`,
      ...blockedReasons(stateAfter, options),
    );
    return observation;
  }

  let current = initial;
  for (let index = 0; index < plan.steps.length; index += 1) {
    const planned = plan.steps[index];
    if (options.mode === "independent") {
      context.phase = runtimeInterface.hasStart ? "start" : "instantiation";
      context.stepIndex = null;
      try {
        current = await instantiateRuntime(
          module,
          runtimeInterface,
          trace,
          context,
          options.wasmToolsBin ?? "wasm-tools",
          staticTableRelations,
          options.seed ?? 0n,
        );
      } catch (error) {
        observation.blockedReasons.push(`independent-instantiation-failure:${planned.exportName}:${error instanceof Error ? error.message : String(error)}`);
        observation.completeness = "incomplete";
        continue;
      }
    }
    const stateBefore = snapshotState(current, runtimeInterface, options);
    const eventStart = trace.length;
    context.phase = "exported-call";
    context.stepIndex = planned.stepIndex;
    const exported = current.instance.exports[planned.exportName];
    let outcome: RuntimeObservationStepV2["outcome"];
    if (typeof exported !== "function") {
      outcome = { kind: "unsupported", reason: `missing function export ${planned.exportName}` };
    } else {
      try {
        const relations = new Map<object, string>();
        if (signatureHasV128(planned.signature)) {
          const adapter = await instantiateScalarAdapter(
            exported as (...args: unknown[]) => unknown,
            planned.signature,
            options.wasmToolsBin ?? "wasm-tools",
          );
          const raw = adapter(...flattenAdapterArguments(planned.arguments));
          outcome = { kind: "returned", values: adapterResultValues(raw, planned.signature, relations) };
        } else {
          const raw = exported(...planned.arguments.map(jsFromTyped));
          const values = planned.signature.results.length === 0 ? [] : planned.signature.results.length === 1 ? [raw] : raw as unknown[];
          outcome = { kind: "returned", values: values.map((value, resultIndex) => typedFromJs(value, planned.signature.results[resultIndex] ?? "unknown", relations)) };
        }
      } catch (error) {
        const trap = normalizeRuntimeTrap(error instanceof Error ? error.message : String(error));
        outcome = { kind: "trapped", trapClass: trap.class, rawText: trap.rawText };
      }
    }
    const stateAfter = snapshotState(current, runtimeInterface, options);
    const changes = stateChanges(stateBefore, stateAfter);
    observation.steps.push({
      stepIndex: planned.stepIndex,
      exportName: planned.exportName,
      phase: "exported-call",
      arguments: planned.arguments,
      importTraceStart: eventStart,
      importTraceEnd: trace.length,
      stateBefore,
      outcome,
      stateAfter,
      stateDelta: changes.delta,
      firstChangedResource: changes.first,
    });
    observation.blockedReasons.push(...blockedReasons(stateBefore, options), ...blockedReasons(stateAfter, options));
  }
  observation.resources = snapshotState(current, runtimeInterface, options);
  observation.blockedReasons.push(...blockedReasons(observation.resources, options));
  observation.blockedReasons = [...new Set(observation.blockedReasons)].sort();
  if (observation.blockedReasons.length > 0) observation.completeness = "incomplete";
  return observation;
}

function threeWayRelation(
  comparison: SemanticComparisonV2 | null,
  originalSide = false,
): "equal" | "different" | "blocked" | "blocked-original" | "unknown" {
  if (comparison === null) return "unknown";
  if (comparison.classification === "semantic-match") return "equal";
  if (comparison.classification === "semantic-mismatch") return "different";
  return originalSide ? "blocked-original" : "blocked";
}

export async function runNodeThreeWaySemanticOracleV2(
  originalWasmPath: string,
  starshineWasmPath: string,
  binaryenWasmPath: string | null,
  options: NodeObservationV2Options & {
    seed: bigint;
    policy: SemanticPolicy;
    wasmToolsBin?: string;
    starshineBin?: string;
    starshineArgsPrefix?: string[];
    maxPairwise?: number;
    binaryenDiagnostic?: "ok" | "tool-failure" | "timeout" | "unsupported";
  },
): Promise<NodeThreeWaySemanticOracleV2Report> {
  const totalStarted = performance.now();
  let stageStarted = performance.now();
  const runtimeInterface = options.starshineBin != null
    ? buildRuntimeInterfaceFromStarshine(
        originalWasmPath,
        options.starshineBin,
        undefined,
        options.starshineArgsPrefix,
      )
    : buildRuntimeInterfaceFromWasm(originalWasmPath, options.wasmToolsBin);
  const runtimeInterfaceMs = performance.now() - stageStarted;
  stageStarted = performance.now();
  const plan = buildInvocationPlanV2(runtimeInterface, {
    seed: options.seed,
    maxPairwise: options.maxPairwise,
  });
  const invocationPlanMs = performance.now() - stageStarted;
  const executionOptions: NodeObservationV2Options = {
    mode: options.mode,
    timeoutMs: options.timeoutMs,
    memoryCapBytes: options.memoryCapBytes,
    tableEntryCap: options.tableEntryCap,
    seed: options.seed,
    wasmToolsBin: options.wasmToolsBin,
  };
  stageStarted = performance.now();
  const original = await executeNodeObservationV2WithTimeout(
    originalWasmPath,
    runtimeInterface,
    plan,
    executionOptions,
  );
  const originalObservationMs = performance.now() - stageStarted;
  stageStarted = performance.now();
  const starshine = await executeNodeObservationV2WithTimeout(
    starshineWasmPath,
    runtimeInterface,
    plan,
    executionOptions,
  );
  const starshineObservationMs = performance.now() - stageStarted;
  stageStarted = performance.now();
  const binaryen = binaryenWasmPath === null
    ? null
    : await executeNodeObservationV2WithTimeout(
        binaryenWasmPath,
        runtimeInterface,
        plan,
        executionOptions,
      );
  const binaryenObservationMs = binaryenWasmPath === null ? 0 : performance.now() - stageStarted;
  stageStarted = performance.now();
  const originalVsStarshine = compareRuntimeObservationsV2(original, starshine, options.policy);
  const originalVsBinaryen = binaryen === null
    ? null
    : compareRuntimeObservationsV2(original, binaryen, options.policy);
  const starshineVsBinaryen = binaryen === null
    ? null
    : compareRuntimeObservationsV2(starshine, binaryen, options.policy);
  const originalBlocked = original.completeness === "incomplete" || original.blockedReasons.length > 0;
  const classification = classifyThreeWaySemanticComparison({
    originalVsStarshine: originalBlocked
      ? "blocked-original"
      : threeWayRelation(originalVsStarshine),
    originalVsBinaryen: originalBlocked
      ? "blocked-original"
      : threeWayRelation(originalVsBinaryen),
    starshineVsBinaryen: threeWayRelation(starshineVsBinaryen),
    binaryenDiagnostic: options.binaryenDiagnostic ?? (binaryen === null ? "tool-failure" : "ok"),
  });
  const comparisonMs = performance.now() - stageStarted;
  return {
    schema: "starshine.optimizer-three-way-runtime-report.v1",
    timings: {
      runtimeInterfaceMs,
      invocationPlanMs,
      originalObservationMs,
      starshineObservationMs,
      binaryenObservationMs,
      comparisonMs,
      totalMs: performance.now() - totalStarted,
    },
    runtimeInterface,
    plan,
    original,
    starshine,
    binaryen,
    originalVsStarshine,
    originalVsBinaryen,
    starshineVsBinaryen,
    classification,
  };
}

export async function executeNodeObservationV2WithTimeout(
  wasmPath: string,
  runtimeInterface: RuntimeInterfaceV1,
  plan: InvocationPlanV2,
  options: NodeObservationV2Options,
): Promise<RuntimeObservationV2> {
  return await new Promise((resolve) => {
    const worker = new Worker(new URL("./optimizer-runtime-v2-worker.ts", import.meta.url), {
      workerData: { wasmPath, runtimeInterface, plan, options },
    });
    worker.unref();
    let settled = false;
    const finish = (observation: RuntimeObservationV2) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      void worker.terminate();
      resolve(observation);
    };
    const timer = setTimeout(() => {
      finish({
        schema: "starshine.optimizer-runtime-observation.v2",
        runtime: { identity: `node:${process.version}`, timeoutMs: options.timeoutMs },
        mode: options.mode,
        compilation: { status: "unknown" },
        instantiation: { status: "timed-out", timeoutMs: options.timeoutMs },
        completeness: "incomplete",
        blockedReasons: [`timeout:${options.timeoutMs}ms`],
        steps: [{
          stepIndex: -1,
          exportName: null,
          phase: "instantiation",
          arguments: [],
          importTraceStart: 0,
          importTraceEnd: 0,
          stateBefore: emptyState(),
          outcome: { kind: "timed-out", timeoutMs: options.timeoutMs },
          stateAfter: emptyState(),
          stateDelta: [],
          firstChangedResource: null,
        }],
        importTrace: [],
        resources: emptyState(),
      });
    }, Math.max(1, options.timeoutMs));
    worker.on("message", (message: { ok: boolean; observation?: RuntimeObservationV2; detail?: string }) => {
      if (message.ok && message.observation) finish(message.observation);
      else finish({
        schema: "starshine.optimizer-runtime-observation.v2",
        runtime: { identity: `node:${process.version}`, timeoutMs: options.timeoutMs },
        mode: options.mode,
        compilation: { status: "unknown" },
        instantiation: {
          status: "failed",
          error: message.detail ?? "unknown",
        },
        completeness: "incomplete",
        blockedReasons: [`worker-failure:${message.detail ?? "unknown"}`],
        steps: [],
        importTrace: [],
        resources: emptyState(),
      });
    });
    worker.on("error", (error) => finish({
      schema: "starshine.optimizer-runtime-observation.v2",
      runtime: { identity: `node:${process.version}`, timeoutMs: options.timeoutMs },
      mode: options.mode,
      compilation: { status: "unknown" },
      instantiation: { status: "failed", error: error.message },
      completeness: "incomplete",
      blockedReasons: [`worker-failure:${error.message}`],
      steps: [],
      importTrace: [],
      resources: emptyState(),
    }));
  });
}
