import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import { assertTarget, fail, makeRepoTmpEnv, resolveMoonBin, resolveRepoPath, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

type CliBenchmarkCase = {
  name: string;
  tags: string[];
  args: string[];
};

type CliBenchmarkResult = {
  iterations: number;
  warmup: number;
  target_arg_count: number;
  parse_total_us: number;
  parse_avg_us: number;
  setup_total_us: number;
  setup_avg_us: number;
  optimize_level: number;
  shrink_level: number;
  effective_pass_count: number;
  resolved_passes: string;
};

type CliBenchmarkCaseResult = CliBenchmarkResult & {
  case: string;
  tags: string[];
  args: string[];
};

export type CliBenchmarkSuite = "smoke" | "standard" | "full";

export type CliBenchmarkRunnerOptions = {
  iterations: number;
  warmup: number;
  suite: CliBenchmarkSuite;
  target: string;
  moonBin: string;
  limit: number | null;
  grep: string | null;
  dryRun: boolean;
  jsonl: boolean;
  outPath: string | null;
  failFast: boolean;
};

const HOT_AND_MODULE_PASSES = [
  "ssa-nomerge",
  "vacuum",
  "dead-code-elimination",
  "remove-unused-names",
  "remove-unused-brs",
  "optimize-instructions",
  "heap-store-optimization",
  "heap2local",
  "optimize-casts",
  "pick-load-signs",
  "precompute",
  "code-pushing",
  "code-folding",
  "tuple-optimization",
  "simplify-locals",
  "simplify-locals-nostructure",
  "simplify-locals-no-structure",
  "simplify-locals-notee-nostructure",
  "local-cse",
  "merge-locals",
  "merge-blocks",
  "redundant-set-elimination",
  "avoid-reinterprets",
  "untee",
  "duplicate-function-elimination",
  "remove-unused-module-elements",
  "remove-unused-nonfunction-module-elements",
  "memory-packing",
  "once-reduction",
  "global-refining",
  "global-struct-inference",
  "reorder-locals",
  "local-subtyping",
  "coalesce-locals",
  "duplicate-import-elimination",
  "dae-optimizing",
  "dead-argument-elimination-optimizing",
  "inlining",
  "inlining-optimizing",
  "string-gathering",
  "reorder-globals",
  "directize",
] as const;

const NO_INLINE_CASES: CliBenchmarkCase[] = [
  {
    name: "pass-no-inline-index",
    tags: ["pass", "inlining", "value-flag"],
    args: ["--no-inline", "0", "input.wasm"],
  },
  {
    name: "pass-no-full-inline-index",
    tags: ["pass", "inlining", "value-flag"],
    args: ["--no-full-inline", "0", "input.wasm"],
  },
  {
    name: "pass-no-partial-inline-index",
    tags: ["pass", "inlining", "value-flag"],
    args: ["--no-partial-inline", "0", "input.wasm"],
  },
];

const CORE_CASES: CliBenchmarkCase[] = [
  {
    name: "single-input-default",
    tags: ["baseline", "input"],
    args: ["input.wasm"],
  },
  {
    name: "optimize-default",
    tags: ["preset", "optimize"],
    args: ["--optimize", "input.wasm"],
  },
  {
    name: "shrink-default",
    tags: ["preset", "shrink"],
    args: ["--shrink", "input.wasm"],
  },
  {
    name: "olevel-o0",
    tags: ["olevel"],
    args: ["-O0", "input.wasm"],
  },
  {
    name: "olevel-o1",
    tags: ["olevel"],
    args: ["-O1", "input.wasm"],
  },
  {
    name: "olevel-o2",
    tags: ["olevel"],
    args: ["-O2", "input.wasm"],
  },
  {
    name: "olevel-o3",
    tags: ["olevel"],
    args: ["-O3", "input.wasm"],
  },
  {
    name: "olevel-oz",
    tags: ["olevel", "shrink"],
    args: ["-Oz", "input.wasm"],
  },
  {
    name: "long-optimize-level",
    tags: ["olevel", "long-flags"],
    args: ["--optimize-level", "3", "input.wasm"],
  },
  {
    name: "long-shrink-level",
    tags: ["olevel", "long-flags", "shrink"],
    args: ["--shrink-level", "2", "input.wasm"],
  },
  {
    name: "closed-world-optimize",
    tags: ["options", "preset"],
    args: ["--optimize", "--closed-world", "input.wasm"],
  },
  {
    name: "trap-mode-never",
    tags: ["options", "trap-mode"],
    args: ["--optimize", "--trap-mode", "never", "input.wasm"],
  },
  {
    name: "traps-never-happen",
    tags: ["options", "trap-mode"],
    args: ["--optimize", "--traps-never-happen", "input.wasm"],
  },
  {
    name: "monomorphize-and-low-memory",
    tags: ["options"],
    args: [
      "--optimize",
      "--monomorphize-min-benefit",
      "8",
      "--low-memory-unused",
      "--low-memory-bound",
      "4096",
      "input.wasm",
    ],
  },
  {
    name: "output-file",
    tags: ["outputs"],
    args: ["--optimize", "--out", "out.wasm", "input.wasm"],
  },
  {
    name: "output-dir",
    tags: ["outputs"],
    args: ["--optimize", "--out-dir", "dist", "input.wasm"],
  },
  {
    name: "stdout-short",
    tags: ["outputs", "short-flags"],
    args: ["-s", "--optimize", "input.wasm"],
  },
  {
    name: "config-explicit-short",
    tags: ["config", "short-flags"],
    args: ["-c", "starshine.config.json", "input.wasm"],
  },
  {
    name: "config-explicit-long",
    tags: ["config"],
    args: ["--config", "starshine.config.json", "input.wasm"],
  },
  {
    name: "format-wasm",
    tags: ["format"],
    args: ["--format", "wasm", "input.bin"],
  },
  {
    name: "format-wat",
    tags: ["format"],
    args: ["--format", "wat", "input.txt"],
  },
  {
    name: "format-wast",
    tags: ["format"],
    args: ["--format", "wast", "input.txt"],
  },
  {
    name: "glob-patterns",
    tags: ["glob", "inputs"],
    args: ["--glob", "examples/**/*.wasm", "tests/**/*.wasm"],
  },
  {
    name: "many-inputs",
    tags: ["inputs"],
    args: ["a.wasm", "b.wasm", "c.wasm", "d.wasm", "e.wasm"],
  },
  {
    name: "examples-simple-wat",
    tags: ["examples", "format", "wat"],
    args: ["--optimize", "examples/modules/simple.wat"],
  },
  {
    name: "examples-feature-mix-wat",
    tags: ["examples", "format", "wat"],
    args: ["--optimize", "-O3", "examples/modules/feature_mix.wat"],
  },
  {
    name: "examples-memory64-shrink",
    tags: ["examples", "format", "wat", "shrink"],
    args: ["--shrink", "examples/modules/memory64_data.wat"],
  },
  {
    name: "examples-simd-table-multi",
    tags: ["examples", "format", "wat", "inputs"],
    args: [
      "--global-refining",
      "--vacuum",
      "examples/modules/table_dispatch.wat",
      "examples/modules/simd_lane_mix.wat",
    ],
  },
  {
    name: "examples-release-config-shape",
    tags: ["examples", "config"],
    args: ["--config", "examples/config/optimize-release.json", "examples/modules/simple.wat"],
  },
  {
    name: "debug-serial-tracing-pass",
    tags: ["debug", "tracing"],
    args: ["--debug-serial-passes", "--tracing", "pass", "--optimize", "input.wasm"],
  },
  {
    name: "tracing-helper",
    tags: ["tracing"],
    args: ["--tracing", "helper", "--optimize", "input.wasm"],
  },
  {
    name: "dump-wasm-control",
    tags: ["pipeline-control"],
    args: ["--optimize", "--dump", "after.wasm", "input.wasm"],
  },
  {
    name: "dump-wat-control",
    tags: ["pipeline-control"],
    args: ["--optimize", "--dump", "after.wat", "input.wasm"],
  },
  {
    name: "extract-functions-control",
    tags: ["pipeline-control"],
    args: ["--extract-functions", "0,1,2", "input.wasm"],
  },
  {
    name: "print-func-control",
    tags: ["pipeline-control"],
    args: ["--print-func", "0", "input.wasm"],
  },
  {
    name: "print-type-control",
    tags: ["pipeline-control"],
    args: ["--print-type", "0", "input.wasm"],
  },
  {
    name: "print-global-control",
    tags: ["pipeline-control"],
    args: ["--print-global", "0", "input.wasm"],
  },
  {
    name: "multi-pass-hot-chain",
    tags: ["pass", "chain"],
    args: [
      "--vacuum",
      "--remove-unused-names",
      "--remove-unused-brs",
      "--optimize-instructions",
      "--precompute",
      "input.wasm",
    ],
  },
  {
    name: "multi-pass-module-chain",
    tags: ["pass", "chain", "module-pass"],
    args: [
      "--memory-packing",
      "--once-reduction",
      "--global-refining",
      "--global-struct-inference",
      "--local-cse",
      "input.wasm",
    ],
  },
];

function passCase(passName: string): CliBenchmarkCase {
  return {
    name: `pass-${passName}`,
    tags: ["pass"],
    args: [`--${passName}`, "input.wasm"],
  };
}

function optionMatrixCases(): CliBenchmarkCase[] {
  const cases: CliBenchmarkCase[] = [];
  const levels = ["-O1", "-O2", "-O3", "-Oz"];
  const trapFlags = [[], ["--trap-mode", "allow"], ["--trap-mode", "never"], ["--traps-never-happen"]];
  const worldFlags = [[], ["--closed-world"], ["--no-closed-world"]];
  for (const level of levels) {
    for (const trap of trapFlags) {
      for (const world of worldFlags) {
        const nameParts = [
          "matrix",
          level.replace(/^-/, "").toLowerCase(),
          trap.length === 0 ? "trap-default" : trap.join("-").replace(/^--/, "").replace(/--/g, ""),
          world.length === 0 ? "world-default" : world[0].replace(/^--/, ""),
        ];
        cases.push({
          name: nameParts.join("-"),
          tags: ["matrix", "options", "olevel"],
          args: [level, ...trap, ...world, "input.wasm"],
        });
      }
    }
  }
  return cases;
}

export function allCliBenchmarkCases(suite: CliBenchmarkSuite): CliBenchmarkCase[] {
  const smoke = CORE_CASES.slice(0, 10);
  if (suite === "smoke") {
    return smoke;
  }

  const standard = [
    ...CORE_CASES,
    ...HOT_AND_MODULE_PASSES.map(passCase),
    ...NO_INLINE_CASES,
  ];
  if (suite === "standard") {
    return standard;
  }

  return [
    ...standard,
    ...optionMatrixCases(),
  ];
}

function usage(): string {
  return [
    "usage: bun run cli-benchmarks [options]",
    "       bun scripts/cli-benchmarks.ts [options]",
    "",
    "Runs many `moon run src/cli-benchmarks -- ... -- <starshine args>` cases.",
    "",
    "Options:",
    "  --suite <smoke|standard|full>  Case suite to run (default: standard).",
    "  --iterations <n>               Iterations per benchmark case (default: 5000).",
    "  --warmup <n>                   Warmup iterations per case (default: 100).",
    "  --target <target>              Moon target for cli-benchmarks (default: wasm-gc).",
    "  --moon <path>                  Moon executable (default: MOON_BIN or moon).",
    "  --limit <n>                    Run at most n selected cases.",
    "  --grep <text>                  Run cases whose name or tag contains text.",
    "  --jsonl                        Emit one JSON result per case instead of a table.",
    "  --out <path>                   Also write results as JSONL to a file.",
    "  --dry-run                      Print generated moon commands without executing.",
    "  --no-fail-fast                 Continue after a failed case.",
    "  --help                         Show this help.",
  ].join("\n");
}

function parsePositiveInt(raw: string, flag: string): number {
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    fail(`invalid ${flag} value: ${raw}`);
  }
  return parsed;
}

