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

  const compactBefore = path.join(tmpdir, "compact-before.json");
  const compactAfter = path.join(tmpdir, "compact-after.json");
  fs.writeFileSync(compactBefore, JSON.stringify({
    schema: "starshine.fuzz-summary-report.v1",
    summary: {
      features: { optional_gc: 1 },
      artifacts: { failure_dirs: 0 },
      failures: { mismatch: 0 },
      statuses: { match: 2 },
      timings: { wall_ms: 10 }
    }
  }));
  fs.writeFileSync(compactAfter, JSON.stringify({
    schema: "starshine.fuzz-summary-report.v1",
    summary: {
      features: { optional_gc: 0 },
      artifacts: { failure_dirs: 1 },
      failures: { mismatch: 1 },
      statuses: { match: 1 },
      timings: { wall_ms: 12 }
    }
  }));
  const compact = run(["fuzz", "coverage-delta", compactBefore, compactAfter], repoRoot);
  assert(compact.status === 0, `compact run-shape diff should not fail without required drops:\n${compact.stdout}`);
  assert(!compact.stdout.includes("optional_gc"), `compact optional feature should remain hidden by default:\n${compact.stdout}`);
  assert(compact.stdout.includes("failure_dirs: 0 -> 1 (+1)"), `compact artifact drift should be visible:\n${compact.stdout}`);
  assert(compact.stdout.includes("mismatch: 0 -> 1 (+1)"), `compact failure drift should be visible:\n${compact.stdout}`);
  assert(compact.stdout.includes("match: 2 -> 1 (-1)"), `compact status drift should be visible:\n${compact.stdout}`);
  assert(compact.stdout.includes("wall_ms: 10 -> 12 (+2)"), `compact timing drift should be visible:\n${compact.stdout}`);

  const genValidBefore = path.join(tmpdir, "gen-valid-smoke-before.json");
  const genValidAfter = path.join(tmpdir, "gen-valid-smoke-after.json");
  fs.writeFileSync(genValidBefore, JSON.stringify({
    schema: "starshine.fuzz-summary-report.v1",
    suite: "validate-valid",
    profile: "smoke",
    seed: "0x1048d",
    summary: {
      features: { required_modules: 128, required_imports: 4, required_ref_types: 6, required_v128: 3, optional_func_exports: 128 },
      strategies: { required_validate_valid: 128 },
      artifacts: { runs: 1 },
      failures: { validation: 0 },
      statuses: { "validate-valid": 1 },
      timings: { wall_ms: 25 }
    }
  }));
  fs.writeFileSync(genValidAfter, JSON.stringify({
    schema: "starshine.fuzz-summary-report.v1",
    suite: "validate-valid",
    profile: "smoke",
    seed: "0x1048d",
    summary: {
      features: { required_modules: 128, required_imports: 3, required_ref_types: 6, required_v128: 3, optional_func_exports: 127, optional_tables: 2 },
      strategies: { required_validate_valid: 128 },
      artifacts: { runs: 1 },
      failures: { validation: 0 },
      statuses: { "validate-valid": 1 },
      timings: { wall_ms: 27 }
    }
  }));
  const genValid = run(["fuzz", "coverage-delta", genValidBefore, genValidAfter], repoRoot);
  assert(genValid.status !== 0, `GenValid required smoke counter drop should fail:\n${genValid.stdout}`);
  assert(genValid.stdout.includes("required_imports: 4 -> 3 (-1)"), `missing GenValid required drop:\n${genValid.stdout}`);
  assert(!genValid.stdout.includes("optional_func_exports"), `GenValid optional drift should be tolerated by default:\n${genValid.stdout}`);
  assert(!genValid.stdout.includes("optional_tables"), `GenValid optional additions should be hidden by default:\n${genValid.stdout}`);
  assert(genValid.stdout.includes("wall_ms: 25 -> 27 (+2)"), `GenValid timing drift should remain visible:\n${genValid.stdout}`);
}

if (import.meta.main) runFuzzCoverageDeltaTest();
