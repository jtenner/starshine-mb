import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function fail(message: string): never {
  throw new Error(message);
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    fail(message);
  }
}

function makeExecutable(basePath: string, source: string): string {
  if (process.platform === "win32") {
    const scriptPath = `${basePath}.js`;
    fs.writeFileSync(scriptPath, source);
    const cmdPath = `${basePath}.cmd`;
    fs.writeFileSync(cmdPath, `@echo off\r\nnode "%~dp0\\${path.basename(scriptPath)}" %*\r\n`);
    return cmdPath;
  }

  fs.writeFileSync(basePath, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(basePath, 0o755);
  return basePath;
}

export function runSelfOptCommandOutputTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-self-opt-test-"));
  fs.mkdirSync(path.join(tmpdir, "bin"), { recursive: true });
  fs.mkdirSync(path.join(tmpdir, "_build", "native", "release", "build", "cmd"), { recursive: true });

  const fakeMoon = makeExecutable(
    path.join(tmpdir, "bin", "moon"),
    `
process.exit(0);
`,
  );

  makeExecutable(
    path.join(tmpdir, "_build", "native", "release", "build", "cmd", "cmd.exe"),
    `
if (!process.argv.slice(2).includes("--debug-serial-passes")) {
  process.stderr.write("expected --debug-serial-passes in args, got: " + process.argv.slice(2).join(" ") + "\\n");
  process.exit(1);
}
process.stdout.write("optimizer trace\\n");
process.stderr.write("repro: starshine --dead-code-elimination --vacuum before.wasm\\n");
`,
  );

  const outputLog = path.join(tmpdir, "output.log");
  const result = spawnSync(
    "bun",
    [path.join(repoRoot, "scripts", "self-opt.ts"), "optimize"],
    {
      cwd: tmpdir,
      env: {
        ...process.env,
        MOON_BIN: fakeMoon,
        SELF_OPT_OUTPUT_LOG: outputLog,
      },
      encoding: "utf8",
    },
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    fail(`self-opt command failed:\n${result.stderr}`);
  }
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;

  assert(output.includes("repro: starshine --dead-code-elimination --vacuum before.wasm"), `expected terminal output to include repro command, got:\n${output}`);
  assert(fs.existsSync(outputLog), "expected output log to be written");
  const logOutput = fs.readFileSync(outputLog, "utf8");
  assert(logOutput.includes("repro: starshine --dead-code-elimination --vacuum before.wasm"), `expected log output to include repro command, got:\n${logOutput}`);
}

if (import.meta.main) {
  runSelfOptCommandOutputTest();
}
