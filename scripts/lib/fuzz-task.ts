import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

import { assertTarget, fail, resolveMoonBin, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";
import { runPassFuzzCompare } from "./pass-fuzz-compare-task";
import { runFuzzCoverageDelta } from "./fuzz-coverage-delta-task";
import { promoteOptimizerFailure } from "./optimizer-corpus";
import { replayOptimizerFailure } from "./optimizer-replay";
import { parseOptimizerSeedRunArgs, runOptimizerSeedCorpus } from "./optimizer-seeds";
import { runOptionalWasmReduce } from "./optimizer-correctness";
import { exploreOptimizerWasmNeighborhood } from "./optimizer-neighborhood";
import { buildThresholdCliffGroup, optimizerThresholdsFromMoonReport, type MoonOptimizerThresholdReport } from "./optimizer-thresholds";
import {
  exhaustiveValidateRewrite,
  proveRewriteWithSolver,
  type IntegerExpression,
  type RewriteContract,
} from "./optimizer-translation-validation";

export type FuzzOptions = {
  profile: string;
  suite: string;
  seed: string | null;
  recipeName: string | null;
  suiteExplicit: boolean;
  profileExplicit: boolean;
  output: "text" | "jsonl";
  seedCount: string | null;
  shardIndex: string | null;
  shardCount: string | null;
  reportJson: string | null;
  outDir: string | null;
  target: string;
  moonBin: string;
  listSuites: boolean;
  listProfiles: boolean;
  help: boolean;
  emitGenValidBatch: boolean;
  batchCount: string | null;
  batchOutDir: string | null;
  genValidProfile: string | null;
  requireFeatures: string[];
  excludeFeatures: string[];
  maxAttempts: string | null;
  manifestPath: string | null;
  metamorphicTransforms: string[];
};

// Parse CLI arguments into validated command settings; defaults are kept conservative
// and missing-value tokens fail immediately.
function defaultFuzzOptions(): FuzzOptions {
  return {
    profile: "smoke",
    suite: "all",
    seed: null,
    recipeName: null,
    suiteExplicit: false,
    profileExplicit: false,
    output: "text",
    seedCount: null,
    shardIndex: null,
    shardCount: null,
    reportJson: null,
    outDir: null,
    target: "wasm-gc",
    moonBin: resolveMoonBin(),
    listSuites: false,
    listProfiles: false,
    help: false,
    emitGenValidBatch: false,
    batchCount: null,
    batchOutDir: null,
    genValidProfile: null,
    requireFeatures: [],
    excludeFeatures: [],
    maxAttempts: null,
    manifestPath: null,
    metamorphicTransforms: [],
  };
}

function parseEmitGenValidBatchArgs(argv: string[]): FuzzOptions {
  const options = defaultFuzzOptions();
  options.emitGenValidBatch = true;

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    if (token.startsWith("--count=")) {
      options.batchCount = token.substring("--count=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--seed=")) {
      options.seed = token.substring("--seed=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--out-dir=")) {
      options.batchOutDir = token.substring("--out-dir=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--target=")) {
      options.target = token.substring("--target=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--moon=")) {
      options.moonBin = token.substring("--moon=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--gen-valid-profile=")) {
      options.genValidProfile = token.substring("--gen-valid-profile=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--require-feature=")) {
      options.requireFeatures.push(token.substring("--require-feature=".length));
      i += 1;
      continue;
    }
    if (token.startsWith("--exclude-feature=")) {
      options.excludeFeatures.push(token.substring("--exclude-feature=".length));
      i += 1;
      continue;
    }
    if (token.startsWith("--max-attempts=")) {
      options.maxAttempts = token.substring("--max-attempts=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--manifest=")) {
      options.manifestPath = token.substring("--manifest=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--metamorphic-transform=")) {
      options.metamorphicTransforms.push(token.substring("--metamorphic-transform=".length));
      i += 1;
      continue;
    }
    switch (token) {
      case "--count":
        options.batchCount = argv[i + 1] ?? fail("missing value for --count");
        i += 2;
        break;
      case "--seed":
        options.seed = argv[i + 1] ?? fail("missing value for --seed");
        i += 2;
        break;
      case "--out-dir":
        options.batchOutDir = argv[i + 1] ?? fail("missing value for --out-dir");
        i += 2;
        break;
      case "--target":
        options.target = argv[i + 1] ?? fail("missing value for --target");
        i += 2;
        break;
      case "--moon":
        options.moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      case "--gen-valid-profile":
        options.genValidProfile = argv[i + 1] ?? fail("missing value for --gen-valid-profile");
        i += 2;
        break;
      case "--require-feature":
        options.requireFeatures.push(argv[i + 1] ?? fail("missing value for --require-feature"));
        i += 2;
        break;
      case "--exclude-feature":
        options.excludeFeatures.push(argv[i + 1] ?? fail("missing value for --exclude-feature"));
        i += 2;
        break;
      case "--max-attempts":
        options.maxAttempts = argv[i + 1] ?? fail("missing value for --max-attempts");
        i += 2;
        break;
      case "--manifest":
        options.manifestPath = argv[i + 1] ?? fail("missing value for --manifest");
        i += 2;
        break;
      case "--metamorphic-transform":
        options.metamorphicTransforms.push(argv[i + 1] ?? fail("missing value for --metamorphic-transform"));
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }

  if (options.batchCount === null) {
    fail("missing required --count for --emit-gen-valid-batch");
  }
  if (options.seed === null) {
    fail("missing required --seed for --emit-gen-valid-batch");
  }
  if (options.batchOutDir === null) {
    fail("missing required --out-dir for --emit-gen-valid-batch");
  }
  assertTarget(options.target);
  return options;
}

export function parseFuzzRunArgs(argv: string[]): FuzzOptions {
  if (argv[0] === "--emit-gen-valid-batch") {
    return parseEmitGenValidBatchArgs(argv.slice(1));
  }

  const options: FuzzOptions = defaultFuzzOptions();

  const positional: string[] = [];
  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    if (token.startsWith("--seed=")) {
      options.seed = token.substring("--seed=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--recipe=")) {
      if (options.recipeName !== null) {
        fail("duplicate --recipe flag");
      }
      options.recipeName = token.substring("--recipe=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--profile=")) {
      options.profile = token.substring("--profile=".length);
      options.profileExplicit = true;
      i += 1;
      continue;
    }
    if (token.startsWith("--output=")) {
      switch (token.substring("--output=".length)) {
        case "text":
          options.output = "text";
          break;
        case "jsonl":
          options.output = "jsonl";
          break;
        default:
          fail("unknown output mode: " + (token.substring("--output=".length) ?? "<missing>"));
      }
      i += 1;
      continue;
    }
    if (token.startsWith("--target=")) {
      options.target = token.substring("--target=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--moon=")) {
      options.moonBin = token.substring("--moon=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--suite=")) {
      options.suite = token.substring("--suite=".length);
      options.suiteExplicit = true;
      i += 1;
      continue;
    }
    if (token.startsWith("--seed-count=")) {
      options.seedCount = token.substring("--seed-count=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--shard-index=")) {
      options.shardIndex = token.substring("--shard-index=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--shard-count=")) {
      options.shardCount = token.substring("--shard-count=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--report-json=")) {
      options.reportJson = token.substring("--report-json=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--out-dir=")) {
      options.outDir = token.substring("--out-dir=".length);
      i += 1;
      continue;
    }
    switch (token) {
      case "--recipe":
        if (options.recipeName !== null) {
          fail("duplicate --recipe flag");
        }
        options.recipeName = argv[i + 1] ?? fail("missing value for --recipe");
        i += 2;
        break;
      case "--profile":
        options.profile = argv[i + 1] ?? fail("missing value for --profile");
        options.profileExplicit = true;
        i += 2;
        break;
      case "--suite":
        options.suite = argv[i + 1] ?? fail("missing value for --suite");
        options.suiteExplicit = true;
        i += 2;
        break;
      case "--seed":
        options.seed = argv[i + 1] ?? fail("missing value for --seed");
        i += 2;
        break;
      case "--output":
        switch (argv[i + 1]) {
          case "text":
            options.output = "text";
            break;
          case "jsonl":
            options.output = "jsonl";
            break;
          default:
            fail("unknown output mode: " + (argv[i + 1] ?? "<missing>"));
        }
        i += 2;
        break;
      case "--jsonl":
        options.output = "jsonl";
        i += 1;
        break;
      case "--seed-count":
        options.seedCount = argv[i + 1] ?? fail("missing value for --seed-count");
        i += 2;
        break;
      case "--shard-index":
        options.shardIndex = argv[i + 1] ?? fail("missing value for --shard-index");
        i += 2;
        break;
      case "--shard-count":
        options.shardCount = argv[i + 1] ?? fail("missing value for --shard-count");
        i += 2;
        break;
      case "--report-json":
        options.reportJson = argv[i + 1] ?? fail("missing value for --report-json");
        i += 2;
        break;
      case "--out-dir":
        options.outDir = argv[i + 1] ?? fail("missing value for --out-dir");
        i += 2;
        break;
      case "--list-suites":
        options.listSuites = true;
        i += 1;
        break;
      case "--list-profiles":
        options.listProfiles = true;
        i += 1;
        break;
      case "--help":
      case "-h":
        options.help = true;
        i += 1;
        break;
      case "--target":
        options.target = argv[i + 1] ?? fail("missing value for --target");
        i += 2;
        break;
      case "--moon":
        options.moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      default:
        if (token.startsWith("--")) {
          fail(`unknown option: ${token}`);
        }
        positional.push(token);
        i += 1;
        break;
    }
  }

  if (positional.length > 3) {
    fail("too many positional arguments; expected [suite] [profile] [seed]");
  }
  if (positional.length >= 1) {
    options.suite = positional[0];
    options.suiteExplicit = true;
  }
  if (positional.length >= 2) {
    options.profile = positional[1];
    options.profileExplicit = true;
  }
  if (positional.length === 3) {
    if (options.seed !== null) {
      fail("seed provided both as positional argument and --seed flag");
    }
    options.seed = positional[2];
  }

  assertTarget(options.target);
  if (options.listSuites && options.listProfiles) {
    fail("--list-suites and --list-profiles cannot be used together");
  }
  if (
    (options.listSuites || options.listProfiles || options.help) &&
    (options.seed !== null || positional.length > 0)
  ) {
    fail(
      "--list-suites, --list-profiles, and --help cannot be combined with suite/profile/seed arguments",
    );
  }
  return options;
}

