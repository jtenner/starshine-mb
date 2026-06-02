import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

import { buildSelfOptimized } from "./build-self-optimized.mjs";
import { runWasmStart } from "./moonbit-wasi-runner.mjs";
import { runSelfOptimizedSpecSuite } from "./run-self-optimized-spec-suite.mjs";
import { distArtifactPaths, nativeStarshineBinaryPaths, validateWasmArtifact } from "./self-optimized-artifacts.mjs";
import { fail, resolveMoonBin, resolveRepoPath, resolveWorkspaceRoot, runOrThrow, teeCommandToFile } from "./task-runtime";

// Parse build-mode options: optional fallback behavior and custom moon executable.
export function parseSelfOptBuildArgs(argv: string[]): { fallbackDebugOnFailure: boolean; moonBin: string } {
  let fallbackDebugOnFailure = false;
  let moonBin = resolveMoonBin();
  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--fallback-debug-on-failure":
        fallbackDebugOnFailure = true;
        i += 1;
        break;
      case "--moon":
        moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }
  return { fallbackDebugOnFailure, moonBin };
}

// Parse options for reuse of an already-configured moon binary during optimize.
export function parseSelfOptOptimizeArgs(argv: string[]): { moonBin: string } {
  let moonBin = resolveMoonBin();
  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--moon":
        moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }
  return { moonBin };
}

export type SelfOptSpecSelection = { limit: number | null; onlyFiles: string[]; wasmPath: string | null };

// Parse optional spec-suite filters (`--limit`, `--file`, `--wasm`) into a normalized
// run descriptor used by the harness.
export function parseSelfOptSpecArgs(argv: string[]): SelfOptSpecSelection {
  let limit: number | null = null;
  let wasmPath: string | null = null;
  const onlyFiles: string[] = [];
  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--limit": {
        const raw = argv[i + 1] ?? fail("missing value for --limit");
        const parsed = Number.parseInt(raw, 10);
        if (!Number.isInteger(parsed) || parsed <= 0) {
          fail(`Invalid --limit value: ${raw}`);
        }
        limit = parsed;
        i += 2;
        break;
      }
      case "--file":
        onlyFiles.push(argv[i + 1] ?? fail("missing value for --file"));
        i += 2;
        break;
      case "--wasm":
        wasmPath = argv[i + 1] ?? fail("missing value for --wasm");
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }
  return { limit, onlyFiles, wasmPath };
}

// Parse the self-optimized artifact safety lane. By default this is a fast smoke
// (`--limit 1`) so it is safe for ordinary validation; `--full-spec` intentionally
// expands to all checked-in WAST spec files.
export function parseSelfOptCheckArgs(argv: string[]): SelfOptSpecSelection {
  let limit: number | null = 1;
  let wasmPath: string | null = null;
  let fullSpec = false;
  let explicitLimit = false;
  const onlyFiles: string[] = [];

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--full-spec":
        if (explicitLimit) {
          fail("--full-spec cannot be combined with --limit");
        }
        fullSpec = true;
        limit = null;
        i += 1;
        break;
      case "--limit": {
        if (fullSpec) {
          fail("--limit cannot be combined with --full-spec");
        }
        const raw = argv[i + 1] ?? fail("missing value for --limit");
        const parsed = Number.parseInt(raw, 10);
        if (!Number.isInteger(parsed) || parsed <= 0) {
          fail(`Invalid --limit value: ${raw}`);
        }
        explicitLimit = true;
        limit = parsed;
        i += 2;
        break;
      }
      case "--file":
        onlyFiles.push(argv[i + 1] ?? fail("missing value for --file"));
        if (!fullSpec) {
          limit = null;
        }
        i += 2;
        break;
      case "--wasm":
        wasmPath = argv[i + 1] ?? fail("missing value for --wasm");
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }

  return { limit, onlyFiles, wasmPath };
}

export type SelfOptSpecRunnerCopy = {
  wasmPath: string;
  cleanup?: () => void;
};

