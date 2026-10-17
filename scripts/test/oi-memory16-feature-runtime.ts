import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";

// This dedicated lane runs Wasm in a separate Node/V8 process, never Bun's engine.
const root = path.resolve(import.meta.dir, "../..");
const [binaryArg, oracleArg] = process.argv.slice(2);
if (!binaryArg || !oracleArg) throw new Error("Usage: bun scripts/test/oi-memory16-feature-runtime.ts <fresh-native-starshine> <verified-v133-wasm-opt>");
const starshine = fs.realpathSync(path.resolve(binaryArg));
const oracle = fs.realpathSync(path.resolve(oracleArg));
const wasmTools = process.env.WASM_TOOLS_BIN ?? "wasm-tools";
const node = process.env.NODE_BIN ?? "node";
fs.mkdirSync(path.join(root, ".tmp"), { recursive: true });
const directory = fs.mkdtempSync(path.join(root, ".tmp/oi-memory16-runtime-"));
const snapshotDirectory = path.join(directory, "memory-snapshots");
fs.mkdirSync(snapshotDirectory);
const hash = (file: string) => createHash("sha256").update(fs.readFileSync(file)).digest("hex");
type CommandRecord = { command: string; args: string[]; status: number | null; signal?: string | null; stdout: string; stderr: string };
const commands: CommandRecord[] = [];
function run(command: string, args: string[], allowFailure = false): CommandRecord {
  const executed = spawnSync(command, args, { cwd: root, timeout: 30_000, encoding: "utf8", maxBuffer: 16 * 1024 * 1024 });
  const result: CommandRecord = { command, args, status: executed.status, signal: executed.signal, stdout: executed.stdout ?? "", stderr: executed.stderr || executed.error?.message || "" };
  commands.push(result);
  fs.writeFileSync(path.join(directory, "commands.json"), JSON.stringify(commands, null, 2));
  if (result.status !== 0 && !allowFailure) throw new Error(`${command} failed (${result.status ?? result.signal}); artifacts: ${directory}\n${result.stderr}`);
  return result;
}

function uleb(value: number): Buffer {
  const bytes: number[] = [];
  do {
    const byte = value & 127;
    value = Math.floor(value / 128);
    bytes.push(byte | (value ? 128 : 0));
  } while (value);
  return Buffer.from(bytes);
}
function features(entries: ["+" | "-", string][]): Buffer {
  return Buffer.concat([uleb(entries.length), ...entries.map(([prefix, name]) => {
    const bytes = Buffer.from(name, "utf8");
    return Buffer.concat([Buffer.from(prefix), uleb(bytes.length), bytes]);
  })]);
}
function customSection(payload: Buffer): Buffer {
  const name = Buffer.from("target_features", "utf8");
  const body = Buffer.concat([uleb(name.length), name, payload]);
  return Buffer.concat([Buffer.from([0]), uleb(body.length), body]);
}
function targetFeaturePayloads(bytes: Buffer): Buffer[] {
  let cursor = 8;
  const payloads: Buffer[] = [];
  function readUleb(): number {
    let value = 0, shift = 0;
    for (;;) {
      assert(cursor < bytes.length && shift <= 28, "Invalid section length");
      const byte = bytes[cursor++];
      value += (byte & 127) * 2 ** shift;
      if (!(byte & 128)) return value;
      shift += 7;
    }
  }
  while (cursor < bytes.length) {
    const id = bytes[cursor++];
    const size = readUleb();
    const end = cursor + size;
    assert(end <= bytes.length, "Truncated section");
    if (id === 0) {
      const nameSize = readUleb();
      const name = bytes.subarray(cursor, cursor + nameSize).toString("utf8");
      cursor += nameSize;
      assert(cursor <= end, "Truncated custom-section name");
      if (name === "target_features") payloads.push(bytes.subarray(cursor, end));
    }
    cursor = end;
  }
  return payloads;
}
const enabled = features([["+", "simd128"]]);
const disabled = features([["-", "simd128"]]);
const contracts = [
  { name: "absent", payloads: [], allowsSimd: true, malformed: false },
  { name: "enabled", payloads: [enabled], allowsSimd: true, malformed: false },
  { name: "banned", payloads: [disabled], allowsSimd: false, malformed: false },
  { name: "enabled-then-banned", payloads: [enabled, disabled], allowsSimd: false, malformed: false },
  { name: "banned-then-enabled", payloads: [disabled, enabled], allowsSimd: false, malformed: false },
  { name: "malformed-empty", payloads: [Buffer.alloc(0)], allowsSimd: false, malformed: true },
  { name: "malformed-truncated", payloads: [Buffer.from([1, 43])], allowsSimd: false, malformed: true },
  { name: "malformed-prefix", payloads: [Buffer.concat([Buffer.from([1, 63, 7]), Buffer.from("simd128")])], allowsSimd: false, malformed: true },
  { name: "malformed-trailing", payloads: [Buffer.from([0, 255])], allowsSimd: false, malformed: true },
  { name: "malformed-utf8", payloads: [Buffer.from([1, 43, 1, 255])], allowsSimd: false, malformed: true },
];