type FuzzRunRuntime = {
  seedFactory: () => string;
  log: (message : string) => void;
};

function defaultFuzzRunSeed() : string {
  const value = ((BigInt(Date.now()) << 16n) ^ BigInt(process.pid)) &
    0x7fff_ffff_ffff_ffffn;
  return `0x${value.toString(16)}`;
}

// Build `moon run src/fuzz` command from parsed options and run in the repo root.
export function runFuzz(
  options: FuzzOptions,
  repoRoot = resolveWorkspaceRoot(),
  runner: typeof runOrThrow = runOrThrow,
  runtime: FuzzRunRuntime = {
    seedFactory: defaultFuzzRunSeed,
    log: (message) => process.stderr.write(`${message}\n`),
  },
): void {
  if (options.emitGenValidBatch) {
    const args = [
      "run",
      "--target",
      options.target,
      "src/fuzz",
      "--",
      "--emit-gen-valid-batch",
      "--count",
      options.batchCount!,
      "--seed",
      options.seed!,
      "--out-dir",
      options.batchOutDir!,
    ];
    if (options.genValidProfile !== null) {
      args.push("--gen-valid-profile", options.genValidProfile);
    }
    for (const feature of options.requireFeatures) {
      args.push("--require-feature", feature);
    }
    for (const feature of options.excludeFeatures) {
      args.push("--exclude-feature", feature);
    }
    if (options.maxAttempts !== null) {
      args.push("--max-attempts", options.maxAttempts);
    }
    if (options.manifestPath !== null) {
      args.push("--manifest", options.manifestPath);
    }
    for (const transform of options.metamorphicTransforms) {
      args.push("--metamorphic-transform", transform);
    }
    runner(options.moonBin, args, { cwd: repoRoot });
    return;
  }
  if (options.help) {
    runOrThrow(
      options.moonBin,
      ["run", "--target", options.target, "src/fuzz", "--", "--help"],
      { cwd: repoRoot },
    );
    return;
  }
  if (options.listSuites) {
    runOrThrow(
      options.moonBin,
      ["run", "--target", options.target, "src/fuzz", "--", "--list-suites"],
      { cwd: repoRoot },
    );
    return;
  }
  if (options.listProfiles) {
    runOrThrow(
      options.moonBin,
      ["run", "--target", options.target, "src/fuzz", "--", "--list-profiles"],
      { cwd: repoRoot },
    );
    return;
  }

  const resolvedSeed = options.seed ?? runtime.seedFactory();
  runtime.log(`fuzz resolved_seed=${resolvedSeed}`);
  const args = ["run", "--target", options.target, "src/fuzz", "--"];
  if (options.recipeName !== null) {
    args.push("--recipe", options.recipeName);
    if (options.suiteExplicit) {
      args.push("--suite", options.suite);
    }
    if (options.profileExplicit) {
      args.push("--profile", options.profile);
    }
  } else {
    args.push(options.suite, options.profile);
  }
  args.push("--seed", resolvedSeed);
  if (options.output === "jsonl") {
    args.push("--output", "jsonl");
  }
  if (options.seedCount != null) {
    args.push("--seed-count", options.seedCount);
  }
  if (options.shardIndex != null) {
    args.push("--shard-index", options.shardIndex);
  }
  if (options.shardCount != null) {
    args.push("--shard-count", options.shardCount);
  }
  if (options.reportJson != null) {
    args.push("--report-json", options.reportJson);
  }
  if (options.outDir != null) {
    args.push("--out-dir", options.outDir);
  }
  runner(options.moonBin, args, { cwd: repoRoot });
}