export type SelfOptCheckDeps = {
  repoRoot?: string;
  validateWasmArtifact?: typeof validateWasmArtifact;
  runWasmStart?: typeof runWasmStart;
  runSelfOptimizedSpecSuite?: typeof runSelfOptimizedSpecSuite;
  prepareSpecRunnerWasm?: (repoRoot: string, wasmPath: string) => SelfOptSpecRunnerCopy;
  writeStdout?: (text: string) => void;
};

function prepareSelfOptSpecRunnerWasm(repoRoot: string, wasmPath: string): SelfOptSpecRunnerCopy {
  const tmpRoot = path.join(repoRoot, ".tmp");
  fs.mkdirSync(tmpRoot, { recursive: true });
  const tmpDir = fs.mkdtempSync(path.join(tmpRoot, "self-opt-check-"));
  const runnerWasm = path.join(tmpDir, "runner.wasm");
  fs.copyFileSync(wasmPath, runnerWasm);
  return {
    wasmPath: runnerWasm,
    cleanup() {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    },
  };
}

// Validate and execute the self-optimized CLI artifact through a minimal runtime
// smoke and the selected WAST spec workload. This lane is intentionally separate
// from building so CI can test an already-produced artifact without silently
// falling back to manual smoke commands.
export async function runSelfOptCheck(argv: string[], deps: SelfOptCheckDeps = {}): Promise<void> {
  const repoRoot = deps.repoRoot ?? resolveWorkspaceRoot();
  const options = parseSelfOptCheckArgs(argv);
  const wasmPath = options.wasmPath === null
    ? distArtifactPaths(repoRoot).selfOptimized
    : resolveRepoPath(repoRoot, options.wasmPath);
  const validate = deps.validateWasmArtifact ?? validateWasmArtifact;
  const runStart = deps.runWasmStart ?? runWasmStart;
  const runSpec = deps.runSelfOptimizedSpecSuite ?? runSelfOptimizedSpecSuite;
  const prepareSpecRunner = deps.prepareSpecRunnerWasm ?? prepareSelfOptSpecRunnerWasm;
  const writeStdout = deps.writeStdout ?? ((text: string) => process.stdout.write(text));

  validate({
    repoRoot,
    wasmPath,
    label: "self-optimized wasm artifact",
  });

  const smokeRoot = path.join(repoRoot, ".tmp");
  fs.mkdirSync(smokeRoot, { recursive: true });
  const smokeDir = fs.mkdtempSync(path.join(smokeRoot, "self-opt-help-"));
  const smokeStdoutPath = path.join(smokeDir, "stdout.log");
  const smokeStderrPath = path.join(smokeDir, "stderr.log");
  const smokeStdoutFd = fs.openSync(smokeStdoutPath, "w");
  const smokeStderrFd = fs.openSync(smokeStderrPath, "w");
  let smokeExitCode = 0;
  try {
    smokeExitCode = await runStart({
      wasmPath,
      args: ["--help"],
      cwd: repoRoot,
      preopens: { ".": repoRoot },
      stdoutFd: smokeStdoutFd,
      stderrFd: smokeStderrFd,
    });
  } finally {
    fs.closeSync(smokeStdoutFd);
    fs.closeSync(smokeStderrFd);
  }
  if (smokeExitCode !== 0) {
    fail(
      `self-optimized wasm --help smoke failed with exit code ${smokeExitCode}\n` +
      `stdout=${smokeStdoutPath}\n` +
      `stderr=${smokeStderrPath}`,
    );
  }
  const smokeStdout = fs.readFileSync(smokeStdoutPath, "utf8");
  if (!smokeStdout.includes("Usage:")) {
    fail(
      `self-optimized wasm --help smoke produced no Usage output\n` +
      `stdout=${smokeStdoutPath}\n` +
      `stderr=${smokeStderrPath}`,
    );
  }

  const specRunner = prepareSpecRunner(repoRoot, wasmPath);
  let result: Awaited<ReturnType<typeof runSelfOptimizedSpecSuite>>;
  try {
    result = await runSpec({
      repoRoot,
      wasmPath: specRunner.wasmPath,
      limit: options.limit,
      onlyFiles: options.onlyFiles,
    });
  } finally {
    specRunner.cleanup?.();
  }
  if (result.exitCode !== 0) {
    fail(`self-optimized wasm spec suite failed with exit code ${result.exitCode}`);
  }
  const specStdout = typeof (result as { stdout?: unknown }).stdout === "string"
    ? (result as { stdout: string }).stdout
    : "";
  const summaryMatch = specStdout.match(/spec suite summary: total=(-?\d+) passed=(-?\d+) skipped=(-?\d+) failed=(-?\d+)/);
  const stdoutPath = typeof (result as { stdoutPath?: unknown }).stdoutPath === "string"
    ? `\nstdout=${(result as { stdoutPath: string }).stdoutPath}`
    : "";
  const stderrPath = typeof (result as { stderrPath?: unknown }).stderrPath === "string"
    ? `\nstderr=${(result as { stderrPath: string }).stderrPath}`
    : "";
  if (summaryMatch === null || Number.parseInt(summaryMatch[1], 10) !== result.selectedFileCount) {
    fail(
      `self-optimized wasm spec smoke produced no summary for ${result.selectedFileCount} selected file(s)` +
      stdoutPath +
      stderrPath,
    );
  }
  const total = Number.parseInt(summaryMatch[1], 10);
  const passed = Number.parseInt(summaryMatch[2], 10);
  const skipped = Number.parseInt(summaryMatch[3], 10);
  const failed = Number.parseInt(summaryMatch[4], 10);
  if (passed < 0 || skipped < 0 || failed < 0 || passed + skipped + failed !== total) {
    fail(
      `self-optimized wasm spec smoke summary counts are inconsistent` +
      stdoutPath +
      stderrPath,
    );
  }

  writeStdout(`Validated self-optimized wasm and executed ${result.selectedFileCount} spec file(s).\n`);
}

