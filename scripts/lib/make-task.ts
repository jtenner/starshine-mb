import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import { main as benchmarkOptimizeMain } from "./benchmark-optimize.mjs";
import { buildNodePackage } from "./build-node-package.mjs";
import { generateNodePackage } from "./generate-node-package.mjs";
import { fail, resolveMoonBin, resolveRepoPath, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

function formatSeconds(startNs: bigint, endNs: bigint): string {
  return `${(Number(endNs - startNs) / 1_000_000_000).toFixed(3)}s`;
}

function measureCommand(repoRoot: string, command: string, args: string[]): string {
  const start = process.hrtime.bigint();
  runOrThrow(command, args, { cwd: repoRoot, stdio: "pipe" });
  const end = process.hrtime.bigint();
  return formatSeconds(start, end);
}

export function updateReadmeBenchmarks(argv: string[]): void {
  const repoRoot = resolveWorkspaceRoot();
  let readmePath = path.join(repoRoot, "README.mbt.md");
  let moonBin = resolveMoonBin();
  let dryRun = false;

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--readme":
        readmePath = resolveRepoPath(repoRoot, argv[i + 1] ?? fail("missing value for --readme"));
        i += 2;
        break;
      case "--moon":
        moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      case "--dry-run":
        dryRun = true;
        i += 1;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }

  if (!fs.existsSync(readmePath)) {
    fail(`README not found: ${readmePath}`);
  }

  const readmeText = fs.readFileSync(readmePath, "utf8");
  const startMarker = "<!-- README_BENCHMARK_TABLE_START -->";
  const endMarker = "<!-- README_BENCHMARK_TABLE_END -->";
  const startIndex = readmeText.indexOf(startMarker);
  const endIndex = readmeText.indexOf(endMarker);
  if (startIndex < 0 || endIndex < 0 || startIndex >= endIndex) {
    fail("benchmark markers missing or invalid in README");
  }

  const rows = [
    {
      name: "Single CLI pipeline test (`run_cmd_with_adapter runs requested passes for each module`)",
      command: [moonBin, ["test", "--quiet", "--package", "jtenner/starshine/cmd", "--file", "cmd_test.mbt", "--index", "5"]] as const,
      displayCommand: "moon test --quiet --package jtenner/starshine/cmd --file cmd_test.mbt --index 5",
    },
    {
      name: "Fuzz runner smoke (`src/fuzz` cmd-harness suite)",
      command: [moonBin, ["run", "src/fuzz", "--", "cmd-harness", "smoke", "--seed", "0x5eed"]] as const,
      displayCommand: "moon run src/fuzz -- cmd-harness smoke --seed 0x5eed",
    },
    {
      name: "Full test suite",
      command: [moonBin, ["test", "--quiet"]] as const,
      displayCommand: "moon test --quiet",
    },
  ];

  const today = new Date().toISOString().slice(0, 10);
  const blockLines = [
    `Measured on \`${today}\` in this repository with warm local build cache (\`moon test --quiet\` and \`moon run src/fuzz -- cmd-harness smoke --seed 0x5eed\`, debug profile, \`wasm-gc\` target). These are smoke/reference numbers, not strict performance guarantees.`,
    "",
    "| Workload | Command | Wall time |",
    "| --- | --- | --- |",
  ];

  for (const row of rows) {
    const seconds = measureCommand(repoRoot, row.command[0], [...row.command[1]]);
    blockLines.push(`| ${row.name} | \`${row.displayCommand}\` | \`${seconds}\` |`);
  }

  if (dryRun) {
    process.stdout.write(`${blockLines.join("\n")}\n`);
    return;
  }

  const before = readmeText.slice(0, startIndex + startMarker.length);
  const after = readmeText.slice(endIndex);
  const nextText = `${before}\n${blockLines.join("\n")}\n${after}`;
  fs.writeFileSync(readmePath, nextText);
  process.stdout.write(`Updated benchmark table in ${readmePath}\n`);
}

export async function main(argv: string[]): Promise<void> {
  const repoRoot = resolveWorkspaceRoot();
  const [subcommand, ...rest] = argv;
  switch (subcommand) {
    case "generate-node-package":
      generateNodePackage();
      return;
    case "node-package":
      buildNodePackage({ repoRoot, moonBin: resolveMoonBin() });
      return;
    case "benchmark-optimize":
      await benchmarkOptimizeMain(rest);
      return;
    case "update-readme-benchmarks":
      updateReadmeBenchmarks(rest);
      return;
    default:
      fail("usage: bun make <generate-node-package|node-package|benchmark-optimize|update-readme-benchmarks> [...]");
  }
}
