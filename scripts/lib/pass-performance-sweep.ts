import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

import {
  fail,
  makeRepoTmpEnv,
  resolveRepoPath,
  resolveWorkspaceRoot,
} from "./task-runtime";

export type PassPerformanceSweepOptions = {
  inputPath: string;
  passes: string[];
  starshineBin: string;
  wasmOptBin: string;
  wasmToolsBin: string;
  outDir: string;
  warmup: number;
  samples: number;
  baselinePass: string;
  bunBin: string;
  dryRun: boolean;
};

export type PassPerformanceSweepPlanEntry = {
  round: number;
  warmup: boolean;
  pass: string;
  referencePosition?: "leading" | "trailing";
  outDir: string;
  args: string[];
};

export type PassPerformanceSample = {
  pass: string;
  round: number;
  resultPath: string;
  starshineNoTraceElapsedMs: number;
  binaryenElapsedMs: number;
  starshinePassElapsedMs: number;
  binaryenPassElapsedMs: number;
  starshineRawSize: number;
  binaryenRawSize: number;
  starshineSize: number;
  binaryenSize: number;
  wasmEqual: boolean;
  tracedNoTraceOutputEqual: boolean;
  starshineRawSha256: string;
  starshineNoTraceSha256: string;
  binaryenRawSha256: string;
  phaseMs?: Record<string, number>;
};

export type PassPerformanceBaselineSummary = {
  pass: string;
  sampleCount: number;
  starshineCommandMedianMs: number;
  starshineCommandMadMs: number;
  binaryenCommandMedianMs: number;
  binaryenCommandMadMs: number;
  starshinePassMedianMs: number;
  starshinePassMadMs: number;
  binaryenPassMedianMs: number;
  binaryenPassMadMs: number;
};

export type PassPerformancePassSummary = {
  pass: string;
  sampleCount: number;
  starshineCommandMedianMs: number;
  starshineCommandMadMs: number;
  binaryenCommandMedianMs: number;
  binaryenCommandMadMs: number;
  commandRatio: number | null;
  starshineIncrementMedianMs: number;
  starshineIncrementMadMs: number;
  binaryenIncrementMedianMs: number;
  binaryenIncrementMadMs: number;
  incrementRatio: number | null;
  starshinePassMedianMs: number;
  starshinePassMadMs: number;
  binaryenPassMedianMs: number;
  binaryenPassMadMs: number;
  passLocalRatio: number | null;
  starshineRawSize: number;
  binaryenRawSize: number;
  starshineSize: number;
  binaryenSize: number;
  canonicalWasmEqualInAllSamples: boolean;
  stableStarshineRawOutput: boolean;
  stableBinaryenRawOutput: boolean;
  allTracedNoTraceOutputsEqual: boolean;
  phaseMediansMs: Record<string, number>;
  rawSamples: PassPerformanceSample[];
};

export type PassPerformanceSummary = {
  baseline: PassPerformanceBaselineSummary;
  passes: PassPerformancePassSummary[];
};

export type PassPerformanceSweepReport = {
  schema: "starshine.pass-performance-sweep.v1";
  generatedAt: string;
  repoHead: string | null;
  sourceTreeStatus: string;
  compilerSourceSha256: string;
  compilerSourceFileCount: number;
  newestCompilerSourceMtimeMs: number;
  inputPath: string;
  inputSha256: string;
  starshineBin: string;
  starshineBinSha256: string;
  starshineBinMtimeMs: number;
  wasmOptBin: string;
  wasmOptBinSha256: string;
  wasmOptVersion: string;
  warmup: number;
  samples: number;
  baselinePass: string;
  passes: string[];
  plan: PassPerformanceSweepPlanEntry[];
  measuredSamples: PassPerformanceSample[];
  summary: PassPerformanceSummary;
};

type SelfOptimizeComparisonResult = {
  starshineNoTraceElapsedMs?: unknown;
  binaryenElapsedMs?: unknown;
  starshinePassElapsedMs?: unknown;
  binaryenPassElapsedMs?: unknown;
  starshineRawSize?: unknown;
  binaryenRawSize?: unknown;
  starshineSize?: unknown;
  binaryenSize?: unknown;
  wasmEqual?: unknown;
  starshineNoTraceOutputEqual?: unknown;
  [key: string]: unknown;
};