type OptimizerThresholdCommandResult = { status: number | null; stdout: string; stderr: string; error?: Error };

export type OptimizerThresholdReportOptions = {
  starshineBin?: string;
  run?: (bin: string, args: string[]) => OptimizerThresholdCommandResult;
};

export function optimizerThresholdReport(seed = "0x5eed", options: OptimizerThresholdReportOptions = {}) {
  const starshineBin = options.starshineBin ?? process.env.STARSHINE_BIN ?? path.join("_build", "native", "release", "build", "cmd", "cmd.exe");
  const run = options.run ?? ((bin: string, args: string[]) => {
    const result = spawnSync(bin, args, { encoding: "utf8" });
    return { status: result.status, stdout: result.stdout ?? "", stderr: result.stderr ?? "", error: result.error };
  });
  const command = run(starshineBin, ["--emit-optimizer-thresholds-json"]);
  if (command.error != null) fail(`failed to run Moon optimizer threshold report: ${command.error.message}`);
  if (command.status !== 0) fail(`Moon optimizer threshold report failed: ${command.stderr || command.stdout || `exit ${command.status}`}`);
  let moonReport: MoonOptimizerThresholdReport;
  try {
    moonReport = JSON.parse(command.stdout) as MoonOptimizerThresholdReport;
  } catch (error) {
    fail(`invalid Moon optimizer threshold JSON: ${error instanceof Error ? error.message : String(error)}`);
  }
  const thresholds = optimizerThresholdsFromMoonReport(moonReport);
  return {
    schema: "starshine.optimizer-threshold-registry.v1" as const,
    source: moonReport.source,
    seed,
    thresholds,
    groups: thresholds.map((descriptor) => buildThresholdCliffGroup(descriptor, seed)),
  };
}

