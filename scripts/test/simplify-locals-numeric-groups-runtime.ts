import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";

// Separate V8 execution covers live i64/f32/f64 remaps. The bounded Moon
// declaration-group tests execute i32 values and validate the other types.
const root = path.resolve(import.meta.dir, "../..");
const [starArg, oracleArg] = process.argv.slice(2);
if (!starArg || !oracleArg) throw new Error("Usage: bun scripts/test/simplify-locals-numeric-groups-runtime.ts <native-starshine> <v133-wasm-opt>");
const star = fs.realpathSync(path.resolve(starArg));
const oracle = fs.realpathSync(path.resolve(oracleArg));
const directory = fs.mkdtempSync(path.join(root, ".tmp/sl-numeric-groups-runtime-"));
const commands: { command: string; args: string[] }[] = [];
const hash = (file: string) => createHash("sha256").update(fs.readFileSync(file)).digest("hex");
function run(command: string, args: string[]): string {
  commands.push({ command, args });
  fs.writeFileSync(path.join(directory, "commands.json"), JSON.stringify(commands, null, 2));
  try {
    return execFileSync(command, args, { cwd: root, encoding: "utf8", timeout: 30_000, maxBuffer: 16 * 1024 * 1024 });
  } catch (error) {
    const failure = error as Error & { status?: number; stdout?: string; stderr?: string };
    fs.writeFileSync(path.join(directory, "failure.json"), JSON.stringify({ command, args, status: failure.status, stdout: failure.stdout, stderr: failure.stderr }, null, 2));
    throw error;
  }
}
const node = process.env.NODE_BIN ?? "node";
const wasmTools = process.env.WASM_TOOLS_BIN ?? "wasm-tools";
function localDeclarationCounts(file: string): number[] {
  const bytes = fs.readFileSync(file);
  let offset = 8;
  const uleb = (): number => {
    let value = 0, shift = 0;
    for (;;) {
      const byte = bytes[offset++];
      assert.notEqual(byte, undefined, "truncated fixture LEB");
      value += (byte & 127) * 2 ** shift;
      if (byte < 128) return value;
      shift += 7;
      assert(shift < 35, "oversized fixture LEB");
    }
  };
  while (offset < bytes.length) {
    const id = bytes[offset++];
    const size = uleb(), end = offset + size;
    assert(end <= bytes.length, "truncated fixture section");
    if (id === 10) {
      const count = uleb(), declarations = [];
      for (let i = 0; i < count; i++) {
        const bodySize = uleb(), bodyEnd = offset + bodySize;
        declarations.push(uleb());
        assert(bodyEnd <= end, "truncated fixture body");
        offset = bodyEnd;
      }
      assert.equal(offset, end);
      return declarations;
    }
    offset = end;
  }
  throw new Error("Fixture has no code section");
}
assert.match(run(oracle, ["--version"]), /\b133\b/);
const checker = path.join(directory, "check.cjs");
fs.writeFileSync(checker, String.raw`
const fs = require('node:fs'), assert = require('node:assert/strict');
let events = [];
const e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {
  env: { mark32(id, value) {events.push([id, value]); return value;},
         mark64(id, value) {events.push([id, value.toString()]); return value;} }
}).exports;
const bits32 = [-2147483648, -1, 0, 1, 2147483647, 0x7f800000, 0x7fc12345, 0x7f812345];
const bits64 = [-9223372036854775808n, -1n, 0n, 1n, 9223372036854775807n, 0x7ff0000000000000n, 0x7ff8123456789abcn, 0x7ff0123456789abcn];
const floats = [[0, -0], [-0, 0], [1.25, -13.5], [-Infinity, Infinity]];
const scratch = new DataView(new ArrayBuffer(8));
function f32bits(value) {scratch.setFloat32(0, value, true); return scratch.getInt32(0, true);}
function f64bits(value) {scratch.setFloat64(0, value, true); return scratch.getBigInt64(0, true);}
const observations = [];
for (const name of ['root', 'loop', 'conditional'])
for (const x of bits32) for (const y of bits64) for (const [f, d] of floats)
for (const trapping of [0, 1]) {
  events = [];
  let result = null, trap = false;
  try {result = e[name](x, y, f, d, trapping);} catch(error) {
    assert(error instanceof WebAssembly.RuntimeError); trap = true;
  }
  assert.equal(trap, trapping === 1, name+' trap');
  assert.deepEqual(events, trapping ? [[1,x]] : [[1,x],[2,y.toString()]], name+' effects');
  if(!trap) assert.deepEqual(result, [x^0x55,y^0x55n,x^0x55,y^0x55n,x,y,x,y,f32bits(f),f64bits(d)], name+' distinct same-type values, exact bits and fixed params');
  observations.push({name,x,y,f32:f32bits(f),f64:f64bits(d),trapping,result,trap,events});
}
process.stdout.write(JSON.stringify({engine: process.version,cases: observations.length,observations},
  (_, value) => typeof value === 'bigint' ? value.toString()+'n' : value));
`);