const PHASE_FIELDS = [
  "starshineElapsedMs",
  "starshineRawElapsedMs",
  "starshineOtherTimedElapsedMs",
  "starshineUntimedElapsedMs",
  "starshineCommandInputElapsedMs",
  "starshineCommandKnownElapsedMs",
  "starshineCommandUnattributedElapsedMs",
  "starshineOptimizerPipelineElapsedMs",
  "starshineOptimizerRawElapsedMs",
  "starshineOptimizerLiftElapsedMs",
  "starshineOptimizerLowerElapsedMs",
  "starshineOptimizerHotCodeSectionElapsedMs",
  "starshineOptimizerHotFunctionElapsedMs",
  "starshineOptimizerHotFunctionOverheadMs",
  "starshineOptimizerHotPrePassElapsedMs",
  "starshineOptimizerHotPostPassElapsedMs",
  "starshineOptimizerHotFunctionUnattributedElapsedMs",
  "starshineOptimizerHotOuterLoopOverheadMs",
  "starshineOptimizerHotModuleRebuildElapsedMs",
  "starshineOptimizerModulePassElapsedMs",
  "starshineOptimizerWritebackElapsedMs",
  "starshineOptimizerFinalValidateElapsedMs",
  "starshineOptimizerHotCodeSectionOverheadMs",
  "starshineOptimizerPipelineUnattributedElapsedMs",
  "starshineOptimizerNonPassElapsedMs",
  "starshineOutsideInputElapsedMs",
  "starshineTraceOverheadMs",
] as const;

function parsePositiveInteger(option: string, value: string | undefined): number {
  if (value === undefined) {
    fail(`missing value for ${option}`);
  }
  if (!/^\d+$/.test(value)) {
    fail(`${option} must be a positive integer, got ${value}`);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    fail(`${option} must be a positive integer, got ${value}`);
  }
  return parsed;
}

function parseNonNegativeInteger(option: string, value: string | undefined): number {
  if (value === undefined) {
    fail(`missing value for ${option}`);
  }
  if (!/^\d+$/.test(value)) {
    fail(`${option} must be a non-negative integer, got ${value}`);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) {
    fail(`${option} must be a non-negative integer, got ${value}`);
  }
  return parsed;
}

function normalizePassName(value: string): string {
  const normalized = value.trim().replace(/^--/, "");
  if (!normalized || !/^[a-z0-9][a-z0-9-]*$/.test(normalized)) {
    fail(`invalid pass name: ${value}`);
  }
  return normalized;
}

function splitPasses(value: string): string[] {
  return value
    .split(",")
    .map(normalizePassName)
    .filter(Boolean);
}

function dedupe(values: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const value of values) {
    if (!seen.has(value)) {
      seen.add(value);
      out.push(value);
    }
  }
  return out;
}