export type OptimizerProofTaskOptions = {
  contractPath: string;
  solverBin: string;
  outDir: string;
};

export function parseOptimizerProofArgs(argv: string[]): OptimizerProofTaskOptions {
  const positional: string[] = [];
  let solverBin = process.env.Z3_BIN || "z3";
  let outDir = path.join(".tmp", "optimizer-rewrite-proofs");
  for (let index = 0; index < argv.length; ) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      positional.push(token);
      index += 1;
      continue;
    }
    switch (token) {
      case "--solver":
        solverBin = argv[index + 1] ?? fail("missing value for --solver");
        index += 2;
        break;
      case "--out-dir":
        outDir = argv[index + 1] ?? fail("missing value for --out-dir");
        index += 2;
        break;
      default:
        fail(`unknown prove-rewrites option: ${token}`);
    }
  }
  if (positional.length !== 1) fail("prove-rewrites requires exactly one contract JSON file");
  return { contractPath: positional[0], solverBin, outDir };
}

function decodeIntegerExpression(value: unknown): IntegerExpression {
  if (value === null || typeof value !== "object" || Array.isArray(value)) fail("malformed integer expression");
  const object = value as Record<string, unknown>;
  const kind = object.kind;
  const width = object.width;
  if (typeof kind !== "string" || typeof width !== "number" || !Number.isInteger(width) || width < 1 || width > 64) {
    fail("malformed integer expression kind or width");
  }
  if (kind === "var") {
    if (typeof object.name !== "string" || object.name.length === 0) fail("malformed integer variable");
    return { kind, name: object.name, width };
  }
  if (kind === "const") {
    if (typeof object.value !== "string" && typeof object.value !== "number") fail("malformed integer constant");
    return { kind, value: BigInt(object.value), width };
  }
  const binaryKinds = new Set(["add", "sub", "mul", "and", "or", "xor", "shl", "shr_u", "div_s", "div_u", "rem_s", "rem_u"]);
  if (!binaryKinds.has(kind)) fail(`unsupported integer expression kind: ${kind}`);
  return {
    kind: kind as Exclude<IntegerExpression["kind"], "var" | "const">,
    width,
    left: decodeIntegerExpression(object.left),
    right: decodeIntegerExpression(object.right),
  };
}

