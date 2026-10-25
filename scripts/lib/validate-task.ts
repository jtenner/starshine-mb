import fs from "node:fs";
import { availableParallelism } from "node:os";
import path from "node:path";
import process from "node:process";

import { parseReadmeApiSyncArgs, verifyReadmeApiSync } from "./readme-api-sync";
import { FuzzOptions, parseFuzzRunArgs, runFuzz } from "./fuzz-task";
import { runSelfOptCheck } from "./self-opt-task";
import { discoverMoonTestFiles } from "./moon-test-selection";
import { assertTarget, fail, resolveMoonBin, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

export type FullOptions = Pick<FuzzOptions, "profile" | "seed" | "target" | "moonBin">;
export type TestOptions = Pick<FullOptions, "target" | "moonBin">;

export type ValidateRunDeps = {
  repoRoot?: string;
  parallelism?: number;
  run?: typeof runOrThrow;
};

export type ValidateFullDeps = ValidateRunDeps & {
  runFuzz?: typeof runFuzz;
};

export type CoverageOptions = {
  top: number;
  baselineFile: string | null;
  updateBaseline: boolean;
  moonBin: string;
};

export type ValidateTraceBenchmarkOptions = {
  repeats: number;
  corpora: string[];
  target: string;
  moonBin: string;
  listCorpora: boolean;
};

export type ValidateSelfOptDeps = {
  runSelfOptCheck?: typeof runSelfOptCheck;
};

const MAX_FULL_TEST_JOBS = 16;

// Keep the full validation lane parallel without spawning more MoonBit workers
// than the host can use or the suite can sustain in memory.
export function moonTestJobsForParallelism(parallelism: number): number {
  return Math.min(MAX_FULL_TEST_JOBS, Math.max(1, Math.floor(parallelism)));
}

export function parseValidateTestArgs(argv: string[]): TestOptions {
  const options: TestOptions = { target: "wasm-gc", moonBin: resolveMoonBin() };
  for (let i = 0; i < argv.length; i += 2) {
    const token = argv[i];
    switch (token) {
      case "--target":
        options.target = argv[i + 1] ?? fail("missing value for --target");
        break;
      case "--moon":
        options.moonBin = argv[i + 1] ?? fail("missing value for --moon");
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }
  assertTarget(options.target);
  return options;
}

// Parse top-level validation defaults and enforce the requested MoonBit target.
export function parseValidateFullArgs(argv: string[]): FullOptions {
  const options: FullOptions = {
    profile: "ci",
    seed: null,
    target: "wasm-gc",
    moonBin: resolveMoonBin(),
  };

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--profile":
        options.profile = argv[i + 1] ?? fail("missing value for --profile");
        i += 2;
        break;
      case "--seed":
        options.seed = argv[i + 1] ?? fail("missing value for --seed");
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
      default:
        fail(`unknown option: ${token}`);
    }
  }

  assertTarget(options.target);
  return options;
}

export function parseValidateCoverageArgs(argv: string[]): CoverageOptions {
  const options: CoverageOptions = {
    top: 10,
    baselineFile: null,
    updateBaseline: false,
    moonBin: resolveMoonBin(),
  };

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--top": {
        const raw = argv[i + 1] ?? fail("missing value for --top");
        const parsed = Number.parseInt(raw, 10);
        if (!Number.isInteger(parsed) || parsed <= 0) {
          fail(`invalid --top value: ${raw}`);
        }
        options.top = parsed;
        i += 2;
        break;
      }
      case "--baseline":
        options.baselineFile = argv[i + 1] ?? fail("missing value for --baseline");
        i += 2;
        break;
      case "--update-baseline":
        options.updateBaseline = true;
        i += 1;
        break;
      case "--moon":
        options.moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }

  return options;
}

