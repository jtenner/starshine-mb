import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { assertWasmException } from "./shell-execution";

const starshine = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
const oracle = resolve(process.env.BINARYEN_BIN ?? ".tmp/binaryen-version_132/bin/wasm-opt");
// Exact saved seed 24301, closed-world dae2 case 15. Keep the original bytes:
// reparsing the adjacent readable WAT is not a replay of the saved input.
const input = readFileSync(new URL("./dae2-resume-throw.wasm", import.meta.url));

for (const closed of [false, true]) {
  for (const pass of ["dae2", "dae2-optimizing"]) {
    test(`${pass}, closed=${closed}: original and both optimizers throw an exception`, () => {
      const dir = mkdtempSync(join(tmpdir(), "starshine-resume-throw-"));
      try {
        expect(execFileSync(oracle, ["--version"], { encoding: "utf8" })).toMatch(/version 132\b/);
        const original = join(dir, "input.wasm");
        writeFileSync(original, input);
        assertWasmException(input, "run");
        const oraclePasses = pass === "dae2" ? ["--dae2"] : ["--dae2", "--simplify-locals", "--vacuum"];
        for (const [name, binary, flags] of [["starshine", starshine, [`--${pass}`]], ["binaryen", oracle, ["--all-features", ...oraclePasses]]] as const) {
          const output = join(dir, `${name}.wasm`);
          execFileSync(binary, [original, ...flags, ...(closed ? ["--closed-world"] : []), "-o", output], { timeout: 10_000 });
          assertWasmException(readFileSync(output), "run");
        }
      } finally {
        rmSync(dir, { recursive: true, force: true });
      }
    });
  }
}

for (const [name, body] of [["normal return", ""], ["trap", "unreachable"]]) {
  test(`exception assertion rejects ${name}`, () => {
    const dir = mkdtempSync(join(tmpdir(), "starshine-exception-control-"));
    try {
      const wat = join(dir, "control.wat");
      const wasm = join(dir, "control.wasm");
      writeFileSync(wat, `(module (func (export "run") ${body}))`);
      execFileSync("wasm-tools", ["parse", wat, "-o", wasm]);
      expect(() => assertWasmException(readFileSync(wasm), "run")).toThrow("expected exception");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
}