function decodeRewriteContract(value: unknown): RewriteContract {
  if (value === null || typeof value !== "object" || Array.isArray(value)) fail("malformed rewrite contract");
  const object = value as Record<string, unknown>;
  if (typeof object.id !== "string" || object.id.length === 0) fail("rewrite contract missing id");
  if (!Array.isArray(object.variables)) fail(`rewrite contract ${object.id} missing variables`);
  const variables = object.variables.map((entry) => {
    if (entry === null || typeof entry !== "object" || Array.isArray(entry)) fail(`rewrite contract ${object.id} has malformed variable`);
    const variable = entry as Record<string, unknown>;
    if (typeof variable.name !== "string" || typeof variable.width !== "number" || !Number.isInteger(variable.width)) {
      fail(`rewrite contract ${object.id} has malformed variable`);
    }
    return { name: variable.name, width: variable.width };
  });
  if ("precondition" in object) fail(`rewrite contract ${object.id} uses unsupported non-declarative precondition`);
  return {
    id: object.id,
    variables,
    before: decodeIntegerExpression(object.before),
    after: decodeIntegerExpression(object.after),
  };
}

function loadRewriteContracts(contractPath: string): RewriteContract[] {
  const parsed = JSON.parse(fs.readFileSync(path.resolve(contractPath), "utf8")) as unknown;
  const entries = Array.isArray(parsed)
    ? parsed
    : parsed !== null && typeof parsed === "object" && Array.isArray((parsed as { contracts?: unknown }).contracts)
      ? (parsed as { contracts: unknown[] }).contracts
      : [parsed];
  return entries.map(decodeRewriteContract);
}

function solverVersion(solverBin: string): string | null {
  const version = spawnSync(solverBin, ["--version"], { encoding: "utf8" });
  return version.error || version.status !== 0 ? null : (version.stdout || version.stderr).trim();
}

async function runOptimizerProofTask(options: OptimizerProofTaskOptions): Promise<void> {
  const contracts = loadRewriteContracts(options.contractPath);
  const outDir = path.resolve(options.outDir);
  fs.mkdirSync(outDir, { recursive: true });
  const version = solverVersion(options.solverBin);
  const results: unknown[] = [];
  for (const contract of contracts) {
    const exhaustive = exhaustiveValidateRewrite(contract);
    const proof = await proveRewriteWithSolver(contract, {
      solver: async (smt) => {
        if (version === null) return { status: "unavailable" as const, stdout: "", version: null };
        const result = spawnSync(options.solverBin, ["-in"], { input: smt, encoding: "utf8", maxBuffer: 16 * 1024 * 1024 });
        if (result.error) return { status: "unavailable" as const, stdout: result.error.message, version };
        const first = result.stdout.trimStart().split(/\s+/, 1)[0];
        if (first === "sat" || first === "unsat" || first === "unknown") {
          return { status: first, stdout: result.stdout, version };
        }
        return { status: "unavailable" as const, stdout: result.stderr || result.stdout || `exit ${String(result.status)}`, version };
      },
    });
    const result = {
      schema: "starshine.optimizer-rewrite-validation.v1",
      ruleId: contract.id,
      exhaustive,
      proof,
    };
    const safeId = contract.id.replace(/[^A-Za-z0-9._-]+/g, "_");
    fs.writeFileSync(path.join(outDir, `${safeId}.smt2`), proof.smtLib);
    fs.writeFileSync(path.join(outDir, `${safeId}.json`), JSON.stringify(result, (_key, child) => typeof child === "bigint" ? child.toString() : child, 2) + "\n");
    results.push(result);
  }
  process.stdout.write(`${JSON.stringify({ schema: "starshine.optimizer-rewrite-validation-batch.v1", solverVersion: version, results }, (_key, child) => typeof child === "bigint" ? child.toString() : child, 2)}\n`);
}

export type OptimizerReplayTaskOptions = {
  source: string;
  starshineBin: string | undefined;
  moonBin: string;
  wasmToolsBin: string;
  inputOverride?: string;
  predicate?: boolean;
};

export type OptimizerReductionTaskOptions = {
  source: string;
  outputPath: string;
  wasmReduceBin: string;
  starshineBin: string | undefined;
  moonBin: string;
  wasmToolsBin: string;
};

export type OptimizerPromotionTaskOptions = {
  failureDir: string;
  corpusRoot: string;
  starshineBin: string | undefined;
  moonBin: string;
  wasmToolsBin: string;
};

export type OptimizerExploreTaskOptions = {
  source: string;
  outDir: string;
  seed: bigint;
  budget: number;
  starshineBin: string | undefined;
  moonBin: string;
  wasmToolsBin: string;
};

