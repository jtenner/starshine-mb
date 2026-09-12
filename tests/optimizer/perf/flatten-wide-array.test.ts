import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

// Dedicated bounded perf regression; deliberately outside the default Moon suite.
// Reduced from the Dewdrop WASI boundary string's v128 array constructor.
for (const computed of [false, true]) {
  test(`Flatten terminates and preserves a wide array constructor (computed=${computed})`, () => {
    const dir = mkdtempSync(join(tmpdir(), "starshine-wide-array-"));
    try {
      const wat = join(dir, "input.wat");
      const input = join(dir, "input.wasm");
      const output = join(dir, "output.wasm");
      const count = 2048;
      writeFileSync(wat, `(module (type $a (array (mut v128)))
        (func (export "main") (result i32) (local (ref null $a))
        ${(computed ? "v128.const i32x4 1 2 3 4\nv128.const i32x4 6 0 0 0\nv128.or\n" : "v128.const i32x4 1 2 3 4\n").repeat(count)}
        array.new_fixed $a ${count} local.tee 0 array.len
        local.get 0 i32.const 0 array.get $a i32x4.extract_lane 0 i32.add))`);
      execFileSync("wasm-tools", ["parse", wat, "-o", input]);
      const observe = `const fs = require('node:fs');
        const i = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[1])));
        console.log(i.exports.main());`;
      const before = execFileSync("node", ["-e", observe, input], {encoding: "utf8"});
      expect(before.trim()).toBe(String(count + (computed ? 7 : 1)));
      execFileSync(resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe"),
        ["--flatten", input, "-o", output], {timeout: 5000});
      execFileSync("wasm-tools", ["validate", "--features", "all", output]);
      expect(execFileSync("node", ["-e", observe, output], {encoding: "utf8"})).toBe(before);
    } finally { rmSync(dir, {recursive: true, force: true}); }
  }, 10000);

}
