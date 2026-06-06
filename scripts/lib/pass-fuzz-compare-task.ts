import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { spawn, spawnSync } from "node:child_process";

import {
  fail,
  makeRepoTmpEnv,
  resolveMoonBin,
  resolveRepoPath,
  resolveWorkspaceRoot,
  runOrThrow,
} from "./task-runtime";
import { type FuzzSummaryReport, formatFuzzSummaryReport, normalizeFuzzSummaryReport } from "./fuzz-summary-counters";
import { type EffectTrapFacts, scanEffectTrapFactsFromWasmBytes } from "./effect-trap-scanner";
import { formatReductionReportLog, reduceBinaryByByteSlicesWithReport, type ReductionStep } from "./fuzz-reducers";

type GeneratorMode = "both" | "wasm-smith" | "gen-valid";
type GeneratorKind = "wasm-smith" | "gen-valid";
type CompareNormalizer = "drop-consts" | "unreachable-control-debris" | "local-cleanup-debris";
type CaseStatus = "match" | "mismatch" | "validation-failure" | "generator-failure" | "command-failure" | "property-failure";
type ExternalValidatorKind = "wasm-tools" | "binaryen" | "wabt";
type RuntimeExecutionMode = "off" | "node";
export type RuntimeInvocationOutcome =
  | { kind: "result"; value: unknown }
  | { kind: "trap"; detail: string }
  | { kind: "unsupported"; detail: string }
  | { kind: "nondeterministic-import"; detail: string };
export type RuntimeInvocationClassification =
  | "equal-result"
  | "equal-trap"
  | "unsupported-runtime"
  | "nondeterministic-import"
  | "semantic-mismatch";
export type RuntimeExportInvocationReport = {
  exportName: string;
  args: string[];
  leftResult: RuntimeInvocationOutcome;
  rightResult: RuntimeInvocationOutcome;
  classification: RuntimeInvocationClassification;
};
export type RuntimeExportInvocationMatrixSummary = {
  total: number;
  equalResults: number;
  equalTraps: number;
  unsupportedRuntimes: number;
  nondeterministicImports: number;
  semanticMismatches: number;
};
export type RuntimeExportInvocationMatrixOutcome = "not-run" | "empty" | "all-equal" | "blocked" | "semantic-mismatch";
type RuntimeExportInvocationMatrixPersistence = {
  summary: RuntimeExportInvocationMatrixSummary;
  outcome: RuntimeExportInvocationMatrixOutcome;
  semanticMismatchSamples: RuntimeExportInvocationReport[];
};
type PropertyMode = "none" | "idempotence" | "composition";
type CommandFailureClass =
  | "starshine-command-failed"
  | "starshine-invalid-limits"
  | "starshine-invalid-range-for-limits"
  | "binaryen-invalid-type-index"
  | "binaryen-invalid-tag-index"
  | "binaryen-rec-group-zero"
  | "binaryen-invalid-wasm-type-neg64"
  | "binaryen-initializer-expression-not-constant"
  | "binaryen-table-index-out-of-range"
  | "binaryen-bad-section-size"
  | "binaryen-command-failed";

type PassFuzzCompareOptions = {
  count: number;
  minCompared: number | null;
  seed: bigint;
  outDir: string;
  moonBin: string;
  starshineBin: string | null;
  wasmOptBin: string;
  wasmToolsBin: string;
  binaryenValidateBin: string;
  wabtValidateBin: string;
  externalValidators: ExternalValidatorKind[];
  runtimeExecution: RuntimeExecutionMode;
  propertyMode: PropertyMode;
  generator: GeneratorMode;
  genValidProfile: string | null;
  genValidRequiredFeatures: string[];
  genValidExcludedFeatures: string[];
  genValidMetamorphicTransforms: string[];
  maxFailures: number;
  keepGoingAfterCommandFailures: boolean;
  jobs: number | null;
  passFlags: string[];
  replayFailuresFrom: string | null;
  failureStatus: CaseStatus | null;
  failureClass: CommandFailureClass | null;
  replayCaseIndex: number | null;
  normalizers: CompareNormalizer[];
};

type ParseCommand =
  | { kind: "run"; options: PassFuzzCompareOptions }
  | { kind: "help" }
  | { kind: "list-passes" }
  | { kind: "list-failure-classes" };

type StarshineInvocation = {
  command: string;
  argsPrefix: string[];
  retryMissingOutput: boolean;
};

type EffectTrapCounts = Record<keyof EffectTrapFacts, number>;
type GenValidTransformCounts = Record<string, number>;

type CaseRecord = {
  caseIndex: number;
  generator: GeneratorKind;
  status: CaseStatus;
  detail: string;
  failureClass?: CommandFailureClass;
  transformId?: string;
  genValidFeatureFacts?: unknown;
  inputEffectTrapFacts?: EffectTrapFacts;
};

type ReplayCase = {
  caseIndex: number;
  generator: GeneratorKind;
  inputPath: string;
};

export type MismatchReductionArtifact = {
  reducedBytes: Uint8Array;
  originalSize: number;
  finalSize: number;
  predicateEvaluations: number;
  steps: ReductionStep[];
};

export type PassFuzzCompareSummary = {
  requestedCount: number;
  minCompared: number | null;
  comparedCount: number;
  normalizedMatchCount: number;
  cleanupNormalizedMatchCount: number;
  mismatchCount: number;
  validationFailureCount: number;
  generatorFailureCount: number;
  commandFailureCount: number;
  commandFailureClasses: Partial<Record<CommandFailureClass, number>>;
  commandFailuresCountTowardMaxFailures: boolean;
  maxFailuresHit: boolean;
  jobs: number;
  seed: string;
  generator: GeneratorMode;
  genValidProfile: string | null;
  genValidRequiredFeatures: string[];
  genValidExcludedFeatures: string[];
  genValidMetamorphicTransforms: string[];
  genValidManifestPath: string | null;
  genValidTransformCounts: GenValidTransformCounts;
  externalValidators: ExternalValidatorKind[];
  runtimeExecution: RuntimeExecutionMode;
  propertyMode: PropertyMode;
  propertyFailureCount: number;
  idempotenceCheckedCount: number;
  idempotenceMatchCount: number;
  compositionCheckedCount: number;
  compositionMatchCount: number;
  runtimeExecutionCounts: {
    checked: number;
    unsupported: number;
    failed: number;
  };
  runtimeExecutionMatrix: RuntimeExportInvocationMatrixPersistence;
  externalValidatorSkipped: Partial<Record<ExternalValidatorKind, number>>;
  generatorCounts: {
    wasmSmith: number;
    genValid: number;
  };
  inputEffectTrapCounts: EffectTrapCounts;
  passFlags: string[];
  binaryenPassFlags: string[];
  normalizers: CompareNormalizer[];
  failureDirs: string[];
};

const RESERVED_OPTIONS = new Set([
  "--count",
  "--seed",
  "--min-compared",
  "--out-dir",
  "--moon",
  "--starshine-bin",
  "--wasm-opt-bin",
  "--wasm-tools-bin",
  "--binaryen-validate-bin",
  "--wabt-validate-bin",
  "--external-validator",
  "--runtime-execution",
  "--property",
  "--generator",
  "--gen-valid-profile",
  "--require-feature",
  "--exclude-feature",
  "--gen-valid-metamorphic-transform",
  "--max-failures",
  "--keep-going-after-command-failures",
  "--normalize",
  "--jobs",
  "--pass",
  "--replay-failures-from",
  "--failure-status",
  "--failure-class",
  "--case-index",
]);

const SUPPORTED_PASS_FLAGS = new Set([
  "--avoid-reinterprets",
  "--untee",
  "--ssa-nomerge",
  "--dead-code-elimination",
  "--remove-unused-names",
  "--remove-unused-brs",
  "--vacuum",
  "--optimize-instructions",
  "--heap-store-optimization",
  "--heap2local",
  "--optimize-casts",
  "--pick-load-signs",
  "--tuple-optimization",
  "--precompute",
  "--code-pushing",
  "--code-folding",
  "--simplify-locals",
  "--simplify-locals-nostructure",
  "--simplify-locals-no-structure",
  "--simplify-locals-notee-nostructure",
  "--merge-blocks",
  "--redundant-set-elimination",
  "--memory-packing",
  "--once-reduction",
  "--global-refining",
  "--global-struct-inference",
  "--reorder-locals",
  "--local-subtyping",
  "--coalesce-locals",
  "--local-cse",
  "--merge-locals",
  "--duplicate-function-elimination",
  "--duplicate-import-elimination",
  "--strip-debug",
  "--simplify-globals-optimizing",
  "--dae-optimizing",
  "--inlining",
  "--inlining-optimizing",
  "--string-gathering",
  "--reorder-globals",
  "--directize",
  "--remove-unused-module-elements",
  "--remove-unused-nonfunction-module-elements",
]);

const BINARYEN_FLAG_ALIASES = new Map<string, string>([
  ["--dead-code-elimination", "--dce"],
  ["--global-struct-inference", "--gsi"],
  ["--redundant-set-elimination", "--rse"],
  ["--simplify-locals-no-structure", "--simplify-locals-nostructure"],
]);

const HELP_TEXT = [
  "usage: bun scripts/pass-fuzz-compare.ts [options] --pass <name>|--<pass-flag>",
  "options:",
  "  --count <n>           Number of modules to compare. Default: 10000",
  "  --seed <value>        Non-negative deterministic seed. Default: 0x5eed",
  "  --min-compared <n>    Require at least this many successful comparisons",
  "  --out-dir <dir>       Output directory for artifacts and failures",
  "  --external-validator <id>",
  "                       Optional skip-clean output validator: wasm-tools | binaryen | wabt. May repeat",
  "  --runtime-execution <mode>",
  "                       Optional runtime smoke execution adapter: off | node. Default: off",
  "  --property <mode>    Optional property checks: idempotence | composition. May be repeated later; default: none",
  "  --binaryen-validate-bin <path>",
  "                       Binaryen validator command for --external-validator binaryen. Default: wasm-validate",
  "  --wabt-validate-bin <path>",
  "                       WABT validator command for --external-validator wabt. Default: wasm-validate",
  "  --generator <mode>    both | wasm-smith | gen-valid. Default: both",
  "  --gen-valid-profile <name>",
  "                       Forward a named GenValid profile to batch generation",
  "  --require-feature <feature>",
  "                       Require a GenValid batch feature floor; may repeat",
  "  --exclude-feature <feature>",
  "                       Exclude GenValid batch features; may repeat",
  "  --gen-valid-metamorphic-transform <id>",
  "                       Request transformed GenValid variants and preserve transform ids in reports; may repeat",
  "  --max-failures <n>    Stop after this many mismatches/failures. Default: 20",
  "  --keep-going-after-command-failures",
  "                       Record command failures without counting them toward --max-failures",
  "  --normalize <name>   Enable compare normalizer. Supported: drop-consts, unreachable-control-debris, local-cleanup-debris. May repeat",
  "  --jobs <n|auto>       Concurrent case jobs. Default: auto with --starshine-bin, otherwise 1; auto uses available parallelism; >1 requires --starshine-bin",
  "  --pass <name>         Canonical pass name without leading --. May repeat",
  "  --replay-failures-from <dir>",
  "                       Replay saved failure inputs from a prior out dir",
  "  --failure-status <status>",
  "                       Restrict replay to mismatch | validation-failure | generator-failure | command-failure",
  "                       Defaults to command-failure for backward-compatible replay",
  "  --failure-class <id> Restrict command-failure replay to one failure family",
  "  --case-index <n>     Restrict replay to one saved case index",
  "  --list-passes         Print supported pass names and exit",
  "  --list-failure-classes",
  "                       Print supported replay failure classes and exit",
  "  --help                Print this text and exit",
].join("\n");

function parseBigIntSeed(raw: string): bigint {
  const text = raw.trim();
  if (text.length === 0) {
    fail("seed must not be empty");
  }
  try {
    const seed = BigInt(text);
    if (seed < 0n) {
      fail("seed must be non-negative");
    }
    return seed;
  } catch {
    fail(`invalid seed: ${raw}`);
  }
}

function parseNonNegativeInt(label: string, raw: string): number {
  if (!/^\d+$/.test(raw.trim())) {
    fail(`invalid ${label}: ${raw}`);
  }
  return Number.parseInt(raw, 10);
}

function availableParallelism(): number {
  const available = (os as typeof os & { availableParallelism?: () => number }).availableParallelism;
  return Math.max(1, available?.() ?? os.cpus().length ?? 1);
}

function parseJobs(raw: string): number {
  const value = raw.trim();
  if (value === "auto") {
    return availableParallelism();
  }
  if (!/^\d+$/.test(value)) {
    fail(`invalid jobs: ${raw}`);
  }
  const jobs = Number.parseInt(value, 10);
  if (jobs < 1) {
    fail(`invalid jobs: ${raw}`);
  }
  return jobs;
}

function seedHex(seed: bigint): string {
  return `0x${seed.toString(16)}`;
}

function normalizeBinaryenPassFlag(flag: string): string {
  return BINARYEN_FLAG_ALIASES.get(flag) ?? flag;
}