function parseOptimizerToolArgs(
  argv: string[],
  kind: "replay" | "promotion",
): OptimizerReplayTaskOptions | OptimizerPromotionTaskOptions {
  const positional: string[] = [];
  let starshineBin: string | undefined;
  let moonBin = "moon";
  let wasmToolsBin = "wasm-tools";
  let corpusRoot = "tests/optimizer/regressions";
  let inputOverride: string | undefined;
  let predicate = false;
  for (let index = 0; index < argv.length; ) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      positional.push(token);
      index += 1;
      continue;
    }
    switch (token) {
      case "--starshine-bin":
        starshineBin = argv[index + 1] ?? fail("missing value for --starshine-bin");
        index += 2;
        break;
      case "--moon":
        moonBin = argv[index + 1] ?? fail("missing value for --moon");
        index += 2;
        break;
      case "--wasm-tools-bin":
        wasmToolsBin = argv[index + 1] ?? fail("missing value for --wasm-tools-bin");
        index += 2;
        break;
      case "--corpus-root":
        if (kind !== "promotion") fail("--corpus-root is only valid for promote-optimizer");
        corpusRoot = argv[index + 1] ?? fail("missing value for --corpus-root");
        index += 2;
        break;
      case "--input":
        if (kind !== "replay") fail("--input is only valid for replay-optimizer");
        inputOverride = argv[index + 1] ?? fail("missing value for --input");
        index += 2;
        break;
      case "--predicate":
        if (kind !== "replay") fail("--predicate is only valid for replay-optimizer");
        predicate = true;
        index += 1;
        break;
      default:
        fail(`unknown optimizer ${kind} option: ${token}`);
    }
  }
  if (positional.length !== 1) {
    fail(`optimizer ${kind} requires exactly one failure directory or manifest`);
  }
  if (kind === "replay") {
    return {
      source: positional[0],
      starshineBin,
      moonBin,
      wasmToolsBin,
      ...(inputOverride === undefined ? {} : { inputOverride }),
      ...(predicate ? { predicate: true } : {}),
    };
  }
  return { failureDir: positional[0], corpusRoot, starshineBin, moonBin, wasmToolsBin };
}

export function parseOptimizerReplayArgs(argv: string[]): OptimizerReplayTaskOptions {
  return parseOptimizerToolArgs(argv, "replay") as OptimizerReplayTaskOptions;
}

export function parseOptimizerPromotionArgs(argv: string[]): OptimizerPromotionTaskOptions {
  return parseOptimizerToolArgs(argv, "promotion") as OptimizerPromotionTaskOptions;
}

export function parseOptimizerExploreArgs(argv: string[]): OptimizerExploreTaskOptions {
  const positional: string[] = [];
  let outDir: string | null = null;
  let seed = 0x5eedn;
  let budget = 32;
  let starshineBin: string | undefined;
  let moonBin = "moon";
  let wasmToolsBin = process.env.WASM_TOOLS_BIN || "wasm-tools";
  for (let index = 0; index < argv.length; ) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      positional.push(token);
      index += 1;
      continue;
    }
    switch (token) {
      case "--out-dir":
        outDir = argv[index + 1] ?? fail("missing value for --out-dir");
        index += 2;
        break;
      case "--seed": {
        const raw = argv[index + 1] ?? fail("missing value for --seed");
        try {
          seed = BigInt(raw);
        } catch {
          fail(`invalid optimizer neighborhood seed: ${raw}`);
        }
        if (seed < 0n) fail("optimizer neighborhood seed must be non-negative");
        index += 2;
        break;
      }
      case "--budget": {
        const raw = argv[index + 1] ?? fail("missing value for --budget");
        budget = Number(raw);
        if (!Number.isInteger(budget) || budget < 0) fail(`invalid optimizer neighborhood budget: ${raw}`);
        index += 2;
        break;
      }
      case "--starshine-bin":
        starshineBin = argv[index + 1] ?? fail("missing value for --starshine-bin");
        index += 2;
        break;
      case "--moon":
        moonBin = argv[index + 1] ?? fail("missing value for --moon");
        index += 2;
        break;
      case "--wasm-tools-bin":
        wasmToolsBin = argv[index + 1] ?? fail("missing value for --wasm-tools-bin");
        index += 2;
        break;
      default:
        fail(`unknown explore-optimizer-repro option: ${token}`);
    }
  }
  if (positional.length !== 1) fail("explore-optimizer-repro requires exactly one failure directory or manifest");
  if (outDir === null) fail("explore-optimizer-repro requires --out-dir <path>");
  return { source: positional[0], outDir, seed, budget, starshineBin, moonBin, wasmToolsBin };
}

