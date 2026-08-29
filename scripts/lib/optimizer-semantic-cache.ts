import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

export type SemanticCacheKeyInput = {
  original: Uint8Array;
  starshine: Uint8Array;
  binaryen: Uint8Array | null;
  seed: bigint;
  policy: string;
  mode: string;
  timeoutMs: number;
  memoryCapBytes: number;
  tableEntryCap: number;
  runtimeVersion: string;
};

type SemanticCacheEntry = {
  schema: "starshine.optimizer-semantic-cache-entry.v1";
  key: string;
  report: unknown;
};

function sha256(bytes: Uint8Array): string {
  return crypto.createHash("sha256").update(bytes).digest("hex");
}

export function buildSemanticCacheKey(input: SemanticCacheKeyInput): string {
  const identity = {
    schema: "starshine.optimizer-semantic-cache-key.v1",
    originalSha256: sha256(input.original),
    starshineSha256: sha256(input.starshine),
    binaryenSha256: input.binaryen === null ? null : sha256(input.binaryen),
    seed: `0x${input.seed.toString(16)}`,
    policy: input.policy,
    mode: input.mode,
    timeoutMs: input.timeoutMs,
    memoryCapBytes: input.memoryCapBytes,
    tableEntryCap: input.tableEntryCap,
    runtimeVersion: input.runtimeVersion,
  };
  return `sha256:${crypto.createHash("sha256").update(JSON.stringify(identity)).digest("hex")}`;
}

function entryPath(cacheRoot: string, key: string): string {
  const digest = key.startsWith("sha256:") ? key.slice("sha256:".length) : key;
  return path.join(cacheRoot, "semantic-v2", digest, "entry.json");
}

export function loadSemanticCacheEntry<Report>(cacheRoot: string, key: string): Report | null {
  const filePath = entryPath(cacheRoot, key);
  if (!fs.existsSync(filePath)) return null;
  try {
    const entry = JSON.parse(fs.readFileSync(filePath, "utf8")) as Partial<SemanticCacheEntry>;
    if (entry.schema !== "starshine.optimizer-semantic-cache-entry.v1" || entry.key !== key || entry.report === undefined) {
      return null;
    }
    return entry.report as Report;
  } catch {
    return null;
  }
}

export function storeSemanticCacheEntry(cacheRoot: string, key: string, report: unknown): void {
  const filePath = entryPath(cacheRoot, key);
  const directory = path.dirname(filePath);
  fs.mkdirSync(directory, { recursive: true });
  const temporary = path.join(directory, `.entry-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}.tmp`);
  const entry: SemanticCacheEntry = {
    schema: "starshine.optimizer-semantic-cache-entry.v1",
    key,
    report,
  };
  fs.writeFileSync(temporary, JSON.stringify(entry, null, 2) + "\n");
  try {
    fs.renameSync(temporary, filePath);
  } catch (error) {
    fs.rmSync(temporary, { force: true });
    if (!fs.existsSync(filePath)) throw error;
  }
}
