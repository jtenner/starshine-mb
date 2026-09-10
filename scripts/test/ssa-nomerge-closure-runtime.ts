import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

// Bound each child: validation alone cannot rule out wrong results or hangs.
const root = path.resolve(import.meta.dir, "../..");
const starshine = process.argv[2] ?? path.join(root, "_build/native/release/build/cmd/cmd.exe");
const directory = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-ssa-closure-"));
const checker = path.join(directory, "check.cjs");
fs.writeFileSync(checker, `
const fs = require("node:fs"), assert = require("node:assert/strict");
const instance = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])));
for (const length of [0, 1, 2, 19]) {
  assert.equal(instance.exports.run(length), length === 0 ? 1 : Number(process.argv[3]), "length=" + length);
}
`);
function run(command: string, args: string[]): void {
  try { execFileSync(command, args, { cwd: root, timeout: 5000, stdio: "pipe" }); }
  catch (error) { throw new Error(`${command} ${args.join(" ")} failed; artifacts: ${directory}`, { cause: error }); }
}
const fixture = fs.readFileSync(path.join(root, "tests/fixtures/ssa-nomerge/closure-loop.wat"), "utf8");
let checks = 0;
for (const bound of [false, true]) {
  for (const truth of [0, 1]) {
    const name = `${bound ? "bound" : "plain"}-${truth}`;
    const source = fixture.replace(
      "(type $plain) (param i32) (result i32) i32.const 1)",
      `(type $${bound ? "bound" : "plain"}) (param ${bound ? "eqref " : ""}i32) (result i32) i32.const ${truth})`,
    );
    const input = path.join(directory, `${name}.wasm`);
    fs.writeFileSync(path.join(directory, `${name}.wat`), source);
    run("wasm-tools", ["parse", path.join(directory, `${name}.wat`), "-o", input]);
    run("node", [checker, input, String(truth)]);
    for (const passes of [["--ssa-nomerge"], ["--ssa-nomerge", "--ssa-nomerge"]]) {
      const output = path.join(directory, `${name}-${passes.length}.wasm`);
      run(starshine, [input, ...passes, "-o", output]);
      run("wasm-tools", ["validate", "--features", "all", output]);
      run("node", [checker, output, String(truth)]);
      checks += 4;
    }
  }
}
console.log(`${checks} SSANoMerge closure runtime checks passed`);
fs.rmSync(directory, { recursive: true });
