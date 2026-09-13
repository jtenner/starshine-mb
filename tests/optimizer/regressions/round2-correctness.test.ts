import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

// Deterministic execution regressions; build the native CLI before this lane.
const binary = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
type Case = { name: string; pass: string; wat: string; args?: unknown[]; flags?: string[]; expected: unknown; host?: string };
const cases: Case[] = [];
const result = (value: unknown, calls = 0, side = 0) => ({ result: value, calls, side });
for (const type of ["f32", "f64"]) {
  const int = type === "f32" ? "i32" : "i64";
  const negative = type === "f32" ? -2147483648 : "-9223372036854775808";
  for (const fixed of [false, true]) cases.push({
    name: `${type} negative zero array ${fixed}`, pass: "optimize-instructions",
    wat: `(module (type $a (array (mut ${type}))) (func (export "main") (result ${int})
      (${int}.reinterpret_${type} (array.get $a (${fixed ? `array.new_fixed $a 2 (${type}.const -0) (${type}.const -0)` : `array.new $a (${type}.const -0) (i32.const 2)`}) (i32.const 0)))))`,
    expected: result(negative),
  });
  for (const condition of [0, 1]) cases.push({name: `${type} signed zero select ${condition}`, pass: "optimize-instructions", args: [condition],
    wat: `(module (func (export "main") (param i32) (result ${int}) (${int}.reinterpret_${type} (select (${type}.const 0) (${type}.const -0) (local.get 0)))))`,
    expected: result(condition ? (type === "f32" ? 0 : "0") : negative),
  });
  cases.push({name: `${type} CSE signed zero`, pass: "local-cse",
    wat: `(module (func (export "main") (result ${int}) (drop (${int}.reinterpret_${type} (${type}.const 0))) (${int}.reinterpret_${type} (${type}.const -0))))`, expected: result(negative)});
}
for (const type of ["i32", "i64"]) for (const op of ["div_u", "div_s", "rem_s"]) {
  cases.push({name: `${type} ${op} range`, pass: "optimize-instructions",
    wat: `(module (func (export "main") (param ${type} ${type}) (result i32)
      (${type}.gt_u (${type}.${op} ${op === "rem_s" ? `(local.get 0) (${type}.const 3)` : `(${type}.and (local.get 0) (${type}.const 255)) (${type}.and (local.get 1) (${type}.const 255))`}) (${type}.const 4))))`,
    args: type === "i32" ? [op === "rem_s" ? -1 : 255, 1] : [{i64: op === "rem_s" ? "-1" : "255"}, {i64: "1"}], expected: result(1)});
}
for (const condition of [0, 1]) cases.push({name: `block prefix range ${condition}`, pass: "optimize-instructions", args: [condition],
  wat: `(module (func (export "main") (param i32) (result i32) (local i32) (i32.and (block $b (result i32) (local.set 1 (block (result i32) (br_if $b (i32.const 99) (local.get 0)))) (i32.const 0)) (i32.const 1))))`, expected: result(condition)});
for (const initial of [0, 1, -1]) for (const setter of [false, true]) cases.push({
  name: `once guard ${initial} setter ${setter}`, pass: "once-reduction",
  wat: `(module (global $a (mut i32) (i32.const ${initial})) (global $b (mut i32) (i32.const 0)) (global $side (export "side") (mut i32) (i32.const 0))
    (func $B global.get $b if return end i32.const 1 global.set $b i32.const 7 global.set $side)
    (func $A global.get $a if return end i32.const 1 global.set $a call $B)
    ${setter ? '(func (export "setup") i32.const 1 global.set $a)' : ""} (func (export "main") call $A))`, expected: result(null, 0, setter || initial ? 0 : 7),
});
cases.push({name: "CSE nested local mutation", pass: "local-cse", args: [2], expected: result(11),
  wat: `(module (func (export "main") (param i32) (result i32) (drop (i32.add (local.get 0) (i32.const 1))) (block (result i32) (block (local.set 0 (i32.const 10))) (i32.add (local.get 0) (i32.const 1)))))`});
cases.push({name: "CSE nested memory fill", pass: "local-cse", expected: result(16843009),
  wat: `(module (memory 1) (func (export "main") (result i32) (drop (i32.load (i32.const 0))) (block (result i32) (memory.fill (i32.const 0) (i32.const 1) (i32.const 4)) (i32.load (i32.const 0)))))`});
cases.push({name: "coalesce reference exit", pass: "coalesce-locals", args: [null], expected: result(7),
  wat: `(module (func (export "main") (param externref) (result i32) (local i32) i32.const 7 local.set 1 block local.get 0 br_on_null 0 drop i32.const 9 local.set 1 end local.get 1))`});
