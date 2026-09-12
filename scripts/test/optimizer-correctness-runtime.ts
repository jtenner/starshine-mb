import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";

const root = path.resolve(import.meta.dir, "../..");
const binary = process.argv[2] ?? path.join(root, "_build/native/release/build/cmd/cmd.exe");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-optimizer-correctness-"));
const runner = path.join(dir, "observe.cjs");
fs.writeFileSync(runner, `
const fs = require('node:fs');
let e;
const shared = new WebAssembly.Global({value: 'i32', mutable: true}, 1);
try { e = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {e: {g: shared, h: shared}}).exports; }
catch (err) { if (!(err instanceof WebAssembly.RuntimeError)) throw err; console.log(JSON.stringify({instantiateTrap:true})); process.exit(0); }
let trap = false, result;
try { result = e.run(); } catch (err) { if (!(err instanceof WebAssembly.RuntimeError)) throw err; trap = true; }
console.log(JSON.stringify({trap, result, tail: e.tail ? e.tail() : undefined, memory: e.memory ? Array.from(new Uint8Array(e.memory.buffer)) : undefined,
 globals: Object.entries(e).filter(([k,v]) => v instanceof WebAssembly.Global).map(([k,v]) => [k,v.value])}));
`);
function command(cmd: string, args: string[]): string {
  return execFileSync(cmd, args, {cwd: root, timeout: 30000, encoding: "utf8"});
}
let count = 0;
let failures = 0;
function check(name: string, wat: string, pass: string, expectedTrap: boolean, result?: number): void {
  const input = path.join(dir, `${name}.wat`), wasm = `${input}.wasm`, output = `${input}.out.wasm`;
  fs.writeFileSync(input, wat);
  command("wasm-tools", ["parse", input, "-o", wasm]);
  command("wasm-tools", ["validate", "--features", "all", wasm]);
  command(binary, [wasm, `--${pass}`, "-o", output]);
  command("wasm-tools", ["validate", "--features", "all", output]);
  const before = JSON.parse(command("node", [runner, wasm]));
  const after = JSON.parse(command("node", [runner, output]));
  try {
    assert.equal(before.instantiateTrap ?? before.trap, expectedTrap, `${name}: fixture trap`);
    if (result !== undefined) assert.equal(before.result, result);
    if (name.startsWith("ordered-operands")) assert.deepEqual(before.globals, [["g", 123]]);
    if (name.startsWith("operand-") || name.startsWith("active-operand-")) assert.deepEqual(before.globals, [["g", 1]]);
    if (name.startsWith("split-") && name.endsWith("-65532")) assert.deepEqual(before.memory.slice(-4), [0, 0, 0, 0]);
    assert.deepEqual(after, before, `${name}: observable behavior`);
    console.log(`${name}: passed`);
  } catch {
    failures++;
    const firstChangedByte = before.memory?.findIndex((byte: number, i: number) => after.memory?.[i] !== byte);
    console.error(`${name}: FAILED (artifacts ${dir}); results ${before.result}/${after.result}, traps ${before.trap}/${after.trap}, first changed byte ${firstChangedByte}, globals ${JSON.stringify(before.globals)}/${JSON.stringify(after.globals)}`);
  }
  count++;
}
const zeros = "\\00".repeat(64);
for (const m64 of [false, true]) {
  const t = m64 ? "i64" : "i32", suffix = m64 ? "64" : "32";
  const memory = `(memory (export "memory") ${m64 ? "i64 " : ""}1)`;
  const init = (dst: string, src: number, len: number, seg = 0) => `(memory.init ${seg} ${dst} (i32.const ${src}) (i32.const ${len}))`;
  const c = (n: number) => `(${t}.const ${n})`;
  for (const [src, len, dst, trap] of [[0,1,0,true],[0,0,0,false],[0,0,65536,false],[0,0,65537,true],[1,0,0,true]] as const) {
    check(`active-${suffix}-${src}-${len}-${dst}`, `(module ${memory} (data (${t}.const 0) "x") (func (export "run") ${init(c(dst),src,len)}))`, "memory-packing", trap);
  }
  for (const [src,len,dst,trap] of [[0,72,65532,true],[0,0,65537,true],[73,0,0,true],[72,0,65536,false],[0,72,0,false]] as const) {
    check(`split-${suffix}-${src}-${len}-${dst}`, `(module ${memory} (data "ABCD${zeros}EFGH") (func (export "run") ${init(c(dst),src,len)}))`, "memory-packing", trap);
  }
  for (const shape of [zeros, `A${zeros}`, `${zeros}A`]) {
    for (const dropped of [false,true]) for (const [src,len] of [[0,1],[1,1],[0,65],[0,0],[1,0]]) {
      const n = shape === zeros ? 64 : 65;
      check(`lifetime-${suffix}-${count}`, `(module ${memory} (data "${shape}") (func (export "run") ${dropped ? "data.drop 0" : ""} ${init(c(0),src,len)}))`, "memory-packing", src + len > n || (dropped && (src !== 0 || len !== 0)));
    }
  }
  for (const dropped of [0,1]) {
    check(`independent-${suffix}-${dropped}`, `(module ${memory} (data "${zeros}A") (data "${zeros}B") (func (export "copyA") ${init(c(128),0,65,0)}) (func (export "copyB") ${init(c(256),0,65,1)}) (func (export "run") (data.drop ${dropped}) ${init(c(0),0,65,1-dropped)}))`, "memory-packing", false);
  }
  for (const offset of [-1, -2, -65536]) for (const bytes of ["", "\\00", "\\00\\00", "A\\00"]) {
    check(`overflow-${suffix}-${count}`, `(module ${memory} (data (${t}.const ${offset}) "${bytes}") (func (export "run")))`, "memory-packing", true);
  }
  for (const active of [false, true]) {
    check(`ordered-operands-${suffix}-${active}`, `(module ${memory}
      (global (export "g") (mut i32) (i32.const 0))
      (data ${active ? `(${t}.const 0)` : ""} "${zeros}")
      (func $step (param i32) (global.set 0 (i32.add (i32.mul (global.get 0) (i32.const 10)) (local.get 0))))
      (func (export "run") (memory.init 0
        (block (result ${t}) (call $step (i32.const 1)) ${c(0)})
        (block (result i32) (call $step (i32.const 2)) (i32.const 0))
        (block (result i32) (call $step (i32.const 3)) (i32.const 1)))))`, "memory-packing", active);
  }
  check(`active-operand-${suffix}`, `(module ${memory} (global (export "g") (mut i32) (i32.const 0)) (data (${t}.const 0) "x") (func (export "run") ${init(`(block (result ${t}) (global.set 0 (i32.add (global.get 0) (i32.const 1))) ${c(0)})`,0,1)}))`, "memory-packing", true);
  check(`active-array-${suffix}`, `(module (type (array (mut i8))) ${memory} (data (${t}.const 0) "${zeros}") (func (export "run") (result i32) (array.len (array.new_data 0 0 (i32.const 0) (i32.const 0)))))`, "memory-packing", false, 0);
  check(`operand-${suffix}`, `(module ${memory} (global (export "g") (mut i32) (i32.const 0)) (data "ABCD${zeros}EFGH") (func (export "run") ${init(`(block (result ${t}) (global.set 0 (i32.add (global.get 0) (i32.const 1))) ${c(65532)})`,0,72)}))`, "memory-packing", true);
}
// Do not export or snapshot this 4 GiB memory: only the final byte is observed.
// V8 reserves it virtually; these fixtures touch at most two pages.
for (const bytes of ["", "\\00", "\\00\\00"]) {
  check(`full32-marker-${count}`, `(module (memory 65536) (data (i32.const -1) "${bytes}") (func (export "run")))`, "memory-packing", bytes.length > 4);
}
check("full32-active-empty", `(module (memory 65536) (data (i32.const 0) "x") (func (export "run") (memory.init 0 (i32.const -1) (i32.const 0) (i32.const 0))))`, "memory-packing", false);
check("full32-split-overflow", `(module (memory 65536) (data (i32.const -1) "Z") (data "A${zeros}") (func (export "tail") (result i32) (i32.load8_u (i32.const -1))) (func (export "run") (memory.init 1 (i32.const -1) (i32.const 0) (i32.const 2))))`, "memory-packing", true);
check("nested-global", `(module (global (export "g") (mut i32) (i32.const 1)) (global (export "h") (mut i32) (i32.const 0)) (func (export "run") (result i32) (local i32) (local.set 0 (global.get 0)) (global.set 1 (block (result i32) (global.set 0 (i32.const 2)) (i32.const 0))) (local.get 0)))`, "code-pushing", false, 1);
check("bounded-local", `(module (func (export "run") (result i32) (local i32 i32) (local.set 0 (i32.const 1)) (local.set 1 (local.get 0)) (block (drop (local.get 0)) (local.set 0 (i32.const 2))) (if (local.get 0) (then nop)) (local.get 1)))`, "code-pushing", false, 1);
for (const nested of [false, true]) {
  check(`imported-global-alias-${nested}`, `(module
    (import "e" "g" (global (mut i32))) (import "e" "h" (global (mut i32)))
    (global (mut i32) (i32.const 0)) (export "g" (global 0)) (export "h" (global 1))
    (func (export "run") (result i32) (local i32)
      (local.set 0 (global.get 0))
      ${nested ? "(global.set 2 (block (result i32) (global.set 1 (i32.const 2)) (i32.const 0)))" : "(global.set 1 (i32.const 2))"}
      (local.get 0)))`, "code-pushing", false, 1);
}
if (failures) throw new Error(`${failures}/${count} failed; artifacts: ${dir}`);
console.log(`${count} optimizer runtime regressions passed`);
fs.rmSync(dir, {recursive:true});
