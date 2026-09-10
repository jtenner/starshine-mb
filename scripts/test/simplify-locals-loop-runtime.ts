import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

// Run Wasm in a child: a valid optimizer output can still loop forever.
const root = path.resolve(import.meta.dir, "../..");
const starshine = process.argv[2] ?? path.join(root, "_build/native/release/build/cmd/cmd.exe");
if (!fs.existsSync(starshine)) throw new Error(`missing native Starshine: ${starshine}`);
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-local-loop-"));
const runner = path.join(dir, "check.cjs");
fs.writeFileSync(runner, `
const fs = require("node:fs");
const assert = require("node:assert/strict");
const instance = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])));
for (const limit of [0, 1, 2, 3, 4, 10, 100]) {
  const start = Number(process.argv[3]), step = Number(process.argv[4]);
  let expected = 0;
  for (let counter = start; counter < limit; counter += step) {
    if (counter === 2) { expected = 1; break; }
  }
  assert.equal(instance.exports.run(limit), expected, "counter result for limit=" + limit);
}
`);
function run(command: string, args: string[], timeout = 5000): void {
  try {
    execFileSync(command, args, { cwd: root, timeout, stdio: "pipe" });
  } catch (error) {
    throw new Error(`${command} ${args.join(" ")} failed; artifacts: ${dir}`, { cause: error });
  }
}
const fixture = fs.readFileSync(path.join(root, "tests/fixtures/simplify-locals/aliased-loop-counter.wat"), "utf8");
for (const [initial, step] of [[0, 1], [1, 1], [0, 2], [3, 2]]) {
  const name = `counter-${initial}-${step}`;
  const wat = path.join(dir, `${name}.wat`);
  const input = path.join(dir, `${name}.wasm`);
  fs.writeFileSync(wat, fixture
    .replace("i32.const 0 local.set $counter", `i32.const ${initial} local.set $counter`)
    .replace("i32.const 1 i32.add local.set $counter", `i32.const ${step} i32.add local.set $counter`));
  run("wasm-tools", ["parse", wat, "-o", input]);
  run("node", [runner, input, String(initial), String(step)]);
  for (const pass of ["simplify-locals-nostructure", "simplify-locals-notee-nostructure", "simplify-locals-nonesting", "simplify-locals"]) {
    const output = path.join(dir, `${name}-${pass}.wasm`);
    const start = performance.now();
    run(starshine, [input, `--${pass}`, "-o", output]);
    run("wasm-tools", ["validate", "--features", "all", output]);
    run("node", [runner, output, String(initial), String(step)]);
    console.log(`${name} ${pass}: seven runtime checks passed (${(performance.now() - start).toFixed(1)} ms)`);
  }
}
fs.rmSync(dir, { recursive: true });
