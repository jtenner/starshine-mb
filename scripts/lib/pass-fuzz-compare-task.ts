import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

import {
  fail,
  makeRepoTmpEnv,
  resolveMoonBin,
  resolveRepoPath,
  resolveWorkspaceRoot,
  runOrThrow,
} from "./task-runtime";

type GeneratorMode = "both" | "wasm-smith" | "gen-valid";
type GeneratorKind = "wasm-smith" | "gen-valid";
type CommandFailureClass =
  | "starshine-command-failed"
  | "binaryen-invalid-type-index"
  | "binaryen-invalid-tag-index"
  | "binaryen-rec-group-zero"
  | "binaryen-invalid-wasm-type-neg64"
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
  generator: GeneratorMode;
  maxFailures: number;
  passFlags: string[];
  replayFailuresFrom: string | null;
  failureClass: CommandFailureClass | null;
  replayCaseIndex: number | null;
};

type ParseCommand =
  | { kind: "run"; options: PassFuzzCompareOptions }
  | { kind: "help" }
  | { kind: "list-passes" };

type StarshineInvocation = {
  command: string;
  argsPrefix: string[];
};

type CaseRecord = {
  caseIndex: number;
  generator: GeneratorKind;
  status: "match" | "mismatch" | "validation-failure" | "generator-failure" | "command-failure";
  detail: string;
  failureClass?: CommandFailureClass;
};

type ReplayCase = {
  caseIndex: number;
  generator: GeneratorKind;
  inputPath: string;
};

type PassFuzzCompareSummary = {
  requestedCount: number;
  minCompared: number | null;
  comparedCount: number;
  normalizedMatchCount: number;
  mismatchCount: number;
  validationFailureCount: number;
  generatorFailureCount: number;
  commandFailureCount: number;
  commandFailureClasses: Partial<Record<CommandFailureClass, number>>;
  maxFailuresHit: boolean;
  seed: string;
  generator: GeneratorMode;
  generatorCounts: {
    wasmSmith: number;
    genValid: number;
  };
  passFlags: string[];
  binaryenPassFlags: string[];
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
  "--generator",
  "--max-failures",
  "--pass",
  "--replay-failures-from",
  "--failure-class",
  "--case-index",
]);

const SUPPORTED_PASS_FLAGS = new Set([
  "--ssa-nomerge",
  "--dead-code-elimination",
  "--remove-unused-names",
  "--remove-unused-brs",
  "--vacuum",
  "--optimize-instructions",
  "--heap-store-optimization",
  "--heap2local",
  "--pick-load-signs",
  "--tuple-optimization",
  "--precompute",
  "--simplify-locals",
  "--memory-packing",
  "--once-reduction",
  "--global-refining",
  "--global-struct-inference",
  "--reorder-locals",
  "--duplicate-function-elimination",
  "--remove-unused-module-elements",
]);

const BINARYEN_FLAG_ALIASES = new Map<string, string>([
  ["--dead-code-elimination", "--dce"],
  ["--global-struct-inference", "--gsi"],
]);

const HELP_TEXT = [
  "usage: bun scripts/pass-fuzz-compare.ts [options] --pass <name>|--<pass-flag>",
  "options:",
  "  --count <n>           Number of modules to compare. Default: 10000",
  "  --seed <value>        Non-negative deterministic seed. Default: 0x5eed",
  "  --min-compared <n>    Require at least this many successful comparisons",
  "  --out-dir <dir>       Output directory for artifacts and failures",
  "  --generator <mode>    both | wasm-smith | gen-valid. Default: both",
  "  --max-failures <n>    Stop after this many mismatches/failures. Default: 20",
  "  --pass <name>         Canonical pass name without leading --. May repeat",
  "  --replay-failures-from <dir>",
  "                       Replay saved command-failure inputs from a prior out dir",
  "  --failure-class <id> Restrict replay to one failure family",
  "  --case-index <n>     Restrict replay to one saved case index",
  "  --list-passes         Print supported pass names and exit",
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

function normalizePassNameToFlag(raw: string): string {
  const trimmed = raw.trim();
  const normalized = trimmed.startsWith("--") ? trimmed : `--${trimmed}`;
  if (!SUPPORTED_PASS_FLAGS.has(normalized)) {
    fail(`unsupported pass flag for pass-fuzz-compare: ${raw}`);
  }
  return normalized;
}

function normalizeCommandFailureClass(raw: string): CommandFailureClass {
  switch (raw.trim()) {
    case "starshine-command-failed":
    case "binaryen-invalid-type-index":
    case "binaryen-invalid-tag-index":
    case "binaryen-rec-group-zero":
    case "binaryen-invalid-wasm-type-neg64":
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
    };
  }

  return {
    command: moonBin,
    argsPrefix: ["run", "--target", "native", "--release", "src/cmd", "--"],
  };
}

