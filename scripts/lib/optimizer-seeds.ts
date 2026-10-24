import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { runNodeSelfSemanticOracle } from "./optimizer-correctness";
import {
  runNodeThreeWaySemanticOracleV2,
  type NodeThreeWaySemanticOracleV2Report,
} from "./optimizer-runtime-executor";
import {
  sha256RuntimeValue,
  type ObservationMode,
  type RuntimeObservationV2,
} from "./optimizer-runtime";

export type OptimizerExternalReplay = {
  sha256: string;
  provenance: {
    url: string;
    artifact: string;
    artifactHash: string;
    license: string;
    licenseUrl: string;
    attribution: string;
  };
  observation: {
    entrypoint: string;
    expectedObservationHash: string;
    requiredFeatures: string[];
    requiredExports: string[];
    timeoutMs: number;
    memoryCapBytes: number;
    tableEntryCap: number;
    minimumStateChanges: number;
    requireTransform: boolean;
  };
};

export type OptimizerSeedEntry = {
  id: string;
  file: string;
  surfaces: string[];
  replay?: OptimizerExternalReplay;
};

export type OptimizerSeedCorpus = {
  schema: "starshine.optimizer-seed-corpus.v1" | "starshine.optimizer-seed-corpus.v2";
  root: string;
  seeds: OptimizerSeedEntry[];
};

export type OptimizerSeedRunOptions = {
  corpusRoot: string;
  passFlags: string[];
  selfSemantic: boolean;
  semanticOracle: "off" | "node-v2";
  observationMode: ObservationMode;
  serialPasses: boolean;
  starshineBin: string | undefined;
  moonBin: string;
  wasmToolsBin: string;
  seed: bigint;
};

function fail(message: string): never {
  throw new Error(message);
}

function requiredString(object: Record<string, unknown>, key: string, label: string): string {
  const value = object[key];
  if (typeof value !== "string" || value.length === 0) fail(`${label} missing ${key}`);
  return value;
}

function requiredStringArray(object: Record<string, unknown>, key: string, label: string): string[] {
  const value = object[key];
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== "string" || entry.length === 0)) {
    fail(`${label} has malformed ${key}`);
  }
  return value as string[];
}

function requiredInteger(
  object: Record<string, unknown>,
  key: string,
  label: string,
  minimum: number,
): number {
  const value = object[key];
  if (typeof value !== "number" || !Number.isInteger(value) || value < minimum) {
    fail(`${label} has malformed ${key}`);
  }
  return value;
}

function requiredObject(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) fail(`malformed ${label}`);
  return value as Record<string, unknown>;
}

