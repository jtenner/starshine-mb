import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

// Build the native CLI before this lane, or set STARSHINE_BIN explicitly.
const binary = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
const duplicateImports = `(module
  (import "env" "f" (func $first (result i32)))
  (import "env" "f" (func $second (result i32)))
  (func (export "run") (result i32)
    (i32.add (call $first) (call $second))))`;
const duplicateExports = `(module
  (func $first (export "first") (result i32) (i32.const 7))
  (func $second (export "second") (result i32) (i32.const 7)))`;
const observeImports = `const fs = require('node:fs');
let reads = 0;
const env = Object.defineProperty({}, 'f', {
  get() { const value = ++reads; return () => value; }
});
const instance = new WebAssembly.Instance(
  new WebAssembly.Module(fs.readFileSync(process.argv[1])), {env});
console.log(JSON.stringify({reads, result: instance.exports.run()}));`;
const observeExports = `const fs = require('node:fs');
const instance = new WebAssembly.Instance(
  new WebAssembly.Module(fs.readFileSync(process.argv[1])));
console.log(JSON.stringify({same: instance.exports.first === instance.exports.second,
  first: instance.exports.first(), second: instance.exports.second()}));`;

function checkHostIdentity(
  name: string,
  wat: string,
  flags: string[],
  observe: string,
  beforeExpected: unknown,
  afterExpected: unknown,
) {
  test(name, () => {
    const dir = mkdtempSync(join(tmpdir(), "starshine-host-identity-"));
    try {
      const watPath = join(dir, "input.wat");
      const input = join(dir, "input.wasm");
      const output = join(dir, "output.wasm");
      writeFileSync(watPath, wat);
      execFileSync("wasm-tools", ["parse", watPath, "-o", input]);
      execFileSync("wasm-tools", ["validate", "--features", "all", input]);
      const run = (path: string) => JSON.parse(execFileSync(
        "node", ["-e", observe, path], {encoding: "utf8", timeout: 10_000},
      ));
      expect(run(input)).toEqual(beforeExpected);
      execFileSync(binary, [...flags, input, "-o", output], {timeout: 20_000});
      execFileSync("wasm-tools", ["validate", "--features", "all", output]);
      expect(run(output)).toEqual(afterExpected);
    } finally {
      rmSync(dir, {recursive: true, force: true});
    }
  });
}

for (const flags of [["--optimize"], ["--shrink"], ["-O4z", "--optimize"], ["-O4z", "--shrink"]]) {
  const preset = flags.join(" ");
  checkHostIdentity(
    `${preset} preserves independent same-name import resolution`,
    duplicateImports, flags, observeImports,
    {reads: 2, result: 3}, {reads: 2, result: 3},
  );
  checkHostIdentity(
    `${preset} preserves distinct exported function identities`,
    duplicateExports, flags, observeExports,
    {same: false, first: 7, second: 7},
    {same: false, first: 7, second: 7},
  );
}

// These are the direct passes' existing opt-in merge contracts. Keep their
// observable effects explicit while presets gain a conservative host policy.
checkHostIdentity(
  "direct duplicate-import-elimination merges same-name import resolution",
  duplicateImports, ["--duplicate-import-elimination"], observeImports,
  {reads: 2, result: 3}, {reads: 1, result: 2},
);
checkHostIdentity(
  "direct duplicate-function-elimination merges exported identities",
  duplicateExports, ["--duplicate-function-elimination"], observeExports,
  {same: false, first: 7, second: 7},
  {same: true, first: 7, second: 7},
);
checkHostIdentity(
  "explicit duplicate-import-elimination still runs after optimize",
  duplicateImports, ["--optimize", "--duplicate-import-elimination"], observeImports,
  {reads: 2, result: 3}, {reads: 1, result: 2},
);
checkHostIdentity(
  "explicit duplicate-function-elimination still runs after optimize",
  duplicateExports, ["--optimize", "--duplicate-function-elimination"], observeExports,
  {same: false, first: 7, second: 7},
  {same: true, first: 7, second: 7},
);