export function parseOptimizerReductionArgs(argv: string[]): OptimizerReductionTaskOptions {
  const positional: string[] = [];
  let outputPath: string | null = null;
  let wasmReduceBin = process.env.WASM_REDUCE_BIN || "wasm-reduce";
  let starshineBin: string | undefined;
  let moonBin = "moon";
  let wasmToolsBin = "wasm-tools";
  for (let index = 0; index < argv.length; ) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      positional.push(token);
      index += 1;
      continue;
    }
    switch (token) {
      case "--out":
        outputPath = argv[index + 1] ?? fail("missing value for --out");
        index += 2;
        break;
      case "--wasm-reduce-bin":
        wasmReduceBin = argv[index + 1] ?? fail("missing value for --wasm-reduce-bin");
        index += 2;
        break;
      case "--starshine-bin":
        starshineBin = argv[index + 1] ?? fail("missing value for --starshine-bin");
        index += 2;
        break;
      case "--moon":
        moonBin = argv[index + 1] ?? fail("missing value for --moon");
        index += 2;
        break;
      case "--wasm-tools-bin":
        wasmToolsBin = argv[index + 1] ?? fail("missing value for --wasm-tools-bin");
        index += 2;
        break;
      default:
        fail(`unknown reduce-optimizer option: ${token}`);
    }
  }
  if (positional.length !== 1) fail("reduce-optimizer requires exactly one failure directory or manifest");
  if (outputPath === null) fail("reduce-optimizer requires --out <path>");
  return { source: positional[0], outputPath, wasmReduceBin, starshineBin, moonBin, wasmToolsBin };
}

