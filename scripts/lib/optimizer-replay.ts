import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import {
  classifyOptimizerDeterminism,
  runNodeSelfSemanticOracle,
  type SemanticComparisonPolicy,
} from "./optimizer-correctness";
import type { OptimizerFailureReplayResult } from "./optimizer-corpus";
import { runNodeThreeWaySemanticOracleV2 } from "./optimizer-runtime-executor";
import type { ObservationMode } from "./optimizer-runtime";
import {
  fingerprintMatches,
  semanticFingerprintFromRuntimeReport,
  type FingerprintMatchLevel,
  type SemanticFailureFingerprint,
} from "./optimizer-failure-fingerprint";

type ReplaySpecification = {
  inputPath: string;
  failureClass: string;
  passFlags: string[];
  semanticPolicy: SemanticComparisonPolicy;
  serialPasses: boolean;
  seed: bigint;
  observationMode: ObservationMode;
  observationMemoryCapBytes: number;
  observationTableEntryCap: number;
  runtimeTimeoutMs: number;
  expectedFingerprint: SemanticFailureFingerprint | null;
};

function parseSeed(value: unknown): bigint {
  if (typeof value === "bigint") return value;
  if (typeof value === "number" && Number.isSafeInteger(value)) return BigInt(value);
  if (typeof value === "string") {
    try {
      return BigInt(value);
    } catch {
      return 0x5eedn;
    }
  }
  return 0x5eedn;
}

function normalizePositiveInt(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0 ? value : fallback;
}

function normalizeObservationMode(value: unknown): ObservationMode {
  return value === "stateful" ? "stateful" : "independent";
}

function normalizePolicy(value: unknown): SemanticComparisonPolicy {
  return value === "strict" || value === "canonical-nan" || value === "trap-aware" ? value : "trap-aware";
}

function loadPersistedFingerprint(directory: string): SemanticFailureFingerprint | null {
  const fingerprintPath = path.join(directory, "semantic-fingerprint.json");
  if (!fs.existsSync(fingerprintPath)) return null;
  const value = JSON.parse(fs.readFileSync(fingerprintPath, "utf8")) as SemanticFailureFingerprint;
  return value.schema === "starshine.optimizer-semantic-fingerprint.v1" ? value : null;
}

function loadReplaySpecification(source: string): ReplaySpecification {
  const resolved = path.resolve(source);
  const directory = fs.statSync(resolved).isDirectory() ? resolved : path.dirname(resolved);
  const explicitFile = fs.statSync(resolved).isFile() ? resolved : null;
  const failureMetadataPath = explicitFile?.endsWith("failure-metadata.json")
    ? explicitFile
    : path.join(directory, "failure-metadata.json");
  if (fs.existsSync(failureMetadataPath)) {
    const metadata = JSON.parse(fs.readFileSync(failureMetadataPath, "utf8")) as {
      propertyFailureClass?: string;
      status?: string;
      replay?: { input?: string; passFlags?: string[] };
      propertyEvidence?: {
        semanticPolicy?: string;
        serialPasses?: boolean;
        observationMode?: string;
        observationMemoryCapBytes?: number;
        observationTableEntryCap?: number;
        runtimeTimeoutMs?: number;
      };
      genValidManifestEntry?: { seed?: unknown };
    };
    const failureClass = metadata.propertyFailureClass ??
      (metadata.status === "validation-failure" ? "validation-failure" : null);
    if (failureClass === null) throw new Error("replay metadata does not name an optimizer failure class");
    const input = metadata.replay?.input ?? "input.wasm";
    return {
      inputPath: path.resolve(directory, input),
      failureClass,
      passFlags: metadata.replay?.passFlags ?? [],
      semanticPolicy: normalizePolicy(metadata.propertyEvidence?.semanticPolicy),
      serialPasses: metadata.propertyEvidence?.serialPasses ?? false,
      seed: parseSeed(metadata.genValidManifestEntry?.seed),
      observationMode: normalizeObservationMode(metadata.propertyEvidence?.observationMode),
      observationMemoryCapBytes: normalizePositiveInt(metadata.propertyEvidence?.observationMemoryCapBytes, 1024 * 1024),
      observationTableEntryCap: normalizePositiveInt(metadata.propertyEvidence?.observationTableEntryCap, 1024),
      runtimeTimeoutMs: normalizePositiveInt(metadata.propertyEvidence?.runtimeTimeoutMs, 1000),
      expectedFingerprint: loadPersistedFingerprint(directory),
    };
  }

  const manifestPath = explicitFile?.endsWith("manifest.json") ? explicitFile : path.join(directory, "manifest.json");
  if (!fs.existsSync(manifestPath)) throw new Error(`missing replay metadata under ${directory}`);
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as {
    schema?: string;
    input?: { path?: string };
    origin?: { seed?: unknown };
    pipeline?: { passes?: string[]; mode?: string };
    property?: {
      kind?: string;
      semanticPolicy?: string | null;
      observationMode?: string;
      observationMemoryCapBytes?: number;
      observationTableEntryCap?: number;
      runtimeTimeoutMs?: number;
    };
    failure?: { class?: string };
    semanticEvidence?: { fingerprint?: { value?: unknown } };
  };
  if (manifest.schema !== "starshine.optimizer-case.v1" && manifest.schema !== "starshine.optimizer-case.v2") {
    throw new Error(`unsupported optimizer case schema ${manifest.schema}`);
  }
  const failureClass = manifest.failure?.class ?? manifest.property?.kind;
  if (!failureClass) throw new Error("optimizer case missing failure class");
  return {
    inputPath: path.resolve(directory, manifest.input?.path ?? "input.wasm"),
    failureClass,
    passFlags: (manifest.pipeline?.passes ?? []).map((name) => name.startsWith("--") ? name : `--${name}`),
    semanticPolicy: normalizePolicy(manifest.property?.semanticPolicy),
    serialPasses: manifest.pipeline?.mode === "serial",
    seed: parseSeed(manifest.origin?.seed),
    observationMode: normalizeObservationMode(manifest.property?.observationMode),
    observationMemoryCapBytes: normalizePositiveInt(manifest.property?.observationMemoryCapBytes, 1024 * 1024),
    observationTableEntryCap: normalizePositiveInt(manifest.property?.observationTableEntryCap, 1024),
    runtimeTimeoutMs: normalizePositiveInt(manifest.property?.runtimeTimeoutMs, 1000),
    expectedFingerprint: (manifest.semanticEvidence?.fingerprint?.value as SemanticFailureFingerprint | undefined) ?? loadPersistedFingerprint(directory),
  };
}