export type SelfOptArtifactOptimizerCompareOptions = {
  optimizerWasmPath: string | null;
  inputWasmPath: string | null;
  expectedWasmPath: string | null;
  nativeBin: string | null;
  outDir: string;
};

export type SelfOptArtifactOptimizerCompareResult = {
  exactMatch: true;
  optimizerWasmPath: string;
  inputWasmPath: string;
  expectedWasmPath: string;
  actualWasmPath: string;
  size: number;
};

export type SelfOptArtifactOptimizerCompareDeps = {
  repoRoot?: string;
  validateWasmArtifact?: typeof validateWasmArtifact;
  runWasmStart?: typeof runWasmStart;
  runNativeOptimizer?: (command: string, args: string[], options: { cwd: string }) => void;
  writeStdout?: (text: string) => void;
};

// Parse exact-repro options for running the self-optimized wasm artifact as the
// optimizer and comparing its output against either a freshly generated native
// baseline or an explicit expected artifact.
export function parseSelfOptArtifactOptimizerCompareArgs(argv: string[]): SelfOptArtifactOptimizerCompareOptions {
  const options: SelfOptArtifactOptimizerCompareOptions = {
    optimizerWasmPath: null,
    inputWasmPath: null,
    expectedWasmPath: null,
    nativeBin: null,
    outDir: ".tmp/self-opt-artifact-optimizer-compare",
  };

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--optimizer-wasm":
        options.optimizerWasmPath = argv[i + 1] ?? fail("missing value for --optimizer-wasm");
        i += 2;
        break;
      case "--input":
        options.inputWasmPath = argv[i + 1] ?? fail("missing value for --input");
        i += 2;
        break;
      case "--expected":
        options.expectedWasmPath = argv[i + 1] ?? fail("missing value for --expected");
        i += 2;
        break;
      case "--native-bin":
        options.nativeBin = argv[i + 1] ?? fail("missing value for --native-bin");
        i += 2;
        break;
      case "--out-dir":
        options.outDir = argv[i + 1] ?? fail("missing value for --out-dir");
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }

  return options;
}

