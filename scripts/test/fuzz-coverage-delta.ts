import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function run(args: string[], cwd: string): { stdout: string; status: number } {
  try {
    const stdout = execFileSync("bun", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    return { stdout, status: 0 };
  } catch (err) {
    const e = err as { stdout?: Buffer | string; status?: number };
    return { stdout: String(e.stdout ?? ""), status: e.status ?? 1 };
  }
}

export function runFuzzCoverageDeltaTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-fuzz-coverage-delta-"));
  const before = path.join(tmpdir, "before.json");
  const after = path.join(tmpdir, "after.json");
  fs.writeFileSync(before, JSON.stringify({
    schema: "starshine.fuzz.summary.v1",
    summary: {
      feature_counters: { required_gc: 3, required_simd: 2, optional_strings: 1 },
      strategy_outcomes: { required_invalid_ast: 4 },
      artifact_counts: { runs: 2, failures: 0 }
    }
  }));
  fs.writeFileSync(after, JSON.stringify({
    schema: "starshine.fuzz.summary.v1",
    summary: {
      feature_counters: { required_gc: 2, optional_strings: 0, optional_new: 7 },
      strategy_outcomes: { required_invalid_ast: 4 },
      artifact_counts: { runs: 2, failures: 1 }
    }
  }));

  const failed = run(["fuzz", "coverage-delta", before, after], repoRoot);
  assert(failed.status !== 0, "required coverage drop should fail");
  assert(failed.stdout.includes("required_gc: 3 -> 2 (-1)"), `missing required drop:\n${failed.stdout}`);
  assert(!failed.stdout.includes("optional_strings"), `optional drop should be tolerated by default:\n${failed.stdout}`);
  assert(failed.stdout.includes("failures: 0 -> 1 (+1)"), `artifact count should be reported:\n${failed.stdout}`);

  const afterOptionalOnly = path.join(tmpdir, "after-optional-only.json");
  fs.writeFileSync(afterOptionalOnly, JSON.stringify({
    schema: "starshine.fuzz.summary.v1",
    summary: {
      feature_counters: { required_gc: 3, required_simd: 2, optional_strings: 0, optional_new: 7 },
      strategy_outcomes: { required_invalid_ast: 4 },
      artifact_counts: { runs: 2, failures: 1 }
    }
  }));
  const passed = run(["fuzz", "coverage-delta", "--optional", before, afterOptionalOnly], repoRoot);
  assert(passed.status === 0, `optional diff should pass:\n${passed.stdout}`);
  assert(passed.stdout.includes("optional_strings: 1 -> 0 (-1)"), `optional diff should be visible with flag:\n${passed.stdout}`);
  assert(passed.stdout.includes("optional_new: 0 -> 7 (+7)"), `new optional counter should be visible:\n${passed.stdout}`);
}

if (import.meta.main) runFuzzCoverageDeltaTest();