function supportedPassNames(): string[] {
  return Array.from(SUPPORTED_PASS_FLAGS)
    .map((flag) => flag.replace(/^--/, ""))
    .sort();
}

function supportedCommandFailureClasses(): CommandFailureClass[] {
  return [
    "starshine-command-failed",
    "starshine-invalid-limits",
    "starshine-invalid-range-for-limits",
    "binaryen-invalid-type-index",
    "binaryen-invalid-tag-index",
    "binaryen-rec-group-zero",
    "binaryen-invalid-wasm-type-neg64",
    "binaryen-initializer-expression-not-constant",
    "binaryen-table-index-out-of-range",
    "binaryen-bad-section-size",
    "binaryen-command-failed",
  ];
}

function normalizePassNameToFlag(raw: string): string {
  const trimmed = raw.trim();
  const normalized = trimmed.startsWith("--") ? trimmed : `--${trimmed}`;
  const starshineFlag =
    normalized === "--rse" ? "--redundant-set-elimination" : normalized;
  if (!SUPPORTED_PASS_FLAGS.has(starshineFlag)) {
    fail(`unsupported pass flag for pass-fuzz-compare: ${raw}`);
  }
  return starshineFlag;
}

function normalizeCompareNormalizer(raw: string): CompareNormalizer {
  switch (raw.trim()) {
    case "drop-consts":
      return "drop-consts";
    case "unreachable-control-debris":
      return "unreachable-control-debris";
    case "local-cleanup-debris":
      return "local-cleanup-debris";
    default:
      fail(`unsupported pass-fuzz-compare normalizer: ${raw}`);
  }
}

function normalizeExternalValidator(raw: string): ExternalValidatorKind {
  switch (raw.trim()) {
    case "wasm-tools":
    case "binaryen":
    case "wabt":
      return raw.trim();
    default:
      fail(`unsupported external validator for pass-fuzz-compare: ${raw}`);
  }
}

function normalizeRuntimeExecutionMode(raw: string): RuntimeExecutionMode {
  switch (raw.trim()) {
    case "off":
    case "node":
      return raw.trim();
    default:
      fail(`unsupported runtime execution mode for pass-fuzz-compare: ${raw}`);
  }
}

function normalizePropertyMode(raw: string): PropertyMode {
  switch (raw.trim()) {
    case "none":
    case "idempotence":
    case "composition":
      return raw.trim();
    default:
      fail(`unsupported property mode for pass-fuzz-compare: ${raw}`);
  }
}

function normalizeFailureStatus(raw: string): CaseStatus {
  switch (raw.trim()) {
    case "mismatch":
    case "validation-failure":
    case "generator-failure":
    case "command-failure":
    case "property-failure":
      return raw.trim();
    default:
      fail(`unsupported failure status for pass-fuzz-compare: ${raw}`);
  }
}

function normalizeCommandFailureClass(raw: string): CommandFailureClass {
  switch (raw.trim()) {
    case "starshine-command-failed":
    case "starshine-invalid-limits":
    case "starshine-invalid-range-for-limits":
    case "binaryen-invalid-type-index":
    case "binaryen-invalid-tag-index":
    case "binaryen-rec-group-zero":
    case "binaryen-invalid-wasm-type-neg64":
    case "binaryen-initializer-expression-not-constant":
    case "binaryen-table-index-out-of-range":
    case "binaryen-bad-section-size":
    case "binaryen-command-failed":
      return raw.trim();
    default:
      fail(`unsupported failure class for pass-fuzz-compare: ${raw}`);
  }
}

function resolveStarshineInvocation(
  repoRoot: string,
  starshineBin: string | null,
  moonBin: string,
): StarshineInvocation {
  if (starshineBin !== null) {
    return {
      command: resolveRepoPath(repoRoot, starshineBin),
      argsPrefix: [],
      retryMissingOutput: false,
    };
  }

  return {
    command: moonBin,
    argsPrefix: ["run", "--target", "native", "--release", "src/cmd", "--"],
    retryMissingOutput: true,
  };
}

type ProcessResult = {
  status: number | null;
  stdout: string;
  stderr: string;
};

function runProcess(
  command: string,
  args: string[],
  {
    cwd = process.cwd(),
    env = process.env,
    input = null,
    maxBuffer = 128 * 1024 * 1024,
  }: {
    cwd?: string;
    env?: NodeJS.ProcessEnv;
    input?: Buffer | string | null;
    maxBuffer?: number;
  } = {},
): Promise<ProcessResult> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      env,
      stdio: [input === null ? "ignore" : "pipe", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";

    child.stdout?.setEncoding("utf8");
    child.stderr?.setEncoding("utf8");
    child.stdout?.on("data", (chunk: string) => {
      stdout += chunk;
      if (stdout.length > maxBuffer) {
        child.kill();
        reject(new Error(`stdout exceeded maxBuffer for command: ${command} ${args.join(" ")}`));
      }
    });
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
      if (stderr.length > maxBuffer) {
        child.kill();
        reject(new Error(`stderr exceeded maxBuffer for command: ${command} ${args.join(" ")}`));
      }
    });
    child.on("error", reject);
    child.on("close", (status) => {
      resolve({ status, stdout, stderr });
    });
    if (input !== null) {
      child.stdin?.end(input);
    }
  });
}

async function runOrThrowAsync(
  command: string,
  args: string[],
  {
    cwd = process.cwd(),
    env = process.env,
    maxBuffer = 128 * 1024 * 1024,
  }: {
    cwd?: string;
    env?: NodeJS.ProcessEnv;
    maxBuffer?: number;
  } = {},
): Promise<{ stdout: string; stderr: string }> {
  const result = await runProcess(command, args, { cwd, env, maxBuffer });
  if (result.status !== 0) {
    const stderr = result.stderr.trim();
    const suffix = stderr ? `\n${stderr}` : "";
    fail(`command failed: ${command} ${args.join(" ")}${suffix}`);
  }
  return {
    stdout: result.stdout,
    stderr: result.stderr,
  };
}

async function runValidateAsync(
  wasmToolsBin: string,
  wasmPath: string,
  repoRoot: string,
): Promise<{ ok: boolean; stderr: string }> {
  const result = await runProcess(wasmToolsBin, ["validate", "--features", "all", wasmPath], {
    cwd: repoRoot,
    env: makeRepoTmpEnv(repoRoot),
  });
  return {
    ok: result.status === 0,
    stderr: result.stderr.trim(),
  };
}

async function runExternalValidatorAsync(
  kind: ExternalValidatorKind,
  options: PassFuzzCompareOptions,
  wasmPath: string,
  repoRoot: string,
): Promise<{ ok: boolean; skipped: boolean; stderr: string }> {
  const env = makeRepoTmpEnv(repoRoot);
  const command =
    kind === "wasm-tools"
      ? options.wasmToolsBin
      : kind === "binaryen"
        ? options.binaryenValidateBin
        : options.wabtValidateBin;
  const args = kind === "wasm-tools" ? ["validate", "--features", "all", wasmPath] : [wasmPath];
  try {
    const result = await runProcess(command, args, { cwd: repoRoot, env });
    return { ok: result.status === 0, skipped: false, stderr: result.stderr.trim() };
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code === "ENOENT") {
      return { ok: true, skipped: true, stderr: `${kind} validator unavailable: ${command}` };
    }
    throw error;
  }
}

export function runtimeImportStubCandidates(descriptor: WebAssembly.ModuleImportDescriptor): unknown[] {
  switch (descriptor.kind) {
    case "function":
      return [() => 0, () => 0n, () => null];
    case "global":
      return [
        0,
        0n,
        new WebAssembly.Global({ value: "i32", mutable: true }, 0),
        new WebAssembly.Global({ value: "i64", mutable: true }, 0n),
        new WebAssembly.Global({ value: "f32", mutable: true }, 0),
        new WebAssembly.Global({ value: "f64", mutable: true }, 0),
      ];
    case "memory":
      return [new WebAssembly.Memory({ initial: 1, maximum: 1 })];
    case "table":
      return [
        new WebAssembly.Table({ element: "anyfunc", initial: 1 }),
        new WebAssembly.Table({ element: "externref", initial: 1 }),
      ];
    default:
      return [];
  }
}

function runtimeValueKey(value: unknown): string {
  if (typeof value === "bigint") return `bigint:${value.toString()}`;
  if (typeof value === "number" && Object.is(value, -0)) return "number:-0";
  if (typeof value === "number" && Number.isNaN(value)) return "number:NaN";
  return `${typeof value}:${String(value)}`;
}

export function classifyRuntimeInvocationPair(
  actual: RuntimeInvocationOutcome,
  expected: RuntimeInvocationOutcome,
): RuntimeInvocationClassification {
  if (actual.kind === "unsupported" || expected.kind === "unsupported") return "unsupported-runtime";
  if (actual.kind === "nondeterministic-import" || expected.kind === "nondeterministic-import") {
    return "nondeterministic-import";
  }
  if (actual.kind === "trap" && expected.kind === "trap" && actual.detail === expected.detail) return "equal-trap";
  if (actual.kind === "result" && expected.kind === "result" && runtimeValueKey(actual.value) === runtimeValueKey(expected.value)) {
    return "equal-result";
  }
  return "semantic-mismatch";
}

export function deterministicExportArgumentVector(func: Function): unknown[] {
  const arity = Math.max(0, Math.min(func.length, 8));
  const args: unknown[] = [];
  for (let index = 0; index < arity; index += 1) {
    args.push(0);
  }
  return args;
}

export function emptyRuntimeExportInvocationMatrixSummary(): RuntimeExportInvocationMatrixSummary {
  return {
    total: 0,
    equalResults: 0,
    equalTraps: 0,
    unsupportedRuntimes: 0,
    nondeterministicImports: 0,
    semanticMismatches: 0,
  };
}

export function summarizeRuntimeExportInvocationMatrix(
  reports: RuntimeExportInvocationReport[],
): RuntimeExportInvocationMatrixSummary {
  const summary = emptyRuntimeExportInvocationMatrixSummary();
  for (const report of reports) {
    summary.total += 1;
    switch (report.classification) {
      case "equal-result":
        summary.equalResults += 1;
        break;
      case "equal-trap":
        summary.equalTraps += 1;
        break;
      case "unsupported-runtime":
        summary.unsupportedRuntimes += 1;
        break;
      case "nondeterministic-import":
        summary.nondeterministicImports += 1;
        break;
      case "semantic-mismatch":
        summary.semanticMismatches += 1;
        break;
    }
  }
  return summary;
}

export function classifyRuntimeExportInvocationMatrix(
  summary: RuntimeExportInvocationMatrixSummary,
): RuntimeExportInvocationMatrixOutcome {
  if (summary.total === 0) return "empty";
  if (summary.semanticMismatches > 0) return "semantic-mismatch";
  if (summary.unsupportedRuntimes > 0 || summary.nondeterministicImports > 0) return "blocked";
  return "all-equal";
}

export function runtimeSemanticMismatchSamples(
  reports: RuntimeExportInvocationReport[],
  limit = 8,
): RuntimeExportInvocationReport[] {
  return reports.filter((report) => report.classification === "semantic-mismatch").slice(0, Math.max(0, limit));
}

async function instantiateNodeRuntime(
  wasmPath: string,
): Promise<{ instance: WebAssembly.Instance } | { unsupported: string }> {
  try {
    const bytes = fs.readFileSync(wasmPath);
    const module = await WebAssembly.compile(bytes);
    const descriptors = WebAssembly.Module.imports(module);
    const importCandidates = descriptors.map((descriptor) => runtimeImportStubCandidates(descriptor));
    if (importCandidates.some((candidates) => candidates.length === 0)) {
      const unsupported = descriptors.find((descriptor, index) => importCandidates[index].length === 0)!;
      return { unsupported: `unsupported import kind ${unsupported.kind}` };
    }
    let instance: WebAssembly.Instance | null = null;
    let lastInstantiateError: unknown = null;
    const maxInstantiateAttempts = 64;
    for (let attempt = 0; attempt < maxInstantiateAttempts; attempt += 1) {
      const imports: Record<string, Record<string, unknown>> = {};
      let remaining = attempt;
      let coveredAllCandidates = true;
      for (let index = 0; index < descriptors.length; index += 1) {
        const descriptor = descriptors[index];
        const candidates = importCandidates[index];
        const candidateIndex = remaining % candidates.length;
        remaining = Math.floor(remaining / candidates.length);
        const moduleImports = (imports[descriptor.module] ??= {});
        moduleImports[descriptor.name] = candidates[candidateIndex];
        if (remaining > 0 && index === descriptors.length - 1) {
          coveredAllCandidates = false;
        }
      }
      if (!coveredAllCandidates) {
        break;
      }
      try {
        instance = await WebAssembly.instantiate(module, imports);
        break;
      } catch (error) {
        lastInstantiateError = error;
      }
    }
    if (instance === null) {
      return { unsupported: commandFailureDetail(lastInstantiateError) };
    }
    return { instance };
  } catch (error) {
    return { unsupported: commandFailureDetail(error) };
  }
}

function invokeNodeExport(func: Function, args: unknown[]): RuntimeInvocationOutcome {
  try {
    return { kind: "result", value: func(...args) };
  } catch (error) {
    return { kind: "trap", detail: commandFailureDetail(error) };
  }
}

