import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

// Bounded independent execution for shared lowering changes made during the
// v132 upgrade. Keep broad generated campaigns in compare-pass.
const root = path.resolve(import.meta.dir, "../..");
const binary = path.resolve(process.argv[2] ?? "_build/native/release/build/cmd/cmd.exe");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-v132-lifetimes-"));
const runner = path.join(dir, "observe.cjs");
fs.writeFileSync(runner, [
  'const fs = require("node:fs");',
  'const assert = require("node:assert/strict");',
  'const calls = [];',
  'let throwing = false;',
  'const env = { alloc: x => { calls.push(["alloc",x]); return x+256; }, observe: (a,b) => { calls.push(["observe",a,b,...(process.argv[3] === "inserted-control-global" ? [e.observed.value] : [])]); }, tri: (a,b) => { calls.push(["tri",a,b]); return [42,101,202]; },',
  'show: (a,b,c) => { calls.push(["show",a,b,c]); return a + 31*b + 997*c; },',
  'may_throw: () => { calls.push(["call",throwing]); if (throwing) throw Error("fixture"); return 7; }};',
  'const e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {env}).exports;',
  'const kind = process.argv[3];',
  'let result;',
  'if (kind === "globals") { e.run(); result = [e.a.value, String(e.b.value)]; assert.deepEqual(result, [1065353216,"1"]); }',
  'else if (kind === "inserted-control-global") { result = [[41,1],[13,0],[-7,9]].map(([a,b]) => { const y=e.run(a,b); assert.equal(y,4); return [y,e.observed.value]; }); assert.deepEqual(calls, [["observe",41,1,17],["observe",-7,9,0]]); assert.deepEqual(result, [[4,1],[4,0],[4,9]]); }',
  'else if (kind === "inserted-control") { result = [[41,1],[13,0],[-7,9]].map(([a,b]) => { const y=e.run(a,b); assert.equal(y,4); return [y,e.observed.value]; }); assert.deepEqual(calls, [["observe",41,1],["observe",3,4],["observe",3,4],["observe",-7,9],["observe",3,4]]); assert.deepEqual(result, [[4,1],[4,1],[4,9]]); }',
  'else if (kind === "throw") { result = [e.run(41)]; throwing = true; result.push(e.run(41)); assert.deepEqual(result, [48,41]); }',
  'else if (kind === "throw-refined") { result = [e.run(41)]; throwing = true; result.push(e.run(41)); assert.deepEqual(result, [49,42]); }',
  'else if (kind === "balanced-tuple") { result = [0,1,-1].map(x => { const [a,b] = e.run(x); return [a,String(b),e.effects.value]; }); assert.deepEqual(result, [[0,"4",0],[0,"3",9],[0,"3",9]]); }',
  'else if (kind.startsWith("tee-condition-")) { const v = kind.endsWith("zero") ? 0 : 7; result = [0n,1n,-1n,9223372036854775807n].map(x => { const y = e.run(x); assert.equal(y, v === 0 ? 1 : 0); assert.equal(e.observed.value, BigInt(v)); return [y,String(e.observed.value)]; }); }',
  'else if (kind === "derived-pointer") { result = [0,16,128].map(x => { const y=e.run(x); assert.equal(y,x+272); assert.equal(new DataView(e.memory.buffer).getInt32(x+264,true),4); return y; }); assert.deepEqual(calls, [["alloc",8],["alloc",24],["alloc",136]]); }',
  'else if (kind === "scalar-from-tuple") { result = [0,1,-2147483648,2147483647].map((x,i) => { const y=e.run(x,17,-3); assert.equal(y,(x*2)|0); assert.equal(e.effects.value,i+1); return [y,e.effects.value]; }); }',
  'else if (kind === "if-readback") { result = [0,1,-1].map(x => e.run(x)); assert.deepEqual(result,[4,2,2]); }',
  'else if (kind === "scalar-capture") { const memory = new DataView(e.memory.buffer); result = [0,17,-2147483648,2147483647].map(x => { memory.setInt32(0,x,true); const y = e.run(); assert.equal(y,(x+2)|0); return y; }); }',
  'else if ((kind === "private-tuple" || kind === "captured-tuple")) { result = [e.run(),e.effects.value]; assert.deepEqual(result, [204567,1]); }',
  'else { result = e.run(); assert.deepEqual(calls, [["tri",42,10000],["show",42,101,202]]); assert.equal(result, 204567); }',
  'process.stdout.write(JSON.stringify({result,calls}));',
].join("\n"));

