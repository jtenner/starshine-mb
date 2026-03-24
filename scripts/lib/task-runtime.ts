import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { spawn, spawnSync } from "node:child_process";

const VALID_TARGETS = new Set(["native", "wasm", "wasm-gc", "llvm", "js"]);

export function fail(message: string): never {
  throw new Error(message);
}

// Walk up from a start path until we find the repo root (`moon.mod.json`), so
// scripts can run from nested directories and still operate repo-wide.
export function resolveWorkspaceRoot(start = process.cwd()): string {
  let current = path.resolve(start);
  while (true) {
    if (fs.existsSync(path.join(current, "moon.mod.json"))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      return path.resolve(start);
    }
    current = parent;
  }
}

export function resolveMoonBin(): string {
  return process.env.MOON_BIN || "moon";
}

export function assertTarget(target: string): void {
  if (!VALID_TARGETS.has(target)) {
    fail(`invalid target: ${target}. expected one of: ${Array.from(VALID_TARGETS).join(", ")}`);
  }
}

export function resolveRepoPath(repoRoot: string, candidate: string): string {
  return path.isAbsolute(candidate) ? candidate : path.join(repoRoot, candidate);
}

export function runOrThrow(
  command: string,
  args: string[],
  {
    cwd = process.cwd(),
    env = process.env,
    stdio = "inherit",
    maxBuffer = 128 * 1024 * 1024,
  }: {
    cwd?: string;
    env?: NodeJS.ProcessEnv;
    stdio?: "inherit" | "pipe";
    maxBuffer?: number;
  } = {},
): { stdout: string; stderr: string } {
  const result = spawnSync(command, args, {
    cwd,
    env,
    stdio,
    encoding: "utf8",
    maxBuffer,
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    const stderr = result.stderr?.trim();
    const suffix = stderr ? `\n${stderr}` : "";
    fail(`command failed: ${command} ${args.join(" ")}${suffix}`);
  }
  return {
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? "",
  };
}

// Execute a command while mirroring stdout/stderr live and teeing both streams into
// a persistent log file for later postmortem when failures happen.
export async function teeCommandToFile(
  command: string,
  args: string[],
  logPath: string,
  {
    cwd = process.cwd(),
    env = process.env,
  }: {
    cwd?: string;
    env?: NodeJS.ProcessEnv;
  } = {},
): Promise<void> {
  fs.rmSync(logPath, { force: true });
  const child = spawn(command, args, {
    cwd,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });

  const log = fs.createWriteStream(logPath, { flags: "a" });

  function forward(stream: NodeJS.ReadableStream | null, writer: NodeJS.WriteStream) {
    if (!stream) {
      return;
    }
    stream.setEncoding("utf8");
    stream.on("data", (chunk: string) => {
      writer.write(chunk);
      log.write(chunk);
    });
  }

  forward(child.stdout, process.stdout);
  forward(child.stderr, process.stderr);

  await new Promise<void>((resolve, reject) => {
    child.on("error", reject);
    child.on("close", (code) => {
      log.end();
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`command failed: ${command} ${args.join(" ")} (exit ${code ?? "unknown"})`));
    });
  });
}
