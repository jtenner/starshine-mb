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
