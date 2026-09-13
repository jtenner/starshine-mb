import { expect, test } from "bun:test";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

// The September 13 atomic-boundary inputs use ordering 2, which the recorded
// Node/wasm-tools versions reject. Use an explicitly verified alternate engine;
// do not reinterpret their blocked observations as successful Node execution.
const compiler = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
const shell = resolve(process.env.BINARYEN_SHELL ?? ".tmp/binaryen-version_132/bin/wasm-shell");
const assembler = join(dirname(shell), "wasm-as");
const optimizer = join(dirname(shell), "wasm-opt");
const orders = ["", "acqrel", "relaxed"];
const values = [-257, -256, -255, -129, -128, -1, 0, 1, 127, 128, 255, 256, 257];
const fixture = `(module
  (type $S (struct (field (mut i8))))
  (type $A (array (mut i32)))
  (func $boundary (param (ref $S))
    ${orders.map(order => `(drop (struct.atomic.get_s ${order} $S 0 (local.get 0)))`).join("\n")}
    (drop (array.get $A (array.new $A (i32.const 7) (i32.const 1)) (i32.const 0))))
  (func (export "run") (param i32) (result i32)
    (call $boundary (struct.new $S (local.get 0)))
    (i32.const 42))
  ${orders.flatMap((order, index) => ["s", "u"].map(sign => `
    (func (export "read_${index}_${sign}") (param i32) (result i32)
      (struct.atomic.get_${sign} ${order} $S 0 (struct.new $S (local.get 0))))`)).join("\n")}
)`;

// Independently computed packed-i8 results, not values obtained from an oracle.
const assertions = values.flatMap(value => [
  `(assert_return (invoke "run" (i32.const ${value})) (i32.const 42))`,
  ...orders.flatMap((_, index) => ["s", "u"].map(sign => {
    const expected = sign === "s" ? (value << 24) >> 24 : value & 255;
    return `(assert_return (invoke "read_${index}_${sign}" (i32.const ${value})) (i32.const ${expected}))`;
  })),
]).join("\n");

for (const pass of ["precompute", "precompute-propagate"]) {
  test(`atomic boundary execution ${pass} with Binaryen 132`, () => {
    for (const tool of [shell, assembler, optimizer]) {
      expect(execFileSync(tool, ["--version"], { encoding: "utf8", timeout: 10_000 })).toMatch(/version 132\b/);
    }
    const dir = mkdtempSync(join(tmpdir(), "starshine-atomic-execution-"));
    try {
      const wat = join(dir, "input.wat");
      const original = join(dir, "original.wasm");
      const starshine = join(dir, "starshine.wasm");
      const binaryen = join(dir, "binaryen.wasm");
      writeFileSync(wat, fixture);
      execFileSync(assembler, [wat, "--all-features", "-o", original], { timeout: 10_000 });
      execFileSync(compiler, [`--${pass}`, original, "-o", starshine], { timeout: 10_000 });
      execFileSync(optimizer, [original, "--all-features", `--${pass}`, "-o", binaryen], { timeout: 10_000 });
      for (const path of [original, starshine, binaryen]) {
        const bytes = Array.from(readFileSync(path), byte => `\\${byte.toString(16).padStart(2, "0")}`).join("");
        const wast = join(dir, "check.wast");
        // Run the actual assembled/optimized bytes rather than re-rendered WAT.
        writeFileSync(wast, `(module binary "${bytes}")\n${assertions}\n`);
        const result = spawnSync(shell, [wast], { encoding: "utf8", timeout: 10_000 });
        if (result.error) throw result.error;
        if (result.status !== 0) throw new Error(`${result.signal ?? result.status}: ${result.stdout}${result.stderr}`);
        expect(result.stdout + result.stderr).toContain("all checks passed.");
      }
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }, 30_000);
}
