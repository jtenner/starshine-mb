import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";

// This lane executes in a separate Node process, so all wasm results use V8.
const root = path.resolve(import.meta.dir, "../..");
const [binaryArg, oracleArg] = process.argv.slice(2);
if (!binaryArg || !oracleArg) throw new Error("Usage: bun scripts/test/tuple-alias-capture-runtime.ts <fresh-native-starshine> <verified-v133-wasm-opt>");
const starshine = fs.realpathSync(path.resolve(binaryArg));
const oracle = fs.realpathSync(path.resolve(oracleArg));
const wasmTools = process.env.WASM_TOOLS_BIN ?? "wasm-tools";
const node = process.env.NODE_BIN ?? "node";
fs.mkdirSync(path.join(root, ".tmp"), { recursive: true });
const directory = fs.mkdtempSync(path.join(root, ".tmp/tuple-alias-runtime-"));
const hash = (file: string) => createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const commands: { command: string; args: string[] }[] = [];
function run(command: string, args: string[]): string {
  commands.push({ command, args });
  fs.writeFileSync(path.join(directory, "commands.json"), JSON.stringify(commands, null, 2));
  try {
    return execFileSync(command, args, { cwd: root, timeout: 30_000, encoding: "utf8", maxBuffer: 16 * 1024 * 1024 });
  } catch (error) {
    const failure = error as Error & { stdout?: string; stderr?: string; status?: number; signal?: string };
    fs.writeFileSync(path.join(directory, "command-failure.json"), JSON.stringify({ command, args, status: failure.status, signal: failure.signal, stdout: failure.stdout, stderr: failure.stderr }, null, 2));
    throw error;
  }
}
const effectCheckerSource = String.raw`
const fs = require("node:fs"), assert = require("node:assert/strict");
let events = [];
const e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {
  env: { mark(id, value) { events.push([id, value]); return value; } }
}).exports;
const observations = [];
for (const name of ["prefix", "trailing", "chain", "mixed", "delayed"])
for (const limit of [0, 1, 2, 4, 8])
for (const capture of [0, 1, 3, 99])
for (const initial of [[0, 0], [7, -13], [-2147483648, 2147483647]])
for (const trapAt of [-1, 0, 1, 3]) {
  events = [];
  const args = [limit, capture, ...initial, trapAt];
  const trapped = trapAt >= 0 && trapAt < limit;
  const steps = trapped ? trapAt + 1 : limit;
  const expectedEvents = [];
  for (let i = 0; i < steps; ++i) expectedEvents.push([1, 11 + i], [2, 100 + i]);
  let actual, trap = false;
  try { actual = e[name](...args); } catch (error) {
    assert(error instanceof WebAssembly.RuntimeError, name + " unexpected exception");
    trap = true;
  }
  assert.equal(trap, trapped, name + " trap " + JSON.stringify(args));
  assert.deepEqual(events, expectedEvents, name + " producer evaluation order " + JSON.stringify(args));
  if (!trapped) {
    let expected = initial.slice();
    if (limit > 0) {
      if (name === "delayed") expected = limit === 1 ? initial.slice() : [11 + limit - 2, 100 + limit - 2];
      else {
        const captured = capture < limit ? [11 + capture, 100 + capture] : initial.slice();
        expected = name === "mixed" ? [captured[0], 100 + limit - 1] : captured;
      }
    }
    assert.deepEqual(actual, expected, name + " values " + JSON.stringify(args));
  }
  observations.push({ name, args, actual: actual ?? null, trap, events: events.slice() });
}
for (const name of ["partial_block_set", "partial_block_tee", "partial_loop_set", "partial_loop_tee"]) {
  events = [];
  const actual = e[name]();
  assert.equal(actual, 100, name + " published lane value");
  assert.deepEqual(events, [[1, 11], [2, 100], [3, 100]], name + " publication and producer order");
  observations.push({ name, args: [], actual, trap: false, events: events.slice() });
}
for (const name of ["copy_prefix", "nested_prefix", "scalar_prefix"])
for (const trapping of [0, 1]) {
  events = [];
  let actual = null, trap = false;
  try { actual = e[name](trapping); } catch (error) {
    assert(error instanceof WebAssembly.RuntimeError, name + " unexpected exception");
    trap = true;
  }
  assert.equal(trap, trapping === 1, name + " prefix trap");
  if (!trap) assert.equal(actual, 111, name + " copy value");
  assert.deepEqual(events, [[9, 9]], name + " copy prefix effect");
  observations.push({ name, args: [trapping], actual, trap, events: events.slice() });
}
for (const name of ["partial_block_call", "partial_loop_call"]) {
  events = [];
  const actual = e[name]();
  assert.equal(actual, 100, name + " published tee value");
  assert.deepEqual(events, [[1, 11], [2, 100], [4, 100], [3, 100]], name + " tee call order");
  observations.push({ name, args: [], actual, trap: false, events: events.slice() });
}
for (const layout of ["block", "loop", "root", "reduced_loop"])
for (const trapping of [false, true]) {
  const name = "earlier_" + layout + (trapping ? "_trap" : "_call");
  events = [];
  let actual = null, trap = false;
  try { actual = e[name](); } catch (error) {
    assert(error instanceof WebAssembly.RuntimeError, name + " unexpected exception");
    trap = true;
  }
  assert.equal(trap, trapping, name + " earlier argument trap");
  if (!trap) assert.equal(actual, 100, name + " later argument publication");
  assert.deepEqual(events, trapping ? [] : [[7, 77], [1, 11], [2, 100], [5, 77], [6, 11], [3, 100]], name + " earlier argument precedes producer");
  observations.push({ name, args: [], actual, trap, events: events.slice() });
}
process.stdout.write(JSON.stringify({ engine: process.version, cases: observations.length, observations }));
`;

