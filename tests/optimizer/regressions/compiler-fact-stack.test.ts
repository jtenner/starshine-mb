import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const binary = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
function uleb(value: number): number[] {
  const bytes: number[] = [];
  do { const byte = value & 127; value = Math.floor(value / 128); bytes.push(byte | (value ? 128 : 0)); } while (value);
  return bytes;
}
// compiler.facts v1, matching compiler_facts_encode.mbt: one body with exact
// i32 facts at canonical expression opcode offsets (excluding local declarations).
function facts(offset: number, lanes: number[]): Uint8Array {
  const sites = lanes.flatMap(lane => [1, ...uleb(offset), lane,
    1, 1, 0, 2, 2, // Some singleton IntegerValue(Int32, 2)
    0, 0, 0, 0, 0]); // other value domains and provenance absent
  const payload = [14, ...Buffer.from("compiler.facts"), 1, 0,
    0, 0, 0, 0, 0, 0, 0, // producer, world, functions/signatures/types/globals/tables
    1, 1, lanes.length, ...sites, // bodies, function, sites
    0, 0, 0, 0, 0, 0, 0, // other body fact vectors
    0]; // hints
  return Uint8Array.from([0, ...uleb(payload.length), ...payload]);
}
const cases = [
  {name: "one parameter", params: "i32", prefix: "i32.const 2 i32.const 1", offset: 4, call: "call $two"},
  {name: "two parameters", params: "i32 i32", prefix: "i32.const 2 i32.const 0 i32.const 1", offset: 6, call: "call $two"},
  {name: "zero parameters", params: "", prefix: "i32.const 2", offset: 2, call: "call $two"},
  {name: "indirect index", params: "i32", prefix: "i32.const 2 i32.const 1 i32.const 0", offset: 6, call: "call_indirect (type $t)", extra: "(table 1 funcref) (elem (i32.const 0) $two)"},
  {name: "reference operand", params: "i32", prefix: "i32.const 2 i32.const 1 ref.func $two", offset: 6, call: "call_ref $t", extra: "(elem declare func $two)"},
  {name: "multiple lanes", params: "i32", prefix: "i32.const 1", offset: 2, call: "call $two", multi: true},
  {name: "intervening drop", params: "", prefix: "i32.const 2 i32.const 1 drop", offset: 5, call: "call $two"},
  {name: "intervening addition", params: "i32", prefix: "i32.const 2 i32.const 0 i32.const 1 i32.add", offset: 7, call: "call $two"},
  {name: "local write", params: "", prefix: "i32.const 2 i32.const 1 local.set 0", offset: 6, call: "call $two", locals: "(local i32)"},
  {name: "local read", params: "i32", prefix: "i32.const 2 local.get 0", offset: 4, call: "call $two", locals: "(local i32)"},
  {name: "global write", params: "", prefix: "i32.const 2 i32.const 1 global.set 0", offset: 6, call: "call $two", extra: "(global (mut i32) (i32.const 0))"},
  {name: "global read", params: "i32", prefix: "i32.const 2 global.get 0", offset: 4, call: "call $two", extra: "(global i32 (i32.const 1))"},
  {name: "block result", params: "", prefix: "i32.const 2", offset: 2, call: "(block (result i32) call $two)"},
  {name: "block input", params: "i32", prefix: "i32.const 2 i32.const 1", offset: 4, call: "(block (param i32) (result i32) call $two)"},
  {name: "if condition", params: "", prefix: "i32.const 2 i32.const 1", offset: 4, call: "(if (result i32) (then call $two) (else call $two))"},
  {name: "loop result", params: "", prefix: "i32.const 2", offset: 2, call: "(loop (result i32) call $two)"},
  {name: "trailing nop", params: "", prefix: "i32.const 2", offset: 2, call: "call $two nop"},
];
for (const c of cases) {
  for (const op of ["i32.eq", "i32.ge_s", "i32.ge_u"]) {
    test(`trusted fact uses actual stack lanes: ${c.name}, ${op}`, () => {
      const dir = mkdtempSync(join(tmpdir(), "starshine-fact-stack-"));
      try {
        const input = join(dir, "input.wasm"), output = join(dir, "output.wasm");
        const result = c.multi ? "i32 i32" : "i32";
        writeFileSync(join(dir, "input.wat"), `(module
          (type $t (func (param ${c.params}) (result ${result})))
          (func $two (type $t) i32.const 2 ${c.multi ? "i32.const 2" : ""})
          ${c.extra ?? ""}
          (func (export "main") (result i32) ${c.locals ?? ""} ${c.prefix} ${c.call} ${op}))`);
        execFileSync("wasm-tools", ["parse", join(dir, "input.wat"), "-o", input]);
        execFileSync("wasm-tools", ["strip", "--all", input, "-o", input]);
        writeFileSync(input, Buffer.concat([readFileSync(input), facts(c.offset, c.multi ? [0, 1] : [0])]));
        const observe = (path: string) => execFileSync("node", ["-e", `const fs=require('fs'); const i=new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[1]))); console.log(i.exports.main());`, path], {encoding: "utf8"}).trim();
        execFileSync("wasm-tools", ["validate", "--features", "all", input]);
        expect(observe(input)).toBe("1");
        execFileSync(binary, ["--compiler-facts=trust", "--apply-compiler-facts", input, "-o", output], {timeout: 10_000});
        execFileSync("wasm-tools", ["validate", "--features", "all", output]);
        expect(observe(output)).toBe("1");
      } finally { rmSync(dir, {recursive: true, force: true}); }
    });
  }
}