const stores = `i32.const 1 local.get 0 call 0 local.set 9
local.get 4 if unreachable end
i32.const 2 local.get 1 call 1 local.set 10
local.get 0 f32.reinterpret_i32 local.set 11
local.get 1 f64.reinterpret_i64 local.set 12`;
// Copy aliases make SL change each body before its declaration grouping step.
const copies = "local.get 9 local.set 5 local.get 10 local.set 6 local.get 11 local.set 7 local.get 12 local.set 8";
const distinguish = `local.get 5 i32.const 85 i32.xor local.set 5
local.get 6 i64.const 85 i64.xor local.set 6
local.get 7 i32.reinterpret_f32 i32.const 85 i32.xor f32.reinterpret_i32 local.set 7
local.get 8 i64.reinterpret_f64 i64.const 85 i64.xor f64.reinterpret_i64 local.set 8`;
const results = "local.get 5 local.get 6 local.get 7 i32.reinterpret_f32 local.get 8 i64.reinterpret_f64 local.get 9 local.get 10 local.get 11 i32.reinterpret_f32 local.get 12 i64.reinterpret_f64 local.get 2 i32.reinterpret_f32 local.get 3 i64.reinterpret_f64";
const layouts = [stores, "loop " + stores + " end", "local.get 0 if " + stores + " else " + stores + " end"];
const names = ["root", "loop", "conditional"];
const wat = `(module
(import "env" "mark32" (func (param i32 i32) (result i32)))
(import "env" "mark64" (func (param i32 i64) (result i64)))
${layouts.map((body, i) => `(func (export "${names[i]}") (param i32 i64 f32 f64 i32) (result i32 i64 i32 i64 i32 i64 i32 i64 i32 i64)
(local i32 i64 f32 f64 i32 i64 f32 f64) ${body} ${copies} ${distinguish} ${results})`).join("\n")})`;
const source = path.join(directory, "input.wat");
const input = path.join(directory, "input.wasm");
fs.writeFileSync(source, wat + "\n");
run(wasmTools, ["parse", source, "-o", input]);
run(wasmTools, ["validate", "--features", "all", input]);
assert.deepEqual(localDeclarationCounts(input), [8, 8, 8]);
const reference = JSON.parse(run(node, [checker, input]));
fs.writeFileSync(path.join(directory, "input-observations.json"), JSON.stringify(reference));
const outputs = [];
for (const pass of ["simplify-locals", "simplify-locals-nostructure"])
for (const tool of ["starshine", "binaryen"])
for (const repetitions of [1, 2]) {
  const name = `${tool}-${pass}-${repetitions}`;
  const output = path.join(directory, name + ".wasm");
  run(tool === "starshine" ? star : oracle, [
    ...(tool === "binaryen" ? ["--all-features", "--disable-compact-imports"] : []),
    input, ...Array(repetitions).fill("--" + pass), "-o", output,
  ]);
  run(wasmTools, ["validate", "--features", "all", output]);
  if (tool === "starshine") assert.deepEqual(localDeclarationCounts(output), [4, 4, 4], name + " grouped live numeric declarations");
  fs.writeFileSync(path.join(directory, name + ".wat"), run(wasmTools, ["print", output]));
  const actual = JSON.parse(run(node, [checker, output]));
  assert.deepEqual(actual, reference, name);
  fs.writeFileSync(path.join(directory, name + "-observations.json"), JSON.stringify(actual));
  outputs.push({ name, sha256: hash(output), bytes: fs.statSync(output).size, comparisons: actual.cases });
}
const summary = {
  complete: true, star: { path: star, sha256: hash(star) }, oracle: { path: oracle, sha256: hash(oracle) },
  node: run(node, ["--version"]).trim(), wasmTools: run(wasmTools, ["--version"]).trim(),
  harnessSha256: hash(import.meta.path), inputSha256: hash(input),
  inputCases: reference.cases, comparisons: outputs.reduce((n, o) => n + o.comparisons, 0), outputs,
};
fs.writeFileSync(path.join(directory, "summary.json"), JSON.stringify(summary, null, 2));
console.log(`${summary.comparisons} SL numeric-group V8 comparisons passed; artifacts: ${directory}`);