type StarshineCommand = { command: string; prefix: string[] };

function resolveStarshineCommand(starshineBin?: string, moonBin = "moon"): StarshineCommand {
  const explicit = starshineBin ?? process.env.STARSHINE_BIN;
  if (explicit) return { command: path.resolve(explicit), prefix: [] };
  const native = path.resolve("_build/native/release/build/cmd/cmd.exe");
  if (fs.existsSync(native)) return { command: native, prefix: [] };
  return { command: moonBin, prefix: ["run", "--target", "native", "--release", "src/cmd", "--"] };
}

function run(command: string, args: string[]): { ok: boolean; detail: string } {
  const result = spawnSync(command, args, { encoding: "utf8", maxBuffer: 128 * 1024 * 1024 });
  if (result.error) return { ok: false, detail: result.error.message };
  return { ok: result.status === 0, detail: result.stderr || result.stdout || `exit ${String(result.status)}` };
}

function runOptimizer(
  starshine: StarshineCommand,
  spec: ReplaySpecification,
  inputPath: string,
  outputPath: string,
  passes: string[] = spec.passFlags,
): { ok: boolean; detail: string } {
  return run(starshine.command, [
    ...starshine.prefix,
    ...(spec.serialPasses ? ["--debug-serial-passes"] : []),
    ...passes,
    "--out",
    outputPath,
    inputPath,
  ]);
}

function externalValidation(wasmToolsBin: string, wasmPath: string): boolean {
  return run(wasmToolsBin, ["validate", "--features", "all", wasmPath]).ok;
}