export async function runNodeExportInvocationMatrix(
  leftWasmPath: string,
  rightWasmPath: string,
  maxInvocations = 8,
): Promise<RuntimeExportInvocationReport[]> {
  const left = await instantiateNodeRuntime(leftWasmPath);
  const right = await instantiateNodeRuntime(rightWasmPath);
  if ("unsupported" in left || "unsupported" in right) {
    const leftResult: RuntimeInvocationOutcome = "unsupported" in left
      ? { kind: "unsupported", detail: left.unsupported }
      : { kind: "result", value: "instantiated" };
    const rightResult: RuntimeInvocationOutcome = "unsupported" in right
      ? { kind: "unsupported", detail: right.unsupported }
      : { kind: "result", value: "instantiated" };
    return [
      {
        exportName: "<instantiate>",
        args: [],
        leftResult,
        rightResult,
        classification: classifyRuntimeInvocationPair(leftResult, rightResult),
      },
    ];
  }

  const reports: RuntimeExportInvocationReport[] = [];
  for (const [exportName, leftValue] of Object.entries(left.instance.exports)) {
    if (typeof leftValue !== "function") continue;
    const rightValue = right.instance.exports[exportName];
    if (typeof rightValue !== "function") continue;
    const args = deterministicExportArgumentVector(leftValue);
    const leftResult = invokeNodeExport(leftValue, args);
    const rightResult = invokeNodeExport(rightValue, args);
    reports.push({
      exportName,
      args: args.map(runtimeValueKey),
      leftResult,
      rightResult,
      classification: classifyRuntimeInvocationPair(leftResult, rightResult),
    });
    if (reports.length >= maxInvocations) break;
  }
  return reports;
}

export async function smokeExecuteNodeRuntime(
  wasmPath: string,
): Promise<{ ok: boolean; unsupported: boolean; detail: string }> {
  const runtime = await instantiateNodeRuntime(wasmPath);
  if ("unsupported" in runtime) {
    return { ok: false, unsupported: true, detail: runtime.unsupported };
  }
  let invoked = 0;
  for (const value of Object.values(runtime.instance.exports)) {
    if (typeof value === "function") {
      const args = deterministicExportArgumentVector(value);
      invokeNodeExport(value, args);
      invoked += 1;
    }
    if (invoked >= 8) {
      break;
    }
  }
  return {
    ok: true,
    unsupported: false,
    detail:
      invoked === 0
        ? "instantiated; no function exports"
        : `instantiated; invoked ${invoked} function export(s) with deterministic simple argument vector(s)`,
  };
}

async function runExternalValidatorsAsync(
  options: PassFuzzCompareOptions,
  wasmPath: string,
  repoRoot: string,
  summary: PassFuzzCompareSummary,
): Promise<{ ok: boolean; stderr: string }> {
  for (const kind of options.externalValidators) {
    const result = await runExternalValidatorAsync(kind, options, wasmPath, repoRoot);
    if (result.skipped) {
      summary.externalValidatorSkipped[kind] = (summary.externalValidatorSkipped[kind] ?? 0) + 1;
      continue;
    }
    if (!result.ok) {
      return { ok: false, stderr: `${kind}: ${result.stderr}` };
    }
  }
  return { ok: true, stderr: "" };
}

function commandFailureDetail(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

function hasNonEmptyFile(pathname: string): boolean {
  try {
    const stat = fs.statSync(pathname);
    return stat.isFile() && stat.size > 0;
  } catch {
    return false;
  }
}

async function runStarshineWithRetry(
  starshineInvocation: StarshineInvocation,
  starshineArgs: string[],
  starshineRawPath: string,
  repoRoot: string,
  repoTmpEnv: NodeJS.ProcessEnv,
): Promise<void> {
  const maxAttempts = starshineInvocation.retryMissingOutput ? 3 : 1;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    fs.rmSync(starshineRawPath, { force: true });
    await runOrThrowAsync(starshineInvocation.command, starshineArgs, {
      cwd: repoRoot,
      env: repoTmpEnv,
    });
    if (hasNonEmptyFile(starshineRawPath)) {
      return;
    }
  }
  fail(
    `Starshine command succeeded but did not create expected output after ${maxAttempts} attempt${maxAttempts === 1 ? "" : "s"}: ${starshineRawPath}`,
  );
}

function classifyCommandFailure(detail: string): CommandFailureClass {
  if (detail.startsWith("Starshine command failed:")) {
    if (detail.includes("DecodeAt(InvalidLimits")) {
      return "starshine-invalid-limits";
    }
    if (detail.includes("Invalid range for limits")) {
      return "starshine-invalid-range-for-limits";
    }
    return "starshine-command-failed";
  }
  if (detail.includes("invalid type index")) {
    return "binaryen-invalid-type-index";
  }
  if (detail.includes("invalid tag index")) {
    return "binaryen-invalid-tag-index";
  }
  if (detail.includes("Recursion groups of size zero not supported")) {
    return "binaryen-rec-group-zero";
  }
  if (detail.includes("invalid wasm type: -64")) {
    return "binaryen-invalid-wasm-type-neg64";
  }
  if (detail.includes("initializer expression is not constant")) {
    return "binaryen-initializer-expression-not-constant";
  }
  if (detail.includes("Table index out of range.")) {
    return "binaryen-table-index-out-of-range";
  }
  if (detail.includes("bad section size")) {
    return "binaryen-bad-section-size";
  }
  return "binaryen-command-failed";
}

function noteCommandFailureClass(
  summary: PassFuzzCompareSummary,
  failureClass: CommandFailureClass,
): void {
  summary.commandFailureClasses[failureClass] =
    (summary.commandFailureClasses[failureClass] ?? 0) + 1;
}

async function normalizePrintWat(
  wasmOptBin: string,
  wasmPath: string,
  watPath: string,
  repoRoot: string,
): Promise<string> {
  await runOrThrowAsync(
    wasmOptBin,
    [wasmPath, "--all-features", "--strip-debug", "-S", "-o", watPath],
    { cwd: repoRoot, env: makeRepoTmpEnv(repoRoot) },
  );
  return fs.readFileSync(watPath, "utf8");
}

async function canonicalizeWasm(
  wasmOptBin: string,
  inputPath: string,
  outputPath: string,
  repoRoot: string,
): Promise<void> {
  await runOrThrowAsync(
    wasmOptBin,
    [inputPath, "--all-features", "--strip-debug", "-o", outputPath],
    { cwd: repoRoot, env: makeRepoTmpEnv(repoRoot) },
  );
}

function parenDelta(line: string): number {
  let delta = 0;
  for (const char of line) {
    if (char === "(") delta += 1;
    if (char === ")") delta -= 1;
  }
  return delta;
}

function isDropConstExpression(text: string): boolean {
  if (!text.trimStart().startsWith("(drop")) return false;
  const unsafePattern = /\b(call|call_ref|return_call|local\.|global\.|load|store|memory\.|table\.|ref\.|struct\.|array\.|br|br_if|br_table|return|if|block|loop|try|try_table|throw|rethrow|delegate|select|unreachable|nop|promote|demote)\b/;
  if (unsafePattern.test(text)) return false;
  if (/\.(?:div_s|div_u|rem_s|rem_u)\b/.test(text) && /\b[if](?:32|64)\.const\s+(?:0|-1)\b/.test(text)) {
    return false;
  }
  // Keep the first drop-consts normalizer intentionally syntax-scoped: it only
  // erases dropped closed numeric expression trees. Div/rem are accepted only
  // for the simple nonzero constant debris shape used by gen-valid; anything
  // that can observe locals/globals/memory/tables, call, branch, or otherwise
  // affect module state is rejected.
  const allowedTokens = new Set([
    "drop",
    "nan",
    "inf",
    "e",
    "E",
    "i32.const",
    "i64.const",
    "f32.const",
    "f64.const",
    "i32.eqz",
    "i64.eqz",
    "i32.eq",
    "i32.ne",
    "i32.lt_s",
    "i32.lt_u",
    "i32.gt_s",
    "i32.gt_u",
    "i32.le_s",
    "i32.le_u",
    "i32.ge_s",
    "i32.ge_u",
    "i64.eq",
    "i64.ne",
    "i64.lt_s",
    "i64.lt_u",
    "i64.gt_s",
    "i64.gt_u",
    "i64.le_s",
    "i64.le_u",
    "i64.ge_s",
    "i64.ge_u",
    "i32.add",
    "i32.sub",
    "i32.mul",
    "i32.div_s",
    "i32.div_u",
    "i32.rem_s",
    "i32.rem_u",
    "i32.and",
    "i32.or",
    "i32.xor",
    "i32.shl",
    "i32.shr_s",
    "i32.shr_u",
    "i32.rotl",
    "i32.rotr",
    "i64.add",
    "i64.sub",
    "i64.mul",
    "i64.div_s",
    "i64.div_u",
    "i64.rem_s",
    "i64.rem_u",
    "i64.and",
    "i64.or",
    "i64.xor",
    "i64.shl",
    "i64.shr_s",
    "i64.shr_u",
    "i64.rotl",
    "i64.rotr",
    "i32.clz",
    "i32.ctz",
    "i32.popcnt",
    "i64.clz",
    "i64.ctz",
    "i64.popcnt",
    "f32.eq",
    "f32.ne",
    "f32.lt",
    "f32.gt",
    "f32.le",
    "f32.ge",
    "f64.eq",
    "f64.ne",
    "f64.lt",
    "f64.gt",
    "f64.le",
    "f64.ge",
    "i32.trunc_f32_u",
    "i32.trunc_f64_u",
    "i64.trunc_f32_u",
    "i64.trunc_f64_u",
    "i32.trunc_sat_f32_s",
    "i32.trunc_sat_f32_u",
    "i32.trunc_sat_f64_s",
    "i32.trunc_sat_f64_u",
    "i64.trunc_sat_f32_s",
    "i64.trunc_sat_f32_u",
    "i64.trunc_sat_f64_s",
    "i64.trunc_sat_f64_u",
    "i64.extend_i32_u",
    "i32.wrap_i64",
    "f32.reinterpret_i32",
    "f64.reinterpret_i64",
    "i32.reinterpret_f32",
    "i64.reinterpret_f64",
    "i32.extend8_s",
    "i32.extend16_s",
    "i64.extend8_s",
    "i64.extend16_s",
    "i64.extend32_s",
    "f32.convert_i32_u",
    "f32.convert_i64_u",
    "f64.convert_i32_u",
    "f64.convert_i64_u",
    "f32.abs",
    "f32.neg",
    "f32.ceil",
    "f32.floor",
    "f32.trunc",
    "f32.nearest",
    "f32.sqrt",
    "f32.min",
    "f32.max",
    "f32.copysign",
    "f64.abs",
    "f64.neg",
    "f64.ceil",
    "f64.floor",
    "f64.trunc",
    "f64.nearest",
    "f64.sqrt",
    "f64.min",
    "f64.max",
    "f64.copysign",
  ]);
  const tokenPattern = /(?<![0-9.])[A-Za-z_][A-Za-z0-9_.$-]*/g;
  for (const match of text.matchAll(tokenPattern)) {
    if (!allowedTokens.has(match[0])) {
      return false;
    }
  }
  return true;
}

function normalizeDroppedConstExpressions(wat: string): string {
  const lines = wat.split("\n");
  const output: string[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.trimStart().startsWith("(drop")) {
      output.push(line);
      continue;
    }
    const exprLines = [line];
    let balance = parenDelta(line);
    while (balance > 0 && index + 1 < lines.length) {
      index += 1;
      exprLines.push(lines[index]);
      balance += parenDelta(lines[index]);
    }
    const exprText = exprLines.join("\n");
    if (!isDropConstExpression(exprText)) {
      output.push(...exprLines);
    }
  }
  return output.join("\n");
}