function optimizerReductionInputPath(source: string): string {
  const resolved = path.resolve(source);
  const directory = fs.statSync(resolved).isDirectory() ? resolved : path.dirname(resolved);
  const failureMetadata = path.join(directory, "failure-metadata.json");
  if (fs.existsSync(failureMetadata)) {
    const metadata = JSON.parse(fs.readFileSync(failureMetadata, "utf8")) as { replay?: { input?: string } };
    return path.resolve(directory, metadata.replay?.input ?? "input.wasm");
  }
  const manifestPath = fs.statSync(resolved).isFile() ? resolved : path.join(directory, "manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as { input?: { path?: string } };
  return path.resolve(directory, manifest.input?.path ?? "input.wasm");
}

async function runOptimizerReplayTask(options: OptimizerReplayTaskOptions): Promise<void> {
  const result = await replayOptimizerFailure({
    source: options.source,
    inputOverride: options.inputOverride,
    starshineBin: options.starshineBin,
    moonBin: options.moonBin,
    wasmToolsBin: options.wasmToolsBin,
  });
  process.stdout.write(
    options.predicate
      ? `${result.reproduced ? result.failureClass ?? "reproduced" : "not-reproduced"}\n`
      : `${JSON.stringify(result)}\n`,
  );
  if (!result.reproduced) process.exitCode = 1;
}

async function runOptimizerReductionTask(options: OptimizerReductionTaskOptions): Promise<void> {
  const outputPath = path.resolve(options.outputPath);
  const testPath = `${outputPath}.test.wasm`;
  const predicateCommand = [
    process.execPath,
    path.resolve("scripts/fuzz.ts"),
    "replay-optimizer",
    path.resolve(options.source),
    "--input",
    testPath,
    "--predicate",
    "--moon",
    options.moonBin,
    "--wasm-tools-bin",
    options.wasmToolsBin,
    ...(options.starshineBin === undefined ? [] : ["--starshine-bin", path.resolve(options.starshineBin)]),
  ];
  const result = runOptionalWasmReduce({
    wasmReduceBin: options.wasmReduceBin,
    inputPath: optimizerReductionInputPath(options.source),
    outputPath,
    predicateCommand,
  });
  fs.writeFileSync(`${outputPath}.reduction.log`, result.status === "unavailable" ? `${result.detail}\n` : result.log);
  process.stdout.write(`${JSON.stringify(result)}\n`);
  if (result.status === "failed") process.exitCode = 1;
}

async function runOptimizerExploreTask(options: OptimizerExploreTaskOptions): Promise<void> {
  const report = await exploreOptimizerWasmNeighborhood({
    source: options.source,
    inputPath: optimizerReductionInputPath(options.source),
    outDir: options.outDir,
    seed: options.seed,
    budget: options.budget,
    starshineBin: options.starshineBin,
    moonBin: options.moonBin,
    wasmToolsBin: options.wasmToolsBin,
  });
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

async function runOptimizerSeedTask(argv: string[]): Promise<void> {
  const report = await runOptimizerSeedCorpus(parseOptimizerSeedRunArgs(argv));
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  if (report.failed > 0) process.exitCode = 1;
}

async function runOptimizerPromotionTask(options: OptimizerPromotionTaskOptions): Promise<void> {
  const result = await promoteOptimizerFailure({
    failureDir: options.failureDir,
    corpusRoot: options.corpusRoot,
    verifyFailure: (context) => replayOptimizerFailure({
      source: options.failureDir,
      inputOverride: context.inputPath,
      starshineBin: options.starshineBin,
      moonBin: options.moonBin,
      wasmToolsBin: options.wasmToolsBin,
    }),
  });
  process.stdout.write(`${result.casePath}\n`);
}

// `bun fuzz run` entrypoint with strict sibling subcommands and no fallback parser.
export function main(argv: string[]): void {
  const [subcommand, ...rest] = argv;
  if (subcommand === "compare-pass") {
    void runPassFuzzCompare(rest);
    return;
  }
  if (subcommand === "coverage-delta") {
    runFuzzCoverageDelta(rest);
    return;
  }
  if (subcommand === "replay-optimizer") {
    void runOptimizerReplayTask(parseOptimizerReplayArgs(rest));
    return;
  }
  if (subcommand === "promote-optimizer") {
    void runOptimizerPromotionTask(parseOptimizerPromotionArgs(rest));
    return;
  }
  if (subcommand === "optimizer-seeds") {
    void runOptimizerSeedTask(rest);
    return;
  }
  if (subcommand === "reduce-optimizer") {
    void runOptimizerReductionTask(parseOptimizerReductionArgs(rest));
    return;
  }
  if (subcommand === "explore-optimizer-repro") {
    void runOptimizerExploreTask(parseOptimizerExploreArgs(rest));
    return;
  }
  if (subcommand === "list-optimizer-thresholds") {
    if (rest.length > 1 || (rest.length === 1 && !rest[0].startsWith("--seed="))) {
      fail("usage: bun fuzz list-optimizer-thresholds [--seed=<value>]");
    }
    const seed = rest[0]?.substring("--seed=".length) || "0x5eed";
    process.stdout.write(`${JSON.stringify(optimizerThresholdReport(seed), null, 2)}\n`);
    return;
  }
  if (subcommand === "prove-rewrites") {
    void runOptimizerProofTask(parseOptimizerProofArgs(rest));
    return;
  }
  if (subcommand !== "run") {
    fail(
      "usage: bun fuzz run [--recipe <name>|--recipe=<name>] [--profile <name>|--profile=<name>] [--suite <name>|--suite=<name>] [--seed <int64>|--seed=<int64>] [--seed-count <n>|--seed-count=<n>] [--shard-index <i>|--shard-index=<i> --shard-count <n>|--shard-count=<n>] [--report-json <path>|--report-json=<path>] [--out-dir <dir>|--out-dir=<dir>] [--output text|jsonl|--jsonl|--output=<text|jsonl>] [--target <target>|--target=<target>] [--moon <path>|--moon=<path>] [--list-suites|--list-profiles|--help]\n   or: bun fuzz run --emit-gen-valid-batch --count <n>|--count=<n> --seed <uint64>|--seed=<uint64> --out-dir <dir>|--out-dir=<dir> [--gen-valid-profile <name>|--gen-valid-profile=<name>] [--require-feature <label[:min]>] [--exclude-feature <label>] [--max-attempts <n>] [--manifest <path>|--manifest=<path>] [--target <target>|--target=<target>] [--moon <path>|--moon=<path>]\n   or: bun fuzz compare-pass [pass-fuzz-compare options]\n   or: bun fuzz replay-optimizer <failure-dir|manifest.json> [--starshine-bin <path>]\n   or: bun fuzz promote-optimizer <failure-dir> [--corpus-root tests/optimizer/regressions] [--starshine-bin <path>]\n   or: bun fuzz optimizer-seeds [--pass <name> ...] [--self-semantic] [--debug-serial-passes]\n   or: bun fuzz reduce-optimizer <failure-dir|manifest.json> --out <reduced.wasm> [--wasm-reduce-bin <path>]\n   or: bun fuzz list-optimizer-thresholds [--seed=<value>]\n   or: bun fuzz prove-rewrites <contracts.json> [--solver z3] [--out-dir .tmp/optimizer-rewrite-proofs]\n   or: bun fuzz coverage-delta [--optional] <before-report.json> <after-report.json>",
    );
  }
  runFuzz(parseFuzzRunArgs(rest));
}

if (import.meta.main) {
  main(process.argv.slice(2));
}
