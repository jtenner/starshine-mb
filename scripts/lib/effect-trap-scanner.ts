export type EffectTrapHazard = {
  offset: number;
  opcode: number;
  kind:
    | "import-or-local-call"
    | "global-write"
    | "memory-read"
    | "memory-write"
    | "table-read"
    | "table-write"
    | "atomic"
    | "exception"
    | "explicit-unreachable"
    | "possible-trap";
};

export type EffectTrapFacts = {
  hasCall: boolean;
  mutatesMemory: boolean;
  mutatesTable: boolean;
  mutatesGlobal: boolean;
  hasException: boolean;
  hasAtomics: boolean;
  hasUnreachable: boolean;
  mayTrap: boolean;
  // Only GC prefix decoding is qualified; other opcode families remain best-effort.
  gcDecodeStatus: "complete" | "incomplete";
  gcDecodeIncompleteOffset: number | null;
  gcDecodeIncompleteReason: string | null;
  hazards: EffectTrapHazard[];
  possibleTrapCategories: string[];
};

export function emptyEffectTrapFacts(): EffectTrapFacts {
  return {
    hasCall: false,
    mutatesMemory: false,
    mutatesTable: false,
    mutatesGlobal: false,
    hasException: false,
    hasAtomics: false,
    hasUnreachable: false,
    mayTrap: false,
    gcDecodeStatus: "complete",
    gcDecodeIncompleteOffset: null,
    gcDecodeIncompleteReason: null,
    hazards: [],
    possibleTrapCategories: [],
  };
}

function noteTrapCategory(facts: EffectTrapFacts, category: string): void {
  if (!facts.possibleTrapCategories.includes(category)) facts.possibleTrapCategories.push(category);
}

function noteHazard(facts: EffectTrapFacts, offset: number, opcode: number, kind: EffectTrapHazard["kind"]): void {
  facts.hazards.push({ offset, opcode, kind });
}

function recordOpcodeHazard(facts: EffectTrapFacts, opcode: number, offset: number): void {
  if (opcode === 0x00) {
    noteHazard(facts, offset, opcode, "explicit-unreachable");
    noteTrapCategory(facts, "explicit-unreachable");
  } else if (
    opcode === 0x10 ||
    opcode === 0x11 ||
    opcode === 0x12 ||
    opcode === 0x13 ||
    opcode === 0x14 ||
    opcode === 0x15
  ) {
    noteHazard(facts, offset, opcode, "import-or-local-call");
    if (opcode === 0x11 || opcode === 0x13) noteTrapCategory(facts, "indirect-call-type-mismatch");
    if (opcode === 0x14 || opcode === 0x15) noteTrapCategory(facts, "null-reference");
  } else if (opcode === 0x24) {
    noteHazard(facts, offset, opcode, "global-write");
  } else if (opcode === 0x25) {
    noteHazard(facts, offset, opcode, "table-read");
    noteTrapCategory(facts, "out-of-bounds-table-access");
  } else if (opcode === 0x26) {
    noteHazard(facts, offset, opcode, "table-write");
    noteTrapCategory(facts, "out-of-bounds-table-access");
  } else if (opcode >= 0x28 && opcode <= 0x35) {
    noteHazard(facts, offset, opcode, "memory-read");
    noteTrapCategory(facts, "out-of-bounds-memory-access");
  } else if (opcode >= 0x36 && opcode <= 0x3e) {
    noteHazard(facts, offset, opcode, "memory-write");
    noteTrapCategory(facts, "out-of-bounds-memory-access");
  } else if ((opcode >= 0x6d && opcode <= 0x70) || (opcode >= 0x7f && opcode <= 0x82)) {
    noteHazard(facts, offset, opcode, "possible-trap");
    noteTrapCategory(facts, "integer-division-or-remainder");
  } else if (opcode === 0xfe) {
    noteHazard(facts, offset, opcode, "atomic");
    noteTrapCategory(facts, "atomic-memory-access");
  } else if (
    opcode === 0x06 ||
    opcode === 0x07 ||
    opcode === 0x08 ||
    opcode === 0x09 ||
    opcode === 0x0a ||
    opcode === 0x18 ||
    opcode === 0x19 ||
    opcode === 0x1f
  ) {
    noteHazard(facts, offset, opcode, "exception");
  }
}

