import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function fail(message: string): never {
  throw new Error(message);
}

function assert(condition: boolean, message: string): void {
  if (!condition) fail(message);
}

function makeExecutable(basePath: string, source: string): string {
  fs.writeFileSync(basePath, `#!/usr/bin/env node\n${source}`);
  fs.chmodSync(basePath, 0o755);
  return basePath;
}

export function runPassFuzzComparePrebuiltGenValidCommandTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-prebuilt-gen-valid-"));
  const outDir = path.join(tmpdir, "out");
  const generatorLog = path.join(tmpdir, "generator.json");
  const moonMarker = path.join(tmpdir, "moon-ran");
  const fakeGenerator = makeExecutable(path.join(tmpdir, "fake-fuzz"), `
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
fs.writeFileSync(process.env.GENERATOR_LOG, JSON.stringify(args));
const outDir = args[args.indexOf("--out-dir") + 1];
const manifest = args[args.indexOf("--manifest") + 1];
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, "gen-valid-000001.wasm"), "input");
fs.writeFileSync(manifest, JSON.stringify({ records: [{ file_name: "gen-valid-000001.wasm" }] }));
`);
  const fakeMoon = makeExecutable(path.join(tmpdir, "fake-moon"), `
const fs = require("node:fs"); fs.writeFileSync(process.env.MOON_MARKER, "ran"); process.exit(99);
`);
  const fakeStarshine = makeExecutable(path.join(tmpdir, "fake-starshine"), `
const fs = require("node:fs"); const path = require("node:path"); const args = process.argv.slice(2);
const out = args[args.indexOf("--out") + 1]; fs.mkdirSync(path.dirname(out), { recursive: true }); fs.writeFileSync(out, "output");
`);
  const fakeWasmOpt = makeExecutable(path.join(tmpdir, "fake-wasm-opt"), `
const fs = require("node:fs"); const path = require("node:path"); const args = process.argv.slice(2);
if (args.includes("--version")) { console.log("wasm-opt version 132 (version_132)"); process.exit(0); }
if (!args.includes("-o")) {
  if (process.env.PRIMARY_VALIDATOR_LOG) fs.appendFileSync(process.env.PRIMARY_VALIDATOR_LOG, JSON.stringify(args) + "\\n");
  process.exit(process.env.PRIMARY_VALIDATOR_REJECT === "1" ? 1 : 0);
}
const out = args[args.indexOf("-o") + 1]; fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, args.includes("-S") ? "(module)\\n" : "output");
`);
  const fakeWasmTools = makeExecutable(path.join(tmpdir, "fake-wasm-tools"), `
if (process.env.PRIMARY_VALIDATOR_LOG && process.argv.includes("validate")) process.exit(97);
process.exit(0);
`);

  const result = spawnSync("bun", [
    path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
    "--count", "1",
    "--seed", "0x5eed",
    "--out-dir", outDir,
    "--moon", fakeMoon,
    "--gen-valid-bin", fakeGenerator,
    "--starshine-bin", fakeStarshine,
    "--wasm-opt-bin", fakeWasmOpt,
    "--require-binaryen-version", "132",
    "--wasm-tools-bin", fakeWasmTools,
    "--no-reduce-mismatches",
    "--pass", "vacuum",
  ], {
    cwd: repoRoot,
    env: { ...process.env, GENERATOR_LOG: generatorLog, MOON_MARKER: moonMarker },
    encoding: "utf8",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) fail(`prebuilt GenValid command failed:\n${result.stderr}`);
  assert(!fs.existsSync(moonMarker), "expected prebuilt generator to bypass moon");
  const generatorArgs = JSON.parse(fs.readFileSync(generatorLog, "utf8")) as string[];
  assert(generatorArgs[0] === "--emit-gen-valid-batch", `unexpected generator args ${JSON.stringify(generatorArgs)}`);
  const summary = JSON.parse(fs.readFileSync(path.join(outDir, "result.json"), "utf8")) as {
    genValidBin: string | null;
    comparedCount: number;
  };
  assert(summary.genValidBin === fakeGenerator, `unexpected generator identity ${summary.genValidBin}`);
  assert(summary.comparedCount === 1, `expected one comparison, got ${summary.comparedCount}`);
  const primaryLog = path.join(tmpdir, "primary-validator.jsonl");
  for (const reject of [false, true]) {
    const primaryOut = path.join(tmpdir, reject ? "invalid-primary" : "binaryen-primary");
    const primary = spawnSync("bun", [
      path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
      "--count", "1", "--min-compared", "1", "--out-dir", primaryOut,
      "--moon", fakeMoon, "--gen-valid-bin", fakeGenerator,
      "--starshine-bin", fakeStarshine, "--wasm-opt-bin", fakeWasmOpt,
      "--wasm-tools-bin", fakeWasmTools, "--primary-validator", "binaryen",
      "--pass", "vacuum", "--no-cache", "--no-reduce-mismatches",
    ], {
      cwd: repoRoot,
      env: { ...process.env, GENERATOR_LOG: generatorLog, MOON_MARKER: moonMarker,
        PRIMARY_VALIDATOR_LOG: primaryLog, PRIMARY_VALIDATOR_REJECT: reject ? "1" : "0" },
      encoding: "utf8",
    });
    const report = JSON.parse(fs.readFileSync(path.join(primaryOut, "result.json"), "utf8"));
    const toolchain = JSON.parse(fs.readFileSync(path.join(primaryOut, "toolchain.json"), "utf8"));
    assert(report.primaryValidator === "binaryen" && toolchain.primaryValidator === "binaryen", "primary oracle must be recorded");
    if (reject) {
      // Intentionally invalid input: validator rejection must not count as a comparison.
      assert(primary.status !== 0 && report.generatorFailureCount === 1 && report.comparedCount === 0, "primary validation failure must remain visible");
    } else {
      assert(primary.status === 0 && report.comparedCount === 1, `explicit primary validator failed: ${primary.stderr}`);
      const calls = fs.readFileSync(primaryLog, "utf8").trim().split("\n").map((line) => JSON.parse(line));
      assert(calls.length >= 2 && calls.every((args) => args.includes("--all-features")), "primary validator must check input and optimized output with proposal features");
      assert(primary.stdout.includes("not independent validation"), "primary oracle caveat must be visible");
    }
  }
  const changedValidator = spawnSync("bun", [
    path.join(repoRoot, "scripts", "pass-fuzz-compare.ts"),
    "--count", "1", "--out-dir", path.join(tmpdir, "binaryen-primary"), "--resume",
    "--moon", fakeMoon, "--gen-valid-bin", fakeGenerator, "--starshine-bin", fakeStarshine,
    "--wasm-opt-bin", fakeWasmOpt, "--wasm-tools-bin", fakeWasmTools,
    "--primary-validator", "wasm-tools", "--pass", "vacuum",
  ], { cwd: repoRoot, encoding: "utf8" });
  assert(changedValidator.status !== 0 && changedValidator.stderr.includes("primary validator differs"), "resume must reject a changed primary validation oracle");
  fs.rmSync(tmpdir, { recursive: true, force: true });

}

if (import.meta.main) {
  runPassFuzzComparePrebuiltGenValidCommandTest();
}