cases.push({name: "coalesce exception exit", pass: "coalesce-locals", expected: result(7),
  wat: `(module (tag $e) (func (export "main") (result i32) (local i32) i32.const 7 local.set 0 block $exit try_table (catch_all $exit) throw $e end end local.get 0))`});
cases.push({name: "coalesce dead cursor", pass: "coalesce-locals", args: [0], expected: result(7),
  wat: `(module (func (export "main") (param i32) (result i32) (local i32 i32) local.get 0 if unreachable local.get 1 drop end block i32.const 7 local.tee 1 drop end i32.const 8 local.set 2 local.get 1))`});
for (const condition of [0, 1]) cases.push({name: `folding fallthrough trap ${condition}`, pass: "code-folding", args: [condition], expected: condition ? {trap: true, calls: 0, side: 0} : result(null),
  wat: `(module (func (export "main") (param i32) block $b local.get 0 br_if $b return end unreachable))`});
cases.push({name: "folding unreachable effects", pass: "code-folding", expected: {trap: true, calls: 0, side: 0},
  wat: `(module (import "m" "side" (func $side (result i32))) (func (export "main") block unreachable call $side drop end))`});
for (const memory of [false, true]) for (const condition of [0, 1]) cases.push({name: `pushing operand effects ${memory} ${condition}`, pass: "code-pushing", flags: [memory ? "--ignore-implicit-traps" : "--traps-never-happen"], args: [condition], expected: result(null, 1),
  wat: `(module (import "m" "side" (func $side (result i32))) ${memory ? "(memory 1)" : ""} (func (export "main") (param i32) (local i32) (local.set 1 (${memory ? "i32.load (call $side)" : "i32.div_s (call $side) (i32.const 1)"})) (if (local.get 0) (then (drop (local.get 1))))))`});
cases.push({name: "branch cleanup prefix effects", pass: "remove-unused-brs", args: [1], expected: result(null, 0, 7),
  wat: `(module (global $side (export "side") (mut i32) (i32.const 0)) (func (export "main") (param i32) (loop $L (block $B (global.set $side (i32.const 7)) (br_if $B (local.get 0)) (drop (i32.const 9)) (br $L)))))`});
cases.push({name: "heap scalarization failing cast", pass: "heap2local", expected: {trap: true, calls: 0, side: 0},
  wat: `(module (type $base (sub (struct (field i32)))) (type $sub (sub $base (struct (field i32)))) (func (export "main") (result i32) (struct.get $base 0 (ref.cast (ref $sub) (struct.new $base (i32.const 7))))))`});
cases.push({name: "cast fold producer effects", pass: "optimize-casts", expected: result(1, 0, 1),
  wat: `(module (type $S (struct)) (global $g (export "side") (mut i32) (i32.const 0)) (func $produce (result (ref $S)) i32.const 1 global.set $g struct.new $S) (func (export "main") (result i32) (ref.test (ref $S) (call $produce))))`});
for (const pass of ["dae2", "dae2-optimizing"]) cases.push({name: "indirect call type identity", pass, flags: ["--closed-world"], expected: {trap: true, calls: 0, side: 0},
  wat: `(module (type $A (func (param i32))) (type $B (func (param i64))) (table 1 funcref) (func $a (type $A)) (elem (i32.const 0) func $a) (func (export "main") i64.const 7 i32.const 0 call_indirect (type $B)))`});
for (const pass of ["dae2", "dae2-optimizing"]) cases.push({name: "equivalent indirect call type identity", pass, flags: ["--closed-world"], expected: result(null, 0, 7),
  wat: `(module (type $A (func (param i32))) (type $B (func (param i32))) (global $side (export "side") (mut i32) (i32.const 0)) (table 1 funcref) (func $a (type $A) local.get 0 global.set $side) (elem (i32.const 0) func $a) (func (export "main") i32.const 7 i32.const 0 call_indirect (type $B)))`});
for (const pass of ["dae2", "dae2-optimizing"]) cases.push({name: "recursive group identity collapse", pass, flags: ["--closed-world"], expected: {trap: true, calls: 0, side: 0},
  wat: `(module (rec (type $A (func (param i32))) (type $AX (struct (field (ref null $A))))) (rec (type $B (func (param i64))) (type $BX (struct (field (ref null $B))))) (global $side (export "side") (mut i32) (i32.const 0)) (table 1 funcref) (func $a (type $A) ) (elem (i32.const 0) func $a) (func (export "main") i64.const 7 i32.const 0 call_indirect (type $B)))`});