function markTrap(facts: EffectTrapFacts): void {
  facts.mayTrap = true;
}

function markIncomplete(facts: EffectTrapFacts, offset: number, reason: string): void {
  if (facts.gcDecodeStatus === "complete") {
    facts.gcDecodeStatus = "incomplete";
    facts.gcDecodeIncompleteOffset = offset;
    facts.gcDecodeIncompleteReason = reason;
  }
}

function readGcUleb(bytes: Uint8Array, offset: number, end: number): { value: number; next: number } | null {
  let value = 0;
  for (let byteIndex = 0; byteIndex < 5; byteIndex += 1) {
    if (offset >= end) return null;
    const byte = bytes[offset++];
    const payload = byte & 0x7f;
    if (byteIndex === 4 && payload > 0x0f) return null;
    value += payload * 2 ** (byteIndex * 7);
    if ((byte & 0x80) === 0) return { value, next: offset };
  }
  return null;
}

function skipGcHeapType(bytes: Uint8Array, offset: number, end: number): number | null {
  if (offset < end && bytes[offset] === 0x62) offset += 1; // exact
  if (offset < end && bytes[offset] === 0x65) offset += 1; // shared
  if (offset >= end) return null;
  const first = bytes[offset];
  if (first === 0x5b || first === 0x5c || (first >= 0x67 && first <= 0x75)) return offset + 1;
  // The remaining core form is a nonnegative signed-33 type index.
  let value = 0;
  for (let byteIndex = 0; byteIndex < 5; byteIndex += 1) {
    if (offset >= end) return null;
    const byte = bytes[offset++];
    value += (byte & 0x7f) * 2 ** (byteIndex * 7);
    if ((byte & 0x80) === 0) {
      if ((byte & 0x40) !== 0) value -= 2 ** ((byteIndex + 1) * 7);
      return value >= 0 && value <= 0xffff_ffff ? offset : null;
    }
  }
  return null;
}

function scanGcOpcode(bytes: Uint8Array, offset: number, end: number, facts: EffectTrapFacts, opcodeOffset: number): number {
  const sub = readGcUleb(bytes, offset, end);
  if (sub === null) {
    markIncomplete(facts, opcodeOffset, "malformed-gc-subopcode");
    return end;
  }
  const opcode = sub.value;
  let next = sub.next;
  const integerOperands = opcode <= 1 || (opcode >= 6 && opcode <= 7)
    || (opcode >= 11 && opcode <= 14) || opcode === 16 ? 1
    : (opcode >= 2 && opcode <= 5) || (opcode >= 8 && opcode <= 10)
      || opcode === 17 || opcode === 18 || opcode === 19 ? 2 : 0;
  if (integerOperands > 0) {
    for (let operand = 0; operand < integerOperands; operand += 1) {
      const parsed = readGcUleb(bytes, next, end);
      if (parsed === null) {
        markIncomplete(facts, opcodeOffset, "malformed-gc-immediate");
        return end;
      }
      next = parsed.next;
    }
  } else if (opcode >= 20 && opcode <= 23) {
    const afterHeap = skipGcHeapType(bytes, next, end);
    if (afterHeap === null) {
      markIncomplete(facts, opcodeOffset, "malformed-gc-heap-type");
      return end;
    }
    next = afterHeap;
  } else if (opcode === 24 || opcode === 25) {
    if (next >= end || bytes[next] > 3) {
      markIncomplete(facts, opcodeOffset, "malformed-gc-cast-flags");
      return end;
    }
    const label = readGcUleb(bytes, next + 1, end);
    const source = label === null ? null : skipGcHeapType(bytes, label.next, end);
    const target = source === null ? null : skipGcHeapType(bytes, source, end);
    if (target === null) {
      markIncomplete(facts, opcodeOffset, "malformed-gc-cast-immediate");
      return end;
    }
    next = target;
  } else if (opcode !== 15 && (opcode < 26 || opcode > 30)) {
    markIncomplete(facts, opcodeOffset, "unsupported-gc-subopcode");
    return end;
  }
  if ((opcode >= 2 && opcode <= 19) || opcode === 22 || opcode === 23 || opcode === 29 || opcode === 30) {
    markTrap(facts);
    noteTrapCategory(facts, "gc-reference-or-bounds");
  }
  return next;
}

