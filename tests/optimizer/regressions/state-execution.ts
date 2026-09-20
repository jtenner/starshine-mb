import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const binary = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
export type StateCase = {name: string; pass: string; wat: string; expected: number; alias?: boolean};
// Each observation creates fresh host globals; aliasing is within one instance.
const observe = `const fs=require('node:fs');
const a=new WebAssembly.Global({value:'i32',mutable:true},1);
const b=process.argv[2]==='true'?a:new WebAssembly.Global({value:'i32',mutable:true},1);
const e=new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[1])),{m:{a,b}}).exports;
console.log(e.run());`;
export function stateRegression(c: StateCase) {
  test(`${c.pass} preserves ${c.name}`, () => {
    const dir = mkdtempSync(join(tmpdir(), "starshine-global-state-"));
    try {
      const wat = join(dir, "input.wat"), input = join(dir, "input.wasm"), output = join(dir, "output.wasm");
      writeFileSync(wat, c.wat);
      execFileSync("wasm-tools", ["parse", wat, "-o", input]);
      execFileSync("wasm-tools", ["validate", "--features", "all", input]);
      const run = (path: string) => Number(execFileSync("node", ["-e", observe, path, String(c.alias)], {encoding:"utf8", timeout: 10000}));
      const before = run(input);
      expect(before).toBe(c.expected);
      execFileSync(binary, [`--${c.pass}`, input, "-o", output], {timeout:10000});
      execFileSync("wasm-tools", ["validate", "--features", "all", output]);
      expect(run(output)).toBe(before);
    } finally { rmSync(dir, {recursive:true, force:true}); }
  });
}