export function parsePassPerformanceSweepArgs(
  argv: string[],
): PassPerformanceSweepOptions {
  let inputPath: string | null = null;
  let passes: string[] = [];
  let starshineBin: string | null = null;
  let wasmOptBin: string | null = null;
  let wasmToolsBin = "wasm-tools";
  let outDir = path.join(".tmp", "pass-performance-sweep");
  let warmup = 1;
  let samples = 3;
  let baselinePass = "strip-debug";
  let bunBin = "bun";
  let dryRun = false;

  for (let idx = 0; idx < argv.length; ) {
    const token = argv[idx];
    switch (token) {
      case "--input":
        inputPath = argv[idx + 1] ?? fail("missing value for --input");
        idx += 2;
        break;
      case "--passes":
        passes.push(...splitPasses(argv[idx + 1] ?? fail("missing value for --passes")));
        idx += 2;
        break;
      case "--starshine-bin":
        starshineBin = argv[idx + 1] ?? fail("missing value for --starshine-bin");
        idx += 2;
        break;
      case "--wasm-opt-bin":
        wasmOptBin = argv[idx + 1] ?? fail("missing value for --wasm-opt-bin");
        idx += 2;
        break;
      case "--wasm-tools-bin":
        wasmToolsBin = argv[idx + 1] ?? fail("missing value for --wasm-tools-bin");
        idx += 2;
        break;
      case "--out-dir":
        outDir = argv[idx + 1] ?? fail("missing value for --out-dir");
        idx += 2;
        break;
      case "--warmup":
        warmup = parseNonNegativeInteger(token, argv[idx + 1]);
        idx += 2;
        break;
      case "--samples":
        samples = parsePositiveInteger(token, argv[idx + 1]);
        idx += 2;
        break;
      case "--baseline-pass":
        baselinePass = normalizePassName(
          argv[idx + 1] ?? fail("missing value for --baseline-pass"),
        );
        idx += 2;
        break;
      case "--bun":
        bunBin = argv[idx + 1] ?? fail("missing value for --bun");
        idx += 2;
        break;
      case "--dry-run":
        dryRun = true;
        idx += 1;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }

  if (inputPath === null) {
    fail("--input is required");
  }
  if (passes.length === 0) {
    fail("--passes must name at least one direct pass");
  }
  if (starshineBin === null) {
    fail("--starshine-bin is required; build and pin the current native release binary");
  }
  if (wasmOptBin === null) {
    fail("--wasm-opt-bin is required; pin the verified Binaryen oracle");
  }
  if (warmup < 1) {
    fail("--warmup must be at least 1 for a measured campaign");
  }
  if (samples < 3) {
    fail("--samples must be at least 3 for a measured campaign");
  }

  passes = dedupe(passes).filter((pass) => pass !== baselinePass);
  if (passes.length === 0) {
    fail("--passes must include at least one pass other than the baseline pass");
  }

  return {
    inputPath,
    passes,
    starshineBin,
    wasmOptBin,
    wasmToolsBin,
    outDir,
    warmup,
    samples,
    baselinePass,
    bunBin,
    dryRun,
  };
}

function roundLabel(round: number, warmupCount: number): string {
  if (round < warmupCount) {
    return `warmup-${round + 1}`;
  }
  return `sample-${round - warmupCount + 1}`;
}

export function buildPassPerformanceSweepPlan(
  options: PassPerformanceSweepOptions,
): PassPerformanceSweepPlanEntry[] {
  const plan: PassPerformanceSweepPlanEntry[] = [];
  const roundCount = options.warmup + options.samples;
  for (let round = 0; round < roundCount; round += 1) {
    const orderedPasses = round % 2 === 0
      ? options.passes
      : [...options.passes].reverse();
    const entries: Array<{
      pass: string;
      referencePosition?: "leading" | "trailing";
    }> = [
      { pass: options.baselinePass, referencePosition: "leading" },
      ...orderedPasses.map((pass) => ({ pass })),
      { pass: options.baselinePass, referencePosition: "trailing" },
    ];
    for (const entry of entries) {
      const passDir = entry.referencePosition === undefined
        ? entry.pass
        : `${entry.pass}-${entry.referencePosition}`;
      const outDir = path.join(
        options.outDir,
        roundLabel(round, options.warmup),
        passDir,
      );
      plan.push({
        round,
        warmup: round < options.warmup,
        pass: entry.pass,
        referencePosition: entry.referencePosition,
        outDir,
        args: [
          "scripts/self-optimize-compare.ts",
          options.inputPath,
          "--out-dir",
          outDir,
          "--starshine-bin",
          options.starshineBin,
          "--wasm-opt-bin",
          options.wasmOptBin,
          "--wasm-tools-bin",
          options.wasmToolsBin,
          "--timing-only",
          "--wall-attribution",
          `--${entry.pass}`,
        ],
      });
    }
  }
  return plan;
}

export function median(values: number[]): number {
  if (values.length === 0) {
    fail("cannot compute the median of an empty sample");
  }
  const sorted = [...values].sort((lhs, rhs) => lhs - rhs);
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 1) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

export function medianAbsoluteDeviation(values: number[]): number {
  const center = median(values);
  return median(values.map((value) => Math.abs(value - center)));
}

function ratio(numerator: number, denominator: number): number | null {
  return numerator >= 0 && denominator > 0 ? numerator / denominator : null;
}

function allSame(values: string[]): boolean {
  return values.length > 0 && values.every((value) => value === values[0]);
}

function phaseMedians(samples: PassPerformanceSample[]): Record<string, number> {
  const values = new Map<string, number[]>();
  for (const sample of samples) {
    for (const [name, value] of Object.entries(sample.phaseMs ?? {})) {
      const existing = values.get(name) ?? [];
      existing.push(value);
      values.set(name, existing);
    }
  }
  return Object.fromEntries(
    [...values.entries()]
      .sort(([lhs], [rhs]) => lhs.localeCompare(rhs))
      .map(([name, samples]) => [name, median(samples)]),
  );
}

function requireOutputIdentity(sample: PassPerformanceSample): void {
  if (
    !sample.tracedNoTraceOutputEqual ||
    sample.starshineRawSha256 !== sample.starshineNoTraceSha256
  ) {
    fail(
      `traced/no-trace output mismatch for ${sample.pass} round ${sample.round}: ${sample.resultPath}`,
    );
  }
}

function requireStableRawOutputs(
  samples: PassPerformanceSample[],
  label: string,
): void {
  if (!allSame(samples.map((sample) => sample.starshineRawSha256))) {
    fail(`unstable Starshine raw output for ${label}`);
  }
  if (!allSame(samples.map((sample) => sample.binaryenRawSha256))) {
    fail(`unstable Binaryen raw output for ${label}`);
  }
}

export function summarizePassPerformanceSamples(
  samples: PassPerformanceSample[],
  passes: string[],
  baselinePass: string,
): PassPerformanceSummary {
  for (const sample of samples) {
    requireOutputIdentity(sample);
  }
  const baselineSamples = samples.filter((sample) => sample.pass === baselinePass);
  if (baselineSamples.length === 0) {
    fail(`missing measured baseline samples for ${baselinePass}`);
  }
  requireStableRawOutputs(baselineSamples, baselinePass);
  const baselineByRound = new Map<number, PassPerformanceSample[]>();
  for (const sample of baselineSamples) {
    const roundSamples = baselineByRound.get(sample.round) ?? [];
    roundSamples.push(sample);
    baselineByRound.set(sample.round, roundSamples);
  }
  for (const [round, roundSamples] of baselineByRound) {
    if (roundSamples.length !== 2) {
      fail(
        `expected leading and trailing ${baselinePass} references for round ${round}, got ${roundSamples.length}`,
      );
    }
  }
  const baseline: PassPerformanceBaselineSummary = {
    pass: baselinePass,
    sampleCount: baselineSamples.length,
    starshineCommandMedianMs: median(
      baselineSamples.map((sample) => sample.starshineNoTraceElapsedMs),
    ),
    starshineCommandMadMs: medianAbsoluteDeviation(
      baselineSamples.map((sample) => sample.starshineNoTraceElapsedMs),
    ),
    binaryenCommandMedianMs: median(
      baselineSamples.map((sample) => sample.binaryenElapsedMs),
    ),
    binaryenCommandMadMs: medianAbsoluteDeviation(
      baselineSamples.map((sample) => sample.binaryenElapsedMs),
    ),
    starshinePassMedianMs: median(
      baselineSamples.map((sample) => sample.starshinePassElapsedMs),
    ),
    starshinePassMadMs: medianAbsoluteDeviation(
      baselineSamples.map((sample) => sample.starshinePassElapsedMs),
    ),
    binaryenPassMedianMs: median(
      baselineSamples.map((sample) => sample.binaryenPassElapsedMs),
    ),
    binaryenPassMadMs: medianAbsoluteDeviation(
      baselineSamples.map((sample) => sample.binaryenPassElapsedMs),
    ),
  };

  const passSummaries = passes.map((pass): PassPerformancePassSummary => {
    const passSamples = samples.filter((sample) => sample.pass === pass);
    if (passSamples.length === 0) {
      fail(`missing measured samples for ${pass}`);
    }
    requireStableRawOutputs(passSamples, pass);
    if (passSamples.length !== baselineByRound.size) {
      fail(
        `expected one ${pass} sample in each of ${baselineByRound.size} measured rounds, got ${passSamples.length}`,
      );
    }
    const passRounds = new Set(passSamples.map((sample) => sample.round));
    if (passRounds.size !== passSamples.length) {
      fail(`duplicate measured round for ${pass}`);
    }
    const starshineIncrements: number[] = [];
    const binaryenIncrements: number[] = [];
    for (const sample of passSamples) {
      const references = baselineByRound.get(sample.round);
      if (!references) {
        fail(`missing ${baselinePass} baseline for ${pass} round ${sample.round}`);
      }
      const starshineFloor = (
        references[0].starshineNoTraceElapsedMs +
        references[1].starshineNoTraceElapsedMs
      ) / 2;
      const binaryenFloor = (
        references[0].binaryenElapsedMs + references[1].binaryenElapsedMs
      ) / 2;
      starshineIncrements.push(
        sample.starshineNoTraceElapsedMs - starshineFloor,
      );
      binaryenIncrements.push(sample.binaryenElapsedMs - binaryenFloor);
    }
    const starshineCommandMedianMs = median(
      passSamples.map((sample) => sample.starshineNoTraceElapsedMs),
    );
    const binaryenCommandMedianMs = median(
      passSamples.map((sample) => sample.binaryenElapsedMs),
    );
    const starshineIncrementMedianMs = median(starshineIncrements);
    const binaryenIncrementMedianMs = median(binaryenIncrements);
    const starshinePassMedianMs = median(
      passSamples.map((sample) => sample.starshinePassElapsedMs),
    );
    const binaryenPassMedianMs = median(
      passSamples.map((sample) => sample.binaryenPassElapsedMs),
    );

    return {
      pass,
      sampleCount: passSamples.length,
      starshineCommandMedianMs,
      starshineCommandMadMs: medianAbsoluteDeviation(
        passSamples.map((sample) => sample.starshineNoTraceElapsedMs),
      ),
      binaryenCommandMedianMs,
      binaryenCommandMadMs: medianAbsoluteDeviation(
        passSamples.map((sample) => sample.binaryenElapsedMs),
      ),
      commandRatio: ratio(starshineCommandMedianMs, binaryenCommandMedianMs),
      starshineIncrementMedianMs,
      starshineIncrementMadMs: medianAbsoluteDeviation(starshineIncrements),
      binaryenIncrementMedianMs,
      binaryenIncrementMadMs: medianAbsoluteDeviation(binaryenIncrements),
      incrementRatio: ratio(starshineIncrementMedianMs, binaryenIncrementMedianMs),
      starshinePassMedianMs,
      starshinePassMadMs: medianAbsoluteDeviation(
        passSamples.map((sample) => sample.starshinePassElapsedMs),
      ),
      binaryenPassMedianMs,
      binaryenPassMadMs: medianAbsoluteDeviation(
        passSamples.map((sample) => sample.binaryenPassElapsedMs),
      ),
      passLocalRatio: ratio(starshinePassMedianMs, binaryenPassMedianMs),
      starshineRawSize: passSamples[0].starshineRawSize,
      binaryenRawSize: passSamples[0].binaryenRawSize,
      starshineSize: passSamples[0].starshineSize,
      binaryenSize: passSamples[0].binaryenSize,
      canonicalWasmEqualInAllSamples: passSamples.every((sample) => sample.wasmEqual),
      stableStarshineRawOutput: allSame(
        passSamples.map((sample) => sample.starshineRawSha256),
      ),
      stableBinaryenRawOutput: allSame(
        passSamples.map((sample) => sample.binaryenRawSha256),
      ),
      allTracedNoTraceOutputsEqual: passSamples.every(
        (sample) => sample.tracedNoTraceOutputEqual,
      ),
      phaseMediansMs: phaseMedians(passSamples),
      rawSamples: passSamples,
    };
  });

  return { baseline, passes: passSummaries };
}

function sha256File(filePath: string): string {
  const hash = createHash("sha256");
  hash.update(fs.readFileSync(filePath));
  return hash.digest("hex");
}

type CompilerSourceIdentity = {
  sha256: string;
  fileCount: number;
  newestMtimeMs: number;
};

function compilerSourceFiles(repoRoot: string): string[] {
  const files: string[] = [];
  const addTree = (directory: string): void => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        addTree(absolute);
      } else if (entry.isFile()) {
        const relative = path.relative(repoRoot, absolute);
        const isTest = /(?:_test|_tests|_wbtest)\.mbt$/.test(entry.name);
        if (entry.name === "moon.pkg" || (entry.name.endsWith(".mbt") && !isTest)) {
          files.push(relative);
        }
      }
    }
  };
  for (const relative of ["moon.mod", "moon.pkg.json"]) {
    if (fs.existsSync(path.join(repoRoot, relative))) {
      files.push(relative);
    }
  }
  addTree(path.join(repoRoot, "src"));
  return files.sort();
}