const pureCheckerSource = String.raw`
const fs = require("node:fs"), assert = require("node:assert/strict");
const e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2]))).exports;
const observations = [];
for (const name of ["prefix", "trailing", "chain", "delayed"])
for (const argument of [0, 1, 2, 3, 4, -1, -4, -2147483648, 2147483647])
for (const capture of [-1, 0, 1, 3, 99]) {
  const limit = (argument & 3) + 1;
  const expected = name === "delayed"
    ? limit === 1 ? [0, 0] : [11 + limit - 2, 100 + limit - 2]
    : capture >= 0 && capture < limit ? [11 + capture, 100 + capture] : [0, 0];
  const args = [argument, capture];
  const actual = e[name](...args);
  assert.deepEqual(actual, expected, name + " old capture " + JSON.stringify(args));
  observations.push({ name, args, actual });
}
process.stdout.write(JSON.stringify({ engine: process.version, cases: observations.length, observations }));
`;

const sourceCheckerSource = String.raw`
const fs = require("node:fs"), assert = require("node:assert/strict");
let events = [];
const e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {
  env: { mark(id, value) { events.push([id, value]); return value; } }
}).exports;
const observations = [];
for (const argument of [-2147483648, -1, 0, 1, 10, 42, 2147483647])
for (const name of ["root", "loop", "typed_entry", "mutable_parameter", "overlap", "trapping", "calls", "multi_group", "interleaved_write", "publication_0", "publication_2", "publication_4"]) {
  events = [];
  let actual = null, trap = false;
  try { actual = e[name](argument, 7); } catch (error) {
    assert(error instanceof WebAssembly.RuntimeError, name + " unexpected exception");
    trap = true;
  }
  assert.equal(trap, name === "trapping", name + " trap");
  const expected = name.startsWith("publication_") ? (Math.imul(argument, 2 + Number(name.slice("publication_".length))) + 102) | 0
    : name === "typed_entry" ? (argument + 9) | 0
    : name === "multi_group" ? (Math.imul(argument, 6) + 21) | 0
    : (Math.imul(argument, 2) + 3 + (name === "interleaved_write" ? 7 : 0)) | 0;
  if (!trap) assert.equal(actual, expected, name + " value");
  const expectedEvents = name === "calls" ? [[1, (argument + 1) | 0], [2, (argument + 2) | 0]]
    : name === "multi_group" ? [[1, (argument + 5) | 0], [2, (argument + 6) | 0]] : [];
  assert.deepEqual(events, expectedEvents, name + " effects");
  observations.push({ name, argument, actual, trap, events: events.slice() });
}
process.stdout.write(JSON.stringify({ engine: process.version, cases: observations.length, observations }));
`;

const callParentCheckerSource = String.raw`
const fs = require("node:fs"), assert = require("node:assert/strict");
let events = [];
const e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {
  env: {
    mark(value) { events.push([0, value]); return value; },
    observe(first, second) { events.push([1, first, second]); return second; }
  }
}).exports;
const observations = [];
for (const argument of [-2147483648, -1, 0, 1, 10, 42, 2147483647])
for (const name of ["call_parent", "earlier_operand", "earlier_trap", "later_operand"]) {
  events = [];
  const a = (argument + 1) | 0, b = (argument + 2) | 0;
  let actual = null, trap = false;
  try { actual = e[name](argument); } catch (error) {
    assert(error instanceof WebAssembly.RuntimeError, name + " unexpected exception");
    trap = true;
  }
  assert.equal(trap, name === "earlier_trap", name + " trap");
  if (!trap) assert.equal(actual, (a + b) | 0, name + " copied values");
  const tail = name === "call_parent" ? [[0, a]]
    : name === "earlier_operand" ? [[0, 77], [1, 77, a]]
    : name === "later_operand" ? [[0, b], [1, a, b]] : [];
  assert.deepEqual(events, [[0, a], [0, b], ...tail], name + " call operand order");
  observations.push({ name, argument, actual, trap, events: events.slice() });
}
process.stdout.write(JSON.stringify({ engine: process.version, cases: observations.length, observations }));
`;

