export type EffectTrapFacts = {
  hasCall: boolean;
  mutatesMemory: boolean;
  mutatesTable: boolean;
  mutatesGlobal: boolean;
  hasException: boolean;
  hasAtomics: boolean;
  hasUnreachable: boolean;
  mayTrap: boolean;
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
  };
}

function markTrap(facts: EffectTrapFacts): void {
  facts.mayTrap = true;
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
        offset = localCount.next + 1; // value type byte
      }
      ranges.push({ start: offset, end: bodyEnd });
      offset = bodyEnd;
    }
    return ranges;
  }
  return null;
}

function skipUlebOperands(bytes: Uint8Array, offset: number, count: number): number {
  let next = offset;
  for (let index = 0; index < count; index += 1) {
    next = readUleb(bytes, next).next;
  }
  return next;
}

function scanOpcode(opcode: number, bytes: Uint8Array, offset: number, end: number, facts: EffectTrapFacts): number {
  switch (opcode) {
    case 0x00: // unreachable
      facts.hasUnreachable = true;
      markTrap(facts);
      return offset;
    case 0x06: // try
      facts.hasException = true;
      return Math.min(end, offset + 1);
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
    case 0x19: // catch_all
      facts.hasException = true;
      return offset;
    case 0x10: // call
    case 0x12: // return_call
      facts.hasCall = true;
      return skipUlebOperands(bytes, offset, 1);
    case 0x11: // call_indirect
    case 0x13: // return_call_indirect
      facts.hasCall = true;
      markTrap(facts);
      return skipUlebOperands(bytes, offset, 2);
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
    case 0x42: // i64.const
      return readUleb(bytes, offset).next;
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
      offset = scanOpcode(input[offset], input, offset + 1, end, facts) - 1;
    }
  }
  return facts;
}