function compilerSourceIdentity(repoRoot: string): CompilerSourceIdentity {
  const hash = createHash("sha256");
  let newestMtimeMs = 0;
  const files = compilerSourceFiles(repoRoot);
  for (const relative of files) {
    const absolute = path.join(repoRoot, relative);
    hash.update(relative);
    hash.update("\0");
    hash.update(fs.readFileSync(absolute));
    hash.update("\0");
    newestMtimeMs = Math.max(newestMtimeMs, fs.statSync(absolute).mtimeMs);
  }
  return { sha256: hash.digest("hex"), fileCount: files.length, newestMtimeMs };
}

export function assertFreshPerformanceSweepOutDir(
  outDir: string,
  exists: boolean = fs.existsSync(outDir),
): void {
  if (exists) {
    fail(`performance sweep output directory already exists: ${outDir}`);
  }
}

export function assertStarshineBinaryFreshness(
  binaryMtimeMs: number,
  newestCompilerSourceMtimeMs: number,
): void {
  if (binaryMtimeMs < newestCompilerSourceMtimeMs) {
    fail(
      `Starshine binary is older than compiler source; rebuild the explicit native release binary before measuring`,
    );
  }
}

export function assertStablePerformanceIdentity(
  label: string,
  beforeSha256: string,
  afterSha256: string,
): void {
  if (beforeSha256 !== afterSha256) {
    fail(
      `${label} changed during the performance sweep: ${beforeSha256} -> ${afterSha256}`,
    );
  }
}

