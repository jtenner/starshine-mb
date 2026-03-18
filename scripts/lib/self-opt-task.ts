import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import { buildSelfOptimized } from "./build-self-optimized.mjs";
import { runSelfOptimizedSpecSuite } from "./run-self-optimized-spec-suite.mjs";
import { fail, resolveMoonBin, resolveRepoPath, resolveWorkspaceRoot, runOrThrow, teeCommandToFile } from "./task-runtime";

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

export function parseSelfOptSpecArgs(argv: string[]): { limit: number | null; onlyFiles: string[]; wasmPath: string | null } {
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

export async function runSelfOptBuild(argv: string[]): Promise<void> {
  const repoRoot = resolveWorkspaceRoot();
  const options = parseSelfOptBuildArgs(argv);
  await buildSelfOptimized({
    repoRoot,
    moonBin: options.moonBin,
    fallbackDebugOnFailure: options.fallbackDebugOnFailure,
  });
}

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
}

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
    default:
      fail("usage: bun self-opt <build|optimize|spec> [...]");
  }
}