function readUleb(bytes: Uint8Array, offset: number): { value: number; next: number } {
  let value = 0;
  let shift = 0;
  let index = offset;
  while (index < bytes.length) {
    const byte = bytes[index++];
    value |= (byte & 0x7f) << shift;
    if ((byte & 0x80) === 0) {
      return { value, next: index };
    }
    shift += 7;
    if (shift > 35) {
      break;
    }
  }
  return { value, next: index };
}

function skipSignedLeb(bytes: Uint8Array, offset: number, maxBytes: number): number {
  let index = offset;
  for (let count = 0; count < maxBytes && index < bytes.length; count += 1) {
    const byte = bytes[index++];
    if ((byte & 0x80) === 0) break;
  }
  return index;
}

function skipValueType(bytes: Uint8Array, offset: number): number {
  const type = bytes[offset];
  if (type !== 0x63 && type !== 0x64) {
    return Math.min(bytes.length, offset + 1);
  }
  let heapTypeOffset = offset + 1;
  if (bytes[heapTypeOffset] === 0x62) heapTypeOffset += 1; // exact
  if (bytes[heapTypeOffset] === 0x65) heapTypeOffset += 1; // shared
  return readUleb(bytes, heapTypeOffset).next;
}

function skipBlockType(bytes: Uint8Array, offset: number): number {
  if (offset >= bytes.length) return bytes.length;
  const first = bytes[offset];
  if (first === 0x63 || first === 0x64) {
    return skipValueType(bytes, offset);
  }
  if ((first & 0x80) === 0) {
    return offset + 1;
  }
  return readUleb(bytes, offset).next;
}

function skipTryTableImmediate(bytes: Uint8Array, offset: number, end: number): number {
  const catchCount = readUleb(bytes, skipBlockType(bytes, offset));
  let next = catchCount.next;
  for (let index = 0; index < catchCount.value && next < end; index += 1) {
    const kind = bytes[next++];
    if (kind === 0x00 || kind === 0x01) {
      next = skipUlebOperands(bytes, next, 2); // tag index, label index
    } else if (kind === 0x02 || kind === 0x03) {
      next = skipUlebOperands(bytes, next, 1); // label index
    } else {
      break;
    }
  }
  return Math.min(end, next);
}

function skipBrTableImmediate(bytes: Uint8Array, offset: number, end: number): number {
  const targetCount = readUleb(bytes, offset);
  let next = targetCount.next;
  // One label follows for every vector entry, then one default label. Keep
  // malformed or truncated inputs bounded by the containing function body.
  for (let index = 0; index <= targetCount.value && next < end; index += 1) {
    next = readUleb(bytes, next).next;
  }
  return Math.min(end, next);
}

function codeBodyRanges(bytes: Uint8Array): { start: number; end: number }[] | null {
  if (bytes.length < 8) {
    return null;
  }
  if (
    bytes[0] !== 0x00 ||
    bytes[1] !== 0x61 ||
    bytes[2] !== 0x73 ||
    bytes[3] !== 0x6d ||
    bytes[4] !== 0x01 ||
    bytes[5] !== 0x00 ||
    bytes[6] !== 0x00 ||
    bytes[7] !== 0x00
  ) {
    return null;
  }

  let offset = 8;
  while (offset < bytes.length) {
    const sectionId = bytes[offset++];
    const sectionSize = readUleb(bytes, offset);
    offset = sectionSize.next;
    const sectionStart = offset;
    const sectionEnd = Math.min(bytes.length, sectionStart + sectionSize.value);
    if (sectionId !== 10) {
      offset = sectionEnd;
      continue;
    }

    const ranges: { start: number; end: number }[] = [];
    const count = readUleb(bytes, offset);
    offset = count.next;
    for (let bodyIndex = 0; bodyIndex < count.value && offset < sectionEnd; bodyIndex += 1) {
      const bodySize = readUleb(bytes, offset);
      offset = bodySize.next;
      const bodyEnd = Math.min(sectionEnd, offset + bodySize.value);
      const localGroupCount = readUleb(bytes, offset);
      offset = localGroupCount.next;
      for (let localGroup = 0; localGroup < localGroupCount.value && offset < bodyEnd; localGroup += 1) {
        const localCount = readUleb(bytes, offset);
        offset = skipValueType(bytes, localCount.next);
      }
      ranges.push({ start: offset, end: bodyEnd });
      offset = bodyEnd;
    }
    return ranges;
  }
  return [];
}

