import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { execFileSync } from "node:child_process";

// Run after building the native CLI, or set STARSHINE_BIN to an explicit build.
const binary = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
const observe = `const fs = require('node:fs');
const instance = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[1])));
try { console.log(JSON.stringify({result: instance.exports.main()})); }
catch (error) { if (!(error instanceof WebAssembly.RuntimeError)) throw error;
 console.log(JSON.stringify({trap: error.message})); }`;

export function regression(fixture: string, passes: readonly string[], expected: unknown) {
  for (const pass of passes) {
    test(`${pass} validates and preserves execution of ${fixture}`, () => {
      const dir = mkdtempSync(join(tmpdir(), "starshine-reference-scope-"));
      try {
        const input = join(dir, "input.wasm");
        const output = join(dir, "output.wasm");
        const wat = readFileSync(new URL(`${fixture}.wat`, import.meta.url), "utf8");
        writeFileSync(join(dir, "input.wat"), wat);
        execFileSync("wasm-tools", ["parse", join(dir, "input.wat"), "-o", input]);
        execFileSync("wasm-tools", ["validate", "--features", "all", input]);
        const before = JSON.parse(execFileSync("node", ["-e", observe, input], {encoding: "utf8"}));
        expect(before).toEqual(expected);
        execFileSync(binary, [`--${pass}`, input, "-o", output], {timeout: 10_000});
        execFileSync("wasm-tools", ["validate", "--features", "all", output]);
        const after = JSON.parse(execFileSync("node", ["-e", observe, output], {encoding: "utf8"}));
        expect(after).toEqual(before);
      } finally {
        rmSync(dir, {recursive: true, force: true});
      }
    });
  }
}