function parseExternalReplay(
  entry: Record<string, unknown>,
  id: string,
  filePath: string,
): OptimizerExternalReplay {
  const replay = requiredObject(entry.replay, `optimizer seed ${id} replay`);
  const sha256 = requiredString(replay, "sha256", `optimizer seed ${id} replay`).toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(sha256)) fail(`optimizer seed ${id} has malformed sha256`);
  const actualSha256 = crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
  if (actualSha256 !== sha256) {
    fail(`optimizer seed ${id} artifact hash mismatch: expected ${sha256}, loaded ${actualSha256}`);
  }
  const provenanceObject = requiredObject(replay.provenance, `optimizer seed ${id} provenance`);
  const provenance = {
    url: requiredString(provenanceObject, "url", `optimizer seed ${id} provenance`),
    artifact: requiredString(provenanceObject, "artifact", `optimizer seed ${id} provenance`),
    artifactHash: requiredString(provenanceObject, "artifactHash", `optimizer seed ${id} provenance`),
    license: requiredString(provenanceObject, "license", `optimizer seed ${id} provenance`),
    licenseUrl: requiredString(provenanceObject, "licenseUrl", `optimizer seed ${id} provenance`),
    attribution: requiredString(provenanceObject, "attribution", `optimizer seed ${id} provenance`),
  };
  if (!/^https:\/\//.test(provenance.url)) fail(`optimizer seed ${id} provenance url must use https`);
  if (!/^https:\/\//.test(provenance.licenseUrl)) {
    fail(`optimizer seed ${id} provenance licenseUrl must use https`);
  }
  const observationObject = requiredObject(replay.observation, `optimizer seed ${id} observation`);
  const expectedObservationHash = requiredString(
    observationObject,
    "expectedObservationHash",
    `optimizer seed ${id} observation`,
  ).toLowerCase();
  if (!/^sha256:[0-9a-f]{64}$/.test(expectedObservationHash)) {
    fail(`optimizer seed ${id} has malformed expectedObservationHash`);
  }
  if (typeof observationObject.requireTransform !== "boolean") {
    fail(`optimizer seed ${id} observation has malformed requireTransform`);
  }
  return {
    sha256,
    provenance,
    observation: {
      entrypoint: requiredString(observationObject, "entrypoint", `optimizer seed ${id} observation`),
      expectedObservationHash,
      requiredFeatures: requiredStringArray(
        observationObject,
        "requiredFeatures",
        `optimizer seed ${id} observation`,
      ),
      requiredExports: requiredStringArray(
        observationObject,
        "requiredExports",
        `optimizer seed ${id} observation`,
      ),
      timeoutMs: requiredInteger(observationObject, "timeoutMs", `optimizer seed ${id} observation`, 1),
      memoryCapBytes: requiredInteger(
        observationObject,
        "memoryCapBytes",
        `optimizer seed ${id} observation`,
        1,
      ),
      tableEntryCap: requiredInteger(
        observationObject,
        "tableEntryCap",
        `optimizer seed ${id} observation`,
        1,
      ),
      minimumStateChanges: requiredInteger(
        observationObject,
        "minimumStateChanges",
        `optimizer seed ${id} observation`,
        0,
      ),
      requireTransform: observationObject.requireTransform,
    },
  };
}

export function loadOptimizerSeedCorpus(root: string): OptimizerSeedCorpus {
  const resolved = path.resolve(root);
  const manifestPath = path.join(resolved, "manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as {
    schema?: string;
    seeds?: unknown[];
  };
  if (
    manifest.schema !== "starshine.optimizer-seed-corpus.v1" &&
    manifest.schema !== "starshine.optimizer-seed-corpus.v2"
  ) {
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
    const replay = manifest.schema === "starshine.optimizer-seed-corpus.v2"
      ? parseExternalReplay(entry, entry.id, filePath)
      : undefined;
    seeds.push({ id: entry.id, file: entry.file, surfaces: entry.surfaces as string[], replay });
  }
  return { schema: manifest.schema, root: resolved, seeds };
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
  let semanticOracle: "off" | "node-v2" = "off";
  let observationMode: ObservationMode = "independent";
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
      case "--semantic-oracle": {
        const value = argv[index + 1] ?? fail("missing value for --semantic-oracle");
        if (value !== "off" && value !== "node-v2") fail(`unsupported optimizer-seeds semantic oracle ${value}`);
        semanticOracle = value;
        index += 2;
        break;
      }
      case "--observation-mode": {
        const value = argv[index + 1] ?? fail("missing value for --observation-mode");
        if (value !== "independent" && value !== "stateful") fail(`unsupported optimizer-seeds observation mode ${value}`);
        observationMode = value;
        index += 2;
        break;
      }
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
  return { corpusRoot, passFlags, selfSemantic, semanticOracle, observationMode, serialPasses, starshineBin, moonBin, wasmToolsBin, seed };
}

function commandResult(command: string, args: string[]): { ok: boolean; detail: string } {
  const result = spawnSync(command, args, { encoding: "utf8", maxBuffer: 128 * 1024 * 1024 });
  if (result.error) return { ok: false, detail: result.error.message };
  return { ok: result.status === 0, detail: result.stderr || result.stdout || `exit ${String(result.status)}` };
}