const checkerSource = String.raw`
const fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2]))).exports;
const snapshots = process.argv[3];
const initial = Uint8Array.from({ length: 65536 }, (_, i) => ((i * 29) ^ (i >>> 8) ^ 167) & 255);
const memory = new Uint8Array(e.memory.buffer);
assert.equal(memory.length, initial.length);
const observations = [];
function execute(name, args) {
  memory.set(initial);
  const expected = initial.slice();
  const destination = args[0] >>> 0;
  const source = name === "copy" ? args[1] >>> 0 : 0;
  const shouldTrap = destination > initial.length - 16 || (name === "copy" && source > initial.length - 16);
  if (!shouldTrap) {
    if (name === "copy") expected.set(initial.slice(source, source + 16), destination);
    else expected.fill(name === "fill_const" ? 171 : args[1] & 255, destination, destination + 16);
  }
  let trapped = false;
  try { e[name](...args); } catch (error) {
    assert(error instanceof WebAssembly.RuntimeError, name + " unexpected exception " + JSON.stringify(args));
    trapped = true;
  }
  assert.equal(trapped, shouldTrap, name + " trap " + JSON.stringify(args));
  // Compare every byte, including unchanged memory after an out-of-bounds trap.
  assert.deepEqual(memory, expected, name + " memory/partial write " + JSON.stringify(args));
  const sha256 = createHash("sha256").update(memory).digest("hex");
  const snapshot = path.join(snapshots, sha256 + ".bin");
  if (!fs.existsSync(snapshot)) fs.writeFileSync(snapshot, memory);
  observations.push({ name, args, trapped, snapshotBytes: memory.length, memorySha256: sha256 });
}
const destinations = [0, 1, 7, 65504, 65520, 65521, 65528, 65535, 65536, 2147483647, -1, -16, -2147483648];
for (const destination of destinations) {
  for (const value of [0, 1, 255, 256, -1, -129, 305419896, -2147483648, 2147483647]) execute("fill", [destination, value]);
  execute("fill_const", [destination]);
}
const addresses = [0, 1, 8, 15, 16, 24, 65504, 65512, 65520, 65521, 65528, 65535, 65536, -1, 2147483647, -2147483648];
for (const destination of addresses) for (const source of addresses) execute("copy", [destination, source]);
process.stdout.write(JSON.stringify({ engine: process.version, engineArgs: process.execArgv, nodeOptions: process.env.NODE_OPTIONS ?? "", cases: observations.length, observations }));
`;