function parseNonNegativeInt(raw: string, flag: string): number {
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isInteger(parsed) || parsed < 0) {
    fail(`invalid ${flag} value: ${raw}`);
  }
  return parsed;
}

export function parseCliBenchmarkRunnerArgs(argv: string[]): CliBenchmarkRunnerOptions {
  const options: CliBenchmarkRunnerOptions = {
    iterations: 5000,
    warmup: 100,
    suite: "standard",
    target: "wasm-gc",
    moonBin: resolveMoonBin(),
    limit: null,
    grep: null,
    dryRun: false,
    jsonl: false,
    outPath: null,
    failFast: true,
  };

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--help":
      case "-h":
        process.stdout.write(`${usage()}\n`);
        process.exit(0);
      case "--suite": {
        const suite = argv[i + 1] ?? fail("missing value for --suite");
        if (suite !== "smoke" && suite !== "standard" && suite !== "full") {
          fail(`invalid --suite value: ${suite}`);
        }
        options.suite = suite;
        i += 2;
        break;
      }
      case "--iterations":
      case "--repeat":
        options.iterations = parsePositiveInt(argv[i + 1] ?? fail(`missing value for ${token}`), token);
        i += 2;
        break;
      case "--warmup":
        options.warmup = parseNonNegativeInt(argv[i + 1] ?? fail("missing value for --warmup"), "--warmup");
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
      case "--limit":
        options.limit = parsePositiveInt(argv[i + 1] ?? fail("missing value for --limit"), "--limit");
        i += 2;
        break;
      case "--grep":
        options.grep = argv[i + 1] ?? fail("missing value for --grep");
        i += 2;
        break;
      case "--jsonl":
        options.jsonl = true;
        i += 1;
        break;
      case "--out":
        options.outPath = argv[i + 1] ?? fail("missing value for --out");
        i += 2;
        break;
      case "--dry-run":
        options.dryRun = true;
        i += 1;
        break;
      case "--no-fail-fast":
        options.failFast = false;
        i += 1;
        break;
      default:
        fail(`unknown option: ${token}\n${usage()}`);
    }
  }

  assertTarget(options.target);
  return options;
}

