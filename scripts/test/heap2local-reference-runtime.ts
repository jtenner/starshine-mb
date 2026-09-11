import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = path.resolve(import.meta.dir, "../..");
const starshine = process.argv[2] ?? path.join(root, "_build/native/release/build/cmd/cmd.exe");
const directory = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-heap-reference-"));
function run(command: string, args: string[]): string {
  try {
    return execFileSync(command, args, { cwd: root, timeout: 5000, encoding: "utf8" });
  } catch (error) {
    throw new Error(`${command} failed; artifacts: ${directory}`, { cause: error });
  }
}
const input = path.join(directory, "input.wasm");
run("wasm-tools", ["parse", path.join(root, "tests/fixtures/heap2local/reference-fields.wat"), "-o", input]);
const checker = path.join(directory, "check.cjs");
fs.writeFileSync(checker, `
const fs = require("node:fs"), assert = require("node:assert/strict");
const wasmExports = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2]))).exports;
for (const value of [0, 1, -7, 42, 2147483640]) {
  assert.equal(wasmExports.sum(value), (value + 7) | 0);
  assert.equal(wasmExports.reference(value), value);
  assert.equal(wasmExports.elements(value), (value + 7) | 0);
}
`);
run("node", [checker, input]);
for (const passes of [["--heap2local"], ["--heap2local", "--heap2local"]]) {
  const output = path.join(directory, `output-${passes.length}.wasm`);
  run(starshine, [input, ...passes, "-o", output]);
  run("wasm-tools", ["validate", "--features", "all", output]);
  run("node", [checker, output]);
}
console.log("30 Heap2Local reference field execution checks passed");
fs.rmSync(directory, { recursive: true });
