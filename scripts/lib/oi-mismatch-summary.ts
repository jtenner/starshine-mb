import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

export type OiMismatchGroup = {
  selectedProfile: string;
  caseLabel: string;
  diffSignature: string;
  count: number;
  representativeCaseIndex: number;
  representativeFailureDir: string;
  removedPreview: string[];
  addedPreview: string[];
};

export type OiMismatchRunSummary = {
  runDir: string;
  requestedCount: number | null;
  comparedCount: number | null;
  normalizedMatchCount: number | null;
  resultMismatchCount: number | null;
  mismatchRecords: number;
  missingFailureArtifacts: number[];
  groups: OiMismatchGroup[];
};

type CaseRecord = {
  caseIndex?: unknown;
  status?: unknown;
  genValidSelectedProfile?: unknown;
  genValidProfileCaseLabel?: unknown;
  transformId?: unknown;
};

function readJsonRecord(pathname: string): Record<string, unknown> {
  if (!fs.existsSync(pathname)) return {};
  const value = JSON.parse(fs.readFileSync(pathname, "utf8"));
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function finiteNumber(record: Record<string, unknown>, key: string): number | null {
  const value = record[key];
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function normalizedWatLines(wat: string): string[] {
  return wat
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => line
      .replace(/\$[A-Za-z0-9_.$-]+/g, "$id")
      .replace(/\b(type|func|local|global|table|memory)=?\d+\b/g, "$1=#")
      .replace(/\s+/g, " "));
}

function multisetDelta(left: string[], right: string[]): string[] {
  const remaining = new Map<string, number>();
  for (const line of right) remaining.set(line, (remaining.get(line) ?? 0) + 1);
  const delta: string[] = [];
  for (const line of left) {
    const count = remaining.get(line) ?? 0;
    if (count === 0) delta.push(line);
    else if (count === 1) remaining.delete(line);
    else remaining.set(line, count - 1);
  }
  return delta.sort();
}

function diffFact(starshineWat: string, binaryenWat: string): {
  signature: string;
  removed: string[];
  added: string[];
} {
  const starshine = normalizedWatLines(starshineWat);
  const binaryen = normalizedWatLines(binaryenWat);
  const removed = multisetDelta(starshine, binaryen);
  const added = multisetDelta(binaryen, starshine);
  const payload = JSON.stringify({ removed, added });
  return {
    signature: `sha256:${crypto.createHash("sha256").update(payload).digest("hex").slice(0, 16)}`,
    removed,
    added,
  };
}

function failureDirForCase(runDir: string, caseIndex: number): string | null {
  const failuresDir = path.join(runDir, "failures");
  if (!fs.existsSync(failuresDir)) return null;
  const prefix = `case-${String(caseIndex).padStart(6, "0")}-`;
  const entry = fs.readdirSync(failuresDir).sort().find((name) => name.startsWith(prefix));
  return entry === undefined ? null : path.join(failuresDir, entry);
}

export function summarizeOiMismatchRun(runDir: string): OiMismatchRunSummary {
  const result = readJsonRecord(path.join(runDir, "result.json"));
  const casesPath = path.join(runDir, "cases.jsonl");
  if (!fs.existsSync(casesPath)) throw new Error(`missing cases.jsonl: ${casesPath}`);

  const grouped = new Map<string, OiMismatchGroup>();
  const missingFailureArtifacts: number[] = [];
  let mismatchRecords = 0;
  for (const line of fs.readFileSync(casesPath, "utf8").split(/\r?\n/)) {
    if (line.trim() === "") continue;
    const record = JSON.parse(line) as CaseRecord;
    if (record.status !== "mismatch" || typeof record.caseIndex !== "number") continue;
    mismatchRecords += 1;
    const failureDir = failureDirForCase(runDir, record.caseIndex);
    if (failureDir === null) {
      missingFailureArtifacts.push(record.caseIndex);
      continue;
    }
    const starshinePath = path.join(failureDir, "starshine.wat");
    const binaryenPath = path.join(failureDir, "binaryen.wat");
    if (!fs.existsSync(starshinePath) || !fs.existsSync(binaryenPath)) {
      missingFailureArtifacts.push(record.caseIndex);
      continue;
    }
    const selectedProfile = typeof record.genValidSelectedProfile === "string"
      ? record.genValidSelectedProfile
      : "<unselected>";
    const caseLabel = typeof record.genValidProfileCaseLabel === "string"
      ? record.genValidProfileCaseLabel
      : typeof record.transformId === "string"
        ? `transform:${record.transformId}`
        : "<unlabeled>";
    const diff = diffFact(
      fs.readFileSync(starshinePath, "utf8"),
      fs.readFileSync(binaryenPath, "utf8"),
    );
    const key = JSON.stringify([selectedProfile, caseLabel, diff.signature]);
    const existing = grouped.get(key);
    if (existing !== undefined) {
      existing.count += 1;
    } else {
      grouped.set(key, {
        selectedProfile,
        caseLabel,
        diffSignature: diff.signature,
        count: 1,
        representativeCaseIndex: record.caseIndex,
        representativeFailureDir: failureDir,
        removedPreview: diff.removed.slice(0, 8),
        addedPreview: diff.added.slice(0, 8),
      });
    }
  }

  const groups = Array.from(grouped.values()).sort((left, right) =>
    right.count - left.count ||
    left.selectedProfile.localeCompare(right.selectedProfile) ||
    left.caseLabel.localeCompare(right.caseLabel) ||
    left.diffSignature.localeCompare(right.diffSignature));

  return {
    runDir,
    requestedCount: finiteNumber(result, "requestedCount"),
    comparedCount: finiteNumber(result, "comparedCount"),
    normalizedMatchCount: finiteNumber(result, "normalizedMatchCount"),
    resultMismatchCount: finiteNumber(result, "mismatchCount"),
    mismatchRecords,
    missingFailureArtifacts: missingFailureArtifacts.sort((a, b) => a - b),
    groups,
  };
}

export function formatOiMismatchSummary(summary: OiMismatchRunSummary): string {
  const lines = [
    `OI mismatch summary: ${summary.runDir}`,
    `result: requested=${summary.requestedCount ?? "?"} compared=${summary.comparedCount ?? "?"} normalized=${summary.normalizedMatchCount ?? "?"} mismatches=${summary.resultMismatchCount ?? "?"}`,
    `mismatch records: ${summary.mismatchRecords}`,
    `missing failure artifacts: ${summary.missingFailureArtifacts.length === 0 ? "<none>" : summary.missingFailureArtifacts.join(",")}`,
    "agent classification: required; grouping is triage evidence only and does not prove semantic safety or a Starshine win.",
    "",
    "Groups:",
  ];
  for (const group of summary.groups) {
    lines.push(`- ${group.selectedProfile} / ${group.caseLabel}: ${group.count} (${group.diffSignature}, representative case ${group.representativeCaseIndex})`);
    lines.push(`  failure: ${group.representativeFailureDir}`);
    lines.push(`  Starshine-only lines: ${group.removedPreview.length === 0 ? "<none>" : group.removedPreview.join(" | ")}`);
    lines.push(`  Binaryen-only lines: ${group.addedPreview.length === 0 ? "<none>" : group.addedPreview.join(" | ")}`);
  }
  return `${lines.join("\n")}\n`;
}