function selectedCases(options: CliBenchmarkRunnerOptions): CliBenchmarkCase[] {
  let cases = allCliBenchmarkCases(options.suite);
  if (options.grep !== null) {
    const needle = options.grep.toLowerCase();
    cases = cases.filter((testCase) => {
      return testCase.name.toLowerCase().includes(needle) ||
        testCase.tags.some((tag) => tag.toLowerCase().includes(needle));
    });
  }
  if (options.limit !== null) {
    cases = cases.slice(0, options.limit);
  }
  if (cases.length === 0) {
    fail("no cli benchmark cases selected");
  }
  return cases;
}

function moonBenchmarkArgs(options: CliBenchmarkRunnerOptions, testCase: CliBenchmarkCase): string[] {
  return [
    "run",
    "src/cli-benchmarks",
    "--target",
    options.target,
    "--",
    "--iterations",
    String(options.iterations),
    "--warmup",
    String(options.warmup),
    "--jsonl",
    "--",
    ...testCase.args,
  ];
}

function parseBenchmarkJson(stdout: string, testCase: CliBenchmarkCase): CliBenchmarkResult {
  const jsonLine = stdout.split(/\r?\n/).map((line) => line.trim()).reverse().find((line) => line.startsWith("{"));
  if (jsonLine === undefined) {
    fail(`benchmark case ${testCase.name} did not emit JSON output`);
  }
  try {
    return JSON.parse(jsonLine) as CliBenchmarkResult;
  } catch (error) {
    fail(`benchmark case ${testCase.name} emitted invalid JSON: ${error}`);
  }
}

