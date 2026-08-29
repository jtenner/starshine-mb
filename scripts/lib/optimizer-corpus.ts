import fs from "node:fs";
import path from "node:path";

export type OptimizerFailureReplayResult = {
  reproduced: boolean;
  failureClass: string | null;
  detail: string;
};

export type OptimizerPromotionVerificationContext = {
  failureDir: string;
  inputPath: string;
  metadata: OptimizerFailureMetadata;
  intendedFailureClass: string;
};

export type OptimizerPromotionResult = {
  casePath: string;
  caseId: string;
  duplicate: boolean;
  usedReducedArtifact: boolean;
};

type OptimizerFailureMetadata = {
  caseIndex: number;
  generator: string;
  status: string;
  detail: string;
  propertyFailureClass: string;
  genValidManifestEntry?: {
    seed?: string | number;
    config_label?: string;
    selected_profile?: string;
    attempts?: number;
    feature_facts?: unknown;
  } | null;
  reduction?: {
    reducedWasm?: string;
    predicateEvaluations?: number;
    steps?: unknown[];
  } | null;
  replay: {
    input: string;
    passFlags: string[];
  };
  propertyEvidence?: {
    semanticPolicy?: string;
    serialPasses?: boolean;
    observationMode?: "independent" | "stateful";
    observationMemoryCapBytes?: number;
    observationTableEntryCap?: number;
    runtimeTimeoutMs?: number;
    passReduction?: { passes?: string[]; predicateEvaluations?: number; steps?: unknown[] } | null;
    selfSemantic?: {
      plan?: unknown;
      before?: unknown;
      after?: unknown;
    } | null;
    semanticV2?: {
      report?: {
        runtimeInterface?: unknown;
        plan?: unknown;
        original?: unknown;
        starshine?: unknown;
        binaryen?: unknown;
        originalVsStarshine?: unknown;
        originalVsBinaryen?: unknown;
        starshineVsBinaryen?: unknown;
        classification?: unknown;
      };
      fingerprint?: { fingerprint?: unknown; hash?: string };
    } | null;
  } | null;
};

type OptimizerCorpusManifestV1 = {
  schema: "starshine.optimizer-case.v1";
  id: string;
  input: { path: "input.wasm"; hash: string; originalHash: string; usedReducedArtifact: boolean };
  origin: {
    generator: string;
    profile: string;
    seed: string;
    attempt: number;
    featureFacts: unknown;
    caseIndex: number;
    failureDirectory: string;
  };
  pipeline: { passes: string[]; originalPasses: string[]; mode: "serial" | "normal" };
  property: { kind: string; semanticPolicy: string | null };
  failure: { class: string; stage: string; detail: string; predicateHash: string };
  reduction: { used: boolean; predicateEvaluations: number | null; steps: unknown[] };
  invocationPlan: unknown | null;
  beforeObservation: unknown | null;
  afterObservation: unknown | null;
  replay: { command: string; manifest: "manifest.json" };
};

type OptimizerCorpusManifestV2 = {
  schema: "starshine.optimizer-case.v2";
  id: string;
  input: OptimizerCorpusManifestV1["input"];
  origin: OptimizerCorpusManifestV1["origin"];
  pipeline: OptimizerCorpusManifestV1["pipeline"];
  property: OptimizerCorpusManifestV1["property"] & {
    observationMode: "independent" | "stateful";
    observationMemoryCapBytes: number;
    observationTableEntryCap: number;
    runtimeTimeoutMs: number;
  };
  failure: OptimizerCorpusManifestV1["failure"];
  reduction: OptimizerCorpusManifestV1["reduction"];
  runtimeInterface: unknown;
  invocationPlan: unknown;
  observations: { original: unknown; starshine: unknown; binaryen: unknown };
  semanticComparisons: {
    originalVsStarshine: unknown;
    originalVsBinaryen: unknown;
    starshineVsBinaryen: unknown;
  };
  threeWayClassification: unknown;
  fingerprint: { value: unknown; hash: string | null };
  replay: OptimizerCorpusManifestV1["replay"];
};

type OptimizerCorpusManifest = OptimizerCorpusManifestV1 | OptimizerCorpusManifestV2;

function requireObject(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`malformed ${label}`);
  }
  return value as Record<string, unknown>;
}

function requireString(object: Record<string, unknown>, key: string): string {
  const value = object[key];
  if (typeof value !== "string" || value.length === 0) throw new Error(`missing ${key}`);
  return value;
}