function sha256File(filePath: string): string {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

export function checkExternalReplayEvidence(
  replay: OptimizerExternalReplay,
  report: Pick<NodeThreeWaySemanticOracleV2Report, "runtimeInterface" | "plan" | "original">,
  transformed: boolean,
): { status: "passed" | "blocked" | "failed"; detail: string } {
  const contract = replay.observation;
  if (contract.requireTransform && !transformed) {
    return { status: "failed", detail: "external replay optimizer output is byte-identical" };
  }
  const actualFeatures = new Set(report.runtimeInterface.features);
  const missingFeature = contract.requiredFeatures.find((feature) => !actualFeatures.has(feature));
  if (missingFeature !== undefined) {
    return { status: "failed", detail: `external replay missing required feature ${missingFeature}` };
  }
  const actualExports = new Set(report.runtimeInterface.exports.map((entry) => entry.name));
  const missingExport = contract.requiredExports.find((name) => !actualExports.has(name));
  if (missingExport !== undefined) {
    return { status: "failed", detail: `external replay missing required export ${missingExport}` };
  }
  if (!report.plan.steps.some((step) => step.exportName === contract.entrypoint)) {
    return { status: "failed", detail: `external replay entrypoint ${contract.entrypoint} is unavailable` };
  }
  if (report.original.completeness !== "complete" || report.original.blockedReasons.length > 0) {
    return {
      status: "blocked",
      detail: `external replay original observation incomplete: ${report.original.blockedReasons.join(",")}`,
    };
  }
  const observationHash = externalReplayObservationHash(report.original);
  if (observationHash !== contract.expectedObservationHash) {
    return {
      status: "failed",
      detail: `external replay observation mismatch: expected ${contract.expectedObservationHash}, loaded ${observationHash}`,
    };
  }
  const stateChanges = report.original.steps.reduce((sum, step) => sum + step.stateDelta.length, 0);
  if (stateChanges < contract.minimumStateChanges) {
    return {
      status: "failed",
      detail: `external replay silently did insufficient work: ${stateChanges} state changes, expected at least ${contract.minimumStateChanges}`,
    };
  }
  return {
    status: "passed",
    detail: `replay observation ${observationHash}, state changes ${stateChanges}`,
  };
}

export function externalReplayObservationHash(observation: RuntimeObservationV2): string {
  const { identity: _runtimeIdentity, ...runtimeContract } = observation.runtime;
  return sha256RuntimeValue({ ...observation, runtime: runtimeContract });
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
      const replay = seed.replay;
      let replayDetail = "";
      if (options.semanticOracle === "node-v2" || replay !== undefined) {
        const contract = replay?.observation;
        const report = await runNodeThreeWaySemanticOracleV2(
          inputPath,
          outputPath,
          null,
          {
            seed: options.seed + BigInt(index),
            policy: "trap-aware",
            mode: options.observationMode,
            timeoutMs: contract?.timeoutMs ?? 1000,
            memoryCapBytes: contract?.memoryCapBytes ?? 1024 * 1024,
            tableEntryCap: contract?.tableEntryCap ?? 1024,
            wasmToolsBin: options.wasmToolsBin,
            starshineBin: starshine.command,
            starshineArgsPrefix: starshine.prefix,
            maxPairwise: contract === undefined ? undefined : 0,
            includedExports: contract === undefined ? undefined : [contract.entrypoint],
            binaryenDiagnostic: "tool-failure",
          },
        );
        if (contract !== undefined) {
          const checked = checkExternalReplayEvidence(
            replay!,
            report,
            sha256File(inputPath) !== sha256File(outputPath),
          );
          if (checked.status !== "passed") {
            cases.push({ id: seed.id, status: checked.status, detail: checked.detail });
            continue;
          }
          replayDetail = `; ${checked.detail}`;
        }
        if (report.classification.primary === "starshine-semantic-mismatch" || report.classification.primary === "starshine-correctness-failure") {
          cases.push({ id: seed.id, status: "failed", detail: `semantic:v2 ${report.classification.primary} ${report.classification.pattern}` });
          continue;
        }
        if (
          report.classification.primary === "blocked-original-runtime" ||
          report.classification.primary === "blocked-starshine-runtime"
        ) {
          cases.push({ id: seed.id, status: "blocked", detail: `semantic:v2 ${report.classification.pattern}` });
          continue;
        }
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
      cases.push({ id: seed.id, status: "passed", detail: `valid optimized output${replayDetail}` });
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
