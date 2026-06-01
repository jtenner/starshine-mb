export type ReductionPredicate<T> = (candidate: T) => boolean;

export type ReductionStep = {
  kind: string;
  start: number;
  length: number;
  beforeSize: number;
  afterSize: number;
};

export type ReductionReport<T> = {
  result: T;
  originalSize: number;
  finalSize: number;
  predicateEvaluations: number;
  steps: ReductionStep[];
};

export type ReductionReportLogOptions = {
  status?: string;
  artifactPath?: string;
  artifactPathKey?: string;
  originalSize: number;
  finalSize: number;
  predicateEvaluations: number;
  steps: readonly ReductionStep[];
};

export type ParsedReductionReportLog = {
  status?: string;
  artifactPath?: string;
  artifactPathKey?: string;
  originalSize: number;
  finalSize: number;
  predicateEvaluations: number;
  steps: ReductionStep[];
};

export function formatReductionReportLog(options: ReductionReportLogOptions): string {
  const lines: string[] = [];
  if (options.status !== undefined) {
    lines.push(`status=${options.status}`);
  }
  lines.push(
    `original_size=${options.originalSize}`,
    `final_size=${options.finalSize}`,
    `predicate_evaluations=${options.predicateEvaluations}`,
  );
  if (options.artifactPath !== undefined) {
    lines.push(`${options.artifactPathKey ?? "reduced_artifact_path"}=${options.artifactPath}`);
  }
  for (const step of options.steps) {
    lines.push(`step=${step.kind}|start=${step.start}|len=${step.length}|before=${step.beforeSize}|after=${step.afterSize}`);
  }
  return lines.join("\n") + "\n";
}

export function parseReductionReportLog(log: string): ParsedReductionReportLog {
  let status: string | undefined;
  let artifactPath: string | undefined;
  let artifactPathKey: string | undefined;
  let originalSize: number | undefined;
  let finalSize: number | undefined;
  let predicateEvaluations: number | undefined;
  const steps: ReductionStep[] = [];

  for (const rawLine of log.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.length === 0) {
      continue;
    }
    if (line.startsWith("step=")) {
      steps.push(parseReductionStepLogLine(line));
      continue;
    }
    const separator = line.indexOf("=");
    if (separator < 0) {
      throw new Error(`Malformed reduction log line: ${line}`);
    }
    const key = line.slice(0, separator);
    const value = line.slice(separator + 1);
    switch (key) {
      case "status":
        status = value;
        break;
      case "original_size":
        originalSize = parseReductionLogInteger(key, value);
        break;
      case "final_size":
        finalSize = parseReductionLogInteger(key, value);
        break;
      case "predicate_evaluations":
        predicateEvaluations = parseReductionLogInteger(key, value);
        break;
      default:
        artifactPathKey = key;
        artifactPath = value;
        break;
    }
  }

  if (originalSize === undefined) {
    throw new Error("Reduction log is missing original_size");
  }
  if (finalSize === undefined) {
    throw new Error("Reduction log is missing final_size");
  }
  if (predicateEvaluations === undefined) {
    throw new Error("Reduction log is missing predicate_evaluations");
  }

  return {
    status,
    artifactPath,
    artifactPathKey,
    originalSize,
    finalSize,
    predicateEvaluations,
    steps,
  };
}

function parseReductionStepLogLine(line: string): ReductionStep {
  const fields = new Map<string, string>();
  for (const part of line.split("|")) {
    const separator = part.indexOf("=");
    if (separator < 0) {
      throw new Error(`Malformed reduction step field: ${part}`);
    }
    fields.set(part.slice(0, separator), part.slice(separator + 1));
  }
  const kind = fields.get("step");
  if (kind === undefined || kind.length === 0) {
    throw new Error(`Reduction step is missing kind: ${line}`);
  }
  return {
    kind,
    start: parseRequiredReductionStepInteger(fields, "start", line),
    length: parseRequiredReductionStepInteger(fields, "len", line),
    beforeSize: parseRequiredReductionStepInteger(fields, "before", line),
    afterSize: parseRequiredReductionStepInteger(fields, "after", line),
  };
}

function parseRequiredReductionStepInteger(fields: Map<string, string>, key: string, line: string): number {
  const value = fields.get(key);
  if (value === undefined) {
    throw new Error(`Reduction step is missing ${key}: ${line}`);
  }
  return parseReductionLogInteger(key, value);
}

function parseReductionLogInteger(key: string, value: string): number {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw new Error(`Invalid reduction log integer ${key}=${value}`);
  }
  return parsed;
}

export function reduceModuleFieldsByDeletion<T>(fields: readonly T[], predicate: ReductionPredicate<readonly T[]>): T[] {
  return reduceModuleFieldsByDeletionWithReport(fields, predicate).result;
}

