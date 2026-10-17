import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dir, "../..");
const argument = process.argv[2];
if (!argument) throw new Error("Usage: bun scripts/test/wasmgc-cli-args.ts <prebuilt-wasmgc-cli>");
const binary = fs.realpathSync(argument);
fs.mkdirSync(path.join(root, ".tmp"), { recursive: true });
const directory = fs.mkdtempSync(path.join(root, ".tmp/wasmgc-cli-args-"));
const commands: unknown[] = [];
const hash = (file: string) => createHash("sha256").update(fs.readFileSync(file)).digest("hex");
fs.writeFileSync(path.join(directory, "identity.json"), JSON.stringify({ binary, sha256: hash(binary), harness: { path: import.meta.path, sha256: hash(import.meta.path) } }, null, 2));
function run(command: string, args: string[]) {
  const result = spawnSync(command, args, { cwd: root, encoding: "utf8", timeout: 30_000 });
  commands.push({ command, args, status: result.status, signal: result.signal, stdout: result.stdout, stderr: result.stderr });
  fs.writeFileSync(path.join(directory, "commands.json"), JSON.stringify(commands, null, 2));
  assert.equal(result.status, 0, `${command} failed; artifacts: ${directory}`);
  return result.stdout;
}
const input = path.join(directory, "input.wasm");
const source = path.join(directory, "input.wat");
fs.writeFileSync(source, '(module (func (export "run") (result i32) i32.const 3 i32.const 4 i32.add))');
run("wasm-tools", ["parse", source, "-o", input]);
const outputs = [];
for (const separator of [false, true]) {
  const output = path.join(directory, separator ? "separator.wasm" : "plain.wasm");
  run("moonrun", [binary, ...(separator ? ["--"] : []), input, "--precompute", "-o", output]);
  assert(fs.existsSync(output), `CLI did not write its requested output; artifacts: ${directory}`);
  run("wasm-tools", ["validate", "--features", "all", output]);
  const printed = run("wasm-tools", ["print", output]);
  assert(!printed.includes("i32.add"), "The requested pass must run");
  const checker = path.join(directory, "check.cjs");
  fs.writeFileSync(checker, 'const fs=require("node:fs"),assert=require("node:assert/strict");const e=new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2]))).exports;assert.equal(e.run(),7);');
  run("node", [checker, output]);
  outputs.push({ separator, bytes: fs.statSync(output).size, sha256: hash(output) });
}
assert.equal(outputs[0].sha256, outputs[1].sha256);
fs.writeFileSync(path.join(directory, "summary.json"), JSON.stringify({ complete: true, binary, sha256: hash(binary), outputs }, null, 2));
console.log(`WasmGC CLI entry-point checks passed; artifacts: ${directory}`);