type Shape = { bulkFill: number; bulkCopy: number; vectorLoad: number; vectorStore: number; scalarStore: number };
function shapes(text: string): Record<string, Shape> {
  const functions = new Map<string, string>();
  for (const match of text.matchAll(/^  \(func\s+(?:(\$[^\s()]+)\s+)?\(;([0-9]+);\)[\s\S]*?(?=\n  \(|\n\)$)/gm)) {
    functions.set(match[2], match[0]);
    if (match[1]) functions.set(match[1], match[0]);
  }
  const result: Record<string, Shape> = {};
  for (const match of text.matchAll(/\(export "([^"]+)" \(func ([^\s()]+)\)\)/g)) {
    const body = functions.get(match[2]);
    assert(body, `Missing printed function ${match[1]}`);
    const count = (pattern: RegExp) => [...body.matchAll(pattern)].length;
    result[match[1]] = {
      bulkFill: count(/\bmemory\.fill\b/g), bulkCopy: count(/\bmemory\.copy\b/g),
      vectorLoad: count(/\bv128\.load\b/g), vectorStore: count(/\bv128\.store\b/g),
      scalarStore: count(/\b(?:i32|i64|f32|f64)\.store(?:8|16|32)?\b/g),
    };
  }
  return result;
}

try {
  const fixture = path.join(root, "tests/fixtures/optimize-instructions/feature-memory16.wat");
  const base = path.join(directory, "base.wasm");
  const checker = path.join(directory, "check.cjs");
  fs.writeFileSync(checker, checkerSource);
  const oracleVersion = run(oracle, ["--version"]).stdout.trim();
  assert(/\bversion\s+133\b/.test(oracleVersion), `Binaryen v133 required; found ${oracleVersion}`);
  const nodeVersion = run(node, ["--version"]).stdout.trim();
  assert(/^v24\./.test(nodeVersion), `Node 24 required; found ${nodeVersion}`);
  const identity = {
    fixture: { path: fixture, sha256: hash(fixture) },
    starshine: { path: starshine, sha256: hash(starshine), modified: fs.statSync(starshine).mtime.toISOString() },
    oracle: { path: oracle, sha256: hash(oracle), version: oracleVersion },
    tools: { node: nodeVersion, nodeFlags: [], nodeOptions: process.env.NODE_OPTIONS ?? "", wasmTools: run(wasmTools, ["--version"]).stdout.trim() },
    subprocessTimeoutMs: 30_000,
    contract: "Full 65536-byte snapshots; 16-byte operations trap before any write; shrink 0 admits SIMD, shrink 1 keeps bulk; malformed metadata forbids SIMD introduction.",
  };
  fs.writeFileSync(path.join(directory, "identity.json"), JSON.stringify(identity, null, 2));
  run(wasmTools, ["parse", fixture, "-o", base]);
  const baseBytes = fs.readFileSync(base);
  const outputs: Record<string, unknown>[] = [];
  for (const contract of contracts) {
    const input = path.join(directory, `${contract.name}-input.wasm`);
    fs.writeFileSync(input, Buffer.concat([baseBytes, ...contract.payloads.map(customSection)]));
    run(wasmTools, ["validate", "--features", "all", input]);
    const baselineText = run(node, [checker, input, snapshotDirectory]).stdout;
    fs.writeFileSync(path.join(directory, `${contract.name}-original.json`), baselineText);
    const baseline = JSON.parse(baselineText);
    for (const shrink of [0, 1]) {
      for (const [tool, command] of [["starshine", starshine], ["binaryen133", oracle]]) {
        const label = `${contract.name}-shrink${shrink}-${tool}`;
        const output = path.join(directory, `${label}.wasm`);
        let oracleInput = "original";
        if (tool === "starshine") {
          run(command, [input, "--optimize-instructions", "--shrink-level", String(shrink), "-o", output]);
        } else {
          const flags = ["--all-features", "--optimize-instructions", `--shrink-level=${shrink}`, "-o", output];
          const attempt = run(command, [input, ...flags], contract.malformed);
          if (attempt.status !== 0) {
            // target_features is custom metadata with no Wasm runtime effect.
            // Keep the raw rejection and use the identical metadata-free code
            // as the independent semantic oracle for this malformed contract.
            assert(contract.malformed && attempt.status !== null && !attempt.signal, "Unexpected Binaryen failure");
            oracleInput = "metadata-free fallback after recorded malformed-metadata rejection";
            run(command, [base, ...flags]);
          }
        }
        run(wasmTools, ["validate", "--features", "all", output]);
        const printed = run(wasmTools, ["print", output]).stdout;
        fs.writeFileSync(path.join(directory, `${label}.wat`), printed);
        const shape = shapes(printed);
        assert.deepEqual(Object.keys(shape).sort(), ["copy", "fill", "fill_const"]);
        if (tool === "starshine") {
          const simd = contract.allowsSimd && shrink === 0;
          assert.deepEqual(shape.fill, { bulkFill: 1, bulkCopy: 0, vectorLoad: 0, vectorStore: 0, scalarStore: 0 }, `${label}: dynamic fill control`);
          assert.deepEqual(shape.fill_const, { bulkFill: simd ? 0 : 1, bulkCopy: 0, vectorLoad: 0, vectorStore: simd ? 1 : 0, scalarStore: 0 }, `${label}: constant fill admission`);
          assert.deepEqual(shape.copy, { bulkFill: 0, bulkCopy: simd ? 0 : 1, vectorLoad: simd ? 1 : 0, vectorStore: simd ? 1 : 0, scalarStore: 0 }, `${label}: copy admission`);
          assert.deepEqual(targetFeaturePayloads(fs.readFileSync(output)), contract.payloads, `${label}: metadata preservation`);
        }
        const observedText = run(node, [checker, output, snapshotDirectory]).stdout;
        fs.writeFileSync(path.join(directory, `${label}-observations.json`), observedText);
        assert.deepEqual(JSON.parse(observedText), baseline, `${label}: original/output memory or trap difference`);
        outputs.push({ contract: contract.name, shrink, tool, oracleInput, inputSha256: hash(input), outputSha256: hash(output), bytes: fs.statSync(output).size, cases: baseline.cases, shape });
        fs.writeFileSync(path.join(directory, "progress.json"), JSON.stringify({ ...identity, complete: false, outputs }, null, 2));
      }
    }
  }
  const summary = { ...identity, complete: true, metadataContracts: contracts.map(({ name, payloads, allowsSimd, malformed }) => ({ name, payloadsHex: payloads.map(payload => payload.toString("hex")), allowsSimd, malformed })), snapshotBytes: 65536, uniqueSnapshots: fs.readdirSync(snapshotDirectory).length, comparisons: outputs.reduce((sum, output) => sum + Number(output.cases), 0), outputs };
  fs.writeFileSync(path.join(directory, "summary.json"), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify(summary, null, 2));
  console.log(`${summary.comparisons} OI memory16 V8 comparisons passed; artifacts: ${directory}`);
} catch (error) {
  fs.writeFileSync(path.join(directory, "failure.txt"), error instanceof Error ? error.stack ?? error.message : String(error));
  throw new Error(`OI memory16 runtime lane failed; artifacts: ${directory}`, { cause: error });
}