export function assertBinaryenPerformanceVersion(version: string): void {
  if (!/\bversion 132\b/.test(version)) {
    fail(`expected Binaryen v132 for performance evidence, got: ${version}`);
  }
}

function requiredNumber(
  result: SelfOptimizeComparisonResult,
  field: string,
  resultPath: string,
): number {
  const value = result[field];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    fail(`missing finite ${field} in ${resultPath}`);
  }
  return value;
}

function readSample(
  repoRoot: string,
  entry: PassPerformanceSweepPlanEntry,
): PassPerformanceSample {
  const absoluteOutDir = resolveRepoPath(repoRoot, entry.outDir);
  const resultPath = path.join(absoluteOutDir, "result.json");
  const result = JSON.parse(
    fs.readFileSync(resultPath, "utf8"),
  ) as SelfOptimizeComparisonResult;
  const phaseMs: Record<string, number> = {};
  for (const field of PHASE_FIELDS) {
    const value = result[field];
    if (typeof value === "number" && Number.isFinite(value)) {
      phaseMs[field] = value;
    }
  }
  const commandPhases = result.starshineCommandPhasesMs;
  if (
    typeof commandPhases === "object" &&
    commandPhases !== null &&
    !Array.isArray(commandPhases)
  ) {
    for (const [name, value] of Object.entries(commandPhases)) {
      if (typeof value === "number" && Number.isFinite(value)) {
        phaseMs[`starshineCommandPhasesMs.${name}`] = value;
      }
    }
  }
  const starshineRawPath = path.join(absoluteOutDir, "starshine.raw.wasm");
  const starshineNoTracePath = path.join(
    absoluteOutDir,
    "starshine.no-trace.wasm",
  );
  const binaryenRawPath = path.join(absoluteOutDir, "binaryen.raw.wasm");
  return {
    pass: entry.pass,
    round: entry.round,
    resultPath: path.relative(repoRoot, resultPath),
    starshineNoTraceElapsedMs: requiredNumber(
      result,
      "starshineNoTraceElapsedMs",
      resultPath,
    ),
    binaryenElapsedMs: requiredNumber(result, "binaryenElapsedMs", resultPath),
    starshinePassElapsedMs: requiredNumber(
      result,
      "starshinePassElapsedMs",
      resultPath,
    ),
    binaryenPassElapsedMs: requiredNumber(
      result,
      "binaryenPassElapsedMs",
      resultPath,
    ),
    starshineRawSize: requiredNumber(result, "starshineRawSize", resultPath),
    binaryenRawSize: requiredNumber(result, "binaryenRawSize", resultPath),
    starshineSize: requiredNumber(result, "starshineSize", resultPath),
    binaryenSize: requiredNumber(result, "binaryenSize", resultPath),
    wasmEqual: result.wasmEqual === true,
    tracedNoTraceOutputEqual: result.starshineNoTraceOutputEqual === true,
    starshineRawSha256: sha256File(starshineRawPath),
    starshineNoTraceSha256: sha256File(starshineNoTracePath),
    binaryenRawSha256: sha256File(binaryenRawPath),
    phaseMs,
  };
}