export function reduceModuleFieldsByDeletionWithReport<T>(
  fields: readonly T[],
  predicate: ReductionPredicate<readonly T[]>,
): ReductionReport<T[]> {
  const reduced = reduceSequenceByChunkDeletion(
    fields,
    (candidate) => candidate,
    predicate,
    "delete-module-field-range",
  );
  return {
    result: reduced.items,
    originalSize: fields.length,
    finalSize: reduced.items.length,
    predicateEvaluations: reduced.predicateEvaluations,
    steps: reduced.steps,
  };
}

export function reduceBinaryByByteSlices(bytes: Uint8Array, predicate: ReductionPredicate<Uint8Array>): Uint8Array {
  return reduceBinaryByByteSlicesWithReport(bytes, predicate).result;
}

export function reduceBinaryByByteSlicesWithReport(
  bytes: Uint8Array,
  predicate: ReductionPredicate<Uint8Array>,
): ReductionReport<Uint8Array> {
  const values = Array.from(bytes);
  const reduced = reduceSequenceByChunkDeletion(
    values,
    (candidate) => Uint8Array.from(candidate),
    predicate,
    "delete-byte-slice",
  );
  const result = Uint8Array.from(reduced.items);
  return {
    result,
    originalSize: bytes.length,
    finalSize: result.length,
    predicateEvaluations: reduced.predicateEvaluations,
    steps: reduced.steps,
  };
}

export function reduceTextByLineDeletion(text: string, predicate: ReductionPredicate<string>): string {
  return reduceTextByLineDeletionWithReport(text, predicate).result;
}

export function reduceTextByLineDeletionWithReport(
  text: string,
  predicate: ReductionPredicate<string>,
): ReductionReport<string> {
  const lines = splitReductionLines(text);
  const reduced = reduceSequenceByChunkDeletion(
    lines,
    (candidate) => candidate.join("\n"),
    predicate,
    "delete-text-line-range",
  );
  const result = reduced.changed ? reduced.items.join("\n") : text;
  return {
    result,
    originalSize: lines.length,
    finalSize: reduced.changed ? reduced.items.length : lines.length,
    predicateEvaluations: reduced.predicateEvaluations,
    steps: reduced.steps,
  };
}

export function reduceTextByTokenDeletion(text: string, predicate: ReductionPredicate<string>): string {
  return reduceTextByTokenDeletionWithReport(text, predicate).result;
}

export function reduceTextByTokenDeletionWithReport(
  text: string,
  predicate: ReductionPredicate<string>,
): ReductionReport<string> {
  const tokens = tokenizeReductionText(text);
  const reduced = reduceSequenceByChunkDeletion(
    tokens,
    (candidate) => candidate.join(" "),
    predicate,
    "delete-text-token-range",
  );
  const result = reduced.changed ? reduced.items.join(" ") : text;
  return {
    result,
    originalSize: tokens.length,
    finalSize: reduced.changed ? reduced.items.length : tokens.length,
    predicateEvaluations: reduced.predicateEvaluations,
    steps: reduced.steps,
  };
}

function reduceSequenceByChunkDeletion<T, Candidate>(
  original: readonly T[],
  makeCandidate: (items: readonly T[]) => Candidate,
  predicate: ReductionPredicate<Candidate>,
  stepKind: string = "delete-sequence-range",
): { items: T[]; changed: boolean; predicateEvaluations: number; steps: ReductionStep[] } {
  let current = Array.from(original);
  let anyChanged = false;
  let predicateEvaluations = 0;
  const steps: ReductionStep[] = [];
  if (current.length === 0) {
    return { items: current, changed: false, predicateEvaluations, steps };
  }

  let chunkSize = largestPowerOfTwoAtMost(current.length);
  while (chunkSize >= 1) {
    let changed = false;
    for (let start = 0; start < current.length; ) {
      const end = Math.min(start + chunkSize, current.length);
      if (start === 0 && end === current.length) {
        start = end;
        continue;
      }
      const beforeSize = current.length;
      const candidateItems = current.slice(0, start).concat(current.slice(end));
      predicateEvaluations += 1;
      if (predicate(makeCandidate(candidateItems))) {
        current = candidateItems;
        changed = true;
        anyChanged = true;
        steps.push({
          kind: stepKind,
          start,
          length: end - start,
          beforeSize,
          afterSize: current.length,
        });
        continue;
      }
      start = end;
    }
    if (!changed) {
      chunkSize = Math.floor(chunkSize / 2);
    }
  }
  return { items: current, changed: anyChanged, predicateEvaluations, steps };
}

function largestPowerOfTwoAtMost(value: number): number {
  let size = 1;
  while (size * 2 <= value) {
    size *= 2;
  }
  return size;
}

function splitReductionLines(text: string): string[] {
  return text.length === 0 ? [] : text.split(/\r?\n/);
}

function tokenizeReductionText(text: string): string[] {
  const matches = text.match(/[A-Za-z0-9_.$:@+\-*/<>=!?|&%^~'`\\\"]+/g);
  return matches === null ? [] : matches;
}