function skipUlebOperands(bytes: Uint8Array, offset: number, count: number): number {
  let next = offset;
  for (let index = 0; index < count; index += 1) {
    next = readUleb(bytes, next).next;
  }
  return next;
}

function skipMemArg(bytes: Uint8Array, offset: number): number {
  const align = readUleb(bytes, offset);
  let next = align.next;
  if ((align.value & 0x40) !== 0) {
    next = readUleb(bytes, next).next;
  }
  return readUleb(bytes, next).next;
}

function scanSimdOpcode(
  bytes: Uint8Array,
  offset: number,
  end: number,
  facts: EffectTrapFacts,
  opcodeOffset: number,
): number {
  const sub = readUleb(bytes, offset);
  const subopcode = sub.value;
  if ((subopcode >= 0 && subopcode <= 10) || subopcode === 92 || subopcode === 93) {
    noteHazard(facts, opcodeOffset, 0xfd, "memory-read");
    noteTrapCategory(facts, "out-of-bounds-memory-access");
    markTrap(facts);
    return skipMemArg(bytes, sub.next);
  }
  if (subopcode === 11) {
    noteHazard(facts, opcodeOffset, 0xfd, "memory-write");
    noteTrapCategory(facts, "out-of-bounds-memory-access");
    facts.mutatesMemory = true;
    markTrap(facts);
    return skipMemArg(bytes, sub.next);
  }
  if (subopcode === 12 || subopcode === 13) {
    return Math.min(end, sub.next + 16);
  }
  if (subopcode >= 21 && subopcode <= 34) {
    return Math.min(end, sub.next + 1);
  }
  if (subopcode >= 84 && subopcode <= 91) {
    const afterMemArg = skipMemArg(bytes, sub.next);
    const store = subopcode >= 88;
    noteHazard(facts, opcodeOffset, 0xfd, store ? "memory-write" : "memory-read");
    noteTrapCategory(facts, "out-of-bounds-memory-access");
    if (store) facts.mutatesMemory = true;
    markTrap(facts);
    return Math.min(end, afterMemArg + 1);
  }
  return sub.next;
}