export async function replayOptimizerFailure(options: {
  source: string;
  inputOverride?: string;
  starshineBin?: string;
  moonBin?: string;
  wasmToolsBin?: string;
  fingerprintLevel?: FingerprintMatchLevel;
}): Promise<OptimizerFailureReplayResult> {
  const loaded = loadReplaySpecification(options.source);
  const spec = options.inputOverride === undefined
    ? loaded
    : { ...loaded, inputPath: path.resolve(options.inputOverride) };
  if (!fs.existsSync(spec.inputPath)) throw new Error(`missing optimizer replay input ${spec.inputPath}`);
  const starshine = resolveStarshineCommand(options.starshineBin, options.moonBin);
  const wasmToolsBin = options.wasmToolsBin ?? process.env.WASM_TOOLS_BIN ?? "wasm-tools";
  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-optimizer-replay-"));
  const optimizedPath = path.join(workDir, "optimized.wasm");
  try {
    const first = runOptimizer(starshine, spec, spec.inputPath, optimizedPath);
    if (!first.ok) {
      return {
        reproduced: spec.failureClass === "command-failure",
        failureClass: spec.failureClass === "command-failure" ? "command-failure" : null,
        detail: `optimizer command failed: ${first.detail}`,
      };
    }

    switch (spec.failureClass) {
      case "semantic-self": {
        const report = await runNodeSelfSemanticOracle(spec.inputPath, optimizedPath, {
          seed: spec.seed,
          policy: spec.semanticPolicy,
        });
        const reproduced = report.classification === "semantic-mismatch" || report.classification === "trap-mismatch";
        return {
          reproduced,
          failureClass: reproduced ? "semantic-self" : null,
          detail: `semantic:self ${report.classification}${report.firstDifference ? ` at ${report.firstDifference.path}` : ""}`,
        };
      }
      case "semantic-self-v2": {
        const report = await runNodeThreeWaySemanticOracleV2(
          spec.inputPath,
          optimizedPath,
          null,
          {
            seed: spec.seed,
            policy: spec.semanticPolicy,
            mode: spec.observationMode,
            timeoutMs: spec.runtimeTimeoutMs,
            memoryCapBytes: spec.observationMemoryCapBytes,
            tableEntryCap: spec.observationTableEntryCap,
            wasmToolsBin,
            starshineBin: starshine.command,
            starshineArgsPrefix: starshine.prefix,
            binaryenDiagnostic: "tool-failure",
          },
        );
        const semanticFailure = report.classification.primary === "starshine-semantic-mismatch"
          || report.classification.primary === "starshine-correctness-failure";
        const actualFingerprint = semanticFailure
          ? semanticFingerprintFromRuntimeReport(report, {
              passSequence: spec.expectedFingerprint?.passSequence ?? spec.passFlags.map((flag) => flag.replace(/^--/, "")),
              firstDivergentPassBoundary: spec.expectedFingerprint?.firstDivergentPassBoundary ?? null,
            })
          : null;
        const fingerprintLevel = options.fingerprintLevel ?? "exact";
        const fingerprintMatch = spec.expectedFingerprint === null
          ? semanticFailure
          : actualFingerprint !== null && fingerprintMatches(spec.expectedFingerprint, actualFingerprint, fingerprintLevel);
        const reproduced = semanticFailure && fingerprintMatch;
        return {
          reproduced,
          failureClass: reproduced ? "semantic-self-v2" : null,
          detail: `semantic:self-v2 ${report.classification.primary} pattern=${report.classification.pattern} difference=${report.originalVsStarshine.firstDifferencePath ?? "none"} fingerprint=${spec.expectedFingerprint === null ? "legacy-class-only" : fingerprintMatch ? `${fingerprintLevel}-match` : "mismatch"}`,
        };
      }
      case "validation-failure": {
        const reproduced = !externalValidation(wasmToolsBin, optimizedPath);
        return {
          reproduced,
          failureClass: reproduced ? "validation-failure" : null,
          detail: reproduced ? "optimized output remains externally invalid" : "optimized output validates",
        };
      }
      case "optimizer-nondeterminism": {
        const secondPath = path.join(workDir, "optimized-second.wasm");
        const second = runOptimizer(starshine, spec, spec.inputPath, secondPath);
        if (!second.ok) return { reproduced: false, failureClass: null, detail: `second optimizer command failed: ${second.detail}` };
        const classification = classifyOptimizerDeterminism(fs.readFileSync(optimizedPath), fs.readFileSync(secondPath));
        const reproduced = classification === "optimizer-nondeterminism";
        return { reproduced, failureClass: reproduced ? "optimizer-nondeterminism" : null, detail: classification };
      }
      case "codec-idempotence": {
        const oncePath = path.join(workDir, "codec-once.wasm");
        const twicePath = path.join(workDir, "codec-twice.wasm");
        const once = runOptimizer(starshine, spec, optimizedPath, oncePath, []);
        const twice = once.ok ? runOptimizer(starshine, spec, oncePath, twicePath, []) : once;
        if (!once.ok || !twice.ok) return { reproduced: false, failureClass: null, detail: `codec replay command failed: ${twice.detail}` };
        const reproduced = !fs.readFileSync(oncePath).equals(fs.readFileSync(twicePath));
        return { reproduced, failureClass: reproduced ? "codec-idempotence" : null, detail: reproduced ? "codec bytes changed" : "codec bytes stable" };
      }
      case "optimizer-idempotence": {
        const twicePath = path.join(workDir, "optimized-twice.wasm");
        const twice = runOptimizer(starshine, spec, optimizedPath, twicePath);
        if (!twice.ok) return { reproduced: false, failureClass: null, detail: `idempotence replay command failed: ${twice.detail}` };
        const reproduced = !fs.readFileSync(optimizedPath).equals(fs.readFileSync(twicePath));
        return { reproduced, failureClass: reproduced ? "optimizer-idempotence" : null, detail: reproduced ? "optimizer bytes changed" : "optimizer bytes stable" };
      }
      default:
        return { reproduced: false, failureClass: null, detail: `unsupported optimizer replay class ${spec.failureClass}` };
    }
  } finally {
    fs.rmSync(workDir, { recursive: true, force: true });
  }
}
