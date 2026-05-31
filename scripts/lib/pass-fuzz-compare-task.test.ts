import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { deterministicExportArgumentVector, smokeExecuteNodeRuntime } from "./pass-fuzz-compare-task";

function wasmFromWat(wat: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-runtime-stubs-"));
  const watPath = path.join(dir, "case.wat");
  const wasmPath = path.join(dir, "case.wasm");
  fs.writeFileSync(watPath, wat);
  const result = spawnSync("wasm-tools", ["parse", watPath, "-o", wasmPath], { encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || "wasm-tools parse failed");
  }
  return wasmPath;
}

describe("runtime export invocation", () => {
  test("choose deterministic zero argument vectors from exported function arity", () => {
    function noArgs() { return 1; }
    function threeArgs(_a: unknown, _b: unknown, _c: unknown) { return 1; }

    expect(deterministicExportArgumentVector(noArgs)).toEqual([]);
    expect(deterministicExportArgumentVector(threeArgs)).toEqual([0, 0, 0]);
  });

  test("invoke simple non-zero-arg exported functions with deterministic arguments", async () => {
    const wasmPath = wasmFromWat(`
      (module
        (func (export "add") (param i32 i32) (result i32)
          local.get 0
          local.get 1
          i32.add))
    `);

    const result = await smokeExecuteNodeRuntime(wasmPath);

    expect(result).toMatchObject({ ok: true, unsupported: false });
    expect(result.detail).toContain("deterministic simple argument vector");
  });
});

describe("runtime import stubs", () => {
  test("instantiate i64 global imports with deterministic zero BigInt stubs", async () => {
    const wasmPath = wasmFromWat(`
      (module
        (import "env" "seed" (global i64))
        (func (export "read") (result i64)
          global.get 0))
    `);

    const result = await smokeExecuteNodeRuntime(wasmPath);

    expect(result).toMatchObject({ ok: true, unsupported: false });
  });

  test("instantiate externref table imports with a matching deterministic table", async () => {
    const wasmPath = wasmFromWat(`
      (module
        (import "env" "refs" (table 1 externref))
        (func (export "size") (result i32)
          table.size 0))
    `);

    const result = await smokeExecuteNodeRuntime(wasmPath);

    expect(result).toMatchObject({ ok: true, unsupported: false });
  });
});