function resolveNativeStarshineBinary(repoRoot: string, nativeBin: string | null): string {
  if (nativeBin !== null) {
    const resolved = resolveRepoPath(repoRoot, nativeBin);
    if (!fs.existsSync(resolved)) {
      fail(`missing native Starshine optimizer: ${resolved}`);
    }
    return resolved;
  }
  const candidates = nativeStarshineBinaryPaths(repoRoot) as string[];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  fail(`missing native Starshine optimizer: ${candidates[0]}`);
}

function selfOptArtifactOptimizerArgs(inputWasmPath: string, outWasmPath: string): string[] {
  return ["--debug-serial-passes", "--optimize", "-O4z", "--out", outWasmPath, inputWasmPath];
}

function runWasmStartWithLargeNodeStack(options: Parameters<typeof runWasmStart>[0]): number {
  const { stdoutFd, stderrFd, ...childOptions } = options as Parameters<typeof runWasmStart>[0] & {
    stdoutFd?: number;
    stderrFd?: number;
  };
  const runnerUrl = pathToFileURL(
    path.join(resolveWorkspaceRoot(), "scripts", "lib", "moonbit-wasi-runner.mjs"),
  ).href;
  const script = `
    import { runWasmStart } from ${JSON.stringify(runnerUrl)};
    const options = JSON.parse(process.argv[1]);
    const code = await runWasmStart(options);
    process.exit(code);
  `;
  const result = spawnSync(
    process.env.NODE ?? "node",
    ["--stack-size=65500", "--input-type=module", "-e", script, JSON.stringify(childOptions)],
    {
      cwd: childOptions.cwd,
      stdio: ["ignore", stdoutFd ?? "inherit", stderrFd ?? "inherit"],
    },
  );
  if (result.error !== undefined) {
    throw result.error;
  }
  if (result.signal !== null) {
    throw new Error(`node wasm runner exited with signal ${result.signal}`);
  }
  return result.status ?? 1;
}