for (const pass of ["dae2", "dae2-optimizing"]) cases.push({name: "recursive group identity split", pass, flags: ["--closed-world"], expected: result(null, 0, 7),
  wat: `(module (rec (type $A (func (param i32))) (type $AX (struct (field (ref null $A))))) (rec (type $B (func (param i32))) (type $BX (struct (field (ref null $B))))) (global $side (export "side") (mut i32) (i32.const 0)) (table 1 funcref) (func $a (type $A) local.get 0 global.set $side) (elem (i32.const 0) func $a) (func (export "main") i32.const 7 i32.const 0 call_indirect (type $B)))`});
cases.push({name: "directize imported dynamic subtype", pass: "directize", expected: result(42),
  host: `(module (type $base (sub (func (result i32)))) (type $child (sub $base (func (result i32)))) (func (export "f") (type $child) i32.const 42))`,
  wat: `(module (type $base (sub (func (result i32)))) (type $child (sub $base (func (result i32)))) (import "m" "f" (func $f (type $base))) (table 1 funcref) (elem (i32.const 0) $f) (func (export "main") (result i32) i32.const 0 call_indirect (type $child)))`});
const observe = `const fs=require('node:fs'); let calls=0;
const imports={m:{side(){calls++;return 0}}};
if(process.argv[3]) imports.m.f=new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[3]))).exports.f;
const e=new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[1])),imports).exports;
const args=JSON.parse(process.argv[2]).map(x=>x&&typeof x==='object'&&'i64'in x?BigInt(x.i64):x);
e.setup?.();
let observation;try {const value=e.main(...args); observation={result: typeof value==='bigint'?String(value):value??null};}
catch(error){if(!(error instanceof WebAssembly.RuntimeError))throw error;observation={trap:true};}
console.log(JSON.stringify({...observation,calls,side:e.side?.value??0}));`;
for (const c of cases.filter(c => !c.host)) test(`round2 execution ${c.pass}: ${c.name}`, () => {
  const dir = mkdtempSync(join(tmpdir(), "starshine-round2-"));
  try {
    const input = join(dir, "input.wasm"), output = join(dir, "output.wasm");
    writeFileSync(join(dir, "input.wat"), c.wat);
    execFileSync("wasm-tools", ["parse", join(dir, "input.wat"), "-o", input]);
    execFileSync("wasm-tools", ["validate", "--features", "all", input]);
    const host = c.host ? join(dir, "host.wasm") : "";
    if (c.host) {writeFileSync(join(dir, "host.wat"), c.host); execFileSync("wasm-tools", ["parse", join(dir, "host.wat"), "-o", host]);}
    const run = (path: string) => JSON.parse(execFileSync("node", ["-e", observe, path, JSON.stringify(c.args ?? []), host], {encoding: "utf8", timeout: 10_000}));
    const before = run(input); expect(before).toEqual(c.expected);
    execFileSync(binary, [`--${c.pass}`, ...(c.flags ?? []), input, "-o", output], {timeout: 10_000});
    execFileSync("wasm-tools", ["validate", "--features", "all", output]);
    expect(run(output)).toEqual(before);
  } finally {rmSync(dir, {recursive: true, force: true});}
}, 30_000);

// Node currently traps on the unchanged imported-subtype fixture. Keep that
// engine discrepancy separate and use verified Binaryen 132 for this case.
test("round2 execution directize imported subtype with Binaryen 132", () => {
  const c = cases.find(c => c.host)!;
  const dir = mkdtempSync(join(tmpdir(), "starshine-round2-import-"));
  const shell = resolve(process.env.BINARYEN_SHELL ?? ".tmp/binaryen-version_132/bin/wasm-shell");
  try {
    expect(execFileSync(shell, ["--version"], {encoding:"utf8"})).toMatch(/version 132\b/);
    const input=join(dir,"input.wasm"), output=join(dir,"output.wasm");
    writeFileSync(join(dir,"input.wat"),c.wat);
    execFileSync("wasm-tools",["parse",join(dir,"input.wat"),"-o",input]);
    const check=(path:string)=>{
      const bytes=Array.from(readFileSync(path), b=>`\\${b.toString(16).padStart(2,"0")}`).join("");
      const script=join(dir,"check.wast");
      writeFileSync(script,`${c.host}\n(register "m")\n(module binary "${bytes}")\n(assert_return (invoke "main") (i32.const 42))\n`);
      execFileSync(shell,[script],{timeout:10_000});
    };
    check(input);
    execFileSync(binary,["--directize",input,"-o",output],{timeout:10_000});
    execFileSync("wasm-tools",["validate","--features","all",output]);
    check(output);
  } finally {rmSync(dir,{recursive:true,force:true});}
});