function runValidate(wasmToolsBin: string, wasmPath: string, repoRoot: string): { ok: boolean; stderr: string } {
  const result = spawnSync(wasmToolsBin, ["validate", wasmPath], {
    cwd: repoRoot,
    env: makeRepoTmpEnv(repoRoot),
    encoding: "utf8",
  });
  if (result.error) {
    throw result.error;
  }
  return {
    ok: result.status === 0,
    stderr: (result.stderr ?? "").trim(),
  };
}

function commandFailureDetail(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

function classifyCommandFailure(detail: string): CommandFailureClass {
  if (detail.startsWith("Starshine command failed:")) {
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
  return "binaryen-command-failed";
}

function noteCommandFailureClass(
  summary: PassFuzzCompareSummary,
  failureClass: CommandFailureClass,
): void {
  summary.commandFailureClasses[failureClass] =
    (summary.commandFailureClasses[failureClass] ?? 0) + 1;
}

function normalizePrintWat(wasmOptBin: string, wasmPath: string, watPath: string, repoRoot: string): string {
  runOrThrow(
    wasmOptBin,
    [wasmPath, "--all-features", "--strip-debug", "-S", "-o", watPath],
    { cwd: repoRoot, env: makeRepoTmpEnv(repoRoot), stdio: "pipe" },
  );
  return fs.readFileSync(watPath, "utf8");
}

function canonicalizeWasm(wasmOptBin: string, inputPath: string, outputPath: string, repoRoot: string): void {
  runOrThrow(
    wasmOptBin,
    [inputPath, "--all-features", "--strip-debug", "-o", outputPath],
    { cwd: repoRoot, env: makeRepoTmpEnv(repoRoot), stdio: "pipe" },
  );
}

function runSmith(wasmToolsBin: string, outputPath: string, seedBytes: Buffer, repoRoot: string): { ok: boolean; stderr: string } {
  const result = spawnSync(wasmToolsBin, ["smith", "-o", outputPath], {
    cwd: repoRoot,
    env: makeRepoTmpEnv(repoRoot),
    input: seedBytes,
    encoding: "utf8",
  });
  if (result.error) {
    throw result.error;
  }
  return {
    ok: result.status === 0,
    stderr: (result.stderr ?? "").trim(),
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

function persistFailureArtifacts(
  outDir: string,
  caseIndex: number,
  generator: GeneratorKind,
  detail: string,
  workDir: string,
  wasmToolsBin: string,
  repoRoot: string,
): string {
  const failureDir = path.join(
    outDir,
    "failures",
    `case-${String(caseIndex).padStart(6, "0")}-${generator}`,
  );
  fs.mkdirSync(failureDir, { recursive: true });
  fs.writeFileSync(path.join(failureDir, "failure.txt"), `${detail}\n`);
  for (const entry of fs.readdirSync(workDir)) {
    const source = path.join(workDir, entry);
    const target = path.join(failureDir, entry);
    if (fs.statSync(source).isFile()) {
      fs.copyFileSync(source, target);
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
    }
  }
  return failureDir;
}

function writeJsonlLine(pathname: string, record: CaseRecord): void {
  fs.appendFileSync(pathname, `${JSON.stringify(record)}\n`);
}

function loadReplayCases(
  repoRoot: string,
  replayFailuresFrom: string,
  failureClass: CommandFailureClass | null,
  replayCaseIndex: number | null,
): ReplayCase[] {
  const replayDir = resolveRepoPath(repoRoot, replayFailuresFrom);
  const casesPath = path.join(replayDir, "cases.jsonl");
  if (!fs.existsSync(casesPath)) {
    fail(`missing cases.jsonl for replay source: ${replayDir}`);
  }

  const replayCases: ReplayCase[] = [];
  for (const line of fs.readFileSync(casesPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      continue;
    }
    const record = JSON.parse(trimmed) as CaseRecord;
    if (record.status !== "command-failure") {
      continue;
    }
    if (replayCaseIndex !== null && record.caseIndex !== replayCaseIndex) {
      continue;
    }
    const recordFailureClass = record.failureClass ?? classifyCommandFailure(record.detail);
    if (failureClass !== null && recordFailureClass !== failureClass) {
      continue;
    }
    const failureDir = path.join(
      replayDir,
      "failures",
      `case-${String(record.caseIndex).padStart(6, "0")}-${record.generator}`,
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
    const detail = failureClass === null ? "command-failure" : failureClass;
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
  let generator: GeneratorMode = "both";
  let maxFailures = 20;
  const passFlags: string[] = [];
  let replayFailuresFrom: string | null = null;
  let failureClass: CommandFailureClass | null = null;
  let replayCaseIndex: number | null = null;
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
      case "--generator": {
        const value = argv[i + 1] ?? fail("missing value for --generator");
        if (value !== "both" && value !== "wasm-smith" && value !== "gen-valid") {
          fail(`invalid generator: ${value}`);
        }
        generator = value;
        i += 2;
        break;
      }
      case "--max-failures":
        maxFailures = parseNonNegativeInt(
          "max-failures",
          argv[i + 1] ?? fail("missing value for --max-failures"),
        );
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
  if (passFlags.length === 0) {
    fail("expected at least one pass flag to compare");
  }
  if (failureClass !== null && replayFailuresFrom === null) {
    fail("--failure-class requires --replay-failures-from");
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
      generator,
      maxFailures,
      passFlags,
      replayFailuresFrom,
      failureClass,
      replayCaseIndex,
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
  const options = parsed.options;
  const outDir = resolveRepoPath(repoRoot, options.outDir);
  const inputsDir = path.join(outDir, "inputs");
  const genValidDir = path.join(inputsDir, "gen-valid");
  const smithDir = path.join(inputsDir, "wasm-smith");
  const resultPath = path.join(outDir, "result.json");
  const casesPath = path.join(outDir, "cases.jsonl");
  const binaryenPassFlags = options.passFlags.map(normalizeBinaryenPassFlag);
  const replayCases =
    options.replayFailuresFrom === null
      ? null
      : loadReplayCases(
          repoRoot,
          options.replayFailuresFrom,
          options.failureClass,
          options.replayCaseIndex,
        );
  const requestedCount = replayCases?.length ?? options.count;

  fs.mkdirSync(outDir, { recursive: true });
  fs.mkdirSync(inputsDir, { recursive: true });
  fs.mkdirSync(smithDir, { recursive: true });
  fs.writeFileSync(casesPath, "");

  const genValidCount =
    replayCases === null ? requiredGenValidCount(options.generator, options.count) : 0;
  if (genValidCount > 0) {
    fs.mkdirSync(genValidDir, { recursive: true });
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
        "--out-dir",
        genValidDir,
      ],
      { cwd: repoRoot, env: repoTmpEnv, stdio: "pipe" },
    );
  }
  const genValidInputs = genValidCount > 0 ? listGeneratedGenValidInputs(genValidDir) : [];

  const starshineInvocation = resolveStarshineInvocation(repoRoot, options.starshineBin, options.moonBin);
  const summary: PassFuzzCompareSummary = {
    requestedCount,
    minCompared: options.minCompared,
    comparedCount: 0,
    normalizedMatchCount: 0,
    mismatchCount: 0,
    validationFailureCount: 0,
    generatorFailureCount: 0,
    commandFailureCount: 0,
    commandFailureClasses: {},
    maxFailuresHit: false,
    seed: seedHex(options.seed),
    generator: options.generator,
    generatorCounts: {
      wasmSmith: 0,
      genValid: 0,
    },
    passFlags: options.passFlags,
    binaryenPassFlags,
    failureDirs: [],
  };

  let genValidIndex = 0;
  let failures = 0;

  for (let replayIndex = 0; replayIndex < requestedCount; replayIndex += 1) {
    if (failures >= options.maxFailures) {
      summary.maxFailuresHit = true;
      break;
    }

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

    try {
      if (replayCase !== null) {
        fs.copyFileSync(replayCase.inputPath, inputPath);
      } else if (generator === "gen-valid") {
        const source = genValidInputs[genValidIndex] ?? fail("not enough generated gen-valid inputs");
        genValidIndex += 1;
        fs.copyFileSync(source, inputPath);
      } else {
        const smith = runSmith(
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
              detail,
              workDir,
              options.wasmToolsBin,
              repoRoot,
            ),
          );
          writeJsonlLine(casesPath, {
            caseIndex: caseNumber,
            generator,
            status: "generator-failure",
            detail,
          });
          continue;
        }
      }

      const baselineValidation = runValidate(options.wasmToolsBin, inputPath, repoRoot);
      if (!baselineValidation.ok) {
        summary.generatorFailureCount += 1;
        failures += 1;
        const detail = `generated input failed validation: ${baselineValidation.stderr || "unknown error"}`;
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
          ),
        );
        writeJsonlLine(casesPath, {
          caseIndex: caseNumber,
          generator,
          status: "generator-failure",
          detail,
        });
        continue;
      }

      const starshineArgs = [
        ...starshineInvocation.argsPrefix,
        ...options.passFlags,
        "--out",
        starshineRawPath,
        inputPath,
      ];
      try {
        runOrThrow(starshineInvocation.command, starshineArgs, {
          cwd: repoRoot,
          env: repoTmpEnv,
          stdio: "pipe",
        });
      } catch (error) {
        summary.commandFailureCount += 1;
        failures += 1;
        const detail = `Starshine command failed: ${commandFailureDetail(error)}`;
        const failureClass = classifyCommandFailure(detail);
        noteCommandFailureClass(summary, failureClass);
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
          ),
        );
        writeJsonlLine(casesPath, {
          caseIndex: caseNumber,
          generator,
          status: "command-failure",
          detail,
          failureClass,
        });
        continue;
      }

      const starshineValidation = runValidate(options.wasmToolsBin, starshineRawPath, repoRoot);
      if (!starshineValidation.ok) {
        summary.validationFailureCount += 1;
        failures += 1;
        const detail = `Starshine output failed validation: ${starshineValidation.stderr || "unknown error"}`;
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
          ),
        );
        writeJsonlLine(casesPath, {
          caseIndex: caseNumber,
          generator,
          status: "validation-failure",
          detail,
        });
        continue;
      }

      let starshineWat = "";
      let binaryenWat = "";
      try {
        runOrThrow(
          options.wasmOptBin,
          [inputPath, "--all-features", ...binaryenPassFlags, "-o", binaryenRawPath],
          { cwd: repoRoot, env: repoTmpEnv, stdio: "pipe" },
        );
        canonicalizeWasm(options.wasmOptBin, starshineRawPath, starshinePath, repoRoot);
        canonicalizeWasm(options.wasmOptBin, binaryenRawPath, binaryenPath, repoRoot);
        starshineWat = normalizePrintWat(options.wasmOptBin, starshinePath, starshineWatPath, repoRoot);
        binaryenWat = normalizePrintWat(options.wasmOptBin, binaryenPath, binaryenWatPath, repoRoot);
      } catch (error) {
        summary.commandFailureCount += 1;
        failures += 1;
        const detail = `Binaryen/canonicalization command failed: ${commandFailureDetail(error)}`;
        const failureClass = classifyCommandFailure(detail);
        noteCommandFailureClass(summary, failureClass);
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
          ),
        );
        writeJsonlLine(casesPath, {
          caseIndex: caseNumber,
          generator,
          status: "command-failure",
          detail,
          failureClass,
        });
        continue;
      }

      summary.comparedCount += 1;
      if (generator === "gen-valid") {
        summary.generatorCounts.genValid += 1;
      } else {
        summary.generatorCounts.wasmSmith += 1;
      }

      if (starshineWat === binaryenWat) {
        summary.normalizedMatchCount += 1;
        writeJsonlLine(casesPath, {
          caseIndex: caseNumber,
          generator,
          status: "match",
          detail: "normalized outputs matched",
        });
      } else {
        summary.mismatchCount += 1;
        failures += 1;
        const detail = "normalized outputs differed";
        summary.failureDirs.push(
          persistFailureArtifacts(
            outDir,
            caseNumber,
            generator,
            detail,
            workDir,
            options.wasmToolsBin,
            repoRoot,
          ),
        );
        writeJsonlLine(casesPath, {
          caseIndex: caseNumber,
          generator,
          status: "mismatch",
          detail,
        });
      }
    } finally {
      fs.rmSync(workDir, { recursive: true, force: true });
    }
  }

  fs.writeFileSync(resultPath, JSON.stringify(summary, null, 2) + "\n");
  if (options.minCompared !== null && summary.comparedCount < options.minCompared) {
    fail(
      `pass-fuzz-compare compared ${summary.comparedCount} cases, below required minimum ${options.minCompared}`,
    );
  }
  process.stdout.write(`Wrote pass fuzz compare artifacts to ${outDir}\n`);
  process.stdout.write(`Compared cases: ${summary.comparedCount}/${summary.requestedCount}\n`);
  process.stdout.write(`Normalized matches: ${summary.normalizedMatchCount}\n`);
  process.stdout.write(`Validation failures: ${summary.validationFailureCount}\n`);
  process.stdout.write(`Generator failures: ${summary.generatorFailureCount}\n`);
  process.stdout.write(`Command failures: ${summary.commandFailureCount}\n`);
  process.stdout.write(`Mismatches: ${summary.mismatchCount}\n`);
}

export async function main(argv: string[]): Promise<void> {
  await runPassFuzzCompare(argv);
}
