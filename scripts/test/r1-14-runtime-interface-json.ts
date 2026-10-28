import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { buildRuntimeInterfaceFromStarshine } from "../lib/optimizer-runtime-executor";

// Exercise the actual command stdout and the executor's JSON.parse boundary.
const binary = process.argv[2] ?? "moonrun";
const argsPrefix = process.argv[3] ? [path.resolve(process.argv[3])] : [];
const names = ["", ...Array.from({ length: 32 }, (_, i) => String.fromCharCode(i)),
  'quote" slash\\ LF\n CR\r tab\t é中文😀\u007f\u0085\u2028\u2029'];
function uleb(n: number): number[] {
  const out: number[] = [];
  do { const byte = n & 127; n >>>= 7; out.push(byte | (n ? 128 : 0)); } while (n);
  return out;
}
const exports = [...uleb(names.length), ...names.flatMap(name => {
  const bytes = [...Buffer.from(name, "utf8")];
  return [...uleb(bytes.length), ...bytes, 2, 0]; // memory export, index 0
})];
const wasm = Buffer.from([0, 97, 115, 109, 1, 0, 0, 0,
  5, 3, 1, 0, 1, // one memory, minimum one page
  7, ...uleb(exports.length), ...exports]);
assert.equal(WebAssembly.validate(wasm), true, "valid Wasm names, including NUL");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-r1-14-"));
try {
  const input = path.join(dir, "names.wasm");
  fs.writeFileSync(input, wasm);
  const report = buildRuntimeInterfaceFromStarshine(input, binary, undefined, argsPrefix);
  assert.deepEqual(report.exports.map(entry => entry.name), names);
  console.log(`R1-14 runtime-interface JSON: ${names.length} export names round-trip`);
} finally {
  fs.rmSync(dir, { recursive: true, force: true });
}
