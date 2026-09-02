interface DecodedU32 {
  value: number;
  next: number;
}

function decodeU32(bytes: Uint8Array, offset: number): DecodedU32 {
  let value = 0;
  let shift = 0;
  let cursor = offset;
  while (cursor < bytes.length && shift < 35) {
    const byte = bytes[cursor++];
    value |= (byte & 0x7f) << shift;
    if ((byte & 0x80) === 0) return { value: value >>> 0, next: cursor };
    shift += 7;
  }
  throw new Error(`invalid u32 LEB at byte ${offset}`);
}

function encodeU32(value: number): number[] {
  const bytes: number[] = [];
  let remaining = value >>> 0;
  do {
    let byte = remaining & 0x7f;
    remaining >>>= 7;
    if (remaining !== 0) byte |= 0x80;
    bytes.push(byte);
  } while (remaining !== 0);
  return bytes;
}

function exportSectionNames(payload: Uint8Array): string[] {
  const decoder = new TextDecoder();
  const count = decodeU32(payload, 0);
  const names: string[] = [];
  let cursor = count.next;
  for (let index = 0; index < count.value; index += 1) {
    const length = decodeU32(payload, cursor);
    const nameStart = length.next;
    const nameEnd = nameStart + length.value;
    if (nameEnd > payload.length) throw new Error("truncated Wasm export name");
    names.push(decoder.decode(payload.subarray(nameStart, nameEnd)));
    cursor = nameEnd + 1;
    const itemIndex = decodeU32(payload, cursor);
    cursor = itemIndex.next;
  }
  if (cursor !== payload.length) throw new Error("unexpected trailing bytes in Wasm export section");
  return names;
}

function rewriteExportSection(payload: Uint8Array, names: Map<string, string>): Uint8Array {
  const decoder = new TextDecoder();
  const encoder = new TextEncoder();
  const count = decodeU32(payload, 0);
  const output: number[] = [...encodeU32(count.value)];
  let cursor = count.next;
  for (let index = 0; index < count.value; index += 1) {
    const length = decodeU32(payload, cursor);
    const nameStart = length.next;
    const nameEnd = nameStart + length.value;
    if (nameEnd > payload.length) throw new Error("truncated Wasm export name");
    const currentName = decoder.decode(payload.subarray(nameStart, nameEnd));
    const renamed = encoder.encode(names.get(currentName) ?? currentName);
    output.push(...encodeU32(renamed.length), ...renamed);
    cursor = nameEnd;
    if (cursor >= payload.length) throw new Error("truncated Wasm export descriptor");
    output.push(payload[cursor++]);
    const itemIndex = decodeU32(payload, cursor);
    output.push(...encodeU32(itemIndex.value));
    cursor = itemIndex.next;
  }
  if (cursor !== payload.length) throw new Error("unexpected trailing bytes in Wasm export section");
  return Uint8Array.from(output);
}

export function listWasmExportNames(wasm: Uint8Array): string[] {
  if (wasm.length < 8 || wasm[0] !== 0x00 || wasm[1] !== 0x61 || wasm[2] !== 0x73 || wasm[3] !== 0x6d) {
    throw new Error("input is not a WebAssembly binary");
  }
  let cursor = 8;
  while (cursor < wasm.length) {
    const sectionId = wasm[cursor++];
    const size = decodeU32(wasm, cursor);
    const payloadStart = size.next;
    const payloadEnd = payloadStart + size.value;
    if (payloadEnd > wasm.length) throw new Error(`truncated Wasm section ${sectionId}`);
    if (sectionId === 7) return exportSectionNames(wasm.subarray(payloadStart, payloadEnd));
    cursor = payloadEnd;
  }
  return [];
}

function concatBytes(chunks: Uint8Array[]): Uint8Array {
  const length = chunks.reduce((total, chunk) => total + chunk.length, 0);
  const output = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.length;
  }
  return output;
}

function customSectionName(payload: Uint8Array): string {
  const length = decodeU32(payload, 0);
  const nameEnd = length.next + length.value;
  if (nameEnd > payload.length) throw new Error("truncated Wasm custom section name");
  return new TextDecoder().decode(payload.subarray(length.next, nameEnd));
}

export function stripWasmCustomSection(wasm: Uint8Array, name: string): Uint8Array {
  if (
    wasm.length < 8 ||
    wasm[0] !== 0x00 ||
    wasm[1] !== 0x61 ||
    wasm[2] !== 0x73 ||
    wasm[3] !== 0x6d
  ) {
    throw new Error("input is not a WebAssembly binary");
  }
  const chunks: Uint8Array[] = [wasm.slice(0, 8)];
  let cursor = 8;
  while (cursor < wasm.length) {
    const sectionStart = cursor;
    const sectionId = wasm[cursor++];
    const size = decodeU32(wasm, cursor);
    const payloadStart = size.next;
    const payloadEnd = payloadStart + size.value;
    if (payloadEnd > wasm.length) throw new Error(`truncated Wasm section ${sectionId}`);
    const remove =
      sectionId === 0 && customSectionName(wasm.subarray(payloadStart, payloadEnd)) === name;
    if (!remove) chunks.push(wasm.slice(sectionStart, payloadEnd));
    cursor = payloadEnd;
  }
  return concatBytes(chunks);
}

export function rewriteWasmExportNames(
  wasm: Uint8Array,
  names: Map<string, string>,
): Uint8Array {
  if (
    wasm.length < 8 ||
    wasm[0] !== 0x00 ||
    wasm[1] !== 0x61 ||
    wasm[2] !== 0x73 ||
    wasm[3] !== 0x6d
  ) {
    throw new Error("input is not a WebAssembly binary");
  }
  const chunks: Uint8Array[] = [wasm.slice(0, 8)];
  let cursor = 8;
  while (cursor < wasm.length) {
    const sectionId = wasm[cursor++];
    const size = decodeU32(wasm, cursor);
    const payloadStart = size.next;
    const payloadEnd = payloadStart + size.value;
    if (payloadEnd > wasm.length) throw new Error(`truncated Wasm section ${sectionId}`);
    const payload = wasm.subarray(payloadStart, payloadEnd);
    const rewritten = sectionId === 7 ? rewriteExportSection(payload, names) : payload;
    chunks.push(Uint8Array.from([sectionId, ...encodeU32(rewritten.length)]), rewritten);
    cursor = payloadEnd;
  }
  return concatBytes(chunks);
}
