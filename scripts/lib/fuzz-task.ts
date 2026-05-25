import process from "node:process";

import { assertTarget, fail, resolveMoonBin, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";
import { runPassFuzzCompare } from "./pass-fuzz-compare-task";
import { runFuzzCoverageDelta } from "./fuzz-coverage-delta-task";

export type FuzzOptions = {
  profile: string;
  suite: string;
  seed: string | null;
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
};

// Parse CLI arguments into validated command settings; defaults are kept conservative
// and missing-value tokens fail immediately.
function defaultFuzzOptions(): FuzzOptions {
  return {
    profile: "smoke",
    suite: "all",
    seed: null,
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
    if (token.startsWith("--profile=")) {
      options.profile = token.substring("--profile=".length);
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
      case "--profile":
        options.profile = argv[i + 1] ?? fail("missing value for --profile");
        i += 2;
        break;
      case "--suite":
        options.suite = argv[i + 1] ?? fail("missing value for --suite");
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
  }
  if (positional.length >= 2) {
    options.profile = positional[1];
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

// Build `moon run src/fuzz` command from parsed options and run in the repo root.
export function runFuzz(options: FuzzOptions, repoRoot = resolveWorkspaceRoot()): void {
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
    runOrThrow(options.moonBin, args, { cwd: repoRoot });
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

  const args = ["run", "--target", options.target, "src/fuzz", "--", options.suite, options.profile];
  if (options.seed !== null) {
    args.push("--seed", options.seed);
  }
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
  runOrThrow(options.moonBin, args, { cwd: repoRoot });
}

// `bun fuzz run` entrypoint with a strict single subcommand and no fallback parser.
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
  if (subcommand !== "run") {
    fail(
      "usage: bun fuzz run [--profile <name>|--profile=<name>] [--suite <name>|--suite=<name>] [--seed <int64>|--seed=<int64>] [--seed-count <n>|--seed-count=<n>] [--shard-index <i>|--shard-index=<i> --shard-count <n>|--shard-count=<n>] [--report-json <path>|--report-json=<path>] [--out-dir <dir>|--out-dir=<dir>] [--output text|jsonl|--jsonl|--output=<text|jsonl>] [--target <target>|--target=<target>] [--moon <path>|--moon=<path>] [--list-suites|--list-profiles|--help]\n   or: bun fuzz run --emit-gen-valid-batch --count <n>|--count=<n> --seed <uint64>|--seed=<uint64> --out-dir <dir>|--out-dir=<dir> [--gen-valid-profile <name>|--gen-valid-profile=<name>] [--require-feature <label[:min]>] [--exclude-feature <label>] [--max-attempts <n>] [--manifest <path>|--manifest=<path>] [--target <target>|--target=<target>] [--moon <path>|--moon=<path>]\n   or: bun fuzz compare-pass [pass-fuzz-compare options]\n   or: bun fuzz coverage-delta [--optional] <before-report.json> <after-report.json>",
    );
  }
  runFuzz(parseFuzzRunArgs(rest));
}

if (import.meta.main) {
  main(process.argv.slice(2));
}
