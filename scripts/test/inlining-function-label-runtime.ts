import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

function fail(message: string): never {
  throw new Error(message);
}

function run(command: string, args: string[], cwd: string): void {
  execFileSync(command, args, { cwd, stdio: "inherit" });
}

async function readObservedGlobal(wasmPath: string): Promise<number> {
  const bytes = fs.readFileSync(wasmPath);
  const { instance } = await WebAssembly.instantiate(bytes);
  const exports = instance.exports as {
    run: () => void;
    get: () => number;
  };
  exports.run();
  return exports.get();
}

export async function runInliningFunctionLabelRuntimeTest(): Promise<void> {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const starshine = path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd.exe");
  if (!fs.existsSync(starshine)) {
    fail(`expected native Starshine binary: ${starshine}`);
  }

  const cases = [
    { name: "root-br", moduleFields: "", params: "", body: "br 0", args: "" },
    { name: "nested-br", moduleFields: "", params: "", body: "block block br 2 end end", args: "" },
    { name: "br-if", moduleFields: "", params: "(param i32)", body: "local.get 0 br_if 0", args: "i32.const 1" },
    { name: "br-table", moduleFields: "", params: "", body: "i32.const 0 br_table 0", args: "" },
    { name: "br-on-null", moduleFields: "", params: "(param externref)", body: "local.get 0 br_on_null 0 drop", args: "ref.null extern" },
    { name: "try-table-catch", moduleFields: "(tag $e)", params: "", body: "try_table (catch_all 0) throw $e end", args: "" },
  ];
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-inlining-function-label-"));

  for (const testCase of cases) {
    const watPath = path.join(tmpDir, `${testCase.name}.wat`);
    const inputPath = path.join(tmpDir, `${testCase.name}.wasm`);
    const outputPath = path.join(tmpDir, `${testCase.name}.inlined.wasm`);
    fs.writeFileSync(
      watPath,
      `(module
        ${testCase.moduleFields}
        (global $observed (mut i32) (i32.const 0))
        (func $helper ${testCase.params} ${testCase.body})
        (func (export "run") ${testCase.args} call $helper i32.const 1 global.set $observed)
        (func (export "get") (result i32) global.get $observed))`,
    );
    run("wasm-tools", ["parse", watPath, "-o", inputPath], repoRoot);
    run(starshine, ["--inlining", "--out", outputPath, inputPath], repoRoot);
    run("wasm-tools", ["validate", "--features", "all", outputPath], repoRoot);

    const before = await readObservedGlobal(inputPath);
    const after = await readObservedGlobal(outputPath);
    if (before !== 1 || after !== before) {
      fail(`${testCase.name}: expected observable suffix result 1 before/after inlining, got ${before}/${after}`);
    }
  }
}

if (import.meta.main) {
  await runInliningFunctionLabelRuntimeTest();
}