function formatResultLine(result: CliBenchmarkCaseResult, index: number, total: number): string {
  const name = result.case.padEnd(42);
  const passes = result.resolved_passes.length === 0 ? "-" : result.resolved_passes;
  return [
    `[${String(index + 1).padStart(String(total).length, " ")}/${total}]`,
    name,
    `parse_avg_us=${String(result.parse_avg_us).padStart(4, " ")}`,
    `setup_avg_us=${String(result.setup_avg_us).padStart(4, " ")}`,
    `passes=${passes}`,
  ].join(" ");
}

function writeSummary(results: CliBenchmarkCaseResult[]): void {
  const bySetup = [...results].sort((a, b) => b.setup_avg_us - a.setup_avg_us).slice(0, 10);
  const byParse = [...results].sort((a, b) => b.parse_avg_us - a.parse_avg_us).slice(0, 10);

  process.stdout.write("\nSlowest setup_avg_us cases:\n");
  for (const result of bySetup) {
    process.stdout.write(`  ${String(result.setup_avg_us).padStart(5, " ")} us  ${result.case}\n`);
  }

  process.stdout.write("\nSlowest parse_avg_us cases:\n");
  for (const result of byParse) {
    process.stdout.write(`  ${String(result.parse_avg_us).padStart(5, " ")} us  ${result.case}\n`);
  }
}

