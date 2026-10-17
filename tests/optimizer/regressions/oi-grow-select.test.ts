import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

// Qualification lead: https://github.com/WebAssembly/binaryen/pull/9227.
// Identical-looking grows return sequential old sizes. No Starshine bug is
// established: test observable outcomes, including eager operand evaluation.
const binary = resolve(process.env.STARSHINE_BIN ?? "_build/native/release/build/cmd/cmd.exe");
const scenarios = [
  { name: "success", maximum: 3, delta: 1, old: [1, 2], size: 3 },
  { name: "zero", maximum: 1, delta: 0, old: [1, 1], size: 1 },
  { name: "failure", maximum: 1, delta: 1, old: [-1, -1], size: 1 },
  { name: "second failure", maximum: 2, delta: 1, old: [1, -1], size: 2 },
];

for (const resource of ["memory", "table"] as const) {
  for (const scenario of scenarios) for (const effects of [false, true]) {
    for (const condition of [0, 1]) {
      test(`OI ${resource} grow select ${scenario.name}, effects ${effects}, condition ${condition}`, () => {
        const dir = mkdtempSync(join(tmpdir(), "starshine-oi-grow-"));
        try {
          const input = join(dir, "input.wasm"), output = join(dir, "output.wasm");
          const operand = effects ? "(call $delta)" : `(i32.const ${scenario.delta})`;
          const grow = resource === "memory"
            ? `(memory.grow ${operand})`
            : `(table.grow 0 (ref.null extern) ${operand})`;
          const declaration = resource === "memory"
            ? `(memory (export "resource") 1 ${scenario.maximum})`
            : `(table (export "resource") 1 ${scenario.maximum} externref)`;
          const wat = `(module
            ${effects ? '(import "env" "delta" (func $delta (result i32))) (import "env" "condition" (func $condition (param i32) (result i32)))' : ""}
            ${declaration}
            (func (export "run") (param i32) (result i32)
              (select ${grow} ${grow} ${effects ? "(call $condition (local.get 0))" : "(local.get 0)"})))`;
          writeFileSync(join(dir, "input.wat"), wat);
          execFileSync("wasm-tools", ["parse", join(dir, "input.wat"), "-o", input]);
          execFileSync("wasm-tools", ["validate", input]);
          const observe = `const fs = require('node:fs');
            const log = [];
            let instance;
            const size = () => ${resource === "memory" ? "instance.exports.resource.buffer.byteLength / 65536" : "instance.exports.resource.length"};
            instance = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[1])), {
              env: { delta() { log.push(['delta', size()]); return ${scenario.delta}; },
                condition(n) { log.push(['condition', size(), n]); return n; } }
            });
            const result = instance.exports.run(${condition});
            console.log(JSON.stringify({result, size: size(), log}));`;
          const observeFile = (path: string) => JSON.parse(execFileSync(
            "node", ["-e", observe, path], { encoding: "utf8", timeout: 10_000 },
          ));
          const expected = {
            result: scenario.old[condition ? 0 : 1], size: scenario.size,
            log: effects ? [
              ["delta", 1],
              ["delta", scenario.old[0] === -1 ? 1 : 1 + scenario.delta],
              ["condition", scenario.size, condition],
            ] : [],
          };
          expect(observeFile(input)).toEqual(expected);
          execFileSync(binary, ["--optimize-instructions", input, "-o", output], { timeout: 20_000 });
          execFileSync("wasm-tools", ["validate", output]);
          expect(observeFile(output)).toEqual(expected);
        } finally {
          rmSync(dir, { recursive: true, force: true });
        }
      });
    }
  }
}