const fixtures = [
  {
    name: "scalar-from-tuple",
    wat: '(module (global (export "effects") (mut i32) (i32.const 0)) (func (param i32 i32 i32) (result i32 i32 i32) global.get 0 i32.const 1 i32.add global.set 0 local.get 0 local.get 1 local.get 2) (func (export "run") (param i32 i32 i32) (result i32) (local i32 i32 i32) local.get 0 local.get 1 local.get 2 call 0 local.set 5 local.set 4 local.set 3 local.get 3 local.get 3 i32.add))',
    passes: ["simplify-locals", "simplify-locals-notee", "dae2-optimizing"],
  },
  {
    name: "if-readback",
    wat: '(module (func (export "run") (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1 local.get 1 i32.add))',
    passes: ["simplify-locals", "simplify-locals-notee", "dae2-optimizing"],
  },
  {
    name: "derived-pointer",
    wat: fs.readFileSync(path.join(root, "tests/fixtures/simplify-locals/carried-derived-pointer.wat"), "utf8"),
    passes: ["simplify-locals", "dae2", "dae2-optimizing", "constraint-analysis", "optimize-instructions"],
  },
  {
    name: "inserted-control-global",
    wat: fs.readFileSync(path.join(root, "tests/fixtures/simplify-locals/inserted-control-global-write.wat"), "utf8"),
    passes: ["simplify-locals", "dae2", "dae2-optimizing", "constraint-analysis", "optimize-instructions"],
  },
  {
    name: "inserted-control",
    wat: fs.readFileSync(path.join(root, "tests/fixtures/simplify-locals/inserted-control-later-tee.wat"), "utf8"),
    passes: ["simplify-locals", "dae2", "dae2-optimizing", "constraint-analysis", "optimize-instructions"],
  },
  {
    name: "globals",
    wat: "(module (global (export \"a\") (mut i32) (i32.const 0)) (global (export \"b\") (mut i64) (i64.const 0)) (func (export \"run\") (local f32) i32.const 1549556771 i16x8.splat i64x2.all_true i64.extend_i32_u f32.const 1 f32.nearest local.tee 0 f32.const nan local.get 0 local.get 0 f32.eq select i32.reinterpret_f32 global.get 0 i32.xor global.set 0 global.get 1 i64.xor global.set 1))",
    passes: ["flatten", "optimize-instructions", "constraint-analysis", "dae2"],
  },
  {
    name: "throw",
    wat: "(module (import \"env\" \"may_throw\" (func (result i32))) (func (export \"run\") (param i32) (result i32) try (result i32) call 0 local.get 0 i32.const 9 local.set 0 i32.add catch_all local.get 0 end))",
    passes: ["optimize-instructions", "constraint-analysis", "dae2", "dae2-optimizing"],
  },
  {
    name: "throw-refined",
    wat: '(module (import "env" "may_throw" (func (result i32))) (func (export "run") (param i32) (result i32) try (result i32) call 0 local.get 0 i32.const 9 local.set 0 i32.add catch_all local.get 0 end local.get 0 local.get 0 i32.eq i32.add))',
    passes: ["constraint-analysis", "dae2-optimizing", "optimize-instructions"],
  },
  ...[0, 7].map(value => ({
    name: value === 0 ? "tee-condition-zero" : "tee-condition-seven",
    wat: `(module (global (export "observed") (mut i64) (i64.const -1)) (func (export "run") (param i64) (result i32) (if (result i32) (i64.eq (local.tee 0 (i64.const ${value})) (i64.const 0)) (then (i64.eqz (local.get 0))) (else (i32.const 0))) (local.get 0) (global.set 0)))`,
    passes: ["optimize-instructions"],
  })),
  {
    name: "scalar-capture",
    wat: '(module (memory (export "memory") 1) (func $source (param i32) (result i32) (local i32) (local.tee 1 (memory.size)) (i32.load (i32.const 0)) (local.get 1) i32.add i32.add) (func $sink (param i32 i32) (result i32) (local.get 0)) (func (export "run") (result i32) (call $source (i32.const 7)) (i32.const 8) (call $sink)))',
    passes: ["dae2", "dae2-optimizing", "constraint-analysis"],
  },
  {
    name: "balanced-tuple",
    wat: '(module (global $effects (export "effects") (mut i32) (i32.const 0)) (func (export "run") (param i32) (result i32 i64) (local i32) local.get 0 if (result i32 i64) local.get 1 i32.const 9 local.set 1 i64.const 3 else local.get 0 i64.const 4 end local.get 1 global.set $effects))',
    passes: ["tuple-optimization", "optimize-instructions", "constraint-analysis", "dae2", "dae2-optimizing"],
  },
  {
    name: "tuple",
    wat: "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (export \"run\") (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 6 local.set 10 local.set 9 local.get 9 local.get 10 local.get 6 call 1))",
    passes: ["tuple-optimization", "simplify-locals", "constraint-analysis", "dae2", "dae2-optimizing"],
  },
  {
    name: "private-tuple",
    wat: '(module (global (export "effects") (mut i32) (i32.const 0)) (func (param i32) (result i32 i32 i32) global.get 0 i32.const 1 i32.add global.set 0 i32.const 42 i32.const 101 i32.const 202) (func (param i32 i32 i32) (result i32) local.get 0 local.get 1 i32.const 31 i32.mul i32.add local.get 2 i32.const 997 i32.mul i32.add) (func (export "run") (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 6 local.set 10 local.set 9 local.get 9 local.get 10 local.get 6 call 1))',
    passes: ["simplify-locals", "dae2", "dae2-optimizing"],
  },
  {
    name: "captured-tuple",
    wat: "(module\n  (type (;0;) (func (param i32 i32 i32) (result i32)))\n  (type (;1;) (func (result i32)))\n  (type (;2;) (func (result i32 i32 i32)))\n  (type (;3;) (func (result i32 i32 i32)))\n  (global (;0;) (mut i32) i32.const 0)\n  (export \"effects\" (global 0))\n  (export \"run\" (func 2))\n  (func (;0;) (type 3) (result i32 i32 i32)\n    (local i32)\n    global.get 0\n    i32.const 1\n    i32.add\n    global.set 0\n    i32.const 42\n    i32.const 101\n    i32.const 202\n  )\n  (func (;1;) (type 0) (param i32 i32 i32) (result i32)\n    local.get 0\n    local.get 1\n    i32.const 31\n    i32.mul\n    i32.add\n    local.get 2\n    i32.const 997\n    i32.mul\n    i32.add\n  )\n  (func (;2;) (type 1) (result i32)\n    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)\n    call 0\n    local.set 11\n    local.set 12\n    local.set 13\n    local.get 11\n    local.set 6\n    local.get 12\n    local.set 5\n    local.get 13\n    local.set 8\n    local.get 5\n    local.set 7\n    block (type 2) (result i32 i32 i32) ;; label = @1\n      local.get 8\n      local.get 7\n      local.get 6\n    end\n    local.set 14\n    local.set 15\n    local.set 16\n    local.get 14\n    local.set 6\n    local.get 15\n    local.set 10\n    local.get 16\n    local.set 9\n    local.get 9\n    local.get 10\n    local.get 6\n    call 1\n  )\n)\n",
    passes: ["simplify-locals", "simplify-locals-notee", "simplify-locals-nostructure", "simplify-locals-notee-nostructure", "simplify-locals-nonesting", "tuple-optimization", "constraint-analysis", "dae2-optimizing"],
  },
];

function run(command: string, args: string[]): string {
  try {
    return execFileSync(command, args, { cwd: root, timeout: 30000, encoding: "utf8", stdio: "pipe" });
  } catch (cause) {
    throw new Error(command + " failed; retained artifacts: " + dir, { cause });
  }
}
let checked = 0;
for (const fixture of fixtures) {
  const source = path.join(dir, fixture.name + ".wat");
  const input = path.join(dir, fixture.name + ".wasm");
  fs.writeFileSync(source, fixture.wat);
  run("wasm-tools", ["parse", source, "-o", input]);
  const expected = run("node", [runner, input, fixture.name]);
  for (const pass of fixture.passes) {
    const output = path.join(dir, fixture.name + "-" + pass + ".wasm");
    run(binary, [input, "--" + pass, "-o", output]);
    run("wasm-tools", ["validate", "--features", "all", output]);
    const actual = run("node", [runner, output, fixture.name]);
    if (actual !== expected) throw new Error("Changed observations for " + fixture.name + "/" + pass + "; " + dir);
    checked++;
  }
}
console.log(checked + " independent lifetime comparisons passed");
fs.rmSync(dir, { recursive: true });
