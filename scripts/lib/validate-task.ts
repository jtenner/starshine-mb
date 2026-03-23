import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import { parseReadmeApiSyncArgs, verifyReadmeApiSync } from "./readme-api-sync";
import { FuzzOptions, runFuzz } from "./fuzz-task";
import { assertTarget, fail, resolveMoonBin, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

export type FullOptions = Pick<FuzzOptions, "profile" | "seed" | "target" | "moonBin">;

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

export function runValidateFull(options: FullOptions): void {
  const repoRoot = resolveWorkspaceRoot();
  runOrThrow(options.moonBin, ["info"], { cwd: repoRoot });
  runOrThrow(options.moonBin, ["fmt"], { cwd: repoRoot });
  runOrThrow(options.moonBin, ["check", "--target", options.target], { cwd: repoRoot });
  runOrThrow(options.moonBin, ["test", "--target", options.target], { cwd: repoRoot });
  runFuzz(
    {
      profile: options.profile,
      suite: "all",
      seed: options.seed,
      target: options.target,
      moonBin: options.moonBin,
    },
    repoRoot,
  );
}

export function runValidateCoverage(options: CoverageOptions): void {
  const repoRoot = resolveWorkspaceRoot();
  const report = runOrThrow(options.moonBin, ["coverage", "analyze"], { cwd: repoRoot, stdio: "pipe" }).stdout;
  const parsed = parseCoverageOutput(report);

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

export function main(argv: string[]): void {
  const [subcommand, ...rest] = argv;
  switch (subcommand) {
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
    default:
      fail("usage: bun validate <full|coverage|readme-api-sync|trace-benchmark> [...]");
  }
}