function parseFailureMetadata(failureDir: string): OptimizerFailureMetadata {
  const metadataPath = path.join(failureDir, "failure-metadata.json");
  if (!fs.existsSync(metadataPath)) throw new Error(`missing failure-metadata.json in ${failureDir}`);
  let raw: unknown;
  try {
    raw = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
  } catch (error) {
    throw new Error(`malformed failure metadata: ${error instanceof Error ? error.message : String(error)}`);
  }
  const object = requireObject(raw, "failure metadata");
  const propertyFailureClass = requireString(object, "propertyFailureClass");
  const replayObject = requireObject(object.replay, "replay metadata");
  const replayInput = requireString(replayObject, "input");
  const passFlags = replayObject.passFlags;
  if (!Array.isArray(passFlags) || passFlags.some((flag) => typeof flag !== "string")) {
    throw new Error("malformed replay passFlags");
  }
  return {
    caseIndex: typeof object.caseIndex === "number" ? object.caseIndex : 0,
    generator: typeof object.generator === "string" ? object.generator : "unknown",
    status: typeof object.status === "string" ? object.status : "unknown",
    detail: typeof object.detail === "string" ? object.detail : "",
    propertyFailureClass,
    genValidManifestEntry:
      object.genValidManifestEntry !== null && typeof object.genValidManifestEntry === "object"
        ? (object.genValidManifestEntry as OptimizerFailureMetadata["genValidManifestEntry"])
        : null,
    reduction:
      object.reduction !== null && typeof object.reduction === "object"
        ? (object.reduction as OptimizerFailureMetadata["reduction"])
        : null,
    replay: { input: replayInput, passFlags: passFlags as string[] },
    propertyEvidence:
      object.propertyEvidence !== null && typeof object.propertyEvidence === "object"
        ? (object.propertyEvidence as OptimizerFailureMetadata["propertyEvidence"])
        : null,
  };
}

function fnv1a64(bytes: Uint8Array): string {
  let hash = 0xcbf29ce484222325n;
  for (const byte of bytes) {
    hash ^= BigInt(byte);
    hash = BigInt.asUintN(64, hash * 0x100000001b3n);
  }
  return `fnv1a64-${hash.toString(16).padStart(16, "0")}`;
}

function hashText(text: string): string {
  return fnv1a64(Buffer.from(text, "utf8"));
}

function stableValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value !== null && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      const child = (value as Record<string, unknown>)[key];
      if (child !== undefined) out[key] = stableValue(child);
    }
    return out;
  }
  if (typeof value === "bigint") return `bigint:${value.toString()}`;
  return value;
}

export function stableOptimizerCaseJson(value: unknown): string {
  return `${JSON.stringify(stableValue(value))}\n`;
}

function portableFailureDirectory(failureDir: string): string {
  return path.basename(path.resolve(failureDir));
}

function normalizedPasses(passFlags: string[]): string[] {
  return passFlags.map((flag) => flag.replace(/^--/, ""));
}

function loadExistingManifests(corpusRoot: string): { path: string; manifest: OptimizerCorpusManifest }[] {
  if (!fs.existsSync(corpusRoot)) return [];
  const entries: { path: string; manifest: OptimizerCorpusManifest }[] = [];
  for (const name of fs.readdirSync(corpusRoot).sort()) {
    const manifestPath = path.join(corpusRoot, name, "manifest.json");
    if (!fs.existsSync(manifestPath)) continue;
    try {
      const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as OptimizerCorpusManifest;
      if (manifest.schema === "starshine.optimizer-case.v1" || manifest.schema === "starshine.optimizer-case.v2") {
        entries.push({ path: path.dirname(manifestPath), manifest });
      }
    } catch {
      // Malformed existing entries are left for corpus lint; promotion does not overwrite them.
    }
  }
  return entries;
}

function writeIndex(corpusRoot: string): void {
  const cases = loadExistingManifests(corpusRoot).map((entry) => entry.manifest.id).sort();
  const index = { schema: "starshine.optimizer-corpus-index.v1", cases };
  fs.writeFileSync(path.join(corpusRoot, "index.json"), stableOptimizerCaseJson(index));
}

