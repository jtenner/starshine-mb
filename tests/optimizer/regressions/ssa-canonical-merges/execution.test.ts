import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import cases from "./cases.json";

const binary = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
const observe = `const fs = require('node:fs');
const i = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[1])));
try { console.log(JSON.stringify(i.exports.main())); }
catch (e) { if (!(e instanceof WebAssembly.RuntimeError)) throw e;
 console.log(JSON.stringify({kind: e.constructor.name, error: e.message})); }`;

// IDs identify the original baseline fixtures in ssa_nomerge_test.mbt.
// The three unconditionally looping inputs have bounded variants. Exact heap
// types require the same descriptor setting for original and optimized runs.
for (const fixture of cases) {
  test(`ssa-nomerge canonical merge ${fixture.id}: ${fixture.name}`, () => {
    const dir = mkdtempSync(join(tmpdir(), "starshine-ssa-canonical-"));
    try {
      const input = join(dir, "input.wasm");
      const output = join(dir, "output.wasm");
      writeFileSync(input, Buffer.from(fixture.wasm, "hex"));
      execFileSync("wasm-tools", ["validate", "--features", "all", input]);
      execFileSync(binary, ["--ssa-nomerge", input, "-o", output], {timeout: 5_000});
      execFileSync("wasm-tools", ["validate", "--features", "all", output]);
      const texts = [input, output].map(file =>
        execFileSync("wasm-tools", ["print", file], {encoding: "utf8"}).trimEnd().slice(0, -1));
      for (const probe of fixture.probes) {
        const results = texts.map(text => {
          const wat = join(dir, "probe.wat");
          const wasm = join(dir, "probe.wasm");
          writeFileSync(wat, text + probe.suffix + ")");
          execFileSync("wasm-tools", ["parse", wat, "-o", wasm]);
          execFileSync("wasm-tools", ["validate", "--features", "all", wasm]);
          return JSON.parse(execFileSync("node", ["--experimental-wasm-custom-descriptors", "-e", observe, wasm],
            {encoding: "utf8", timeout: 1_000}));
        });
        expect(results[0]).toEqual(probe.expected);
        expect(results[1]).toEqual(results[0]);
      }
    } finally {
      rmSync(dir, {recursive: true, force: true});
    }
  }, 10_000);
}
