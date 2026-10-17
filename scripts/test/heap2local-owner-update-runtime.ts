import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import assert from "node:assert/strict";

// Build src/cmd in native release mode before this dedicated runtime lane.
// The required CLI argument prevents a fallback to an old target/native binary.
const root = path.resolve(import.meta.dir, "../..");
const [cliArg, oracleArg] = process.argv.slice(2);
if (!cliArg) throw new Error("Usage: bun scripts/test/heap2local-owner-update-runtime.ts <fresh-native-starshine> [verified-v133-wasm-opt]");
const starshine = fs.realpathSync(path.resolve(cliArg));
const oracle = oracleArg ? fs.realpathSync(path.resolve(oracleArg)) : undefined;
const wasmTools = process.env.WASM_TOOLS_BIN ?? "wasm-tools";
const node = process.env.NODE_BIN ?? "node";
// Binaryen's local cleanup can introduce exact reference types.
const nodeFlags = ["--experimental-wasm-custom-descriptors"];
const temporaryRoot = path.join(root, ".tmp");
fs.mkdirSync(temporaryRoot, { recursive: true });
const directory = fs.mkdtempSync(path.join(temporaryRoot, "heap2local-owner-runtime-"));
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

function transformCoverage(text: string): Record<string, number> {
  const functions = new Map<string, string>();
  for (const match of text.matchAll(/^  \(func\s+(?:(\$[^\s()]+)\s+)?\(;([0-9]+);\)[\s\S]*?(?=\n  \(|\n\)$)/gm)) {
    functions.set(match[2], match[0]);
    if (match[1]) functions.set(match[1], match[0]);
  }
  const result: Record<string, number> = {};
  for (const match of text.matchAll(/\(export "([^"]+)" \(func ([^\s()]+)\)\)/g)) {
    const body = functions.get(match[2]);
    assert(body, `Missing printed body for export ${match[1]}`);
    result[match[1]] = [...body.matchAll(/\b(?:struct|array)\.(?:new(?:_default|_fixed)?|get(?:_[su])?|set)\b/g)].length;
  }
  return result;
}

// A separate Node process uses V8 rather than Bun's WebAssembly implementation.
// Every call has a fixed expected result in addition to the original/output comparison.
const checkerSource = String.raw`
const fs = require("node:fs"), assert = require("node:assert/strict");
let events = [];
const instance = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {
  env: { mark(id, value) { events.push([id, value]); return value; } }
});
const e = instance.exports, observations = [];
function check(name, args, expected, expectedEvents = [], expectedOrder) {
  events = [];
  const actual = e[name](...args);
  assert.deepEqual(actual, expected, name + " " + JSON.stringify(args));
  assert.deepEqual(events, expectedEvents, name + " import order");
  if (expectedOrder !== undefined) assert.equal(e.order.value, expectedOrder, name + " global order");
  observations.push({ name, args, actual, events: events.slice(), order: expectedOrder });
}
const flags = [0, 1, -7];
const refs = [null, undefined, { id: 1 }, { id: 2 }, "reference", 0, NaN];
const boxes = [{ box: 1 }, { box: 2 }, { box: 3 }].map(payload => e.make_box(payload));
function refId(value) { return refs.findIndex(candidate => Object.is(candidate, value)); }
for (let ai = 0; ai < boxes.length; ++ai)
for (let bi = 0; bi < boxes.length; ++bi)
for (let ci = 0; ci < boxes.length; ++ci) {
  const ri = (ai + bi + ci + 1) % boxes.length;
  for (const name of ["straight_box_old_read", "straight_box_cycle"]) {
    events = [];
    const args = [boxes[ai], boxes[bi], boxes[ci], ...(name === "straight_box_old_read" ? [boxes[ri]] : [])];
    const actual = e[name](...args);
    const expected = name === "straight_box_old_read"
      ? [boxes[ri], boxes[ai], boxes[bi]]
      : [boxes[bi], boxes[ci], boxes[ai]];
    for (let field = 0; field < 3; ++field) assert.equal(actual[field], expected[field], name + " non-null identity " + [ai, bi, ci, ri, field]);
    assert.deepEqual(events, [], name + " unexpected import");
    observations.push({ name, args: [ai, bi, ci, ri], actual: actual.map(box => boxes.indexOf(box)) });
  }
}
for (const first of flags) for (const second of flags) {
  const a = first ? 10 : 11, b = first ? 20 : 21, c = first ? 30 : 31;
  check("old_read", [first, second], [100, a]);
  check("swap", [first, second], [b, a]);
  check("cycle", [first, second], [b, c, a]);
  check("selected", [first, second], second ? [b, a] : [a + 3, b - 7]);
  check("result_if_escape", [first, second], first ? (second ? [99, 100] : [10, 20]) : [11, 21]);
  for (const count of [0, 1, 2, 7, 16]) {
    let x = a, y = b;
    for (let i = 0; i < count; ++i) [x, y] = second ? [y, (x + i) | 0] : [(y + 1) | 0, (x - i) | 0];
    check("repeated", [first, second, count], [x, y]);
  }
  for (const inner of flags) {
    check("nested_first", [first, second, inner], [a, 70]);
    check("nested_second", [first, second, inner], [a, a]);
    check("independent", [first, second, inner], [b, a, second ? 40 : 41, second ? 30 : 31]);
    for (const fail of flags) {
      check("nested_abort", [first, second, inner, fail], fail ? [inner ? 70 : 71, a] : [500, a], [[1, 500]], 1);
    }
  }
  for (let ai = 0; ai < boxes.length; ++ai) for (let bi = 0; bi < boxes.length; ++bi) {
    const replacement = (ai + bi + 1) % boxes.length;
    for (const name of ["box_swap", "box_old_read"]) {
      const args = [first, second, boxes[ai], boxes[bi], ...(name === "box_old_read" ? [boxes[replacement]] : [])];
      const actual = e[name](...args);
      const expected = name === "box_swap"
        ? (first ? [boxes[bi], boxes[ai]] : [boxes[ai], boxes[bi]])
        : [boxes[replacement], first ? boxes[ai] : boxes[bi]];
      for (let field = 0; field < 2; ++field) assert.equal(actual[field], expected[field], name + " non-null Box identity " + [first, second, ai, bi, field]);
      observations.push({ name, args: [first, second, ai, bi, replacement], actual: actual.map(box => boxes.indexOf(box)) });
    }
  }
  for (let ai = 0; ai < refs.length; ++ai) for (let bi = 0; bi < refs.length; ++bi) {
    const actual = e.references(first, second, refs[ai], refs[bi]);
    const expected = first ? [refs[bi], refs[ai]] : [refs[ai], refs[bi]];
    for (let field = 0; field < 2; ++field) assert(Object.is(actual[field], expected[field]), "reference identity " + [first, second, ai, bi, field]);
    observations.push({ name: "references", args: [first, second, ai, bi], actual: actual.map(refId) });
  }
  const values = [0, 1, -1, 127, 128, 255, 256, 32767, 32768, 65535, 65536, -32769];
  for (let i = 0; i < values.length; ++i) {
    const left = values[i], right = values[(i + 5) % values.length];
    const oldByte = (first ? left : right) << 24 >> 24;
    const oldWord = (first ? right : left) & 65535;
    const byte = oldWord & 255, word = oldByte & 65535;
    check("packed", [first, second, left, right], [byte << 24 >> 24, byte, word << 16 >> 16, word]);
  }
  check("effects", [first, second], [c, a, 12], [[1, c], [2, a], [3, 12]], 123);
  check("unused_effects", [first, second], a, [[1, a], [2, 200], [3, 300]], 123);
  for (const fail of flags) {
    check("abort", [first, second, fail], fail ? [a, b] : [100, a], [[1, 100]], 1);
    check("unused_abort", [first, second, fail], fail ? a : 100, [[1, 100], [2, 200]], 12);
  }
}
// These calls exercise direct consumers of local.tee, so scalarization must
// preserve allocation effects even when no later owner read needs the values.
const arrayArguments = [
  [7, 9, -129],
  [-129, 32768, 65535],
  [-2147483648, 2147483647, -1],
];
const storeValues = [-129, 128, 32768, 65535, -2147483648, 2147483647];
for (const width of [32, 8, 16]) {
  const pack = value => width === 8 ? value << 24 >> 24 : width === 16 ? value << 16 >> 16 : value | 0;
  for (const operation of ["get", "set"])
  for (const suffix of ["zero", "negative", "end"])
  for (const abc of arrayArguments)
  for (const value of operation === "set" ? storeValues : [0]) {
    const name = "array_tee_i" + width + "_" + operation + "_" + suffix;
    const args = [...abc, ...(operation === "set" ? [value] : [])];
    events = [];
    let actual, trapped = false;
    try { actual = e[name](...args); } catch (error) {
      assert(error instanceof WebAssembly.RuntimeError, name + " unexpected exception");
      trapped = true;
    }
    assert.equal(trapped, suffix !== "zero", name + " bounds trap " + JSON.stringify(args));
    const expectedEvents = abc.map((item, index) => [index + 1, item]);
    if (operation === "set") expectedEvents.push([4, value]);
    assert.deepEqual(events, expectedEvents, name + " operand order " + JSON.stringify(args));
    if (!trapped) {
      const expected = operation === "set"
        ? [pack(value), pack(abc[1]), pack(abc[2])]
        : pack(abc[0]);
      assert.deepEqual(actual, expected, name + " packed values " + JSON.stringify(args));
    }
    observations.push({ name, args, actual: actual ?? null, trapped, events: events.slice() });
  }
}
// The earlier packed variant is retained heap. These flows require real
// scalarization of get_u masks, including their values before a later trap.
const unsignedValues = [0, 1, -1, 127, 128, 255, 256, 32767, 32768, 65535, 65536, -32769, -2147483648, 2147483647];
for (const width of [8, 16]) {
  const signed = value => width === 8 ? value << 24 >> 24 : value << 16 >> 16;
  const unsigned = value => value & (width === 8 ? 255 : 65535);
  for (const family of ["struct", "array", "array_tee"])
  for (let index = 0; index < unsignedValues.length; ++index)
  for (const fail of [0, 1]) {
    const a = unsignedValues[index], b = unsignedValues[(index + 5) % unsignedValues.length], c = unsignedValues[(index + 9) % unsignedValues.length];
    const name = "packed_unsigned_i" + width + "_" + family;
    const args = [a, b, c, fail];
    events = [];
    let actual, trapped = false;
    try { actual = e[name](...args); } catch (error) {
      assert(error instanceof WebAssembly.RuntimeError, name + " unexpected exception");
      trapped = true;
    }
    assert.equal(trapped, fail !== 0, name + " constructor trap " + JSON.stringify(args));
    const expectedEvents = family === "array_tee"
      ? [[1, a], [2, b], [3, c]]
      : [[1, unsigned(b)], [2, signed(c)], [3, unsigned(a)]];
    assert.deepEqual(events, fail ? expectedEvents.slice(0, 1) : expectedEvents, name + " unsigned operand order " + JSON.stringify(args));
    if (!trapped) {
      const expected = family === "array_tee"
        ? [unsigned(a), signed(a), unsigned(b), signed(b), unsigned(c), signed(c)]
        : [signed(b), unsigned(b), signed(c), unsigned(c), signed(a), unsigned(a)];
      assert.deepEqual(actual, expected, name + " signed/unsigned values " + JSON.stringify(args));
    }
    observations.push({ name, args, actual: actual ?? null, trapped, events: events.slice() });
  }
}
process.stdout.write(JSON.stringify({ engine: process.version, cases: observations.length, observations }));
`;

try {
  const fixture = path.join(root, "tests/fixtures/heap2local/owner-updates.wat");
  const input = path.join(directory, "input.wasm");
  const checker = path.join(directory, "check.cjs");
  fs.writeFileSync(checker, checkerSource);
  const tools = { node: run(node, ["--version"]).trim(), nodeFlags, wasmTools: run(wasmTools, ["--version"]).trim() };
  let oracleVersion: string | undefined;
  if (oracle) {
    oracleVersion = run(oracle, ["--version"]).trim();
    assert(/\bversion\s+133\b/.test(oracleVersion), `Binaryen v133 required; found ${oracleVersion}`);
  }
  const identity = {
    harness: { path: import.meta.path, sha256: hash(import.meta.path) },
    checkerSha256: createHash("sha256").update(checkerSource).digest("hex"),
    fixture: { path: fixture, sha256: hash(fixture) },
    starshine: { path: starshine, sha256: hash(starshine), modified: fs.statSync(starshine).mtime.toISOString() },
    oracle: oracle ? { path: oracle, sha256: hash(oracle), version: oracleVersion } : undefined,
    tools,
  };
  fs.writeFileSync(path.join(directory, "identity.json"), JSON.stringify(identity, null, 2));
  run(wasmTools, ["parse", fixture, "-o", input]);
  run(wasmTools, ["validate", "--features", "all", input]);
  const printedInput = run(wasmTools, ["print", input]);
  fs.writeFileSync(path.join(directory, "input.wat"), printedInput);
  const inputHeapOperations = transformCoverage(printedInput);
  const expectedExports = Object.keys(inputHeapOperations).sort();
  const baselineText = run(node, [...nodeFlags, checker, input]);
  fs.writeFileSync(path.join(directory, "original-observations.json"), baselineText);
  const baseline = JSON.parse(baselineText);
  const cleanup = ["--heap2local", "--simplify-locals", "--coalesce-locals", "--vacuum"];
  const pipelines = [
    { name: "once", passes: ["--heap2local"] },
    { name: "twice", passes: ["--heap2local", "--heap2local"] },
    { name: "cleanup", passes: cleanup },
    { name: "cleanup-twice", passes: [...cleanup, ...cleanup] },
  ];
  const outputs: { name: string; tool: string; sha256: string; bytes: number; cases: number; heapOperations: Record<string, number> }[] = [];
  for (const { name, passes } of pipelines) {
    for (const [toolName, command] of [["starshine", starshine], ...(oracle ? [["binaryen133", oracle]] : [])]) {
      const output = path.join(directory, `${toolName}-${name}.wasm`);
      run(command, [input, ...passes, ...(toolName === "binaryen133" ? ["--all-features"] : []), "-o", output]);
      run(wasmTools, ["validate", "--features", "all", output]);
      const printed = run(wasmTools, ["print", output]);
      fs.writeFileSync(path.join(directory, `${toolName}-${name}.wat`), printed);
      const observations = run(node, [...nodeFlags, checker, output]);
      fs.writeFileSync(path.join(directory, `${toolName}-${name}-observations.json`), observations);
      assert.deepEqual(JSON.parse(observations), baseline, `${toolName}/${name} differs from original; artifacts: ${directory}`);
      const heapOperations = transformCoverage(printed);
      assert.deepEqual(Object.keys(heapOperations).sort(), expectedExports, "Every input function export must retain transform evidence");
      if (toolName === "starshine") {
        for (const [exportName, count] of Object.entries(heapOperations)) {
          // Packed branch-local flows are explicitly unsupported by the variant
          // scanner. Their signed/unsigned runtime checks cover the retained heap.
          // make_box is the escaping setup helper. The result-if escape case
          // requires valid, correct output while its transform support is audited.
          if (!["packed", "make_box", "result_if_escape"].includes(exportName)) assert.equal(count, 0, `${name}/${exportName}: required owner-update transform was skipped`);
        }
      }
      outputs.push({ name, tool: toolName, sha256: hash(output), bytes: fs.statSync(output).size, cases: baseline.cases, heapOperations });
      fs.writeFileSync(path.join(directory, "progress.json"), JSON.stringify({ ...identity, complete: false, originalCases: baseline.cases, inputHeapOperations, outputs }, null, 2));
    }
  }
  const summary = { ...identity, complete: true, originalCases: baseline.cases, inputHeapOperations, outputs };
  fs.writeFileSync(path.join(directory, "summary.json"), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify(summary, null, 2));
  console.log(`${outputs.reduce((total, output) => total + output.cases, 0)} Heap2Local owner-update V8 comparisons passed; artifacts: ${directory}`);
} catch (error) {
  fs.writeFileSync(path.join(directory, "failure.txt"), error instanceof Error ? `${error.stack}\n${String(error.cause ?? "")}` : String(error));
  throw new Error(`Heap2Local owner-update runtime lane failed; artifacts: ${directory}`, { cause: error });
}