// Parse trace benchmark options; validates repeat values and target before runtime
// executes any trace runs.
export function parseValidateTraceBenchmarkArgs(argv: string[]): ValidateTraceBenchmarkOptions {
  const options: ValidateTraceBenchmarkOptions = {
    repeats: 1,
    corpora: [],
    target: "wasm-gc",
    moonBin: resolveMoonBin(),
    listCorpora: false,
  };

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--repeat": {
        const raw = argv[i + 1] ?? fail("missing value for --repeat");
        const parsed = Number.parseInt(raw, 10);
        if (!Number.isInteger(parsed) || parsed <= 0) {
          fail(`invalid --repeat value: ${raw}`);
        }
        options.repeats = parsed;
        i += 2;
        break;
      }
      case "--corpus":
        options.corpora.push(argv[i + 1] ?? fail("missing value for --corpus"));
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
      case "--list-corpora":
        options.listCorpora = true;
        i += 1;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }

  assertTarget(options.target);
  return options;
}

// Parse "moon coverage analyze" text into structured counts and sorted file rows so
// CI can fail only when uncovered-lines regress versus an optional baseline.
export function parseCoverageOutput(report: string): { totalUncovered: number; fileCount: number; entries: Array<{ count: number; file: string }> } {
  let totalUncovered: number | null = null;
  let fileCount: number | null = null;
  const entries: Array<{ count: number; file: string }> = [];

  for (const line of report.split(/\r?\n/)) {
    let match = line.match(/^(\d+) uncovered line\(s\) in (.*):$/);
    if (match) {
      entries.push({
        count: Number.parseInt(match[1], 10),
        file: match[2],
      });
      continue;
    }

    match = line.match(/^Total: (\d+) uncovered line\(s\) in (\d+) file\(s\)$/);
    if (match) {
      totalUncovered = Number.parseInt(match[1], 10);
      fileCount = Number.parseInt(match[2], 10);
    }
  }

  if (totalUncovered === null || fileCount === null) {
    fail("unable to parse coverage summary from moon output");
  }

  entries.sort((left, right) => right.count - left.count || left.file.localeCompare(right.file));
  return { totalUncovered, fileCount, entries };
}

// Bound each selection so Moon's per-test-kind JSON stays below the OS argument
// limit. Keep batches sequential because Moon shares a workspace build lock.
// Explicit source paths preserve Moon's default skip and test-kind semantics.
export function runValidateTest(options: TestOptions, deps: ValidateRunDeps = {}): void {
  const repoRoot = deps.repoRoot ?? resolveWorkspaceRoot();
  const testJobs = moonTestJobsForParallelism(deps.parallelism ?? availableParallelism());
  const files = discoverMoonTestFiles(repoRoot);
  const batchSize = 300;
  for (let start = 0; start < files.length; start += batchSize) {
    (deps.run ?? runOrThrow)(options.moonBin, [
      "test", "--target", options.target, "--jobs", String(testJobs), ...files.slice(start, start + batchSize),
    ], { cwd: repoRoot });
  }
}

// Run the core quality gate in order: info, format, check, test, then fuzz.
export function runValidateFull(options: FullOptions, deps: ValidateFullDeps = {}): void {
  const repoRoot = deps.repoRoot ?? resolveWorkspaceRoot();
  const run = deps.run ?? runOrThrow;
  run(options.moonBin, ["info"], { cwd: repoRoot });
  run(options.moonBin, ["fmt"], { cwd: repoRoot });
  run(options.moonBin, ["check", "--target", options.target], { cwd: repoRoot });
  runValidateTest(options, { ...deps, repoRoot });
  const fuzzArgs = ["--suite", "all", "--profile", options.profile, "--target", options.target, "--moon", options.moonBin];
  if (options.seed !== null) {
    fuzzArgs.push("--seed", options.seed);
  }
  (deps.runFuzz ?? runFuzz)(parseFuzzRunArgs(fuzzArgs), repoRoot);
}