export async function promoteOptimizerFailure(options: {
  failureDir: string;
  corpusRoot: string;
  verifyFailure: (context: OptimizerPromotionVerificationContext) => Promise<OptimizerFailureReplayResult>;
}): Promise<OptimizerPromotionResult> {
  const failureDir = path.resolve(options.failureDir);
  const corpusRoot = path.resolve(options.corpusRoot);
  const metadata = parseFailureMetadata(failureDir);
  const originalPath = path.join(failureDir, metadata.replay.input);
  if (!fs.existsSync(originalPath)) throw new Error(`missing original replay artifact ${metadata.replay.input}`);

  const reducedRelative = metadata.reduction?.reducedWasm;
  const reducedPath = reducedRelative ? path.join(failureDir, reducedRelative) : null;
  const usedReducedArtifact = reducedPath !== null && fs.existsSync(reducedPath);
  const selectedPath = usedReducedArtifact ? reducedPath! : originalPath;
  const replay = await options.verifyFailure({
    failureDir,
    inputPath: selectedPath,
    metadata,
    intendedFailureClass: metadata.propertyFailureClass,
  });
  if (!replay.reproduced) throw new Error(`failure did not replay: ${replay.detail}`);
  if (replay.failureClass !== metadata.propertyFailureClass) {
    throw new Error(
      `wrong failure predicate: expected ${metadata.propertyFailureClass}, reproduced ${replay.failureClass ?? "none"}`,
    );
  }

  const selectedBytes = fs.readFileSync(selectedPath);
  const originalBytes = fs.readFileSync(originalPath);
  const inputHash = fnv1a64(selectedBytes);
  const predicateText = stableOptimizerCaseJson({
    failureClass: metadata.propertyFailureClass,
    passes: normalizedPasses(metadata.replay.passFlags),
    semanticPolicy: metadata.propertyEvidence?.semanticPolicy ?? null,
    serialPasses: metadata.propertyEvidence?.serialPasses ?? false,
    semanticFingerprintHash: metadata.propertyEvidence?.semanticV2?.fingerprint?.hash ?? null,
  });
  const predicateHash = hashText(predicateText);

  fs.mkdirSync(corpusRoot, { recursive: true });
  for (const existing of loadExistingManifests(corpusRoot)) {
    if (existing.manifest.input.hash === inputHash && existing.manifest.failure.predicateHash === predicateHash) {
      writeIndex(corpusRoot);
      return {
        casePath: existing.path,
        caseId: existing.manifest.id,
        duplicate: true,
        usedReducedArtifact,
      };
    }
  }

  const caseId = `${metadata.propertyFailureClass}-${inputHash.slice("fnv1a64-".length)}`;
  const casePath = path.join(corpusRoot, caseId);
  if (fs.existsSync(casePath)) throw new Error(`optimizer corpus identity collision at ${caseId}`);
  fs.mkdirSync(casePath, { recursive: true });
  fs.copyFileSync(selectedPath, path.join(casePath, "input.wasm"));

  const source = metadata.genValidManifestEntry;
  const selfSemantic = metadata.propertyEvidence?.selfSemantic;
  const semanticV2 = metadata.propertyEvidence?.semanticV2;
  const common = {
    id: caseId,
    input: {
      path: "input.wasm",
      hash: inputHash,
      originalHash: fnv1a64(originalBytes),
      usedReducedArtifact,
    },
    origin: {
      generator: metadata.generator,
      profile: source?.selected_profile ?? source?.config_label ?? "unknown",
      seed: String(source?.seed ?? "unknown"),
      attempt: source?.attempts ?? 0,
      featureFacts: source?.feature_facts ?? null,
      caseIndex: metadata.caseIndex,
      failureDirectory: portableFailureDirectory(failureDir),
    },
    pipeline: {
      passes: normalizedPasses(
        metadata.propertyEvidence?.passReduction?.passes ?? metadata.replay.passFlags,
      ),
      originalPasses: normalizedPasses(metadata.replay.passFlags),
      mode: metadata.propertyEvidence?.serialPasses ? "serial" : "normal",
    },
    property: {
      kind: metadata.propertyFailureClass,
      semanticPolicy: metadata.propertyEvidence?.semanticPolicy ?? null,
    },
    failure: {
      class: metadata.propertyFailureClass,
      stage: metadata.status,
      detail: metadata.detail,
      predicateHash,
    },
    reduction: {
      used: usedReducedArtifact,
      predicateEvaluations: metadata.reduction?.predicateEvaluations ?? null,
      steps: metadata.reduction?.steps ?? [],
    },
    replay: {
      command: `bun fuzz replay-optimizer ${caseId}`,
      manifest: "manifest.json" as const,
    },
  };
  const manifest: OptimizerCorpusManifest = metadata.propertyFailureClass === "semantic-self-v2" && semanticV2?.report
    ? {
        ...common,
        schema: "starshine.optimizer-case.v2",
        property: {
          ...common.property,
          observationMode: metadata.propertyEvidence?.observationMode ?? "independent",
          observationMemoryCapBytes: metadata.propertyEvidence?.observationMemoryCapBytes ?? 1024 * 1024,
          observationTableEntryCap: metadata.propertyEvidence?.observationTableEntryCap ?? 1024,
          runtimeTimeoutMs: metadata.propertyEvidence?.runtimeTimeoutMs ?? 1000,
        },
        runtimeInterface: semanticV2.report.runtimeInterface ?? null,
        invocationPlan: semanticV2.report.plan ?? null,
        observations: {
          original: semanticV2.report.original ?? null,
          starshine: semanticV2.report.starshine ?? null,
          binaryen: semanticV2.report.binaryen ?? null,
        },
        semanticComparisons: {
          originalVsStarshine: semanticV2.report.originalVsStarshine ?? null,
          originalVsBinaryen: semanticV2.report.originalVsBinaryen ?? null,
          starshineVsBinaryen: semanticV2.report.starshineVsBinaryen ?? null,
        },
        threeWayClassification: semanticV2.report.classification ?? null,
        fingerprint: {
          value: semanticV2.fingerprint?.fingerprint ?? null,
          hash: semanticV2.fingerprint?.hash ?? null,
        },
      }
    : {
        ...common,
        schema: "starshine.optimizer-case.v1",
        invocationPlan: selfSemantic?.plan ?? null,
        beforeObservation: selfSemantic?.before ?? null,
        afterObservation: selfSemantic?.after ?? null,
      };
  fs.writeFileSync(path.join(casePath, "manifest.json"), stableOptimizerCaseJson(manifest));
  writeIndex(corpusRoot);
  return { casePath, caseId, duplicate: false, usedReducedArtifact };
}