function isUnreachableControlDebrisBlock(text: string): boolean {
  const labelMatch = text.match(/^\s*\(block\s+(\$[A-Za-z0-9_.$-]+)/);
  if (!labelMatch) return false;
  const label = labelMatch[1];
  const unsafePattern = /\b(call|call_ref|return_call|local\.|global\.|load|store|memory\.|table\.|ref\.|struct\.|array\.|br_if|return|if|loop|try|try_table|throw|rethrow|delegate|select|nop|unreachable)\b/;
  if (unsafePattern.test(text)) return false;
  const brTableMatch = text.match(/\(br_table\s+([^()]+?)\s*\(/s);
  if (!brTableMatch) return false;
  const targets = Array.from(brTableMatch[1].matchAll(/\$[A-Za-z0-9_.$-]+/g)).map((match) => match[0]);
  if (targets.length === 0 || targets.some((target) => target !== label)) return false;
  const allowedTokens = new Set(["block", "br_table", "i32.const"]);
  const tokenPattern = /[A-Za-z_][A-Za-z0-9_.$-]*/g;
  for (const match of text.matchAll(tokenPattern)) {
    if (!allowedTokens.has(match[0])) return false;
  }
  return true;
}

function stripFunctionTypeIds(wat: string): string {
  return wat
    .split("\n")
    .filter((line) => !/^\s*\(type\s+\$/.test(line))
    .map((line) => line.replace(/\s+\(type\s+\$[A-Za-z0-9_.$-]+\)/g, ""))
    .join("\n");
}

function isVoidBranchUnreachableBlockDebris(text: string): boolean {
  const labelMatch = text.match(/^\s*\(block\s+(\$[A-Za-z0-9_.$-]+)\s*\n/);
  if (!labelMatch) return false;
  const label = labelMatch[1].replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = new RegExp(
    `^\\s*\\(block\\s+${label}\\s*\\n` +
      `\\s*\\(block\\s*\\n` +
      `\\s*\\(br\\s+${label}\\)\\s*\\n` +
      `\\s*\\)\\s*\\n` +
      `\\s*\\(unreachable\\)\\s*\\n` +
      `\\s*\\)\\s*$`,
  );
  return pattern.test(text);
}

function normalizeVoidBranchUnreachableBlockDebris(wat: string): string {
  const lines = wat.split("\n");
  const output: string[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.trimStart().startsWith("(block")) {
      output.push(line);
      continue;
    }
    const exprLines = [line];
    let balance = parenDelta(line);
    while (balance > 0 && index + 1 < lines.length) {
      index += 1;
      exprLines.push(lines[index]);
      balance += parenDelta(lines[index]);
    }
    const exprText = exprLines.join("\n");
    if (isVoidBranchUnreachableBlockDebris(exprText)) {
      continue;
    }
    output.push(...exprLines);
  }
  return output.join("\n");
}

function normalizeLocalUnreachableControlDebris(wat: string): string {
  const lines = wat.split("\n");
  const output: string[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.trimStart().startsWith("(block")) {
      output.push(line);
      continue;
    }
    const exprLines = [line];
    let balance = parenDelta(line);
    while (balance > 0 && index + 1 < lines.length) {
      index += 1;
      exprLines.push(lines[index]);
      balance += parenDelta(lines[index]);
    }
    const nextLine = index + 1 < lines.length ? lines[index + 1].trim() : "";
    const exprText = exprLines.join("\n");
    if (nextLine === "(unreachable)" && isUnreachableControlDebrisBlock(exprText)) {
      continue;
    }
    output.push(...exprLines);
  }
  return output.join("\n");
}

function normalizeUnusedUnreachableFunctions(wat: string): string {
  const referenced = new Set<string>();
  for (const match of wat.matchAll(/\(export\s+"[^"]+"\s+\(func\s+(\$[A-Za-z0-9_.$-]+)\)\)/g)) {
    referenced.add(match[1]);
  }
  for (const match of wat.matchAll(/\b(?:call|return_call|ref\.func)\s+(\$[A-Za-z0-9_.$-]+)/g)) {
    referenced.add(match[1]);
  }
  const lines = wat.split("\n");
  const output: string[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const funcMatch = line.match(/^\s*\(func\s+(\$[A-Za-z0-9_.$-]+)/);
    if (!funcMatch || referenced.has(funcMatch[1])) {
      output.push(line);
      continue;
    }
    const exprLines = [line];
    let balance = parenDelta(line);
    while (balance > 0 && index + 1 < lines.length) {
      index += 1;
      exprLines.push(lines[index]);
      balance += parenDelta(lines[index]);
    }
    const body = normalizeLocalUnreachableControlDebris(normalizeDroppedConstExpressions(exprLines.join("\n")));
    const unsafePattern = /\b(call|call_ref|return_call|local\.|global\.|load|store|memory\.|table\.|ref\.|struct\.|array\.|br|br_if|br_table|return|if|block|loop|try|try_table|throw|rethrow|delegate|select|nop)\b/;
    const bodyWithoutDecls = body
      .split("\n")
      .filter((bodyLine) => !/^\s*\(func\b/.test(bodyLine) && !/^\s*\(local\b/.test(bodyLine) && bodyLine.trim() !== ")")
      .join("\n");
    if (bodyWithoutDecls.includes("(unreachable)") && !unsafePattern.test(bodyWithoutDecls.replace(/\(unreachable\)/g, ""))) {
      output.push(` (func ${funcMatch[1]}`);
      output.push("  (unreachable)");
      output.push(" )");
    } else {
      output.push(...exprLines);
    }
  }
  return output.join("\n");
}

function isDropUnreachableExpression(exprText: string): boolean {
  return /^\s*\(drop\s*\n\s*\(unreachable\)\s*\n\s*\)\s*$/.test(exprText);
}

function normalizeDropUnreachableBeforeUnreachable(wat: string): string {
  const lines = wat.split("\n");
  const output: string[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.trimStart().startsWith("(drop")) {
      output.push(line);
      continue;
    }
    const exprLines = [line];
    let balance = parenDelta(line);
    while (balance > 0 && index + 1 < lines.length) {
      index += 1;
      exprLines.push(lines[index]);
      balance += parenDelta(lines[index]);
    }
    const nextLine = index + 1 < lines.length ? lines[index + 1].trim() : "";
    const exprText = exprLines.join("\n");
    if (nextLine === "(unreachable)" && isDropUnreachableExpression(exprText)) {
      continue;
    }
    output.push(...exprLines);
  }
  return output.join("\n");
}

function normalizeUnreachableControlDebris(wat: string): string {
  return stripFunctionTypeIds(
    normalizeDropUnreachableBeforeUnreachable(
      normalizeUnusedUnreachableFunctions(
        normalizeVoidBranchUnreachableBlockDebris(
          normalizeLocalUnreachableControlDebris(wat),
        ),
      ),
    ),
  );
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function normalizeStandaloneNops(wat: string): string {
  return wat
    .split("\n")
    .filter((line) => line.trim() !== "(nop)")
    .join("\n");
}

function normalizeUnusedLocalDeclarationsInFunction(funcText: string): string {
  if (/\blocal\.(?:get|set|tee)\s+\d+\b/.test(funcText)) return funcText;
  const lines = funcText.split("\n");
  const localDeclPattern = /^\s*\(local\s+(\$[A-Za-z0-9_.$-]+)\s+[A-Za-z0-9_.]+\)\s*$/;
  return lines
    .filter((line) => {
      const match = line.match(localDeclPattern);
      if (!match) return true;
      const localName = match[1];
      const refPattern = new RegExp(`\\blocal\\.(?:get|set|tee)\\s+${escapeRegExp(localName)}\\b`);
      return refPattern.test(funcText);
    })
    .join("\n");
}

function normalizeLocalNamesInFunction(funcText: string): string {
  if (/\blocal\.(?:get|set|tee)\s+\d+\b/.test(funcText)) return funcText;
  const localNames: string[] = [];
  for (const match of funcText.matchAll(/\(param\s+(\$[A-Za-z0-9_.$-]+)\s+[A-Za-z0-9_.]+/g)) {
    if (!localNames.includes(match[1])) localNames.push(match[1]);
  }
  for (const match of funcText.matchAll(/^\s*\(local\s+(\$[A-Za-z0-9_.$-]+)\s+[A-Za-z0-9_.]+\)\s*$/gm)) {
    if (!localNames.includes(match[1])) localNames.push(match[1]);
  }
  if (localNames.length === 0) return funcText;
  const localNameMap = new Map(localNames.map((name, index) => [name, `$local${index}`]));
  return funcText
    .split("\n")
    .map((line) => line
      .replace(/\((param|local)\s+(\$[A-Za-z0-9_.$-]+)\b/g, (full, kind: string, name: string) => {
        const replacement = localNameMap.get(name);
        return replacement === undefined ? full : `(${kind} ${replacement}`;
      })
      .replace(/\blocal\.(get|set|tee)\s+(\$[A-Za-z0-9_.$-]+)\b/g, (full, kind: string, name: string) => {
        const replacement = localNameMap.get(name);
        return replacement === undefined ? full : `local.${kind} ${replacement}`;
      }))
    .join("\n");
}

function normalizeUnusedLocalDeclarations(wat: string): string {
  const lines = wat.split("\n");
  const output: string[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.trimStart().startsWith("(func")) {
      output.push(line);
      continue;
    }
    const funcLines = [line];
    let balance = parenDelta(line);
    while (balance > 0 && index + 1 < lines.length) {
      index += 1;
      funcLines.push(lines[index]);
      balance += parenDelta(lines[index]);
    }
    output.push(...normalizeLocalNamesInFunction(normalizeUnusedLocalDeclarationsInFunction(funcLines.join("\n"))).split("\n"));
  }
  return output.join("\n");
}

function normalizeLocalCleanupDebris(wat: string): string {
  return normalizeStandaloneNops(normalizeUnusedLocalDeclarations(wat));
}

function applyCompareNormalizers(wat: string, normalizers: CompareNormalizer[]): string {
  let normalized = wat;
  for (const normalizer of normalizers) {
    if (normalizer === "drop-consts") {
      normalized = normalizeDroppedConstExpressions(normalized);
    } else if (normalizer === "unreachable-control-debris") {
      normalized = normalizeUnreachableControlDebris(normalized);
    } else if (normalizer === "local-cleanup-debris") {
      normalized = normalizeLocalCleanupDebris(normalized);
    }
  }
  return normalized;
}

export function applyCompareNormalizersForTest(wat: string, normalizers: CompareNormalizer[]): string {
  return applyCompareNormalizers(wat, normalizers);
}

async function runSmith(
  wasmToolsBin: string,
  outputPath: string,
  seedBytes: Buffer,
  repoRoot: string,
): Promise<{ ok: boolean; stderr: string }> {
  const result = await runProcess(wasmToolsBin, ["smith", "-o", outputPath], {
    cwd: repoRoot,
    env: makeRepoTmpEnv(repoRoot),
    input: seedBytes,
  });
  return {
    ok: result.status === 0,
    stderr: result.stderr.trim(),
  };
}

function makeSmithSeedBytes(seed: bigint, length = 64): Buffer {
  const mask = (1n << 64n) - 1n;
  let state = seed & mask;
  const out = Buffer.alloc(length);
  for (let i = 0; i < length; i += 8) {
    state = (state + 0x9e3779b97f4a7c15n) & mask;
    let z = state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & mask;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & mask;
    z ^= z >> 31n;
    const value = z & mask;
    for (let j = 0; j < 8 && i + j < length; j += 1) {
      out[i + j] = Number((value >> BigInt(j * 8)) & 0xffn);
    }
  }
  return out;
}

function generatorForIndex(mode: GeneratorMode, index: number): GeneratorKind {
  if (mode === "wasm-smith") {
    return "wasm-smith";
  }
  if (mode === "gen-valid") {
    return "gen-valid";
  }
  return index % 2 === 0 ? "wasm-smith" : "gen-valid";
}

function requiredGenValidCount(mode: GeneratorMode, totalCount: number): number {
  if (mode === "wasm-smith") {
    return 0;
  }
  if (mode === "gen-valid") {
    return totalCount;
  }
  return Math.floor(totalCount / 2);
}

function listGeneratedGenValidInputs(dir: string): string[] {
  return fs
    .readdirSync(dir)
    .filter((entry) => entry.endsWith(".wasm"))
    .sort()
    .map((entry) => path.join(dir, entry));
}

function emptyEffectTrapCounts(): EffectTrapCounts {
  return {
    hasCall: 0,
    mutatesMemory: 0,
    mutatesTable: 0,
    mutatesGlobal: 0,
    hasException: 0,
    hasAtomics: 0,
    hasUnreachable: 0,
    mayTrap: 0,
  };
}

function noteInputEffectTrapFacts(summary: PassFuzzCompareSummary, facts: EffectTrapFacts): void {
  if (facts.hasCall) summary.inputEffectTrapCounts.hasCall += 1;
  if (facts.mutatesMemory) summary.inputEffectTrapCounts.mutatesMemory += 1;
  if (facts.mutatesTable) summary.inputEffectTrapCounts.mutatesTable += 1;
  if (facts.mutatesGlobal) summary.inputEffectTrapCounts.mutatesGlobal += 1;
  if (facts.hasException) summary.inputEffectTrapCounts.hasException += 1;
  if (facts.hasAtomics) summary.inputEffectTrapCounts.hasAtomics += 1;
  if (facts.hasUnreachable) summary.inputEffectTrapCounts.hasUnreachable += 1;
  if (facts.mayTrap) summary.inputEffectTrapCounts.mayTrap += 1;
}

function genValidManifestTransformId(genValidManifestEntry: unknown | null): string | null {
  if (genValidManifestEntry !== null && typeof genValidManifestEntry === "object" && "transform_id" in genValidManifestEntry) {
    const transformId = (genValidManifestEntry as { transform_id?: unknown }).transform_id;
    if (typeof transformId === "string" && transformId.length > 0) {
      return transformId;
    }
  }
  return null;
}

function genValidManifestFeatureFacts(genValidManifestEntry: unknown | null): unknown | null {
  if (genValidManifestEntry !== null && typeof genValidManifestEntry === "object" && "feature_facts" in genValidManifestEntry) {
    return (genValidManifestEntry as { feature_facts?: unknown }).feature_facts ?? null;
  }
  return null;
}

function noteGenValidTransformCount(summary: PassFuzzCompareSummary, transformId: string | null): void {
  if (transformId === null) {
    return;
  }
  summary.genValidTransformCounts[transformId] = (summary.genValidTransformCounts[transformId] ?? 0) + 1;
}

function noteRuntimeExportInvocationMatrix(
  summary: PassFuzzCompareSummary,
  reports: RuntimeExportInvocationReport[],
): void {
  const caseSummary = summarizeRuntimeExportInvocationMatrix(reports);
  summary.runtimeExecutionMatrix.summary.total += caseSummary.total;
  summary.runtimeExecutionMatrix.summary.equalResults += caseSummary.equalResults;
  summary.runtimeExecutionMatrix.summary.equalTraps += caseSummary.equalTraps;
  summary.runtimeExecutionMatrix.summary.unsupportedRuntimes += caseSummary.unsupportedRuntimes;
  summary.runtimeExecutionMatrix.summary.nondeterministicImports += caseSummary.nondeterministicImports;
  summary.runtimeExecutionMatrix.summary.semanticMismatches += caseSummary.semanticMismatches;
  for (const sample of runtimeSemanticMismatchSamples(reports)) {
    if (summary.runtimeExecutionMatrix.semanticMismatchSamples.length >= 8) {
      break;
    }
    summary.runtimeExecutionMatrix.semanticMismatchSamples.push(sample);
  }
  const outcome = classifyRuntimeExportInvocationMatrix(summary.runtimeExecutionMatrix.summary);
  if (outcome === "semantic-mismatch" || summary.runtimeExecutionMatrix.outcome !== "semantic-mismatch") {
    summary.runtimeExecutionMatrix.outcome = outcome;
  }
}

function runtimeExportInvocationMatrixPersistence(
  reports: RuntimeExportInvocationReport[],
): RuntimeExportInvocationMatrixPersistence {
  const matrixSummary = summarizeRuntimeExportInvocationMatrix(reports);
  return {
    summary: matrixSummary,
    outcome: classifyRuntimeExportInvocationMatrix(matrixSummary),
    semanticMismatchSamples: runtimeSemanticMismatchSamples(reports),
  };
}

function addCounter(target: Record<string, number>, key: string, value: number): void {
  if (Number.isFinite(value) && value !== 0) {
    target[key] = value;
  }
}

function sanitizeCounterKey(value: string): string {
  return value.replace(/[^A-Za-z0-9._-]+/g, "_").replace(/^_+|_+$/g, "") || "unknown";
}

function passFuzzProfileName(summary: PassFuzzCompareSummary): string {
  const passName = summary.passFlags.map((flag) => flag.replace(/^--/, "")).join("+") || "no-pass";
  return `${passName}+${summary.generator}`;
}

export function passFuzzSummaryCoverageReport(summary: PassFuzzCompareSummary): FuzzSummaryReport {
  const features: Record<string, number> = {};
  addCounter(features, "optional_input_has_call", summary.inputEffectTrapCounts.hasCall);
  addCounter(features, "optional_input_mutates_memory", summary.inputEffectTrapCounts.mutatesMemory);
  addCounter(features, "optional_input_mutates_table", summary.inputEffectTrapCounts.mutatesTable);
  addCounter(features, "optional_input_mutates_global", summary.inputEffectTrapCounts.mutatesGlobal);
  addCounter(features, "optional_input_has_exception", summary.inputEffectTrapCounts.hasException);
  addCounter(features, "optional_input_has_atomics", summary.inputEffectTrapCounts.hasAtomics);
  addCounter(features, "optional_input_has_unreachable", summary.inputEffectTrapCounts.hasUnreachable);
  addCounter(features, "optional_input_may_trap", summary.inputEffectTrapCounts.mayTrap);
  addCounter(features, "optional_runtime_checked", summary.runtimeExecutionCounts.checked);
  addCounter(features, "optional_runtime_unsupported", summary.runtimeExecutionCounts.unsupported);
  addCounter(features, "optional_runtime_failed", summary.runtimeExecutionCounts.failed);
  for (const [kind, count] of Object.entries(summary.externalValidatorSkipped)) {
    addCounter(features, `optional_external_validator_${sanitizeCounterKey(kind)}_skipped`, count ?? 0);
  }

  const strategies: Record<string, number> = {
    required_requested_cases: summary.requestedCount,
    required_compared_cases: summary.comparedCount,
  };
  addCounter(strategies, "optional_generator_wasm_smith", summary.generatorCounts.wasmSmith);
  addCounter(strategies, "optional_generator_gen_valid", summary.generatorCounts.genValid);
  for (const [transform, count] of Object.entries(summary.genValidTransformCounts)) {
    addCounter(strategies, `optional_gen_valid_transform_${sanitizeCounterKey(transform)}`, count);
  }
  addCounter(strategies, "optional_property_idempotence_checked", summary.idempotenceCheckedCount);
  addCounter(strategies, "optional_property_idempotence_matched", summary.idempotenceMatchCount);
  addCounter(strategies, "optional_property_composition_checked", summary.compositionCheckedCount);
  addCounter(strategies, "optional_property_composition_matched", summary.compositionMatchCount);

  const matchCount = summary.normalizedMatchCount + summary.cleanupNormalizedMatchCount;
  const statuses: Record<string, number> = {};
  addCounter(statuses, "match", matchCount);
  addCounter(statuses, "normalized-match", summary.normalizedMatchCount);
  addCounter(statuses, "cleanup-normalized-match", summary.cleanupNormalizedMatchCount);
  addCounter(statuses, "mismatch", summary.mismatchCount);
  addCounter(statuses, "validation-failure", summary.validationFailureCount);
  addCounter(statuses, "generator-failure", summary.generatorFailureCount);
  addCounter(statuses, "command-failure", summary.commandFailureCount);
  addCounter(statuses, "property-failure", summary.propertyFailureCount);
  addCounter(statuses, "max-failures-hit", summary.maxFailuresHit ? 1 : 0);

  const failures: Record<string, number> = {};
  addCounter(failures, "mismatch", summary.mismatchCount);
  addCounter(failures, "validation", summary.validationFailureCount);
  addCounter(failures, "generator", summary.generatorFailureCount);
  addCounter(failures, "command", summary.commandFailureCount);
  addCounter(failures, "property", summary.propertyFailureCount);
  for (const [failureClass, count] of Object.entries(summary.commandFailureClasses)) {
    addCounter(failures, `command-class.${failureClass}`, count ?? 0);
  }
  addCounter(failures, "runtime.semantic-mismatch", summary.runtimeExecutionMatrix.summary.semanticMismatches);
  addCounter(failures, "runtime.unsupported", summary.runtimeExecutionMatrix.summary.unsupportedRuntimes);
  addCounter(failures, "runtime.nondeterministic-import", summary.runtimeExecutionMatrix.summary.nondeterministicImports);

  const artifacts: Record<string, number> = {};
  addCounter(artifacts, "failure_dirs", summary.failureDirs.length);
  addCounter(artifacts, "gen_valid_manifest", summary.genValidManifestPath === null ? 0 : 1);

  return normalizeFuzzSummaryReport({
    suite: "compare-pass",
    profile: passFuzzProfileName(summary),
    seed: summary.seed,
    summary: {
      features,
      opcodes: {},
      strategies,
      statuses,
      failures,
      timings: {},
      artifacts,
    },
  });
}

function safeArtifactNameSegment(value: string): string {
  return value.replace(/[^A-Za-z0-9._-]+/g, "_").replace(/^_+|_+$/g, "") || "unknown";
}

export function passFuzzReductionLogTextForTest(status: CaseStatus, reductionArtifact: MismatchReductionArtifact): string {
  return formatReductionReportLog({
    status,
    artifactPath: "reduced-input.wasm",
    artifactPathKey: "reduced_wasm_path",
    originalSize: reductionArtifact.originalSize,
    finalSize: reductionArtifact.finalSize,
    predicateEvaluations: reductionArtifact.predicateEvaluations,
    steps: reductionArtifact.steps,
  });
}

function persistFailureArtifacts(
  outDir: string,
  caseIndex: number,
  generator: GeneratorKind,
  status: CaseStatus,
  detail: string,
  workDir: string,
  wasmToolsBin: string,
  repoRoot: string,
  passFlags: string[],
  genValidManifestEntry: unknown | null = null,
  inputEffectTrapFacts: EffectTrapFacts | null = null,
  runtimeInvocationReports: RuntimeExportInvocationReport[] | null = null,
  reductionArtifact: MismatchReductionArtifact | null = null,
): string {
  const transformId = genValidManifestTransformId(genValidManifestEntry);
  const failureDir = path.join(
    outDir,
    "failures",
    `case-${String(caseIndex).padStart(6, "0")}-${generator}${transformId === null ? "" : `-transform-${safeArtifactNameSegment(transformId)}`}`,
  );
  fs.mkdirSync(failureDir, { recursive: true });
  fs.writeFileSync(path.join(failureDir, "failure.txt"), `${detail}\n`);
  const artifacts: string[] = [];
  for (const entry of fs.readdirSync(workDir)) {
    const source = path.join(workDir, entry);
    const target = path.join(failureDir, entry);
    if (fs.statSync(source).isFile()) {
      fs.copyFileSync(source, target);
      artifacts.push(entry);
    }
  }
  const inputPath = path.join(failureDir, "input.wasm");
  if (fs.existsSync(inputPath)) {
    const result = spawnSync(wasmToolsBin, ["print", inputPath], {
      cwd: repoRoot,
      encoding: "utf8",
    });
    if (result.error) {
      throw result.error;
    }
    if (result.status === 0) {
      fs.writeFileSync(path.join(failureDir, "input.print.wat"), result.stdout ?? "");
      artifacts.push("input.print.wat");
    }
  }
  if (reductionArtifact !== null) {
    fs.writeFileSync(path.join(failureDir, "reduced-input.wasm"), reductionArtifact.reducedBytes);
    fs.writeFileSync(path.join(failureDir, "reduction.txt"), passFuzzReductionLogTextForTest(status, reductionArtifact));
    artifacts.push("reduced-input.wasm", "reduction.txt");
  }
  fs.writeFileSync(
    path.join(failureDir, "failure-metadata.json"),
    JSON.stringify(
      {
        caseIndex,
        generator,
        status,
        detail,
        artifacts: artifacts.sort(),
        genValidManifestEntry,
        transformId,
        inputEffectTrapFacts,
        runtimeExecutionMatrix:
          runtimeInvocationReports === null
            ? null
            : runtimeExportInvocationMatrixPersistence(runtimeInvocationReports),
        reduction:
          reductionArtifact === null
            ? null
            : {
                originalSize: reductionArtifact.originalSize,
                finalSize: reductionArtifact.finalSize,
                predicateEvaluations: reductionArtifact.predicateEvaluations,
                steps: reductionArtifact.steps,
                reducedWasm: "reduced-input.wasm",
                log: "reduction.txt",
              },
        replay: {
          input: "input.wasm",
          passFlags,
        },
      },
      null,
      2,
    ) + "\n",
  );
  return failureDir;
}

function runSyncOk(
  command: string,
  args: string[],
  repoRoot: string,
  env: NodeJS.ProcessEnv,
): boolean {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    env,
    encoding: "utf8",
    maxBuffer: 128 * 1024 * 1024,
  });
  return !result.error && result.status === 0;
}

function normalizePrintWatSync(
  wasmOptBin: string,
  wasmPath: string,
  watPath: string,
  repoRoot: string,
  env: NodeJS.ProcessEnv,
): string | null {
  if (!runSyncOk(wasmOptBin, [wasmPath, "--all-features", "--strip-debug", "-S", "-o", watPath], repoRoot, env)) {
    return null;
  }
  return fs.readFileSync(watPath, "utf8");
}

function canonicalizeWasmSync(
  wasmOptBin: string,
  inputPath: string,
  outputPath: string,
  repoRoot: string,
  env: NodeJS.ProcessEnv,
): boolean {
  return runSyncOk(wasmOptBin, [inputPath, "--all-features", "--strip-debug", "-o", outputPath], repoRoot, env);
}

function candidateStillHasPassFuzzMismatch(
  candidateBytes: Uint8Array,
  options: PassFuzzCompareOptions,
  starshineInvocation: StarshineInvocation,
  binaryenPassFlags: string[],
  repoRoot: string,
  repoTmpDir: string,
  repoTmpEnv: NodeJS.ProcessEnv,
): boolean {
  const workDir = fs.mkdtempSync(path.join(repoTmpDir, "starshine-pass-fuzz-reduce-"));
  try {
    const inputPath = path.join(workDir, "input.wasm");
    const starshineRawPath = path.join(workDir, "starshine.raw.wasm");
    const starshinePath = path.join(workDir, "starshine.wasm");
    const binaryenRawPath = path.join(workDir, "binaryen.raw.wasm");
    const binaryenPath = path.join(workDir, "binaryen.wasm");
    const starshineWatPath = path.join(workDir, "starshine.wat");
    const binaryenWatPath = path.join(workDir, "binaryen.wat");
    fs.writeFileSync(inputPath, candidateBytes);
    if (!runSyncOk(options.wasmToolsBin, ["validate", "--features", "all", inputPath], repoRoot, repoTmpEnv)) {
      return false;
    }
    const starshineArgs = [
      ...starshineInvocation.argsPrefix,
      ...options.passFlags,
      "--out",
      starshineRawPath,
      inputPath,
    ];
    if (!runSyncOk(starshineInvocation.command, starshineArgs, repoRoot, repoTmpEnv)) {
      return false;
    }
    if (!runSyncOk(options.wasmToolsBin, ["validate", "--features", "all", starshineRawPath], repoRoot, repoTmpEnv)) {
      return false;
    }
    if (!runSyncOk(options.wasmOptBin, [inputPath, "--all-features", ...binaryenPassFlags, "-o", binaryenRawPath], repoRoot, repoTmpEnv)) {
      return false;
    }
    if (!canonicalizeWasmSync(options.wasmOptBin, starshineRawPath, starshinePath, repoRoot, repoTmpEnv)) {
      return false;
    }
    if (!canonicalizeWasmSync(options.wasmOptBin, binaryenRawPath, binaryenPath, repoRoot, repoTmpEnv)) {
      return false;
    }
    const starshineWat = normalizePrintWatSync(options.wasmOptBin, starshinePath, starshineWatPath, repoRoot, repoTmpEnv);
    if (starshineWat === null) {
      return false;
    }
    const binaryenWat = normalizePrintWatSync(options.wasmOptBin, binaryenPath, binaryenWatPath, repoRoot, repoTmpEnv);
    if (binaryenWat === null) {
      return false;
    }
    if (starshineWat === binaryenWat) {
      return false;
    }
    if (options.normalizers.length > 0) {
      return applyCompareNormalizers(starshineWat, options.normalizers) !==
        applyCompareNormalizers(binaryenWat, options.normalizers);
    }
    return true;
  } finally {
    fs.rmSync(workDir, { recursive: true, force: true });
  }
}

function reduceGenValidMismatchInput(
  inputPath: string,
  options: PassFuzzCompareOptions,
  starshineInvocation: StarshineInvocation,
  binaryenPassFlags: string[],
  repoRoot: string,
  repoTmpDir: string,
  repoTmpEnv: NodeJS.ProcessEnv,
): MismatchReductionArtifact | null {
  const originalBytes = fs.readFileSync(inputPath);
  const reduction = reduceBinaryByByteSlicesWithReport(originalBytes, (candidate) => {
    return candidateStillHasPassFuzzMismatch(
      candidate,
      options,
      starshineInvocation,
      binaryenPassFlags,
      repoRoot,
      repoTmpDir,
      repoTmpEnv,
    );
  });
  if (reduction.finalSize >= reduction.originalSize) {
    return null;
  }
  return {
    reducedBytes: reduction.result,
    originalSize: reduction.originalSize,
    finalSize: reduction.finalSize,
    predicateEvaluations: reduction.predicateEvaluations,
    steps: reduction.steps,
  };
}

function loadReplayCases(
  repoRoot: string,
  replayFailuresFrom: string,
  failureStatus: CaseStatus | null,
  failureClass: CommandFailureClass | null,
  replayCaseIndex: number | null,
): ReplayCase[] {
  const replayDir = resolveRepoPath(repoRoot, replayFailuresFrom);
  const casesPath = path.join(replayDir, "cases.jsonl");
  if (!fs.existsSync(casesPath)) {
    fail(`missing cases.jsonl for replay source: ${replayDir}`);
  }

  const replayStatus = failureStatus ?? "command-failure";
  const replayCases: ReplayCase[] = [];
  for (const line of fs.readFileSync(casesPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      continue;
    }
    const record = JSON.parse(trimmed) as CaseRecord;
    if (record.status !== replayStatus) {
      continue;
    }
    if (replayCaseIndex !== null && record.caseIndex !== replayCaseIndex) {
      continue;
    }
    if (record.status === "command-failure") {
      const recordFailureClass = record.failureClass ?? classifyCommandFailure(record.detail);
      if (failureClass !== null && recordFailureClass !== failureClass) {
        continue;
      }
    } else if (failureClass !== null) {
      continue;
    }
    const failureDir = path.join(
      replayDir,
      "failures",
      `case-${String(record.caseIndex).padStart(6, "0")}-${record.generator}${record.transformId === undefined ? "" : `-transform-${safeArtifactNameSegment(record.transformId)}`}`,
    );
    const inputPath = path.join(failureDir, "input.wasm");
    if (!fs.existsSync(inputPath)) {
      fail(`missing saved replay input: ${inputPath}`);
    }
    replayCases.push({
      caseIndex: record.caseIndex,
      generator: record.generator,
      inputPath,
    });
  }

  if (replayCases.length === 0) {
    const detail = failureClass === null ? replayStatus : `${replayStatus}/${failureClass}`;
    fail(`no replay cases found for ${detail} in ${replayDir}`);
  }
  return replayCases;
}

export function parsePassFuzzCompareArgs(argv: string[]): ParseCommand {
  let count = 10000;
  let minCompared: number | null = null;
  let seed = 0x5eedn;
  let outDir = path.join(os.tmpdir(), `starshine-pass-fuzz-compare-${process.pid}`);
  let moonBin = resolveMoonBin();
  let starshineBin: string | null = null;
  let wasmOptBin = process.env.WASM_OPT_BIN || "wasm-opt";
  let wasmToolsBin = process.env.WASM_TOOLS_BIN || "wasm-tools";
  let binaryenValidateBin = process.env.BINARYEN_WASM_VALIDATE_BIN || "wasm-validate";
  let wabtValidateBin = process.env.WABT_WASM_VALIDATE_BIN || "wasm-validate";
  const externalValidators: ExternalValidatorKind[] = [];
  let runtimeExecution: RuntimeExecutionMode = "off";
  let propertyMode: PropertyMode = "none";
  let generator: GeneratorMode = "both";
  let genValidProfile: string | null = null;
  const genValidRequiredFeatures: string[] = [];
  const genValidExcludedFeatures: string[] = [];
  const genValidMetamorphicTransforms: string[] = [];
  let maxFailures = 20;
  let keepGoingAfterCommandFailures = false;
  let jobs: number | null = null;
  const passFlags: string[] = [];
  let replayFailuresFrom: string | null = null;
  let failureStatus: CaseStatus | null = null;
  let failureClass: CommandFailureClass | null = null;
  let replayCaseIndex: number | null = null;
  const normalizers: CompareNormalizer[] = [];
  let command: ParseCommand["kind"] = "run";

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--help":
      case "-h":
        command = "help";
        i += 1;
        break;
      case "--list-passes":
        command = "list-passes";
        i += 1;
        break;
      case "--list-failure-classes":
        command = "list-failure-classes";
        i += 1;
        break;
      case "--count":
        count = parseNonNegativeInt("count", argv[i + 1] ?? fail("missing value for --count"));
        i += 2;
        break;
      case "--seed":
        seed = parseBigIntSeed(argv[i + 1] ?? fail("missing value for --seed"));
        i += 2;
        break;
      case "--min-compared":
        minCompared = parseNonNegativeInt(
          "min-compared",
          argv[i + 1] ?? fail("missing value for --min-compared"),
        );
        i += 2;
        break;
      case "--out-dir":
        outDir = argv[i + 1] ?? fail("missing value for --out-dir");
        i += 2;
        break;
      case "--moon":
        moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      case "--starshine-bin":
        starshineBin = argv[i + 1] ?? fail("missing value for --starshine-bin");
        i += 2;
        break;
      case "--wasm-opt-bin":
        wasmOptBin = argv[i + 1] ?? fail("missing value for --wasm-opt-bin");
        i += 2;
        break;
      case "--wasm-tools-bin":
        wasmToolsBin = argv[i + 1] ?? fail("missing value for --wasm-tools-bin");
        i += 2;
        break;
      case "--binaryen-validate-bin":
        binaryenValidateBin = argv[i + 1] ?? fail("missing value for --binaryen-validate-bin");
        i += 2;
        break;
      case "--wabt-validate-bin":
        wabtValidateBin = argv[i + 1] ?? fail("missing value for --wabt-validate-bin");
        i += 2;
        break;
      case "--external-validator":
        externalValidators.push(
          normalizeExternalValidator(argv[i + 1] ?? fail("missing value for --external-validator")),
        );
        i += 2;
        break;
      case "--runtime-execution":
        runtimeExecution = normalizeRuntimeExecutionMode(
          argv[i + 1] ?? fail("missing value for --runtime-execution"),
        );
        i += 2;
        break;
      case "--property":
        propertyMode = normalizePropertyMode(argv[i + 1] ?? fail("missing value for --property"));
        i += 2;
        break;
      case "--generator": {
        const value = argv[i + 1] ?? fail("missing value for --generator");
        if (value !== "both" && value !== "wasm-smith" && value !== "gen-valid") {
          fail(`invalid generator: ${value}`);
        }
        generator = value;
        i += 2;
        break;
      }
      case "--gen-valid-profile":
        genValidProfile = argv[i + 1] ?? fail("missing value for --gen-valid-profile");
        i += 2;
        break;
      case "--require-feature":
        genValidRequiredFeatures.push(argv[i + 1] ?? fail("missing value for --require-feature"));
        i += 2;
        break;
      case "--exclude-feature":
        genValidExcludedFeatures.push(argv[i + 1] ?? fail("missing value for --exclude-feature"));
        i += 2;
        break;
      case "--gen-valid-metamorphic-transform":
        genValidMetamorphicTransforms.push(
          argv[i + 1] ?? fail("missing value for --gen-valid-metamorphic-transform"),
        );
        i += 2;
        break;
      case "--max-failures":
        maxFailures = parseNonNegativeInt(
          "max-failures",
          argv[i + 1] ?? fail("missing value for --max-failures"),
        );
        i += 2;
        break;
      case "--keep-going-after-command-failures":
        keepGoingAfterCommandFailures = true;
        i += 1;
        break;
      case "--normalize":
        normalizers.push(normalizeCompareNormalizer(argv[i + 1] ?? fail("missing value for --normalize")));
        i += 2;
        break;
      case "--jobs":
        jobs = parseJobs(argv[i + 1] ?? fail("missing value for --jobs"));
        i += 2;
        break;
      case "--pass":
        passFlags.push(normalizePassNameToFlag(argv[i + 1] ?? fail("missing value for --pass")));
        i += 2;
        break;
      case "--replay-failures-from":
        replayFailuresFrom = argv[i + 1] ?? fail("missing value for --replay-failures-from");
        i += 2;
        break;
      case "--failure-status":
        failureStatus = normalizeFailureStatus(
          argv[i + 1] ?? fail("missing value for --failure-status"),
        );
        i += 2;
        break;
      case "--failure-class":
        failureClass = normalizeCommandFailureClass(
          argv[i + 1] ?? fail("missing value for --failure-class"),
        );
        i += 2;
        break;
      case "--case-index":
        replayCaseIndex = parseNonNegativeInt(
          "case-index",
          argv[i + 1] ?? fail("missing value for --case-index"),
        );
        i += 2;
        break;
      default:
        if (token.startsWith("--external-validator=")) {
          externalValidators.push(
            normalizeExternalValidator(token.substring("--external-validator=".length)),
          );
          i += 1;
          break;
        }
        if (token.startsWith("--runtime-execution=")) {
          runtimeExecution = normalizeRuntimeExecutionMode(
            token.substring("--runtime-execution=".length),
          );
          i += 1;
          break;
        }
        if (token.startsWith("--property=")) {
          propertyMode = normalizePropertyMode(token.substring("--property=".length));
          i += 1;
          break;
        }
        if (token.startsWith("--binaryen-validate-bin=")) {
          binaryenValidateBin = token.substring("--binaryen-validate-bin=".length);
          i += 1;
          break;
        }
        if (token.startsWith("--wabt-validate-bin=")) {
          wabtValidateBin = token.substring("--wabt-validate-bin=".length);
          i += 1;
          break;
        }
        if (token.startsWith("--gen-valid-profile=")) {
          genValidProfile = token.substring("--gen-valid-profile=".length);
          i += 1;
          break;
        }
        if (token.startsWith("--require-feature=")) {
          genValidRequiredFeatures.push(token.substring("--require-feature=".length));
          i += 1;
          break;
        }
        if (token.startsWith("--exclude-feature=")) {
          genValidExcludedFeatures.push(token.substring("--exclude-feature=".length));
          i += 1;
          break;
        }
        if (token.startsWith("--gen-valid-metamorphic-transform=")) {
          genValidMetamorphicTransforms.push(
            token.substring("--gen-valid-metamorphic-transform=".length),
          );
          i += 1;
          break;
        }
        if (RESERVED_OPTIONS.has(token)) {
          fail(`missing value for ${token}`);
        }
        if (!token.startsWith("--")) {
          fail(`unexpected positional argument: ${token}`);
        }
        passFlags.push(normalizePassNameToFlag(token));
        i += 1;
        break;
    }
  }

  if (command === "help") {
    return { kind: "help" };
  }
  if (command === "list-passes") {
    return { kind: "list-passes" };
  }
  if (command === "list-failure-classes") {
    return { kind: "list-failure-classes" };
  }
  if (passFlags.length === 0) {
    fail("expected at least one pass flag to compare");
  }
  if (failureStatus !== null && replayFailuresFrom === null) {
    fail("--failure-status requires --replay-failures-from");
  }
  if (failureClass !== null && replayFailuresFrom === null) {
    fail("--failure-class requires --replay-failures-from");
  }
  if (failureClass !== null && failureStatus !== null && failureStatus !== "command-failure") {
    fail("--failure-class can only be combined with --failure-status command-failure");
  }
  if (replayCaseIndex !== null && replayFailuresFrom === null) {
    fail("--case-index requires --replay-failures-from");
  }

  return {
    kind: "run",
    options: {
      count,
      minCompared,
      seed,
      outDir,
      moonBin,
      starshineBin,
      wasmOptBin,
      wasmToolsBin,
      binaryenValidateBin,
      wabtValidateBin,
      externalValidators,
      runtimeExecution,
      propertyMode,
      generator,
      genValidProfile,
      genValidRequiredFeatures,
      genValidExcludedFeatures,
      genValidMetamorphicTransforms,
      maxFailures,
      keepGoingAfterCommandFailures,
      jobs,
      passFlags,
      replayFailuresFrom,
      failureStatus,
      failureClass,
      replayCaseIndex,
      normalizers,
    },
  };
}

export async function runPassFuzzCompare(argv: string[]): Promise<void> {
  const repoRoot = resolveWorkspaceRoot();
  const repoTmpEnv = makeRepoTmpEnv(repoRoot);
  const repoTmpDir = repoTmpEnv.TMPDIR || path.join(repoRoot, ".tmp", "codex-tmp");
  const parsed = parsePassFuzzCompareArgs(argv);
  if (parsed.kind === "help") {
    process.stdout.write(`${HELP_TEXT}\n`);
    return;
  }
  if (parsed.kind === "list-passes") {
    process.stdout.write(`${supportedPassNames().join("\n")}\n`);
    return;
  }
  if (parsed.kind === "list-failure-classes") {
    process.stdout.write(`${supportedCommandFailureClasses().join("\n")}\n`);
    return;
  }
  const options = parsed.options;
  const outDir = resolveRepoPath(repoRoot, options.outDir);
  const inputsDir = path.join(outDir, "inputs");
  const genValidDir = path.join(inputsDir, "gen-valid");
  const smithDir = path.join(inputsDir, "wasm-smith");
  const resultPath = path.join(outDir, "result.json");
  const summaryPath = path.join(outDir, "summary.json");
  const casesPath = path.join(outDir, "cases.jsonl");
  const binaryenPassFlags = options.passFlags.map(normalizeBinaryenPassFlag);
  const replayCases =
    options.replayFailuresFrom === null
      ? null
      : loadReplayCases(
          repoRoot,
          options.replayFailuresFrom,
          options.failureStatus,
          options.failureClass,
          options.replayCaseIndex,
        );
  const requestedCount = replayCases?.length ?? options.count;
  const defaultJobs = options.starshineBin === null ? 1 : availableParallelism();
  const effectiveJobs = Math.min(options.jobs ?? defaultJobs, Math.max(requestedCount, 1));
  if (effectiveJobs > 1 && options.starshineBin === null) {
    fail(
      "--jobs >1 requires --starshine-bin so parallel cases do not run concurrent moon invocations; " +
        "build src/cmd once and pass its native binary path",
    );
  }

  fs.mkdirSync(outDir, { recursive: true });
  fs.mkdirSync(inputsDir, { recursive: true });
  fs.mkdirSync(smithDir, { recursive: true });
  fs.writeFileSync(casesPath, "");

  const genValidCount =
    replayCases === null ? requiredGenValidCount(options.generator, options.count) : 0;
  if (genValidCount > 0) {
    const genValidMoonDir = path.relative(repoRoot, genValidDir) || ".";
    const genValidManifestPath = path.join(genValidMoonDir, "manifest.json");
    runOrThrow(
      options.moonBin,
      [
        "run",
        "--target",
        "native",
        "--release",
        "src/fuzz",
        "--",
        "--emit-gen-valid-batch",
        "--count",
        String(genValidCount),
        "--seed",
        seedHex(options.seed),
        ...(options.genValidProfile === null ? [] : ["--gen-valid-profile", options.genValidProfile]),
        ...options.genValidRequiredFeatures.flatMap((feature) => ["--require-feature", feature]),
        ...options.genValidExcludedFeatures.flatMap((feature) => ["--exclude-feature", feature]),
        ...options.genValidMetamorphicTransforms.flatMap((id) => ["--metamorphic-transform", id]),
        "--out-dir",
        genValidMoonDir,
        "--manifest",
        genValidManifestPath,
      ],
      { cwd: repoRoot, env: repoTmpEnv, stdio: "pipe" },
    );
  }
  const genValidInputs = genValidCount > 0 ? listGeneratedGenValidInputs(genValidDir) : [];
  const genValidManifestPath = path.join(genValidDir, "manifest.json");
  const genValidManifestRecords = new Map<string, unknown>();
  if (genValidCount > 0 && fs.existsSync(genValidManifestPath)) {
    try {
      const manifest = JSON.parse(fs.readFileSync(genValidManifestPath, "utf8")) as { records?: unknown[] };
      for (const record of manifest.records ?? []) {
        if (record !== null && typeof record === "object" && "file_name" in record) {
          const fileName = (record as { file_name?: unknown }).file_name;
          if (typeof fileName === "string") {
            genValidManifestRecords.set(fileName, record);
          }
        }
      }
    } catch (error) {
      fail(`failed to read gen-valid manifest ${genValidManifestPath}: ${commandFailureDetail(error)}`);
    }
  }

  const starshineInvocation = resolveStarshineInvocation(repoRoot, options.starshineBin, options.moonBin);
  const summary: PassFuzzCompareSummary = {
    requestedCount,
    minCompared: options.minCompared,
    comparedCount: 0,
    normalizedMatchCount: 0,
    cleanupNormalizedMatchCount: 0,
    mismatchCount: 0,
    validationFailureCount: 0,
    generatorFailureCount: 0,
    commandFailureCount: 0,
    commandFailureClasses: {},
    commandFailuresCountTowardMaxFailures: !options.keepGoingAfterCommandFailures,
    maxFailuresHit: false,
    jobs: effectiveJobs,
    seed: seedHex(options.seed),
    generator: options.generator,
    genValidProfile: options.genValidProfile,
    genValidRequiredFeatures: options.genValidRequiredFeatures,
    genValidExcludedFeatures: options.genValidExcludedFeatures,
    genValidMetamorphicTransforms: options.genValidMetamorphicTransforms,
    genValidManifestPath:
      genValidCount > 0 && fs.existsSync(genValidManifestPath)
        ? path.relative(outDir, genValidManifestPath)
        : null,
    genValidTransformCounts: {},
    externalValidators: options.externalValidators,
    runtimeExecution: options.runtimeExecution,
    propertyMode: options.propertyMode,
    propertyFailureCount: 0,
    idempotenceCheckedCount: 0,
    idempotenceMatchCount: 0,
    compositionCheckedCount: 0,
    compositionMatchCount: 0,
    runtimeExecutionCounts: {
      checked: 0,
      unsupported: 0,
      failed: 0,
    },
    runtimeExecutionMatrix: {
      summary: emptyRuntimeExportInvocationMatrixSummary(),
      outcome: options.runtimeExecution === "off" ? "not-run" : "empty",
      semanticMismatchSamples: [],
    },
    externalValidatorSkipped: {},
    generatorCounts: {
      wasmSmith: 0,
      genValid: 0,
    },
    inputEffectTrapCounts: emptyEffectTrapCounts(),
    passFlags: options.passFlags,
    binaryenPassFlags,
    normalizers: options.normalizers,
    failureDirs: [],
  };

  let failures = 0;
  let nextReplayIndex = 0;
  const caseRecords: CaseRecord[] = [];
  const caseTransformIds = new Map<number, string>();
  const caseGenValidFeatureFacts = new Map<number, unknown>();

  function recordCase(record: CaseRecord): void {
    const transformId = caseTransformIds.get(record.caseIndex);
    const genValidFeatureFacts = caseGenValidFeatureFacts.get(record.caseIndex);
    const enrichedRecord = {
      ...record,
      ...(record.transformId === undefined && transformId !== undefined ? { transformId } : {}),
      ...(record.genValidFeatureFacts === undefined && genValidFeatureFacts !== undefined
        ? { genValidFeatureFacts }
        : {}),
    };
    caseRecords.push(enrichedRecord);
    fs.appendFileSync(casesPath, `${JSON.stringify(enrichedRecord)}\n`);
  }

  function genValidInputIndexForReplayIndex(replayIndex: number): number {
    if (options.generator === "gen-valid") {
      return replayIndex;
    }
    return Math.floor(replayIndex / 2);
  }

  async function runCase(replayIndex: number): Promise<void> {
    const replayCase = replayCases?.[replayIndex] ?? null;
    const generator = replayCase?.generator ?? generatorForIndex(options.generator, replayIndex);
    const caseNumber = replayCase?.caseIndex ?? replayIndex + 1;
    const workDir = fs.mkdtempSync(path.join(repoTmpDir, "starshine-pass-fuzz-case-"));
    const inputPath = path.join(workDir, "input.wasm");
    const starshineRawPath = path.join(workDir, "starshine.raw.wasm");
    const starshinePath = path.join(workDir, "starshine.wasm");
    const binaryenRawPath = path.join(workDir, "binaryen.raw.wasm");
    const binaryenPath = path.join(workDir, "binaryen.wasm");
    const starshineWatPath = path.join(workDir, "starshine.wat");
    const binaryenWatPath = path.join(workDir, "binaryen.wat");
    const idempotenceRawPath = path.join(workDir, "starshine.idempotence.raw.wasm");
    const idempotencePath = path.join(workDir, "starshine.idempotence.wasm");
    const idempotenceWatPath = path.join(workDir, "starshine.idempotence.wat");
    const compositionRawPrefix = path.join(workDir, "starshine.composition.step");
    const compositionPath = path.join(workDir, "starshine.composition.wasm");
    const compositionWatPath = path.join(workDir, "starshine.composition.wat");
    let genValidManifestEntry: unknown | null = null;
    let transformId: string | null = null;
    let inputEffectTrapFacts: EffectTrapFacts | null = null;
    let runtimeInvocationReports: RuntimeExportInvocationReport[] | null = null;

    try {
      if (replayCase !== null) {
        fs.copyFileSync(replayCase.inputPath, inputPath);
      } else if (generator === "gen-valid") {
        const source =
          genValidInputs[genValidInputIndexForReplayIndex(replayIndex)] ??
          fail("not enough generated gen-valid inputs");
        genValidManifestEntry = genValidManifestRecords.get(path.basename(source)) ?? null;
        transformId = genValidManifestTransformId(genValidManifestEntry);
        if (transformId !== null) {
          caseTransformIds.set(caseNumber, transformId);
        }
        const featureFacts = genValidManifestFeatureFacts(genValidManifestEntry);
        if (featureFacts !== null) {
          caseGenValidFeatureFacts.set(caseNumber, featureFacts);
        }
        fs.copyFileSync(source, inputPath);
      } else {
        const smith = await runSmith(
          options.wasmToolsBin,
          inputPath,
          makeSmithSeedBytes(options.seed + BigInt(replayIndex)),
          repoRoot,
        );
        if (!smith.ok) {
          summary.generatorFailureCount += 1;
          failures += 1;
          const detail = `wasm-smith generation failed: ${smith.stderr || "unknown error"}`;
          summary.failureDirs.push(
            persistFailureArtifacts(
              outDir,
              caseNumber,
              generator,
              "generator-failure",
              detail,
              workDir,
              options.wasmToolsBin,
              repoRoot,
              options.passFlags,
            ),
          );
          recordCase({
            caseIndex: caseNumber,
            generator,
            status: "generator-failure",
            detail,
          });
          return;
        }
      }

      inputEffectTrapFacts = scanEffectTrapFactsFromWasmBytes(fs.readFileSync(inputPath));
      noteInputEffectTrapFacts(summary, inputEffectTrapFacts);

      const baselineValidation = await runValidateAsync(options.wasmToolsBin, inputPath, repoRoot);
      if (!baselineValidation.ok) {
        summary.generatorFailureCount += 1;
        failures += 1;
        const detail = `generated input failed validation: ${baselineValidation.stderr || "unknown error"}`;
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            "generator-failure",
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
            options.passFlags,
            genValidManifestEntry,
            inputEffectTrapFacts,
          ),
        );
        recordCase({
          caseIndex: caseNumber,
          generator,
          status: "generator-failure",
          detail,
          inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
        });
        return;
      }

      const starshineArgs = [
        ...starshineInvocation.argsPrefix,
        ...options.passFlags,
        "--out",
        starshineRawPath,
        inputPath,
      ];
      try {
        await runStarshineWithRetry(
          starshineInvocation,
          starshineArgs,
          starshineRawPath,
          repoRoot,
          repoTmpEnv,
        );
      } catch (error) {
        summary.commandFailureCount += 1;
        if (!options.keepGoingAfterCommandFailures) {
          failures += 1;
        }
        const detail = `Starshine command failed: ${commandFailureDetail(error)}`;
        const failureClass = classifyCommandFailure(detail);
        noteCommandFailureClass(summary, failureClass);
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            "command-failure",
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
            options.passFlags,
            genValidManifestEntry,
            inputEffectTrapFacts,
          ),
        );
        recordCase({
          caseIndex: caseNumber,
          generator,
          status: "command-failure",
          detail,
          failureClass,
          inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
        });
        return;
      }

      const starshineValidation = await runValidateAsync(
        options.wasmToolsBin,
        starshineRawPath,
        repoRoot,
      );
      const externalValidation = starshineValidation.ok
        ? await runExternalValidatorsAsync(options, starshineRawPath, repoRoot, summary)
        : { ok: true, stderr: "" };
      if (!starshineValidation.ok || !externalValidation.ok) {
        summary.validationFailureCount += 1;
        failures += 1;
        const detail = !starshineValidation.ok
          ? `Starshine output failed validation: ${starshineValidation.stderr || "unknown error"}`
          : `Starshine output failed external validation: ${externalValidation.stderr || "unknown error"}`;
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            "validation-failure",
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
            options.passFlags,
            genValidManifestEntry,
            inputEffectTrapFacts,
          ),
        );
        recordCase({
          caseIndex: caseNumber,
          generator,
          status: "validation-failure",
          detail,
          inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
        });
        return;
      }

      if (options.propertyMode === "idempotence") {
        summary.idempotenceCheckedCount += 1;
        const idempotenceArgs = [
          ...starshineInvocation.argsPrefix,
          ...options.passFlags,
          "--out",
          idempotenceRawPath,
          starshineRawPath,
        ];
        try {
          await runStarshineWithRetry(
            starshineInvocation,
            idempotenceArgs,
            idempotenceRawPath,
            repoRoot,
            repoTmpEnv,
          );
          const idempotenceValidation = await runValidateAsync(
            options.wasmToolsBin,
            idempotenceRawPath,
            repoRoot,
          );
          if (!idempotenceValidation.ok) {
            throw new Error(`second Starshine output failed validation: ${idempotenceValidation.stderr || "unknown error"}`);
          }
          await canonicalizeWasm(options.wasmOptBin, starshineRawPath, starshinePath, repoRoot);
          await canonicalizeWasm(options.wasmOptBin, idempotenceRawPath, idempotencePath, repoRoot);
          const firstWat = await normalizePrintWat(
            options.wasmOptBin,
            starshinePath,
            starshineWatPath,
            repoRoot,
          );
          const secondWat = await normalizePrintWat(
            options.wasmOptBin,
            idempotencePath,
            idempotenceWatPath,
            repoRoot,
          );
          if (firstWat === secondWat) {
            summary.idempotenceMatchCount += 1;
          } else {
            summary.propertyFailureCount += 1;
            failures += 1;
            const detail = "idempotence property failed: pass(pass(input)) differed from pass(input)";
            summary.failureDirs.push(
              persistFailureArtifacts(
                outDir,
                caseNumber,
                generator,
                "property-failure",
                detail,
                workDir,
                options.wasmToolsBin,
                repoRoot,
                options.passFlags,
                genValidManifestEntry,
                inputEffectTrapFacts,
              ),
            );
            recordCase({
              caseIndex: caseNumber,
              generator,
              status: "property-failure",
              detail,
              inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
            });
            return;
          }
        } catch (error) {
          summary.propertyFailureCount += 1;
          failures += 1;
          const detail = `idempotence property command failed: ${commandFailureDetail(error)}`;
          summary.failureDirs.push(
            persistFailureArtifacts(
              outDir,
              caseNumber,
              generator,
              "property-failure",
              detail,
              workDir,
              options.wasmToolsBin,
              repoRoot,
              options.passFlags,
              genValidManifestEntry,
              inputEffectTrapFacts,
            ),
          );
          recordCase({
            caseIndex: caseNumber,
            generator,
            status: "property-failure",
            detail,
            inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
          });
          return;
        }
      }

      if (options.propertyMode === "composition") {
        if (options.passFlags.length < 2) {
          fail("--property composition requires at least two pass flags");
        }
        summary.compositionCheckedCount += 1;
        let compositionInputPath = inputPath;
        let finalCompositionRawPath = "";
        try {
          for (let passIndex = 0; passIndex < options.passFlags.length; passIndex += 1) {
            finalCompositionRawPath = `${compositionRawPrefix}.${String(passIndex + 1).padStart(2, "0")}.raw.wasm`;
            const compositionArgs = [
              ...starshineInvocation.argsPrefix,
              options.passFlags[passIndex],
              "--out",
              finalCompositionRawPath,
              compositionInputPath,
            ];
            await runStarshineWithRetry(
              starshineInvocation,
              compositionArgs,
              finalCompositionRawPath,
              repoRoot,
              repoTmpEnv,
            );
            const compositionValidation = await runValidateAsync(
              options.wasmToolsBin,
              finalCompositionRawPath,
              repoRoot,
            );
            if (!compositionValidation.ok) {
              throw new Error(`composition step ${passIndex + 1} output failed validation: ${compositionValidation.stderr || "unknown error"}`);
            }
            compositionInputPath = finalCompositionRawPath;
          }
          await canonicalizeWasm(options.wasmOptBin, starshineRawPath, starshinePath, repoRoot);
          await canonicalizeWasm(options.wasmOptBin, finalCompositionRawPath, compositionPath, repoRoot);
          const combinedWat = await normalizePrintWat(
            options.wasmOptBin,
            starshinePath,
            starshineWatPath,
            repoRoot,
          );
          const sequentialWat = await normalizePrintWat(
            options.wasmOptBin,
            compositionPath,
            compositionWatPath,
            repoRoot,
          );
          if (combinedWat === sequentialWat) {
            summary.compositionMatchCount += 1;
          } else {
            summary.propertyFailureCount += 1;
            failures += 1;
            const detail = "composition property failed: combined pass invocation differed from sequential single-pass invocations";
            summary.failureDirs.push(
              persistFailureArtifacts(
                outDir,
                caseNumber,
                generator,
                "property-failure",
                detail,
                workDir,
                options.wasmToolsBin,
                repoRoot,
                options.passFlags,
                genValidManifestEntry,
                inputEffectTrapFacts,
              ),
            );
            recordCase({
              caseIndex: caseNumber,
              generator,
              status: "property-failure",
              detail,
              inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
            });
            return;
          }
        } catch (error) {
          summary.propertyFailureCount += 1;
          failures += 1;
          const detail = `composition property command failed: ${commandFailureDetail(error)}`;
          summary.failureDirs.push(
            persistFailureArtifacts(
              outDir,
              caseNumber,
              generator,
              "property-failure",
              detail,
              workDir,
              options.wasmToolsBin,
              repoRoot,
              options.passFlags,
              genValidManifestEntry,
              inputEffectTrapFacts,
            ),
          );
          recordCase({
            caseIndex: caseNumber,
            generator,
            status: "property-failure",
            detail,
            inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
          });
          return;
        }
      }

      let starshineWat = "";
      let binaryenWat = "";
      try {
        await runOrThrowAsync(
          options.wasmOptBin,
          [inputPath, "--all-features", ...binaryenPassFlags, "-o", binaryenRawPath],
          { cwd: repoRoot, env: repoTmpEnv },
        );
        await canonicalizeWasm(options.wasmOptBin, starshineRawPath, starshinePath, repoRoot);
        await canonicalizeWasm(options.wasmOptBin, binaryenRawPath, binaryenPath, repoRoot);
        starshineWat = await normalizePrintWat(
          options.wasmOptBin,
          starshinePath,
          starshineWatPath,
          repoRoot,
        );
        binaryenWat = await normalizePrintWat(
          options.wasmOptBin,
          binaryenPath,
          binaryenWatPath,
          repoRoot,
        );
      } catch (error) {
        summary.commandFailureCount += 1;
        if (!options.keepGoingAfterCommandFailures) {
          failures += 1;
        }
        const detail = `Binaryen/canonicalization command failed: ${commandFailureDetail(error)}`;
        const failureClass = classifyCommandFailure(detail);
        noteCommandFailureClass(summary, failureClass);
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            "command-failure",
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
            options.passFlags,
            genValidManifestEntry,
            inputEffectTrapFacts,
          ),
        );
        recordCase({
          caseIndex: caseNumber,
          generator,
          status: "command-failure",
          detail,
          failureClass,
          inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
        });
        return;
      }

      if (options.runtimeExecution === "node") {
        const runtimeReports = await runNodeExportInvocationMatrix(starshineRawPath, binaryenRawPath);
        runtimeInvocationReports = runtimeReports;
        noteRuntimeExportInvocationMatrix(summary, runtimeReports);
        if (runtimeReports.length === 0) {
          summary.runtimeExecutionCounts.checked += 1;
        } else if (runtimeReports.some((report) => report.classification === "semantic-mismatch")) {
          summary.runtimeExecutionCounts.failed += 1;
        } else if (runtimeReports.some((report) => report.classification === "unsupported-runtime" || report.classification === "nondeterministic-import")) {
          summary.runtimeExecutionCounts.unsupported += 1;
        } else {
          summary.runtimeExecutionCounts.checked += 1;
        }
      }

      summary.comparedCount += 1;
      if (generator === "gen-valid") {
        summary.generatorCounts.genValid += 1;
        noteGenValidTransformCount(summary, transformId);
      } else {
        summary.generatorCounts.wasmSmith += 1;
      }

      const starshineCompareWat = applyCompareNormalizers(starshineWat, options.normalizers);
      const binaryenCompareWat = applyCompareNormalizers(binaryenWat, options.normalizers);
      if (starshineWat === binaryenWat) {
        summary.normalizedMatchCount += 1;
        recordCase({
          caseIndex: caseNumber,
          generator,
          status: "match",
          detail: "normalized outputs matched",
          inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
        });
      } else if (options.normalizers.length > 0 && starshineCompareWat === binaryenCompareWat) {
        summary.cleanupNormalizedMatchCount += 1;
        recordCase({
          caseIndex: caseNumber,
          generator,
          status: "match",
          detail: `compare-normalized outputs matched with ${options.normalizers.join(",")}`,
          inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
        });
      } else {
        summary.mismatchCount += 1;
        failures += 1;
        const detail = "normalized outputs differed";
        const reductionArtifact = generator === "gen-valid" && replayCase === null
          ? reduceGenValidMismatchInput(
              inputPath,
              options,
              starshineInvocation,
              binaryenPassFlags,
              repoRoot,
              repoTmpDir,
              repoTmpEnv,
            )
          : null;
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            "mismatch",
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
            options.passFlags,
            genValidManifestEntry,
            inputEffectTrapFacts,
            runtimeInvocationReports,
            reductionArtifact,
          ),
        );
        recordCase({
          caseIndex: caseNumber,
          generator,
          status: "mismatch",
          detail,
          inputEffectTrapFacts: inputEffectTrapFacts ?? undefined,
        });
      }
    } finally {
      fs.rmSync(workDir, { recursive: true, force: true });
    }
  }

  async function runWorker(): Promise<void> {
    while (true) {
      if (failures >= options.maxFailures) {
        if (nextReplayIndex < requestedCount) {
          summary.maxFailuresHit = true;
        }
        return;
      }
      const replayIndex = nextReplayIndex;
      if (replayIndex >= requestedCount) {
        return;
      }
      nextReplayIndex += 1;
      await runCase(replayIndex);
    }
  }

  await Promise.all(Array.from({ length: summary.jobs }, () => runWorker()));

  summary.failureDirs.sort();
  caseRecords.sort((left, right) => left.caseIndex - right.caseIndex);
  fs.writeFileSync(
    casesPath,
    caseRecords.map((record) => JSON.stringify(record)).join("\n") +
      (caseRecords.length === 0 ? "" : "\n"),
  );
  fs.writeFileSync(resultPath, JSON.stringify(summary, null, 2) + "\n");
  fs.writeFileSync(summaryPath, formatFuzzSummaryReport(passFuzzSummaryCoverageReport(summary)));
  if (options.minCompared !== null && summary.comparedCount < options.minCompared) {
    fail(
      `pass-fuzz-compare compared ${summary.comparedCount} cases, below required minimum ${options.minCompared}`,
    );
  }
  process.stdout.write(`Wrote pass fuzz compare artifacts to ${outDir}\n`);
  process.stdout.write(`Jobs: ${summary.jobs}\n`);
  process.stdout.write(`Compared cases: ${summary.comparedCount}/${summary.requestedCount}\n`);
  process.stdout.write(`Normalized matches: ${summary.normalizedMatchCount}\n`);
  process.stdout.write(`Compare-normalized matches: ${summary.cleanupNormalizedMatchCount}\n`);
  process.stdout.write(`Validation failures: ${summary.validationFailureCount}\n`);
  process.stdout.write(`Property failures: ${summary.propertyFailureCount}\n`);
  process.stdout.write(`Generator failures: ${summary.generatorFailureCount}\n`);
  process.stdout.write(`Command failures: ${summary.commandFailureCount}\n`);
  process.stdout.write(`Mismatches: ${summary.mismatchCount}\n`);
}

export async function main(argv: string[]): Promise<void> {
  await runPassFuzzCompare(argv);
}
