import { expect, test } from "bun:test";

import { stripWasmCustomSection } from "./wasm-export-renaming";

const header = [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00];

function customSection(name: string, payload: number[]): number[] {
  const nameBytes = [...new TextEncoder().encode(name)];
  const sectionPayload = [nameBytes.length, ...nameBytes, ...payload];
  return [0x00, sectionPayload.length, ...sectionPayload];
}

test("stripWasmCustomSection removes only the selected custom section", () => {
  const abi = customSection("dew.abi", [0x01, 0x02]);
  const names = customSection("name", [0x01, 0x00]);
  const wasm = Uint8Array.from([...header, ...abi, ...names]);

  // This check keeps the semantic Dew ABI section and removes only debug names.
  expect([...stripWasmCustomSection(wasm, "name")]).toEqual([...header, ...abi]);
});
