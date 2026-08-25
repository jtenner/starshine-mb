import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { runNodeSelfSemanticOracle } from "./optimizer-correctness";

export type OptimizerSeedEntry = {
  id: string;
  file: string;
  surfaces: string[];
};

export type OptimizerSeedCorpus = {
  schema: "starshine.optimizer-seed-corpus.v1";
  root: string;
  seeds: OptimizerSeedEntry[];
};

export type OptimizerSeedRunOptions = {
  corpusRoot: string;
  passFlags: string[];
  selfSemantic: boolean;
  serialPasses: boolean;
  starshineBin: string | undefined;
  moonBin: string;
  wasmToolsBin: string;
  seed: bigint;
};

function fail(message: string): never {
  throw new Error(message);
}

export function loadOptimizerSeedCorpus(root: string): OptimizerSeedCorpus {
  const resolved = path.resolve(root);
  const manifestPath = path.join(resolved, "manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as {
    schema?: string;
    seeds?: unknown[];
  };
  if (manifest.schema !== "starshine.optimizer-seed-corpus.v1") {
    fail(`unsupported optimizer seed schema ${manifest.schema ?? "missing"}`);
  }
  if (!Array.isArray(manifest.seeds)) fail("optimizer seed manifest is missing seeds");
  const seen = new Set<string>();
  const seeds: OptimizerSeedEntry[] = [];
  for (const raw of manifest.seeds) {
    if (raw === null || typeof raw !== "object") fail("malformed optimizer seed entry");
    const entry = raw as Record<string, unknown>;
    if (typeof entry.id !== "string" || entry.id.length === 0) fail("optimizer seed entry missing id");
    if (seen.has(entry.id)) fail(`duplicate optimizer seed id ${entry.id}`);
    if (typeof entry.file !== "string" || entry.file.length === 0) fail(`optimizer seed ${entry.id} missing file`);
    if (!Array.isArray(entry.surfaces) || entry.surfaces.some((surface) => typeof surface !== "string")) {
      fail(`optimizer seed ${entry.id} has malformed surfaces`);
    }
    const filePath = path.resolve(resolved, entry.file);
    if (!filePath.startsWith(`${resolved}${path.sep}`) || !fs.existsSync(filePath)) {
      fail(`optimizer seed ${entry.id} is missing ${entry.file}`);
    }
    seen.add(entry.id);
    seeds.push({ id: entry.id, file: entry.file, surfaces: entry.surfaces as string[] });
  }
  return { schema: "starshine.optimizer-seed-corpus.v1", root: resolved, seeds };
}

function parseSeed(raw: string): bigint {
  try {
    return BigInt(raw);
  } catch {
    fail(`invalid optimizer seed root ${raw}`);
  }
}

export function parseOptimizerSeedRunArgs(argv: string[]): OptimizerSeedRunOptions {
  let corpusRoot = "tests/optimizer/seeds";
  const passFlags: string[] = [];
  let selfSemantic = false;
  let serialPasses = false;
  let starshineBin: string | undefined;
  let moonBin = "moon";
  let wasmToolsBin = "wasm-tools";
  let seed = 0x5eedn;
  for (let index = 0; index < argv.length; ) {
    const token = argv[index];
    switch (token) {
      case "--corpus-root":
        corpusRoot = argv[index + 1] ?? fail("missing value for --corpus-root");
        index += 2;
        break;
      case "--pass": {
        const name = argv[index + 1] ?? fail("missing value for --pass");
        passFlags.push(name.startsWith("--") ? name : `--${name}`);
        index += 2;
        break;
      }
      case "--self-semantic":
        selfSemantic = true;
        index += 1;
        break;
      case "--debug-serial-passes":
        serialPasses = true;
        index += 1;
        break;
      case "--starshine-bin":
        starshineBin = argv[index + 1] ?? fail("missing value for --starshine-bin");
        index += 2;
        break;
      case "--moon":
        moonBin = argv[index + 1] ?? fail("missing value for --moon");
        index += 2;
        break;
      case "--wasm-tools-bin":
        wasmToolsBin = argv[index + 1] ?? fail("missing value for --wasm-tools-bin");
        index += 2;
        break;
      case "--seed":
        seed = parseSeed(argv[index + 1] ?? fail("missing value for --seed"));
        index += 2;
        break;
      default:
        fail(`unknown optimizer-seeds option ${token}`);
    }
  }
  return { corpusRoot, passFlags, selfSemantic, serialPasses, starshineBin, moonBin, wasmToolsBin, seed };
}

