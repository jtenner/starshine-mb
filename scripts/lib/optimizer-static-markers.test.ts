import { expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { instrumentNamedWat, survivingMarkers, compareMarkerSets } from "./optimizer-static-markers";

function validate(wat: string) {
  const result = spawnSync("wasm-tools", ["validate", "--features", "all", "-"], { input: wat, encoding: "utf8" });
  expect(result.stderr).toBe("");
  expect(result.status).toBe(0);
}

test("markers keep numeric function references stable through named printing and insertion", () => {
  const printed = spawnSync("wasm-tools", ["print", "--name-unnamed", "-"], { input: `(module
    (type (func (param i32) (result i32)))
    (import "m" "f" (func (result i32)))
    (table 1 funcref) (elem (i32.const 0) func 1)
    (func (type 0) (param i32) (result i32) call 0)
    (export "run" (func 1)))`, encoding: "utf8" });
  expect(printed.status).toBe(0);
  const result = instrumentNamedWat(printed.stdout);
  validate(result.wat);
  expect(result.markers.length).toBe(1);
  expect(survivingMarkers(result.wat)).toEqual([0]);
});

test("typed and multivalue controls keep stack and branch operands valid", () => {
  const result = instrumentNamedWat(`(module
    (type $pair (func (param i32 i64) (result i32 i64)))
    (func $run (param $c i32) (result i32 i64)
      i32.const 7 i64.const 8 block $b (type $pair) (param i32 i64) (result i32 i64)
        local.get $c br_if $b
        loop $l (type $pair) (param i32 i64) (result i32 i64)
          local.get $c if $i nop else nop end
        end
        i32.const 0 br_table $b $b
      end))`);
  validate(result.wat);
  expect(result.markers.map(m => m.kind)).toEqual(expect.arrayContaining(["function", "block", "loop", "then", "else", "after-br_if", "after-br_table"]));
});

test("survival counts call sites and resolves import identity after index changes", () => {
  const wat = `(module
    (type (func)) (import "starshine.static-marker" "4" (func $renamed))
    (import "starshine.static-marker" "9" (func $unused))
    (func $run call $renamed call $renamed))`;
  expect(survivingMarkers(wat)).toEqual([4]);
  expect(survivingMarkers(`(module (import "starshine.static-marker" "4" (func)) (func call 0))`)).toEqual([4]);
  expect(survivingMarkers(`(module (import "starshine.static-marker" "4" (func)))`)).toEqual([]);
});

test("primary candidates exclude nested consequences and preserve reverse differences", () => {
  const markers = [
    { id: 0, parent: null, kind: "function", function: "$f" },
    { id: 1, parent: 0, kind: "then", function: "$f" },
    { id: 2, parent: 1, kind: "block", function: "$f" },
    { id: 3, parent: 0, kind: "else", function: "$f" },
  ];
  expect(compareMarkerSets(markers, [0, 3], [0, 1, 2])).toEqual({
    candidates: [1, 2], primaryCandidates: [1], reverseDifferences: [3],
  });
});

test("existing marker namespace and unsupported exception controls reject explicitly", () => {
  expect(() => instrumentNamedWat(`(module (import "starshine.static-marker" "0" (func $x)))`)).toThrow("reserved marker namespace");
  expect(() => instrumentNamedWat(`(module (func $f try nop catch_all nop end))`)).toThrow("unsupported control");
});

test("unconditional transfers and quoted control names do not confuse placement", () => {
  const result = instrumentNamedWat(`(module (data "block if return")
    (func $f block $b br $b end return unreachable))`);
  validate(result.wat);
  expect(result.markers.map(m => m.kind)).toEqual(["function", "block", "after-br", "after-end", "after-return", "after-unreachable"]);
});

test("typed select, call_indirect and GC types stay valid", () => {
  const printed = spawnSync("wasm-tools", ["print", "--name-unnamed", "-"], { input: `(module
    (type (struct (field i32))) (type (func (result i32)))
    (table 1 funcref) (func (result i32) i32.const 0 call_indirect (type 1))
    (func (param i32) (result (ref null 0))
      ref.null 0 ref.null 0 local.get 0 select (result (ref null 0))))`, encoding: "utf8" });
  expect(printed.status).toBe(0);
  validate(instrumentNamedWat(printed.stdout).wat);
});

test("unnamed or folded input is rejected instead of shifting numeric references", () => {
  expect(() => instrumentNamedWat(`(module (func i32.const 0 drop))`)).toThrow("must have names");
  expect(() => instrumentNamedWat(`(module (func $f (drop (i32.const 0))))`)).toThrow("flat instructions");
});

test("raw function-index metadata rejects before imports change indices", () => {
  expect(() => instrumentNamedWat(`(module (@custom "compiler.facts" "raw") (func $f nop))`)).toThrow("function-index metadata");
});

test("static marker command validates its own options through the fuzz dispatcher", async () => {
  const { main } = await import("./fuzz-task");
  expect(() => main(["static-markers", "--unknown", "x"])).toThrow("invalid static marker option");
  expect(() => main(["static-markers"])).toThrow("missing --input");
});

test("named modules keep the identifier before inserted imports", () => {
  validate(instrumentNamedWat(`(module $named (func $f nop))`).wat);
});

test("baseline and candidate commands retain both binary identities and a withheld cleanup", async () => {
  const fs = await import("node:fs");
  const os = await import("node:os");
  const path = await import("node:path");
  const { runStaticMarkerComparison } = await import("./optimizer-static-markers");
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "static-marker-binaries-"));
  try {
    const input = path.join(root, "input.wasm");
    const parsed = spawnSync("wasm-tools", ["parse", "-", "-o", input], { input: "(module (func $f return))", encoding: "utf8" });
    expect(parsed.status).toBe(0);
    const weak = path.join(root, "weak"), strong = path.join(root, "strong");
    fs.writeFileSync(weak, `#!/usr/bin/env bun\nimport {spawnSync} from 'node:child_process';\nconst wat='(module (import "starshine.static-marker" "0" (func)) (import "starshine.static-marker" "1" (func)) (func call 0 return))';\nconst result=spawnSync('wasm-tools',['parse','-','-o',process.argv[process.argv.indexOf('-o')+1]],{input:wat});\nprocess.exit(result.status ?? 1);\n`, { mode: 0o755 });
    // Test-only negative control: deliberately withhold safe dead-code cleanup.
    fs.writeFileSync(strong, `#!/usr/bin/env bun\nimport fs from 'node:fs';\nfs.copyFileSync(process.argv[2],process.argv[process.argv.indexOf('-o')+1]);\n`, { mode: 0o755 });
    const report = runStaticMarkerComparison(["--input", input, "--out-dir", path.join(root, "out"), "--starshine-bin", strong, "--weaker-bin", weak, "--weaker", "dead-code-elimination", "--stronger", "dead-code-elimination"]);
    expect(report.survivors).toEqual([[0], [0, 1]]);
    expect(report.primaryCandidates).toEqual([1]);
    expect(report.optimizerHashes[0]).not.toBe(report.optimizerHashes[1]);
    expect(fs.existsSync(path.join(root, "out", "original.wasm"))).toBe(true);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});

test("a marker stored in a global is inconclusive instead of reported dead", () => {
  expect(() => survivingMarkers(`(module (import "starshine.static-marker" "0" (func $m)) (global funcref (ref.func $m)))`)).toThrow("indirect marker reference");
});

test("fallthrough markers suppress nested consequences of the same branch", () => {
  const result = instrumentNamedWat(`(module (func $f block $b i32.const 0 br_if $b block $c nop end end))`);
  const ids = result.markers.map(m => m.id);
  const fallthrough = result.markers.find(m => m.kind === "after-br_if")!.id;
  const missing = [fallthrough, fallthrough + 1, fallthrough + 2];
  expect(compareMarkerSets(result.markers, ids.filter(id => !missing.includes(id)), ids).primaryCandidates).toEqual([fallthrough]);
});

test("typed GC casts remain opaque instruction operands", () => {
  const printed = spawnSync("wasm-tools", ["print", "--name-unnamed", "-"], { input: `(module (type (struct (field i32))) (func (result (ref null 0)) ref.null 0 ref.cast (ref null 0)))`, encoding: "utf8" });
  expect(printed.status).toBe(0);
  validate(instrumentNamedWat(printed.stdout).wat);
});