function sha256File(filePath: string): string {
  return createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function firstDiffOffset(expected: Buffer, actual: Buffer): number {
  const limit = Math.min(expected.length, actual.length);
  for (let i = 0; i < limit; i += 1) {
    if (expected[i] !== actual[i]) {
      return i;
    }
  }
  if (expected.length !== actual.length) {
    return limit;
  }
  return -1;
}

// Run the self-optimized wasm CLI as an optimizer over the debug artifact and
// require byte-for-byte equality with a native optimizer baseline (or an explicit
// `--expected` artifact). This catches nondeterminism or runtime-only optimizer
// drift that the ordinary spec lane cannot see.
export async function runSelfOptArtifactOptimizerCompare(
  argv: string[],
  deps: SelfOptArtifactOptimizerCompareDeps = {},
): Promise<SelfOptArtifactOptimizerCompareResult> {
  const repoRoot = deps.repoRoot ?? resolveWorkspaceRoot();
  const dist = distArtifactPaths(repoRoot);
  const options = parseSelfOptArtifactOptimizerCompareArgs(argv);
  const optimizerWasmPath = options.optimizerWasmPath === null
    ? dist.selfOptimized
    : resolveRepoPath(repoRoot, options.optimizerWasmPath);
  const inputWasmPath = options.inputWasmPath === null
    ? dist.debug
    : resolveRepoPath(repoRoot, options.inputWasmPath);
  const outDir = resolveRepoPath(repoRoot, options.outDir);
  const nativeOutputPath = path.join(outDir, "native-o4z.wasm");
  const actualWasmPath = path.join(outDir, "wasm-artifact-o4z.wasm");
  const wasmStdoutPath = path.join(outDir, "wasm-artifact-optimizer.stdout.log");
  const wasmStderrPath = path.join(outDir, "wasm-artifact-optimizer.stderr.log");
  const validate = deps.validateWasmArtifact ?? validateWasmArtifact;
  const runStart = deps.runWasmStart ?? runWasmStartWithLargeNodeStack;
  const runNative = deps.runNativeOptimizer ?? ((command, args, runOptions) => {
    runOrThrow(command, args, { cwd: runOptions.cwd, stdio: "inherit" });
  });
  const writeStdout = deps.writeStdout ?? ((text: string) => process.stdout.write(text));

  fs.mkdirSync(outDir, { recursive: true });
  for (const artifact of [nativeOutputPath, actualWasmPath, wasmStdoutPath, wasmStderrPath]) {
    fs.rmSync(artifact, { force: true });
  }

  validate({
    repoRoot,
    wasmPath: optimizerWasmPath,
    label: "self-optimized wasm optimizer artifact",
  });
  validate({
    repoRoot,
    wasmPath: inputWasmPath,
    label: "debug wasm input artifact",
  });

  let expectedWasmPath: string;
  if (options.expectedWasmPath === null) {
    const nativeBin = deps.runNativeOptimizer === undefined
      ? resolveNativeStarshineBinary(repoRoot, options.nativeBin)
      : options.nativeBin === null
        ? "native-starshine"
        : resolveRepoPath(repoRoot, options.nativeBin);
    runNative(nativeBin, selfOptArtifactOptimizerArgs(inputWasmPath, nativeOutputPath), { cwd: repoRoot });
    expectedWasmPath = nativeOutputPath;
  } else {
    expectedWasmPath = resolveRepoPath(repoRoot, options.expectedWasmPath);
  }
  validate({
    repoRoot,
    wasmPath: expectedWasmPath,
    label: "expected native optimizer output artifact",
  });

  const stdoutFd = fs.openSync(wasmStdoutPath, "w");
  const stderrFd = fs.openSync(wasmStderrPath, "w");
  let exitCode = 0;
  try {
    exitCode = await runStart({
      wasmPath: optimizerWasmPath,
      args: selfOptArtifactOptimizerArgs(inputWasmPath, actualWasmPath),
      cwd: repoRoot,
      preopens: { ".": repoRoot },
      stdoutFd,
      stderrFd,
    });
  } catch (err) {
    const reason = err instanceof Error ? `${err.name}: ${err.message}` : String(err);
    fail(
      `self-optimized wasm optimizer trapped: ${reason}\n` +
      `stdout=${wasmStdoutPath}\n` +
      `stderr=${wasmStderrPath}`,
    );
  } finally {
    fs.closeSync(stdoutFd);
    fs.closeSync(stderrFd);
  }
  if (exitCode !== 0) {
    fail(
      `self-optimized wasm optimizer failed with exit code ${exitCode}\n` +
      `stdout=${wasmStdoutPath}\n` +
      `stderr=${wasmStderrPath}`,
    );
  }
  if (!fs.existsSync(actualWasmPath)) {
    fail(
      `self-optimized wasm optimizer did not produce output\n` +
      `actual=${actualWasmPath}\n` +
      `stdout=${wasmStdoutPath}\n` +
      `stderr=${wasmStderrPath}`,
    );
  }
  validate({
    repoRoot,
    wasmPath: actualWasmPath,
    label: "wasm artifact optimizer output artifact",
  });

  const expectedBytes = fs.readFileSync(expectedWasmPath);
  const actualBytes = fs.readFileSync(actualWasmPath);
  if (!expectedBytes.equals(actualBytes)) {
    fail(
      `self-optimized wasm optimizer output mismatch\n` +
      `expected=${expectedWasmPath}\n` +
      `actual=${actualWasmPath}\n` +
      `expectedSize=${expectedBytes.length}\n` +
      `actualSize=${actualBytes.length}\n` +
      `firstDiffOffset=${firstDiffOffset(expectedBytes, actualBytes)}\n` +
      `expectedSha256=${sha256File(expectedWasmPath)}\n` +
      `actualSha256=${sha256File(actualWasmPath)}`,
    );
  }

  writeStdout(
    `Self-optimized wasm optimizer matched expected output exactly.\n` +
    `optimizer=${optimizerWasmPath}\n` +
    `input=${inputWasmPath}\n` +
    `expected=${expectedWasmPath}\n` +
    `actual=${actualWasmPath}\n` +
    `size=${actualBytes.length} bytes\n`,
  );
  return {
    exactMatch: true,
    optimizerWasmPath,
    inputWasmPath,
    expectedWasmPath,
    actualWasmPath,
    size: actualBytes.length,
  };
}

// Rebuild self-optimized artifacts (debug + optimized + native) from source using
// parsed options and selected moon binary.
export async function runSelfOptBuild(argv: string[]): Promise<void> {
  const repoRoot = resolveWorkspaceRoot();
  const options = parseSelfOptBuildArgs(argv);
  await buildSelfOptimized({
    repoRoot,
    moonBin: options.moonBin,
    fallbackDebugOnFailure: options.fallbackDebugOnFailure,
  });
}

// Build release artifacts then run the optimizer pipeline against debug wasm; prefer
// an existing release binary if present, otherwise fallback to `moon run`.
export async function runSelfOptOptimize(argv: string[]): Promise<void> {
  const repoRoot = resolveWorkspaceRoot();
  const { moonBin } = parseSelfOptOptimizeArgs(argv);

  runOrThrow(moonBin, ["clean"], { cwd: repoRoot });
  runOrThrow(moonBin, ["build", "--target", "wasm"], { cwd: repoRoot });
  runOrThrow(moonBin, ["build", "--target", "native", "--release", "--package", "jtenner/starshine/cmd"], { cwd: repoRoot });

  const traceLevel = process.env.SELF_OPT_TRACING_LEVEL || "pass";
  const outputPath = process.env.SELF_OPT_OUTPUT_LOG || path.join(repoRoot, "output.log");
  const serialOptFlag = process.env.SELF_OPT_SERIAL_FLAG || "--debug-serial-passes";
  const releaseBinaryExe = path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd.exe");
  const releaseBinary = path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd");
  const debugWasm = path.join(repoRoot, "_build", "wasm", "debug", "build", "cmd", "cmd.wasm");
  const outWasm = path.join(repoRoot, "tests", "node", "dist", "starshine-self-optimized-wasi.wasm");

  let command = moonBin;
  let args: string[];
  if (fs.existsSync(releaseBinaryExe)) {
    command = releaseBinaryExe;
    args = ["--tracing", traceLevel, serialOptFlag, "--optimize", "-O4z", "--out", outWasm, debugWasm];
  } else if (fs.existsSync(releaseBinary)) {
    command = releaseBinary;
    args = ["--tracing", traceLevel, serialOptFlag, "--optimize", "-O4z", "--out", outWasm, debugWasm];
  } else {
    args = [
      "run",
      "--target",
      "native",
      "--release",
      "src/cmd",
      "--",
      "--tracing",
      traceLevel,
      serialOptFlag,
      "--optimize",
      "-O4z",
      "--out",
      outWasm,
      debugWasm,
    ];
  }

  await teeCommandToFile(command, args, outputPath, { cwd: repoRoot });
  validateWasmArtifact({
    repoRoot,
    wasmPath: outWasm,
    label: "self-optimized wasm artifact",
  });
}

// Run the spec-validation harness against the generated self-optimized wasm with optional
// file filtering and artifact path override.
export async function runSelfOptSpec(argv: string[]): Promise<void> {
  const repoRoot = resolveWorkspaceRoot();
  const options = parseSelfOptSpecArgs(argv);
  const result = await runSelfOptimizedSpecSuite({
    repoRoot,
    wasmPath: options.wasmPath === null ? null : resolveRepoPath(repoRoot, options.wasmPath),
    limit: options.limit,
    onlyFiles: options.onlyFiles,
  });
  process.stdout.write(`Executed wasm CLI spec command for ${result.selectedFileCount} file(s).\n`);
  process.exitCode = result.exitCode;
}

export async function main(argv: string[]): Promise<void> {
  const [subcommand, ...rest] = argv;
  switch (subcommand) {
    case "build":
      await runSelfOptBuild(rest);
      return;
    case "optimize":
      await runSelfOptOptimize(rest);
      return;
    case "spec":
      await runSelfOptSpec(rest);
      return;
    case "check":
      await runSelfOptCheck(rest);
      return;
    case "compare-artifact-optimizer":
      await runSelfOptArtifactOptimizerCompare(rest);
      return;
    default:
      fail("usage: bun self-opt <build|optimize|spec|check|compare-artifact-optimizer> [...]");
  }
}