const wideCheckerSource = String.raw`
const fs = require("node:fs"), assert = require("node:assert/strict");
let events = [];
const e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {
  env: { mark(value) { events.push(value); return value; } }
}).exports;
const observations = [];
for (const name of Object.keys(e))
for (const argument of [-2147483648, -1, 0, 1, 10, 42, 2147483647]) {
  const overlap = name.startsWith("overlap_");
  const arity = overlap ? 3 : Number(name.split("_")[1]);
  const values = Array.from({length: arity}, (_, lane) => (argument + lane + 1) | 0);
  const expected = overlap ? [values[0], values[1], values[1]] : values;
  events = [];
  const actual = e[name](argument);
  assert.deepEqual(actual, expected, name + " individual copied lanes");
  assert.deepEqual(events, values, name + " source event order");
  observations.push({name, argument, actual, events: events.slice()});
}
assert.equal(observations.length, 126, "all18 wide/overlap functions must execute");
process.stdout.write(JSON.stringify({engine: process.version, cases: observations.length, observations}));
`;

// Lowering can add scalar wrapper blocks around tuple producers and copies.
// Count the original direct scalar-copy payload, not those new wrappers.
const mixedLaneCheckerSource = String.raw`
const fs = require("node:fs"), assert = require("node:assert/strict");
const module_ = new WebAssembly.Module(fs.readFileSync(process.argv[2]));
const width = 64, observations = [];
for (const argument of [-2147483648, -1, 0, 1, 10, 42, 2147483647])
for (let trapAt = -1; trapAt < width; ++trapAt) {
  const events = [], sentinel = new Error("host stop");
  const e = new WebAssembly.Instance(module_, {env: {mark(value) {
    events.push(value);
    if (events.length - 1 === trapAt) throw sentinel;
    return value;
  }}}).exports;
  const expected = Array.from({length: width}, (_, lane) => (argument + lane + 1) | 0);
  let actual = null, trapped = false;
  try { actual = e.run(argument); } catch (error) {
    assert.equal(error, sentinel, "only the requested host exception may escape");
    trapped = true;
  }
  assert.equal(trapped, trapAt >= 0, "host exception boundary");
  if (!trapped) assert.deepEqual(actual, expected, "all mixed numeric lane bits");
  assert.deepEqual(events, expected.slice(0, trapAt < 0 ? width : trapAt + 1), "each producer call occurs once in source order");
  observations.push({argument, trapAt, actual, trapped, events});
}
assert.equal(observations.length, 455);
process.stdout.write(JSON.stringify({engine: process.version, cases: observations.length, observations}));
`;

function directScalarCopies(text: string): number {
  const flat = text.replace(/;;[^\n]*/g, "").replace(/\s+/g, " ");
  return [...flat.matchAll(/\bblock \(result i32\) (?:local\.get \S+ local\.set \S+ local\.get \S+|local\.get \S+ local\.get \S+ local\.set \S+) end local\.set \S+/g)].length;
}