function scanOpcode(
  opcode: number,
  bytes: Uint8Array,
  offset: number,
  end: number,
  facts: EffectTrapFacts,
  opcodeOffset: number,
): number {
  switch (opcode) {
    case 0x00: // unreachable
      facts.hasUnreachable = true;
      markTrap(facts);
      return offset;
    case 0x02: // block
    case 0x03: // loop
    case 0x04: // if
      return skipBlockType(bytes, offset);
    case 0x06: // try
      facts.hasException = true;
      return skipBlockType(bytes, offset);
    case 0x07: // catch
      facts.hasException = true;
      return skipUlebOperands(bytes, offset, 1);
    case 0x08: // throw
    case 0x09: // rethrow
    case 0x18: // delegate
      facts.hasException = true;
      markTrap(facts);
      return skipUlebOperands(bytes, offset, 1);
    case 0x0a: // throw_ref
      facts.hasException = true;
      markTrap(facts);
      return offset;
    case 0x0c: // br
    case 0x0d: // br_if
      return skipUlebOperands(bytes, offset, 1);
    case 0x0e: // br_table
      return skipBrTableImmediate(bytes, offset, end);
    case 0x19: // catch_all
      facts.hasException = true;
      return offset;
    case 0x1f: // try_table
      facts.hasException = true;
      return skipTryTableImmediate(bytes, offset, end);
    case 0x10: // call
    case 0x12: // return_call
      facts.hasCall = true;
      return skipUlebOperands(bytes, offset, 1);
    case 0x11: // call_indirect
    case 0x13: // return_call_indirect
      facts.hasCall = true;
      markTrap(facts);
      return skipUlebOperands(bytes, offset, 2);
    case 0x14: // call_ref
    case 0x15: // return_call_ref
      facts.hasCall = true;
      markTrap(facts);
      return skipUlebOperands(bytes, offset, 1);
    case 0x20: // local.get
    case 0x21: // local.set
    case 0x22: // local.tee
    case 0x23: // global.get
      return skipUlebOperands(bytes, offset, 1);
    case 0x24: // global.set
      facts.mutatesGlobal = true;
      return skipUlebOperands(bytes, offset, 1);
    case 0x25: // table.get
      markTrap(facts);
      return skipUlebOperands(bytes, offset, 1);
    case 0x26: // table.set
      facts.mutatesTable = true;
      markTrap(facts);
      return skipUlebOperands(bytes, offset, 1);
    case 0x41: // i32.const
      return skipSignedLeb(bytes, offset, 5);
    case 0x42: // i64.const
      return skipSignedLeb(bytes, offset, 10);
    case 0x43: // f32.const
      return Math.min(end, offset + 4);
    case 0x44: // f64.const
      return Math.min(end, offset + 8);
    case 0xd0: // ref.null
    case 0xd2: // ref.func
      return skipUlebOperands(bytes, offset, 1);
    case 0xd4: // ref.as_non_null
      markTrap(facts);
      return offset;
    default:
      break;
  }

  if ((opcode >= 0x28 && opcode <= 0x35) || (opcode >= 0x36 && opcode <= 0x3e)) {
    markTrap(facts);
    if (opcode >= 0x36) {
      facts.mutatesMemory = true;
    }
    return skipUlebOperands(bytes, offset, 2);
  }

  if ((opcode >= 0x6d && opcode <= 0x70) || (opcode >= 0x7f && opcode <= 0x82)) {
    // integer div/rem can trap on zero divisor or signed overflow.
    markTrap(facts);
    return offset;
  }

  if (opcode === 0xfd) {
    return scanSimdOpcode(bytes, offset, end, facts, opcodeOffset);
  }

  if (opcode === 0xfb) {
    // A valid function body ends with 0x0b; it cannot supply a missing GC
    // immediate even when the byte value would look like a valid index.
    const operandEnd = end > offset && bytes[end - 1] === 0x0b ? end - 1 : end;
    return scanGcOpcode(bytes, offset, operandEnd, facts, opcodeOffset);
  }

  if (opcode === 0xfc || opcode === 0xfe) {
    const sub = readUleb(bytes, offset);
    if (opcode === 0xfe) {
      facts.hasAtomics = true;
      // Treat atomic-prefix instructions as memory-effecting conservatively; even loads
      // still synchronize with shared memory and may trap on their memarg.
      facts.mutatesMemory = true;
      markTrap(facts);
      return skipUlebOperands(bytes, sub.next, 2);
    }
    switch (sub.value) {
      case 8: // memory.init
        facts.mutatesMemory = true;
        markTrap(facts);
        return skipUlebOperands(bytes, sub.next, 2);
      case 10: // memory.copy
        facts.mutatesMemory = true;
        markTrap(facts);
        return skipUlebOperands(bytes, sub.next, 2);
      case 11: // memory.fill
        facts.mutatesMemory = true;
        markTrap(facts);
        return skipUlebOperands(bytes, sub.next, 1);
      case 12: // table.init
        facts.mutatesTable = true;
        markTrap(facts);
        return skipUlebOperands(bytes, sub.next, 2);
      case 14: // table.copy
        facts.mutatesTable = true;
        markTrap(facts);
        return skipUlebOperands(bytes, sub.next, 2);
      case 15: // table.grow
      case 17: // table.fill
        facts.mutatesTable = true;
        markTrap(facts);
        return skipUlebOperands(bytes, sub.next, 1);
      case 9: // data.drop
      case 13: // elem.drop
        break;
      case 16: // table.size
        break;
      default:
        break;
    }
    return sub.next;
  }

  return offset;
}

export function scanEffectTrapFactsFromWasmBytes(input: Uint8Array): EffectTrapFacts {
  const facts = emptyEffectTrapFacts();
  const ranges = codeBodyRanges(input) ?? [{ start: 0, end: input.length }];
  for (const { start, end } of ranges) {
    for (let offset = start; offset < end; offset += 1) {
      const opcodeOffset = offset;
      const opcode = input[offset];
      recordOpcodeHazard(facts, opcode, opcodeOffset);
      offset = scanOpcode(opcode, input, offset + 1, end, facts, opcodeOffset) - 1;
    }
  }
  return facts;
}