function commandOutput(command: string, args: string[], cwd: string): string {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    stdio: "pipe",
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`command failed: ${command} ${args.join(" ")}\n${result.stderr ?? ""}`);
  }
  return `${result.stdout ?? ""}${result.stderr ?? ""}`.trim();
}

function gitHead(repoRoot: string): string | null {
  const result = spawnSync("git", ["rev-parse", "HEAD"], {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: "pipe",
  });
  return result.status === 0 ? result.stdout.trim() : null;
}

function gitStatus(repoRoot: string): string {
  const result = spawnSync("git", ["status", "--short"], {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: "pipe",
  });
  return result.status === 0 ? result.stdout.trim() : "unavailable";
}

function fmtMs(value: number): string {
  return value.toFixed(3);
}

function fmtRatio(value: number | null): string {
  return value === null ? "n/a" : `${value.toFixed(3)}x`;
}

function fmtMeasurement(medianMs: number, madMs: number): string {
  return `${fmtMs(medianMs)}±${fmtMs(madMs)}ms`;
}

export function formatPassPerformanceSweepReport(
  report: PassPerformanceSweepReport,
): string {
  const lines = [
    "# Pass performance sweep",
    "",
    `- Generated: ${report.generatedAt}`,
    `- Repository HEAD: \`${report.repoHead ?? "unknown"}\``,
    `- Compiler source identity: \`${report.compilerSourceSha256}\` across ${report.compilerSourceFileCount} files; tree ${report.sourceTreeStatus.length === 0 ? "clean" : "dirty"}`,
    `- Input: \`${report.inputPath}\` (SHA-256 \`${report.inputSha256}\`)`,
    `- Starshine: \`${report.starshineBin}\` (SHA-256 \`${report.starshineBinSha256}\`)`,
    `- Binaryen: \`${report.wasmOptBin}\` (SHA-256 \`${report.wasmOptBinSha256}\`)`,
    `- Binaryen version: \`${report.wasmOptVersion}\``,
    `- Method: ${report.warmup} warmup round(s), ${report.samples} measured alternating serial round(s), bracketed reference \`${report.baselinePass}\``,
    "",
    `Reference medians (median±MAD): Starshine ${fmtMeasurement(report.summary.baseline.starshineCommandMedianMs, report.summary.baseline.starshineCommandMadMs)}; Binaryen ${fmtMeasurement(report.summary.baseline.binaryenCommandMedianMs, report.summary.baseline.binaryenCommandMadMs)}. Reference-adjusted increments use the mean of each round's leading and trailing references.`,
    "",
    "| Pass | Starshine command | Binaryen command | Command ratio | Starshine increment | Binaryen increment | Increment ratio | Starshine pass | Binaryen pass | Pass ratio | Raw bytes S/B | Stable S/B | Canonical equal |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :---: | :---: |",
  ];
  for (const pass of report.summary.passes) {
    lines.push(
      `| \`${pass.pass}\` | ${fmtMeasurement(pass.starshineCommandMedianMs, pass.starshineCommandMadMs)} | ${fmtMeasurement(pass.binaryenCommandMedianMs, pass.binaryenCommandMadMs)} | ${fmtRatio(pass.commandRatio)} | ${fmtMeasurement(pass.starshineIncrementMedianMs, pass.starshineIncrementMadMs)} | ${fmtMeasurement(pass.binaryenIncrementMedianMs, pass.binaryenIncrementMadMs)} | ${fmtRatio(pass.incrementRatio)} | ${fmtMeasurement(pass.starshinePassMedianMs, pass.starshinePassMadMs)} | ${fmtMeasurement(pass.binaryenPassMedianMs, pass.binaryenPassMadMs)} | ${fmtRatio(pass.passLocalRatio)} | ${pass.starshineRawSize}/${pass.binaryenRawSize} | ${pass.stableStarshineRawOutput ? "yes" : "no"}/${pass.stableBinaryenRawOutput ? "yes" : "no"} | ${pass.canonicalWasmEqualInAllSamples ? "yes" : "no"} |`,
    );
  }
  lines.push("", "## Raw samples", "");
  for (const pass of report.summary.passes) {
    lines.push(`### \`${pass.pass}\``, "");
    for (const sample of pass.rawSamples) {
      lines.push(
        `- Round ${sample.round}: Starshine ${fmtMs(sample.starshineNoTraceElapsedMs)}ms command / ${fmtMs(sample.starshinePassElapsedMs)}ms pass; Binaryen ${fmtMs(sample.binaryenElapsedMs)}ms command / ${fmtMs(sample.binaryenPassElapsedMs)}ms pass; \`${sample.resultPath}\`.`,
      );
    }
    const phases = Object.entries(pass.phaseMediansMs);
    if (phases.length > 0) {
      lines.push(
        `- Phase medians: ${phases.map(([name, value]) => `${name}=${fmtMs(value)}ms`).join(", ")}.`,
      );
    }
    lines.push("");
  }
  return `${lines.join("\n")}\n`;
}

