import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function fail(message: string): never {
  throw new Error(message);
}

function run(command: string, args: string[], cwd: string): void {
  const result = spawnSync(command, args, { cwd, encoding: "utf8" });
  if (result.status !== 0) {
    fail(
      `${command} ${args.join(" ")} failed with ${result.status}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
    );
  }
}

const wat = String.raw`
(module
  (memory (export "memory") 1)
  (global $effects (export "effects") (mut i32) (i32.const 0))

  (func $effect (result (ref null eq))
    global.get $effects
    i32.const 1
    i32.add
    global.set $effects
    i32.const 0
    i32.const 1234
    i32.store
    i32.const 9
    ref.i31)

  (func $consume2 (param (ref eq) (ref null eq)) (result i32)
    i32.const 42)
  (func $same (param $r (ref null eq)) (result i32)
    (call $consume2
      (ref.as_non_null (local.get $r))
      (local.tee $r (call $effect))))

  (func $different (param $r (ref null eq)) (result i32)
    (local $other (ref null eq))
    (call $consume2
      (ref.as_non_null (local.get $r))
      (local.tee $other (call $effect))))

  (func $nested (param $r (ref null eq)) (result i32)
    (call $consume2
      (ref.as_non_null (ref.as_non_null (local.get $r)))
      (local.tee $r (call $effect))))

  (func (export "same_null") (result i32)
    ref.null eq
    call $same)
  (func (export "same_nonnull") (result i32)
    i32.const 7
    ref.i31
    call $same)
  (func (export "different_null") (result i32)
    ref.null eq
    call $different)
  (func (export "different_nonnull") (result i32)
    i32.const 7
    ref.i31
    call $different)
  (func (export "nested_null") (result i32)
    ref.null eq
    call $nested)
  (func (export "nested_nonnull") (result i32)
    i32.const 7
    ref.i31
    call $nested))
`;

async function instantiate(wasmPath: string): Promise<WebAssembly.Instance> {
  const bytes = fs.readFileSync(wasmPath);
  const result = await WebAssembly.instantiate(bytes);
  return result.instance;
}

async function checkCase(
  wasmPath: string,
  exportName: string,
  shouldTrap: boolean,
  expectedResult: number,
): Promise<void> {
  const instance = await instantiate(wasmPath);
  const exports = instance.exports as Record<string, WebAssembly.ExportValue>;
  const invoke = exports[exportName];
  if (typeof invoke !== "function") fail(`missing function export ${exportName}`);
  let trapped = false;
  let result: unknown;
  try {
    result = invoke();
  } catch (error) {
    if (!(error instanceof WebAssembly.RuntimeError)) throw error;
    trapped = true;
  }
  if (trapped !== shouldTrap) {
    fail(`${exportName}: expected trap=${shouldTrap}, got trap=${trapped}`);
  }
  if (!shouldTrap && result !== expectedResult) {
    fail(`${exportName}: expected ${expectedResult}, got ${String(result)}`);
  }
  const effects = exports.effects;
  if (!(effects instanceof WebAssembly.Global)) fail("missing mutable effects global");
  const expectedEffects = shouldTrap ? 0 : 1;
  if (effects.value !== expectedEffects) {
    fail(`${exportName}: expected ${expectedEffects} effects, got ${String(effects.value)}`);
  }
  const memory = exports.memory;
  if (!(memory instanceof WebAssembly.Memory)) fail("missing memory export");
  const stored = new DataView(memory.buffer).getInt32(0, true);
  const expectedStored = shouldTrap ? 0 : 1234;
  if (stored !== expectedStored) {
    fail(`${exportName}: expected memory[0]=${expectedStored}, got ${stored}`);
  }
}

async function main(): Promise<void> {
  const repoRoot = path.resolve(import.meta.dir, "../..");
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-flatten-trap-order-"));
  try {
    const watPath = path.join(tmp, "input.wat");
    const inputPath = path.join(tmp, "input.wasm");
    const outputPath = path.join(tmp, "output.wasm");
    fs.writeFileSync(watPath, wat);
    run("wasm-tools", ["parse", watPath, "-o", inputPath], repoRoot);
    run(
      path.join(repoRoot, "_build/native/release/build/cmd/cmd.exe"),
      ["--flatten", "--out", outputPath, inputPath],
      repoRoot,
    );
    run("wasm-tools", ["validate", "--features", "all", outputPath], repoRoot);

    for (const [name, traps, result] of [
      ["same_null", true, 42],
      ["same_nonnull", false, 42],
      ["different_null", true, 42],
      ["different_nonnull", false, 42],
      ["nested_null", true, 42],
      ["nested_nonnull", false, 42],
    ] as const) {
      await checkCase(outputPath, name, traps, result);
    }
    console.log("flatten trap-order runtime regression passed");
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

await main();
