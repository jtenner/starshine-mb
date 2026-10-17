import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dir, "../..");
const [starArg, oracleArg] = process.argv.slice(2);
if (!starArg || !oracleArg) throw new Error("Usage: bun scripts/test/dae-call-sink-context-runtime.ts <native-starshine> <v133-wasm-opt>");
const star = fs.realpathSync(path.resolve(starArg));
const oracle = fs.realpathSync(path.resolve(oracleArg));
const directory = fs.mkdtempSync(path.join(root, ".tmp/dae-call-sink-runtime-"));
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
const nodeFlags = ["--experimental-wasm-custom-descriptors"];
assert.match(run(oracle, ["--version"]), /\b133\b/);
const checker = path.join(directory, "check.cjs");
fs.writeFileSync(checker, String.raw`
const fs = require('node:fs'), assert = require('node:assert/strict');
const module_ = new WebAssembly.Module(fs.readFileSync(process.argv[2]));
const observations = [];
const integers = [-2147483648, -1, 0, 1, 7, 13, 2147483647];
const wides = [-9223372036854775808n, -1n, 0n, 11n, 9223372036854775807n];
for (const x of integers) for (const y of wides) for (let stop = -1; stop < 5; stop++) {
  const events = [], sentinel = new Error('host-stop');
  function record(kind, value) {
    events.push([kind, String(value)]);
    if (events.length - 1 === stop) throw sentinel;
    return value;
  }
  const e = new WebAssembly.Instance(module_, {host: {
    sink32(value) {record('i32', value);},
    sink64(value) {record('i64', value);},
    mark32(value) {return record('result', value);}
  }}).exports;
  const expected = [['i32','7'],['i32',String(x)],['i64','11'],['i64',String(y)],['result','13']];
  let trapped = false;
  try {assert.equal(e.run(x,y), undefined);} catch (error) {
    assert.equal(error, sentinel, 'preserve the original host exception'); trapped = true;
  }
  assert.equal(trapped, stop >= 0, 'every host call retains its trap boundary');
  assert.deepEqual(events, stop < 0 ? expected : expected.slice(0,stop+1), 'exact event order and integer values');
  observations.push({x,y,stop,trapped,events:events.slice()});
  if (stop < 0) {
    events.length = 0;
    assert.equal(e.public32(x), undefined);
    assert.equal(e.public64(y), undefined);
    assert.deepEqual(events, [['i32',String(x)],['i64',String(y)]], 'public argument contracts');
    observations.push({public:true,x,y,events:events.slice()});
  }
}
for (const x of integers) for (const mode of ['gc_run', 'gc_nonnull', 'gc_null'])
for (let stop = -1; stop < 2; stop++) {
  const events = [], sentinel = new Error('gc-host-stop');
  const e = new WebAssembly.Instance(module_, {host: {
    sink32() {throw new Error('unexpected numeric sink');},
    sink64() {throw new Error('unexpected wide sink');},
    mark32(value) {
      events.push(['result',String(value)]);
      if (events.length - 1 === stop) throw sentinel;
      return value;
    }
  }}).exports;
  let actual = null, trap = 'none';
  try { actual = mode === 'gc_run' ? e.gc_run(x) : e.gc_nullable(x, mode === 'gc_null' ? 1 : 0); }
  catch (error) {
    if (error === sentinel) trap = 'host';
    else {assert(error instanceof WebAssembly.RuntimeError); trap = 'wasm';}
  }
  const expectedTrap = stop === 0 ? 'host' : mode === 'gc_null' ? 'wasm' : stop === 1 ? 'host' : 'none';
  assert.equal(trap, expectedTrap, 'GC null/host trap boundary');
  if (trap === 'none') assert.equal(actual,x,'GC field and refined call results');
  const count = stop === 0 || mode === 'gc_null' ? 1 : 2;
  assert.deepEqual(events,Array.from({length:count},()=>['result',String(x)]),'GC host calls occur once in source order');
  observations.push({mode,x,stop,actual,trap,events});
}
process.stdout.write(JSON.stringify({engine:process.version,cases:observations.length,observations},
  (_, value) => typeof value === 'bigint' ? value.toString()+'n' : value));
`);
const source = path.join(root, "tests/fixtures/dead-argument-elimination/call-sink-context.wat");
const input = path.join(directory, "input.wasm");
run(wasmTools, ["parse", source, "-o", input]);
run(wasmTools, ["validate", "--features", "all", input]);
const reference = JSON.parse(run(node, [...nodeFlags, checker, input]));
fs.writeFileSync(path.join(directory, "input-observations.json"), JSON.stringify(reference));
const outputs = [];
for (const pass of ["dae", "dae-optimizing"])
for (const tool of ["starshine", "binaryen133"]) {
  let previous = input;
  for (let iteration = 1; iteration <= 2; iteration++) {
    const output = path.join(directory, `${pass}-${tool}-${iteration}.wasm`);
    run(tool === "starshine" ? star : oracle, [
      ...(tool === "binaryen133" ? ["--all-features", "--disable-compact-imports"] : []),
      `--${pass}`, previous, "-o", output,
    ]);
    run(wasmTools, ["validate", "--features", "all", output]);
    const actual = JSON.parse(run(node, [...nodeFlags, checker, output]));
    assert.equal(actual.cases, reference.cases);
    assert.deepEqual(actual.observations, reference.observations);
    fs.writeFileSync(output + ".observations.json", JSON.stringify(actual));
    outputs.push({ pass, tool, iteration, sha256: hash(output), bytes: fs.statSync(output).size, cases: actual.cases });
    previous = output;
  }
}
fs.writeFileSync(path.join(directory, "result.json"), JSON.stringify({
  binaries: {starshine: {path: star, sha256: hash(star)}, binaryen133: {path: oracle, sha256: hash(oracle)}},
  sourceSha256: hash(source), runtimeCompatibility: "Node 26 custom descriptors enabled for every variant; Binaryen compact imports disabled only for runtime compatibility; optimizer transforms retained.", node: run(node, ["--version"]).trim(), nodeFlags, outputs,
}, null, 2));
console.log(`${outputs.reduce((sum, item) => sum + item.cases, 0)} DAE sink-context V8 comparisons passed; artifacts: ${directory}`);
