export type ReductionPredicate<T> = (candidate: T) => boolean;

export function reduceModuleFieldsByDeletion<T>(fields: readonly T[], predicate: ReductionPredicate<readonly T[]>): T[] {
  return reduceSequenceByChunkDeletion(fields, (candidate) => candidate, predicate).items;
}

export function reduceBinaryByByteSlices(bytes: Uint8Array, predicate: ReductionPredicate<Uint8Array>): Uint8Array {
  const values = Array.from(bytes);
  const reduced = reduceSequenceByChunkDeletion(
    values,
    (candidate) => Uint8Array.from(candidate),
    predicate,
  );
  return Uint8Array.from(reduced.items);
}

export function reduceTextByTokenDeletion(text: string, predicate: ReductionPredicate<string>): string {
  const tokens = tokenizeReductionText(text);
  const reduced = reduceSequenceByChunkDeletion(
    tokens,
    (candidate) => candidate.join(" "),
    predicate,
  );
  return reduced.changed ? reduced.items.join(" ") : text;
}

function reduceSequenceByChunkDeletion<T, Candidate>(
  original: readonly T[],
  makeCandidate: (items: readonly T[]) => Candidate,
  predicate: ReductionPredicate<Candidate>,
): { items: T[]; changed: boolean } {
  let current = Array.from(original);
  let anyChanged = false;
  if (current.length === 0) {
    return { items: current, changed: false };
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
      const candidateItems = current.slice(0, start).concat(current.slice(end));
      if (predicate(makeCandidate(candidateItems))) {
        current = candidateItems;
        changed = true;
        anyChanged = true;
        continue;
      }
      start = end;
    }
    if (!changed) {
      chunkSize = Math.floor(chunkSize / 2);
    }
  }
  return { items: current, changed: anyChanged };
}

function largestPowerOfTwoAtMost(value: number): number {
  let size = 1;
  while (size * 2 <= value) {
    size *= 2;
  }
  return size;
}

function tokenizeReductionText(text: string): string[] {
  const matches = text.match(/[A-Za-z0-9_.$:@+\-*/<>=!?|&%^~'`\\"]+/g);
  return matches === null ? [] : matches;
}
