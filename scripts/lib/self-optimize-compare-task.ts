import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";

import { fail, resolveMoonBin, resolveRepoPath, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

type StarshineInvocation = {
  command: string;
  argsPrefix: string[];
};

type SelfOptimizeCompareOptions = {
  inputPath: string;
  outDir: string;
  moonBin: string;
  starshineBin: string | null;
  wasmOptBin: string;
  wasmToolsBin: string;
  passFlags: string[];
};

type ComparisonSummary = {
  inputPath: string;
  outDir: string;
  passFlags: string[];
  binaryenPassFlags: string[];
  starshineCommand: string[];
  binaryenCommand: string[];
  starshineSize: number;
  binaryenSize: number;
  wasmEqual: boolean;
  starshineElapsedMs: number;
  binaryenElapsedMs: number;
  starshineAtLeastAsFast: boolean;
  starshinePassElapsedMs: number;
  binaryenPassElapsedMs: number;
  starshinePassAtLeastAsFast: boolean;
  normalizedWatEqual: boolean;
};

const RESERVED_OPTIONS = new Set([
  "--out-dir",
  "--starshine-bin",
  "--wasm-opt-bin",
  "--wasm-tools-bin",
  "--moon",
]);

const BINARYEN_FLAG_ALIASES = new Map<string, string>([
  ["--dead-code-elimination", "--dce"],
  ["--dead-argument-elimination", "--dae"],
  ["--dead-argument-elimination-optimizing", "--dae-optimizing"],
  ["--global-struct-inference", "--gsi"],
  ["--redundant-set-elimination", "--rse"],
]);

const UNSUPPORTED_PRESET_FLAGS = new Set(["--optimize", "--shrink"]);

// Build a deterministic temp directory name so multiple runs can run without
// clobbering each other (and still be easy to clean up).
function defaultOutDir(inputPath: string): string {
  const stem = path.basename(inputPath).replace(/\.[^.]+$/, "");
  return path.join(os.tmpdir(), `starshine-self-optimize-compare-${stem}-${process.pid}`);
}

function normalizeBinaryenPassFlag(flag: string): string {
  // Translate compatible Starshine-style flags to Binaryen CLI names; reject
  // preset-style options that would alter whole-tool behavior.
  if (UNSUPPORTED_PRESET_FLAGS.has(flag) || /^-O\d/.test(flag)) {
    fail(`unsupported preset flag for self-optimize compare: ${flag}`);
  }
  return BINARYEN_FLAG_ALIASES.get(flag) ?? flag;
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

  const releaseBinaryExe = path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd.exe");
  const releaseBinary = path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd");
  if (fs.existsSync(releaseBinaryExe)) {
    return { command: releaseBinaryExe, argsPrefix: [] };
  }
  if (fs.existsSync(releaseBinary)) {
    return { command: releaseBinary, argsPrefix: [] };
  }
  return {
    command: moonBin,
    argsPrefix: ["run", "--target", "native", "--release", "src/cmd", "--"],
  };
}

function normalizePrintWat(wasmOptBin: string, wasmPath: string, repoRoot: string): string {
  // Run wasm-opt in text mode and read the canonicalized WAT from disk so
  // very large modules do not overflow spawnSync stdout buffers.
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-compare-wat-"));
  const watPath = path.join(tempDir, "normalized.wat");
  try {
    runOrThrow(
      wasmOptBin,
      [wasmPath, "--all-features", "--strip-debug", "-S", "-o", watPath],
      { cwd: repoRoot, stdio: "pipe" },
    );
    return fs.readFileSync(watPath, "utf8");
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

function canonicalizeWasm(
  wasmOptBin: string,
  inputPath: string,
  outputPath: string,
  repoRoot: string,
): void {
  // Canonicalize both outputs through the same strip-debug writer so raw
  // compare noise from names or non-canonical section ordering does not mask
  // actual pass correctness parity.
  runOrThrow(
    wasmOptBin,
    [inputPath, "--all-features", "--strip-debug", "-o", outputPath],
    { cwd: repoRoot, stdio: "pipe" },
  );
}

function runTimedOrThrow(
  command: string,
  args: string[],
  options: Parameters<typeof runOrThrow>[2],
): { stdout: string; stderr: string; elapsedMs: number } {
  const start = process.hrtime.bigint();
  const result = runOrThrow(command, args, options);
  const elapsedMs = Number(process.hrtime.bigint() - start) / 1_000_000;
  return { ...result, elapsedMs };
}

function parseStarshinePassElapsedMs(stderr: string): number {
  const matches = Array.from(stderr.matchAll(/perf:timer name=pass:[^\s]+ elapsed_us=(\d+)/g));
  if (matches.length === 0) {
    fail("failed to parse Starshine pass timing from traced stderr");
  }
  return matches.reduce((sum, match) => sum + Number(match[1]), 0) / 1000;
}

function parseBinaryenPassElapsedMs(stdout: string, stderr: string): number {
  const combined = `${stdout}\n${stderr}`;
  const matches = Array.from(combined.matchAll(/passes took ([0-9.]+) seconds\./g));
  const last = matches.at(-1);
  if (!last) {
    fail("failed to parse Binaryen pass timing from --debug output");
  }
  return Number(last[1]) * 1000;
}

function validateInputBaseline(wasmToolsBin: string, inputPath: string, repoRoot: string): void {
  // Fail fast if baseline input is malformed, because compare results are not
  // meaningful when either input or reference decoder rejects it first.
  try {
    runOrThrow(wasmToolsBin, ["validate", inputPath], {
      cwd: repoRoot,
      stdio: "pipe",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    fail(`input baseline is invalid and cannot be compared: ${inputPath}\n${message}`);
  }
}

export function parseSelfOptimizeCompareArgs(argv: string[]): SelfOptimizeCompareOptions {
  let inputPath: string | null = null;
  let outDir: string | null = null;
  let moonBin = resolveMoonBin();
  let starshineBin: string | null = null;
  let wasmOptBin = process.env.WASM_OPT_BIN || "wasm-opt";
  let wasmToolsBin = process.env.WASM_TOOLS_BIN || "wasm-tools";
  const passFlags: string[] = [];

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--out-dir":
        outDir = argv[i + 1] ?? fail("missing value for --out-dir");
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
      case "--moon":
        moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      case "--wasm-tools-bin":
        wasmToolsBin = argv[i + 1] ?? fail("missing value for --wasm-tools-bin");
        i += 2;
        break;
      default:
        if (RESERVED_OPTIONS.has(token)) {
          fail(`missing value for ${token}`);
        }
        if (token.startsWith("--")) {
          passFlags.push(token);
          i += 1;
          break;
        }
        if (inputPath === null) {
          inputPath = token;
          i += 1;
          break;
        }
        fail(`unexpected positional argument: ${token}`);
    }
  }

  if (inputPath === null) {
    fail("usage: bun scripts/self-optimize-compare.ts <input.wasm> [options] [--pass ...]");
  }
  if (passFlags.length === 0) {
    fail("expected at least one pass flag to compare");
  }

  return {
    inputPath,
    outDir: outDir ?? defaultOutDir(inputPath),
    moonBin,
    starshineBin,
    wasmOptBin,
    wasmToolsBin,
    passFlags,
  };
}

// Run Starshine and Binaryen side-by-side, normalize both outputs to WAT, and
// persist an explicit command/size summary for reproducibility.
export async function runSelfOptimizeCompare(argv: string[]): Promise<void> {
  const repoRoot = resolveWorkspaceRoot();
  const options = parseSelfOptimizeCompareArgs(argv);
  const inputPath = resolveRepoPath(repoRoot, options.inputPath);
  const outDir = resolveRepoPath(repoRoot, options.outDir);
  const starshineRawOutputPath = path.join(outDir, "starshine.raw.wasm");
  const binaryenRawOutputPath = path.join(outDir, "binaryen.raw.wasm");
  const starshineOutputPath = path.join(outDir, "starshine.wasm");
  const binaryenOutputPath = path.join(outDir, "binaryen.wasm");
  const starshineWatPath = path.join(outDir, "starshine.print.wat");
  const binaryenWatPath = path.join(outDir, "binaryen.print.wat");
  const summaryPath = path.join(outDir, "result.json");
  const commandsPath = path.join(outDir, "commands.txt");

  if (!fs.existsSync(inputPath)) {
    fail(`input file not found: ${inputPath}`);
  }

  fs.mkdirSync(outDir, { recursive: true });
  validateInputBaseline(options.wasmToolsBin, inputPath, repoRoot);

  const binaryenPassFlags = options.passFlags.map(normalizeBinaryenPassFlag);
  const starshineInvocation = resolveStarshineInvocation(
    repoRoot,
    options.starshineBin,
    options.moonBin,
  );
  const starshineArgs = [
    ...starshineInvocation.argsPrefix,
    ...options.passFlags,
    "--out",
    starshineRawOutputPath,
    inputPath,
  ];
  const binaryenArgs = [
    inputPath,
    "--all-features",
    ...binaryenPassFlags,
    "--debug",
    "-o",
    binaryenRawOutputPath,
  ];

  const starshineRun = runTimedOrThrow(starshineInvocation.command, starshineArgs, {
    cwd: repoRoot,
    env: {
      ...process.env,
      STARSHINE_TRACING: "pass",
    },
    stdio: "pipe",
  });
  const binaryenRun = runTimedOrThrow(options.wasmOptBin, binaryenArgs, {
    cwd: repoRoot,
    stdio: "pipe",
  });
  const starshinePassElapsedMs = parseStarshinePassElapsedMs(starshineRun.stderr);
  const binaryenPassElapsedMs = parseBinaryenPassElapsedMs(
    binaryenRun.stdout,
    binaryenRun.stderr,
  );

  canonicalizeWasm(options.wasmOptBin, starshineRawOutputPath, starshineOutputPath, repoRoot);
  // Binaryen's direct output is the reference artifact we want to match; keep
  // it verbatim so the published compare pair answers "did Starshine reach the
  // Binaryen bytes?" instead of "did both survive another rewrite step?".
  fs.copyFileSync(binaryenRawOutputPath, binaryenOutputPath);

  const starshineWat = normalizePrintWat(options.wasmOptBin, starshineOutputPath, repoRoot);
  const binaryenWat = normalizePrintWat(options.wasmOptBin, binaryenOutputPath, repoRoot);
  fs.writeFileSync(starshineWatPath, starshineWat);
  fs.writeFileSync(binaryenWatPath, binaryenWat);
  const wasmEqual =
    fs.readFileSync(starshineOutputPath).equals(fs.readFileSync(binaryenOutputPath));

  const summary: ComparisonSummary = {
    inputPath,
    outDir,
    passFlags: options.passFlags,
    binaryenPassFlags,
    starshineCommand: [starshineInvocation.command, ...starshineArgs],
    binaryenCommand: [options.wasmOptBin, ...binaryenArgs],
    starshineSize: fs.statSync(starshineOutputPath).size,
    binaryenSize: fs.statSync(binaryenOutputPath).size,
    wasmEqual,
    starshineElapsedMs: starshineRun.elapsedMs,
    binaryenElapsedMs: binaryenRun.elapsedMs,
    starshineAtLeastAsFast: starshineRun.elapsedMs <= binaryenRun.elapsedMs,
    starshinePassElapsedMs,
    binaryenPassElapsedMs,
    starshinePassAtLeastAsFast: starshinePassElapsedMs <= binaryenPassElapsedMs,
    normalizedWatEqual: starshineWat === binaryenWat,
  };

  fs.writeFileSync(
    commandsPath,
    [
      `starshine: ${summary.starshineCommand.join(" ")}`,
      `binaryen: ${summary.binaryenCommand.join(" ")}`,
    ].join("\n") + "\n",
  );
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2) + "\n");

  process.stdout.write(`Wrote comparison artifacts to ${outDir}\n`);
  process.stdout.write(`Starshine raw wasm: ${starshineRawOutputPath}\n`);
  process.stdout.write(`Binaryen raw wasm: ${binaryenRawOutputPath}\n`);
  process.stdout.write(`Starshine wasm: ${starshineOutputPath}\n`);
  process.stdout.write(`Binaryen wasm: ${binaryenOutputPath}\n`);
  process.stdout.write(`Starshine normalized WAT: ${starshineWatPath}\n`);
  process.stdout.write(`Binaryen normalized WAT: ${binaryenWatPath}\n`);
  process.stdout.write(`Canonical wasm equal: ${summary.wasmEqual ? "yes" : "no"}\n`);
  process.stdout.write(`Starshine runtime (ms): ${summary.starshineElapsedMs.toFixed(3)}\n`);
  process.stdout.write(`Binaryen runtime (ms): ${summary.binaryenElapsedMs.toFixed(3)}\n`);
  process.stdout.write(`Starshine at least as fast: ${summary.starshineAtLeastAsFast ? "yes" : "no"}\n`);
  process.stdout.write(`Starshine pass runtime (ms): ${summary.starshinePassElapsedMs.toFixed(3)}\n`);
  process.stdout.write(`Binaryen pass runtime (ms): ${summary.binaryenPassElapsedMs.toFixed(3)}\n`);
  process.stdout.write(`Starshine pass at least as fast: ${summary.starshinePassAtLeastAsFast ? "yes" : "no"}\n`);
  process.stdout.write(`Normalized WAT equal: ${summary.normalizedWatEqual ? "yes" : "no"}\n`);
}

export async function main(argv: string[]): Promise<void> {
  await runSelfOptimizeCompare(argv);
}