function commandResult(command: string, args: string[]): { ok: boolean; detail: string } {
  const result = spawnSync(command, args, { encoding: "utf8", maxBuffer: 128 * 1024 * 1024 });
  if (result.error) return { ok: false, detail: result.error.message };
  return { ok: result.status === 0, detail: result.stderr || result.stdout || `exit ${String(result.status)}` };
}

function starshineCommand(options: OptimizerSeedRunOptions): { command: string; prefix: string[] } {
  const explicit = options.starshineBin ?? process.env.STARSHINE_BIN;
  if (explicit) return { command: path.resolve(explicit), prefix: [] };
  const native = path.resolve("_build/native/release/build/cmd/cmd.exe");
  if (fs.existsSync(native)) return { command: native, prefix: [] };
  return { command: options.moonBin, prefix: ["run", "--target", "native", "--release", "src/cmd", "--"] };
}

export async function runOptimizerSeedCorpus(options: OptimizerSeedRunOptions): Promise<{
  schema: "starshine.optimizer-seed-run.v1";
  total: number;
  passed: number;
  blocked: number;
  failed: number;
  cases: { id: string; status: "passed" | "blocked" | "failed"; detail: string }[];
}> {
  const corpus = loadOptimizerSeedCorpus(options.corpusRoot);
  const starshine = starshineCommand(options);
  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-optimizer-seeds-"));
  const cases: { id: string; status: "passed" | "blocked" | "failed"; detail: string }[] = [];
  try {
    for (let index = 0; index < corpus.seeds.length; index += 1) {
      const seed = corpus.seeds[index];
      const inputPath = path.join(workDir, `${seed.id}.wasm`);
      const outputPath = path.join(workDir, `${seed.id}.optimized.wasm`);
      const parsed = commandResult(options.wasmToolsBin, ["parse", path.join(corpus.root, seed.file), "-o", inputPath]);
      if (!parsed.ok) {
        cases.push({ id: seed.id, status: "failed", detail: `parse failed: ${parsed.detail}` });
        continue;
      }
      const optimized = commandResult(starshine.command, [
        ...starshine.prefix,
        ...(options.serialPasses ? ["--debug-serial-passes"] : []),
        ...options.passFlags,
        "--out",
        outputPath,
        inputPath,
      ]);
      if (!optimized.ok) {
        cases.push({ id: seed.id, status: "failed", detail: `optimize failed: ${optimized.detail}` });
        continue;
      }
      const validated = commandResult(options.wasmToolsBin, ["validate", "--features", "all", outputPath]);
      if (!validated.ok) {
        cases.push({ id: seed.id, status: "failed", detail: `validation failed: ${validated.detail}` });
        continue;
      }
      if (options.selfSemantic) {
        const report = await runNodeSelfSemanticOracle(inputPath, outputPath, {
          seed: options.seed + BigInt(index),
          policy: "trap-aware",
          runtimeTimeoutMs: 1000,
        });
        if (report.classification === "semantic-mismatch" || report.classification === "trap-mismatch") {
          cases.push({ id: seed.id, status: "failed", detail: `semantic:self ${report.classification}` });
          continue;
        }
        if (report.classification !== "equal-result" && report.classification !== "equal-trap") {
          cases.push({ id: seed.id, status: "blocked", detail: `semantic:self ${report.classification}` });
          continue;
        }
      }
      cases.push({ id: seed.id, status: "passed", detail: "valid optimized output" });
    }
  } finally {
    fs.rmSync(workDir, { recursive: true, force: true });
  }
  return {
    schema: "starshine.optimizer-seed-run.v1",
    total: cases.length,
    passed: cases.filter((entry) => entry.status === "passed").length,
    blocked: cases.filter((entry) => entry.status === "blocked").length,
    failed: cases.filter((entry) => entry.status === "failed").length,
    cases,
  };
}
