import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = path.resolve(import.meta.dir, "../..");
const starshine = process.argv[2] ?? path.join(root, "_build/native/release/build/cmd/cmd.exe");
if (!fs.existsSync(starshine)) throw new Error(`missing native Starshine: ${starshine}`);
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-local-state-"));
const runner = path.join(dir, "check.cjs");
fs.writeFileSync(runner, `
const fs = require("node:fs");
const assert = require("node:assert/strict");
const e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {env: {tri: () => [42, 101, 202]}}).exports;
switch (process.argv[3]) {
  case "branch-join": assert.equal(e.run(0), 10); assert.equal(e.run(1), 20); break;
  case "tuple-copy": assert.equal(e.run(), 42); break;
  case "carried-read": assert.equal(e.run(), 3); break;
  case "carried-allocation":
    assert.throws(() => e.run(), error => error instanceof WebAssembly.RuntimeError && /out of bounds/.test(error.message));
    break;
  default: throw new Error("unknown local-state fixture");
}
`);
function run(command: string, args: string[]): void {
  try {
    execFileSync(command, args, { cwd: root, timeout: 5000, stdio: "pipe" });
  } catch (error) {
    throw new Error(`${command} ${args.join(" ")} failed; artifacts: ${dir}`, { cause: error });
  }
}
for (const name of ["branch-join", "carried-read", "carried-allocation", "tuple-copy"]) {
  const input = path.join(dir, `${name}.wasm`);
  run("wasm-tools", ["parse", `tests/fixtures/simplify-locals/${name}.wat`, "-o", input]);
  run("node", [runner, input, name]);
  const output = path.join(dir, `${name}.optimized.wasm`);
  const start = performance.now();
  run(starshine, [input, name === "tuple-copy" ? "--tuple-optimization" : "--simplify-locals-nostructure", "-o", output]);
  run("wasm-tools", ["validate", "--features", "all", output]);
  run("node", [runner, output, name]);
  console.log(`${name}: values/traps preserved (${(performance.now() - start).toFixed(1)} ms)`);
}
fs.rmSync(dir, { recursive: true });
