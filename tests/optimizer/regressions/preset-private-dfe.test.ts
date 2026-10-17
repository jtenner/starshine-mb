import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const binary = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
const fixture = `(module
  (import "host" "tick" (func $tick (param i32) (result i32)))
  (func $private_first (param i32) (result i32) local.get 0 call $tick local.get 0 i32.mul local.get 0 i32.add)
  (func $private_second (param i32) (result i32) local.get 0 call $tick local.get 0 i32.mul local.get 0 i32.add)
  (func $export_first (export "first") (result i32) i32.const 7)
  (func $export_second (export "second") (result i32) i32.const 7)
  (func $table_first (result i32) i32.const 7)
  (func $table_second (result i32) i32.const 7)
  (func $global_first (result i32) i32.const 7)
  (func $global_second (result i32) i32.const 7)
  (func $body_first (result i32) i32.const 7)
  (func $body_second (result i32) i32.const 7)
  (table (export "refs") 2 funcref)
  (elem (i32.const 0) func $table_first $table_second)
  (elem declare func $global_first $global_second $body_first $body_second)
  (global (export "first_ref") funcref (ref.func $global_first))
  (global (export "second_ref") funcref (ref.func $global_second))
  (func (export "body_first") (result funcref) ref.func $body_first)
  (func (export "body_second") (result funcref) ref.func $body_second)
  (func (export "run") (param i32) (result i32)
    local.get 0 call $private_first local.get 0 call $private_second i32.add))`;

// Read the defined-function count from section 3, without rendered WAT snapshots.
function definedFunctionCount(bytes: Uint8Array): number {
  let position = 8;
  const readUleb = () => {
    let value = 0;
    let shift = 0;
    for (;;) {
      const byte = bytes[position++];
      if (byte === undefined || shift >= 35) throw new Error("invalid fixture encoding");
      value += (byte & 127) * 2 ** shift;
      if (!(byte & 128)) return value;
      shift += 7;
    }
  };
  while (position < bytes.length) {
    const section = bytes[position++];
    const length = readUleb();
    if (section === 3) return readUleb();
    position += length;
  }
  return 0;
}

const observe = `const fs = require('node:fs');
const calls = [];
const instance = new WebAssembly.Instance(
  new WebAssembly.Module(fs.readFileSync(process.argv[1])),
  {host: {tick(value) { calls.push(value); return value + 1; }}});
const e = instance.exports;
const refs = [e.first, e.second, e.refs.get(0), e.refs.get(1),
  e.first_ref.value, e.second_ref.value, e.body_first(), e.body_second()];
const identities = refs.map(a => refs.map(b => a === b));
const values = refs.map(f => f());
const results = [7, 3, 9].map(n => e.run(n));
console.log(JSON.stringify({identities, values, results, calls}));`;

for (const preset of ["--optimize", "--shrink"]) {
  test(`full O4z ${preset} removes private duplicates and keeps visible identities`, () => {
    const evidenceRoot = resolve(".tmp/report-optimization-20261014");
    mkdirSync(evidenceRoot, { recursive: true });
    const directory = mkdtempSync(join(evidenceRoot, "private-dfe-test-"));
    try {
      const source = join(directory, "input.wat");
      const original = join(directory, "input.wasm");
      const optimized = join(directory, "output.wasm");
      writeFileSync(source, fixture);
      execFileSync("wasm-tools", ["parse", source, "-o", original]);
      execFileSync("wasm-tools", ["validate", "--features", "all", original]);
      const run = (path: string) => JSON.parse(execFileSync(
        "node", ["-e", observe, path], { encoding: "utf8", timeout: 10_000 },
      ));
      const before = run(original);
      expect(before.values).toEqual(Array(8).fill(7));
      expect(before.identities).toEqual(Array.from({ length: 8 }, (_, i) =>
        Array.from({ length: 8 }, (_, j) => i === j)));
      expect(before.results).toEqual([126, 30, 198]);
      expect(before.calls).toEqual([7, 7, 3, 3, 9, 9]);
      execFileSync(binary, [
        "-O4z", preset,
        "--always-inline-max-function-size", "0",
        "--one-caller-inline-max-function-size", "0",
        "--flexible-inline-max-function-size", "0",
        original, "-o", optimized,
      ], { timeout: 20_000 });
      execFileSync("wasm-tools", ["validate", "--features", "all", optimized]);
      expect(run(optimized)).toEqual(before);
      const originalBytes = readFileSync(original);
      const optimizedBytes = readFileSync(optimized);
      expect(definedFunctionCount(originalBytes)).toBe(13);
      expect(definedFunctionCount(optimizedBytes)).toBe(12);
      expect(optimizedBytes.length).toBeLessThan(originalBytes.length);
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });
}