try {
  const scopes = [
    { name: "pure", file: "alias-captures.wat", checker: pureCheckerSource, requiredCopies: 4 },
    { name: "effects", file: "alias-captures-effects.wat", checker: effectCheckerSource, requiredCopies: 0 },
    { name: "source", file: "source-only-arithmetic.wat", checker: sourceCheckerSource, requiredCopies: 0 },
    { name: "call-parent", file: "copy-call-parent.wat", checker: callParentCheckerSource, requiredCopies: 0 },
    { name: "wide", file: "wide-scalar-copies.wat", checker: wideCheckerSource, requiredCopies: 0 },
    { name: "mixed-lanes", file: "available-mixed-lanes.wat", checker: mixedLaneCheckerSource, requiredCopies: 0 },
  ];
  const oracleVersion = run(oracle, ["--version"]).trim();
  assert(/\bversion\s+133\b/.test(oracleVersion), `Binaryen v133 required; found ${oracleVersion}`);
  const identity = {
    harness: { path: import.meta.path, sha256: hash(import.meta.path) },
    fixtures: scopes.map(scope => {
      const fixture = path.join(root, "tests/fixtures/tuple-optimization", scope.file);
      return { scope: scope.name, path: fixture, sha256: hash(fixture), checkerSha256: createHash("sha256").update(scope.checker).digest("hex") };
    }),
    starshine: { path: starshine, sha256: hash(starshine), modified: fs.statSync(starshine).mtime.toISOString() },
    oracle: { path: oracle, sha256: hash(oracle), version: oracleVersion },
    tools: { node: run(node, ["--version"]).trim(), wasmTools: run(wasmTools, ["--version"]).trim() },
  };
  fs.writeFileSync(path.join(directory, "identity.json"), JSON.stringify(identity, null, 2));
  const cleanup = ["--tuple-optimization", "--simplify-locals-nostructure", "--coalesce-locals", "--vacuum"];
  const pipelines = [
    { name: "once", passes: ["--tuple-optimization"] },
    { name: "twice", passes: ["--tuple-optimization", "--tuple-optimization"] },
    { name: "cleanup", passes: cleanup },
    { name: "cleanup-twice", passes: [...cleanup, ...cleanup] },
  ];
  const outputs: { scope: string; name: string; tool: string; sha256: string; bytes: number; cases: number; directScalarCopies: number }[] = [];
  let originalCases = 0;
  for (const scope of scopes) {
    const fixture = path.join(root, "tests/fixtures/tuple-optimization", scope.file);
    const input = path.join(directory, `${scope.name}-input.wasm`);
    const checker = path.join(directory, `${scope.name}-check.cjs`);
    fs.writeFileSync(checker, scope.checker);
    run(wasmTools, ["parse", fixture, "-o", input]);
    run(wasmTools, ["validate", "--features", "all", input]);
    const printedInput = run(wasmTools, ["print", input]);
    fs.writeFileSync(path.join(directory, `${scope.name}-input.wat`), printedInput);
    if (scope.requiredCopies) assert.equal(directScalarCopies(printedInput), scope.requiredCopies, "Each pure alias layout must start with its direct scalar-copy payload");
    const baselineText = run(node, [checker, input]);
    fs.writeFileSync(path.join(directory, `${scope.name}-original-observations.json`), baselineText);
    const baseline = JSON.parse(baselineText);
    originalCases += baseline.cases;
    const scopedPipelines = scope.name === "source" ? [
      ...pipelines,
      { name: "sl-only", passes: ["--simplify-locals-nostructure"] },
      { name: "sl-only-twice", passes: ["--simplify-locals-nostructure", "--simplify-locals-nostructure"] },
    ] : pipelines;
    for (const { name, passes } of scopedPipelines) {
      for (const [tool, command] of [["starshine", starshine], ["binaryen133", oracle]]) {
        const output = path.join(directory, `${scope.name}-${tool}-${name}.wasm`);
        run(command, [input, ...passes, ...(tool === "binaryen133" ? ["--all-features", "--disable-compact-imports"] : []), "-o", output]);
        run(wasmTools, ["validate", "--features", "all", output]);
        const printed = run(wasmTools, ["print", output]);
        fs.writeFileSync(path.join(directory, `${scope.name}-${tool}-${name}.wat`), printed);
        const remainingCopies = directScalarCopies(printed);
        if (tool === "starshine" && scope.name === "wide" && name === "once") {
          // The16 disjoint copies must lose their scalar wrappers. The two
          // read-after-write overlap controls can retain their original block.
          const scalarWrappers = [...printed.matchAll(/\bblock \(result i32\)/g)].length;
          assert(scalarWrappers <= 2, `wide copies retain ${scalarWrappers} scalar wrappers`);
          assert(fs.statSync(output).size < fs.statSync(input).size, "wide copies must save encoded bytes");
        }
        if (tool === "starshine" && scope.requiredCopies) assert.equal(remainingCopies, 0, `${name}: the original pure tuple alias-copy payloads were not transformed`);
        const observations = run(node, [checker, output]);
        fs.writeFileSync(path.join(directory, `${scope.name}-${tool}-${name}-observations.json`), observations);
        assert.deepEqual(JSON.parse(observations), baseline, `${scope.name}/${tool}/${name} differs from original; artifacts: ${directory}`);
        outputs.push({ scope: scope.name, name, tool, sha256: hash(output), bytes: fs.statSync(output).size, cases: baseline.cases, directScalarCopies: remainingCopies });
        fs.writeFileSync(path.join(directory, "progress.json"), JSON.stringify({ ...identity, complete: false, originalCases, outputs }, null, 2));
      }
    }
  }
  const summary = { ...identity, complete: true, originalCases, outputs };
  fs.writeFileSync(path.join(directory, "summary.json"), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify(summary, null, 2));
  console.log(`${outputs.reduce((total, output) => total + output.cases, 0)} tuple alias V8 comparisons passed; artifacts: ${directory}`);
} catch (error) {
  fs.writeFileSync(path.join(directory, "failure.txt"), error instanceof Error ? `${error.stack}\n${String(error.cause ?? "")}` : String(error));
  throw new Error(`Tuple alias runtime lane failed; artifacts: ${directory}`, { cause: error });
}