export function runValidateCoverage(options: CoverageOptions, deps: ValidateRunDeps = {}): void {
  const repoRoot = deps.repoRoot ?? resolveWorkspaceRoot();
  // One analyze call retains Moon's clean/test/report cycle. Repeated analyze
  // calls would remove coverage collected by earlier file selections.
  const args = ["coverage", "analyze", ...discoverMoonTestFiles(repoRoot).map(file => `--test-flag=${file}`)];
  const report = (deps.run ?? runOrThrow)(options.moonBin, args, { cwd: repoRoot, stdio: "pipe" }).stdout;
  const parsed = parseCoverageOutput(report);

  // Emit top-N uncovered files as operator-readable diff context before
  // applying baseline deltas.

  process.stdout.write(`Coverage summary: total uncovered lines=${parsed.totalUncovered}, files=${parsed.fileCount}\n`);
  process.stdout.write(`Top ${options.top} uncovered files:\n`);
  if (parsed.entries.length === 0) {
    process.stdout.write("  (no uncovered files reported)\n");
  } else {
    for (const entry of parsed.entries.slice(0, options.top)) {
      process.stdout.write(`  ${entry.count}\t${entry.file}\n`);
    }
  }

  if (options.baselineFile === null) {
    return;
  }

  const baselinePath = path.isAbsolute(options.baselineFile)
    ? options.baselineFile
    : path.join(repoRoot, options.baselineFile);

  let baselineTotal = 0;
  let baselineFiles = 0;
  if (fs.existsSync(baselinePath)) {
    const baselineText = fs.readFileSync(baselinePath, "utf8");
    for (const line of baselineText.split(/\r?\n/)) {
      const totalMatch = line.match(/^total=(\d+)$/);
      if (totalMatch) {
        baselineTotal = Number.parseInt(totalMatch[1], 10);
      }
      const fileMatch = line.match(/^files=(\d+)$/);
      if (fileMatch) {
        baselineFiles = Number.parseInt(fileMatch[1], 10);
      }
    }
  }

  const deltaTotal = parsed.totalUncovered - baselineTotal;
  const deltaFiles = parsed.fileCount - baselineFiles;
  const totalPrefix = deltaTotal > 0 ? "+" : "";
  const filePrefix = deltaFiles > 0 ? "+" : "";
  process.stdout.write(
    `Coverage delta vs baseline (${baselinePath}): lines ${totalPrefix}${deltaTotal}, files ${filePrefix}${deltaFiles}\n`,
  );

  if (options.updateBaseline) {
    fs.mkdirSync(path.dirname(baselinePath), { recursive: true });
    fs.writeFileSync(baselinePath, `total=${parsed.totalUncovered}\nfiles=${parsed.fileCount}\n`);
    process.stdout.write(`Updated baseline: ${baselinePath}\n`);
  }

  if (process.env.CI === "true" && deltaTotal > 0) {
    fail(`::error::Uncovered line count increased by ${deltaTotal} (baseline ${baselineTotal}, current ${parsed.totalUncovered})`);
  }
}

// Execute the trace benchmark suite with optional list-only mode.
export function runValidateTraceBenchmark(options: ValidateTraceBenchmarkOptions): void {
  const repoRoot = resolveWorkspaceRoot();
  const args = ["run", "--target", options.target, "src/validate_trace", "--"];
  if (options.listCorpora) {
    args.push("--list-corpora");
  } else {
    args.push("--repeat", String(options.repeats));
    for (const corpus of options.corpora) {
      args.push("--corpus", corpus);
    }
  }
  runOrThrow(options.moonBin, args, { cwd: repoRoot });
}

export async function runValidateSelfOptSmoke(argv: string[], deps: ValidateSelfOptDeps = {}): Promise<void> {
  await (deps.runSelfOptCheck ?? runSelfOptCheck)(argv);
}

export async function runValidateSelfOptFull(argv: string[], deps: ValidateSelfOptDeps = {}): Promise<void> {
  await (deps.runSelfOptCheck ?? runSelfOptCheck)(["--full-spec", ...argv]);
}

export async function main(argv: string[]): Promise<void> {
  const [subcommand, ...rest] = argv;
  switch (subcommand) {
    case "test":
      runValidateTest(parseValidateTestArgs(rest));
      return;
    case "full":
      runValidateFull(parseValidateFullArgs(rest));
      return;
    case "coverage":
      runValidateCoverage(parseValidateCoverageArgs(rest));
      return;
    case "readme-api-sync":
      verifyReadmeApiSync(parseReadmeApiSyncArgs(rest));
      return;
    case "trace-benchmark":
      runValidateTraceBenchmark(parseValidateTraceBenchmarkArgs(rest));
      return;
    case "self-opt-smoke":
      await runValidateSelfOptSmoke(rest);
      return;
    case "self-opt-full":
      await runValidateSelfOptFull(rest);
      return;
    default:
      fail("usage: bun validate <test|full|coverage|readme-api-sync|trace-benchmark|self-opt-smoke|self-opt-full> [...]");
  }
}