function writeOutFile(repoRoot: string, outPath: string, results: CliBenchmarkCaseResult[]): void {
  const resolved = resolveRepoPath(repoRoot, outPath);
  fs.mkdirSync(path.dirname(resolved), { recursive: true });
  fs.writeFileSync(resolved, results.map((result) => JSON.stringify(result)).join("\n") + "\n");
  process.stdout.write(`\nWrote JSONL results: ${resolved}\n`);
}

export function runCliBenchmarks(options: CliBenchmarkRunnerOptions): CliBenchmarkCaseResult[] {
  const repoRoot = resolveWorkspaceRoot();
  const env = makeRepoTmpEnv(repoRoot);
  const cases = selectedCases(options);

  if (options.dryRun) {
    for (const testCase of cases) {
      process.stdout.write(`${options.moonBin} ${moonBenchmarkArgs(options, testCase).join(" ")}\n`);
    }
    return [];
  }

  if (!options.jsonl) {
    process.stdout.write(
      `Running ${cases.length} CLI benchmark cases (suite=${options.suite}, iterations=${options.iterations}, warmup=${options.warmup}, target=${options.target})\n`,
    );
  }

  const results: CliBenchmarkCaseResult[] = [];
  const failures: Array<{ name: string; error: unknown }> = [];

  for (let index = 0; index < cases.length; index += 1) {
    const testCase = cases[index];
    try {
      const run = runOrThrow(options.moonBin, moonBenchmarkArgs(options, testCase), {
        cwd: repoRoot,
        env,
        stdio: "pipe",
      });
      const parsed = parseBenchmarkJson(run.stdout, testCase);
      const result: CliBenchmarkCaseResult = {
        ...parsed,
        case: testCase.name,
        tags: testCase.tags,
        args: testCase.args,
      };
      results.push(result);
      if (options.jsonl) {
        process.stdout.write(`${JSON.stringify(result)}\n`);
      } else {
        process.stdout.write(`${formatResultLine(result, index, cases.length)}\n`);
      }
    } catch (error) {
      failures.push({ name: testCase.name, error });
      const message = error instanceof Error ? error.message : String(error);
      process.stderr.write(`FAIL: ${testCase.name}: ${message}\n`);
      if (options.failFast) {
        break;
      }
    }
  }

  if (options.outPath !== null) {
    writeOutFile(repoRoot, options.outPath, results);
  }

  if (!options.jsonl && results.length > 0) {
    writeSummary(results);
  }

  if (failures.length > 0) {
    fail(`${failures.length} cli benchmark case(s) failed`);
  }

  return results;
}

export function main(argv: string[]): void {
  runCliBenchmarks(parseCliBenchmarkRunnerArgs(argv));
}