export function runPassPerformanceSweep(
  options: PassPerformanceSweepOptions,
): PassPerformanceSweepReport | null {
  const repoRoot = resolveWorkspaceRoot();
  const absoluteInput = resolveRepoPath(repoRoot, options.inputPath);
  const absoluteStarshineBin = resolveRepoPath(repoRoot, options.starshineBin);
  const absoluteWasmOptBin = resolveRepoPath(repoRoot, options.wasmOptBin);
  for (const [label, filePath] of [
    ["input", absoluteInput],
    ["Starshine binary", absoluteStarshineBin],
    ["Binaryen binary", absoluteWasmOptBin],
  ] as const) {
    if (!fs.existsSync(filePath)) {
      fail(`missing ${label}: ${filePath}`);
    }
  }

  const resolvedOptions: PassPerformanceSweepOptions = {
    ...options,
    inputPath: absoluteInput,
    starshineBin: absoluteStarshineBin,
    wasmOptBin: absoluteWasmOptBin,
  };
  const plan = buildPassPerformanceSweepPlan(resolvedOptions);
  if (options.dryRun) {
    for (const entry of plan) {
      process.stdout.write(
        `${entry.warmup ? "warmup" : "measure"} round=${entry.round} pass=${entry.pass}: ${options.bunBin} ${entry.args.join(" ")}\n`,
      );
    }
    return null;
  }

  const inputSha256 = sha256File(absoluteInput);
  const starshineBinSha256 = sha256File(absoluteStarshineBin);
  const starshineBinMtimeMs = fs.statSync(absoluteStarshineBin).mtimeMs;
  const wasmOptBinSha256 = sha256File(absoluteWasmOptBin);
  const repoHead = gitHead(repoRoot);
  const sourceTreeStatus = gitStatus(repoRoot);
  const compilerSources = compilerSourceIdentity(repoRoot);
  assertStarshineBinaryFreshness(
    starshineBinMtimeMs,
    compilerSources.newestMtimeMs,
  );
  const wasmOptVersion = commandOutput(
    absoluteWasmOptBin,
    ["--version"],
    repoRoot,
  );
  assertBinaryenPerformanceVersion(wasmOptVersion);

  const absoluteOutDir = resolveRepoPath(repoRoot, options.outDir);
  assertFreshPerformanceSweepOutDir(absoluteOutDir);
  fs.mkdirSync(path.dirname(absoluteOutDir), { recursive: true });
  fs.mkdirSync(absoluteOutDir);
  fs.writeFileSync(
    path.join(absoluteOutDir, "plan.json"),
    `${JSON.stringify(plan, null, 2)}\n`,
  );

  const measuredSamples: PassPerformanceSample[] = [];
  for (const entry of plan) {
    process.stdout.write(
      `[pass-performance-sweep] ${entry.warmup ? "warmup" : "measure"} round=${entry.round} pass=${entry.pass}\n`,
    );
    const result = spawnSync(options.bunBin, entry.args, {
      cwd: repoRoot,
      env: makeRepoTmpEnv(repoRoot),
      stdio: "inherit",
    });
    if (result.error) {
      throw result.error;
    }
    if (result.status !== 0) {
      fail(
        `comparison failed for ${entry.pass} round ${entry.round} with exit ${result.status ?? "unknown"}`,
      );
    }
    const sample = readSample(repoRoot, entry);
    requireOutputIdentity(sample);
    if (!entry.warmup) {
      measuredSamples.push(sample);
    }
  }

  assertStablePerformanceIdentity(
    "input",
    inputSha256,
    sha256File(absoluteInput),
  );
  assertStablePerformanceIdentity(
    "Starshine binary",
    starshineBinSha256,
    sha256File(absoluteStarshineBin),
  );
  assertStablePerformanceIdentity(
    "Binaryen binary",
    wasmOptBinSha256,
    sha256File(absoluteWasmOptBin),
  );
  const finalCompilerSources = compilerSourceIdentity(repoRoot);
  assertStablePerformanceIdentity(
    "compiler source tree",
    compilerSources.sha256,
    finalCompilerSources.sha256,
  );

  const report: PassPerformanceSweepReport = {
    schema: "starshine.pass-performance-sweep.v1",
    generatedAt: new Date().toISOString(),
    repoHead,
    sourceTreeStatus,
    compilerSourceSha256: compilerSources.sha256,
    compilerSourceFileCount: compilerSources.fileCount,
    newestCompilerSourceMtimeMs: compilerSources.newestMtimeMs,
    inputPath: absoluteInput,
    inputSha256,
    starshineBin: absoluteStarshineBin,
    starshineBinSha256,
    starshineBinMtimeMs,
    wasmOptBin: absoluteWasmOptBin,
    wasmOptBinSha256,
    wasmOptVersion,
    warmup: options.warmup,
    samples: options.samples,
    baselinePass: options.baselinePass,
    passes: options.passes,
    plan,
    measuredSamples,
    summary: summarizePassPerformanceSamples(
      measuredSamples,
      options.passes,
      options.baselinePass,
    ),
  };
  fs.writeFileSync(
    path.join(absoluteOutDir, "result.json"),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  const markdown = formatPassPerformanceSweepReport(report);
  fs.writeFileSync(path.join(absoluteOutDir, "summary.md"), markdown);
  process.stdout.write(markdown);
  return report;
}

function printHelp(): void {
  process.stdout.write(`Usage: bun scripts/pass-performance-sweep.ts \\
  --input <artifact.wasm> --passes <a,b,...> \\
  --starshine-bin <current-native-cli> --wasm-opt-bin <verified-v132-wasm-opt> [options]

Runs bracketing references plus each direct pass serially, alternates pass order by round,
requires traced/no-trace byte identity, and writes raw samples plus median timing,
MAD, phase, size, hash, and reference-adjusted summaries.

Options:
  --out-dir <dir>          Artifact directory (default: .tmp/pass-performance-sweep)
  --warmup <N>             Warmup rounds (default/minimum: 1)
  --samples <N>            Measured rounds (default/minimum: 3)
  --baseline-pass <name>   Bracketing reference pass (default: strip-debug)
  --wasm-tools-bin <path>  wasm-tools executable (default: wasm-tools)
  --bun <path>             Bun executable (default: bun)
  --dry-run                Print the serial plan without executing it
  --help                   Show this help

For uncontended measurements, wrap the complete command in the repository's
shared performance lock when other agents or builds may be active.
`);
}

export function main(argv: string[]): void {
  if (argv.includes("--help")) {
    printHelp();
    return;
  }
  runPassPerformanceSweep(parsePassPerformanceSweepArgs(argv));
}
