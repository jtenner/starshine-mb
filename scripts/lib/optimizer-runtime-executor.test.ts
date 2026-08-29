import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { describe, expect, test } from "bun:test";

import { buildInvocationPlanV2 } from "./optimizer-runtime";
import {
  buildRuntimeInterfaceFromStarshine,
  buildRuntimeInterfaceFromWasm,
  executeNodeObservationV2WithTimeout,
  runNodeThreeWaySemanticOracleV2,
} from "./optimizer-runtime-executor";

function compileWat(wat: string): { dir: string; wasmPath: string } {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-runtime-v2-"));
  const watPath = path.join(dir, "module.wat");
  const wasmPath = path.join(dir, "module.wasm");
  fs.writeFileSync(watPath, wat);
  const result = spawnSync("wasm-tools", ["parse", watPath, "-o", wasmPath], { encoding: "utf8" });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || "wasm-tools parse failed");
  return { dir, wasmPath };
}

const RUNTIME_WAT = `(module
  (import "env" "tick" (func $tick (param i32) (result i32)))
  (import "env" "g" (global $g (mut i32)))
  (import "env" "mem" (memory $mem 2 3))
  (import "env" "tab" (table $tab 2 4 funcref))
  (global $counter (export "counter") (mut i32) (i32.const 0))
  (func $target (result i32) i32.const 7)
  (elem (i32.const 0) func $target)
  (func $start
    i32.const 5
    call $tick
    global.set $counter)
  (start $start)
  (func (export "run") (param i32) (result i32)
    local.get 0
    call $tick
    global.set $counter
    i32.const 70000
    global.get $counter
    i32.store8
    global.get $counter)
  (export "imported-global" (global $g))
  (export "memory" (memory $mem))
  (export "table" (table $tab)))`;

describe("runtime-interface extraction", () => {
  test("loads the decoded interface from the native Starshine report", () => {
    const calls: Array<{ bin: string; args: string[] }> = [];
    const expected = {
      schema: "starshine.optimizer-runtime-interface.v1" as const,
      moduleHash: "fnv1a64:abc",
      interfaceHash: "fnv1a64:def",
      features: [],
      hasStart: false,
      imports: { functions: [], globals: [], memories: [], tables: [], tags: [] },
      exports: [],
    };
    const actual = buildRuntimeInterfaceFromStarshine("input.wasm", "starshine-test", (bin, args) => {
      calls.push({ bin, args });
      return { status: 0, stdout: JSON.stringify(expected), stderr: "" };
    });

    expect(calls).toEqual([{ bin: "starshine-test", args: ["--emit-runtime-interface-json", "input.wasm"] }]);
    expect(actual).toEqual(expected);
  });

  test("reports typed imports, exports, limits, aliases, and start presence", () => {
    const { wasmPath } = compileWat(RUNTIME_WAT);
    const runtimeInterface = buildRuntimeInterfaceFromWasm(wasmPath);

    expect(runtimeInterface.schema).toBe("starshine.optimizer-runtime-interface.v1");
    expect(runtimeInterface.hasStart).toBe(true);
    expect(runtimeInterface.moduleHash).toMatch(/^sha256:/);
    expect(runtimeInterface.interfaceHash).toMatch(/^sha256:/);
    expect(runtimeInterface.imports.functions).toEqual([
      {
        module: "env",
        field: "tick",
        index: 0,
        signature: { params: ["i32"], results: ["i32"] },
        support: "directly-constructible",
      },
    ]);
    expect(runtimeInterface.imports.globals[0]).toMatchObject({
      module: "env",
      field: "g",
      index: 0,
      valueType: "i32",
      mutable: true,
      support: "directly-constructible",
    });
    expect(runtimeInterface.imports.memories[0]).toMatchObject({
      module: "env",
      field: "mem",
      index: 0,
      minimum: "2",
      maximum: "3",
      shared: false,
      memory64: false,
      support: "directly-constructible",
    });
    expect(runtimeInterface.imports.tables[0]).toMatchObject({
      module: "env",
      field: "tab",
      index: 0,
      minimum: "2",
      maximum: "4",
      elementType: "funcref",
      nullable: true,
      support: "directly-constructible",
    });
    expect(runtimeInterface.exports.find((entry) => entry.name === "run")).toMatchObject({
      kind: "function",
      index: 3,
      signature: { params: ["i32"], results: ["i32"] },
      support: "directly-constructible",
    });
    expect(runtimeInterface.exports.find((entry) => entry.name === "memory")).toMatchObject({
      kind: "memory",
      index: 0,
      support: "directly-constructible",
    });
  });
});

describe("three-way Node semantic oracle v2", () => {
  test("uses the original as primary and identifies only-Starshine divergence", async () => {
    const original = compileWat(`(module (func (export "run") (param i32) (result i32) local.get 0))`);
    const starshine = compileWat(`(module (func (export "run") (param i32) (result i32) local.get 0 i32.const 1 i32.add))`);
    const binaryen = compileWat(`(module (func (export "run") (param i32) (result i32) local.get 0))`);

    const report = await runNodeThreeWaySemanticOracleV2(
      original.wasmPath,
      starshine.wasmPath,
      binaryen.wasmPath,
      {
        seed: 0x5eedn,
        policy: "strict",
        mode: "independent",
        timeoutMs: 1000,
        memoryCapBytes: 1024,
        tableEntryCap: 16,
      },
    );

    expect(report.schema).toBe("starshine.optimizer-three-way-runtime-report.v1");
    expect(report.classification.primary).toBe("starshine-semantic-mismatch");
    expect(report.classification.pattern).toBe("only-starshine-differs");
    expect(report.originalVsStarshine.classification).toBe("semantic-mismatch");
    expect(report.originalVsBinaryen?.classification).toBe("semantic-match");
  });

  test("continues original-versus-Starshine when Binaryen is unavailable", async () => {
    const original = compileWat(`(module (func (export "run") (result i32) i32.const 7))`);
    const starshine = compileWat(`(module (func (export "run") (result i32) i32.const 7))`);

    const report = await runNodeThreeWaySemanticOracleV2(
      original.wasmPath,
      starshine.wasmPath,
      null,
      {
        seed: 7n,
        policy: "strict",
        mode: "stateful",
        timeoutMs: 1000,
        memoryCapBytes: 1024,
        tableEntryCap: 16,
        binaryenDiagnostic: "tool-failure",
      },
    );

    expect(report.originalVsStarshine.classification).toBe("semantic-match");
    expect(report.binaryen).toBeNull();
    expect(report.classification.primary).toBe("semantic-match");
    expect(report.classification.pattern).toBe("binaryen-discrepancy");
    expect(report.classification.binaryenDiagnostic).toBe("tool-failure");
  });
});

describe("Node runtime observation v2", () => {
  test("records start/import events and complete stateful resource snapshots", async () => {
    const { wasmPath } = compileWat(RUNTIME_WAT);
    const runtimeInterface = buildRuntimeInterfaceFromWasm(wasmPath);
    const generated = buildInvocationPlanV2(runtimeInterface, { seed: 0x5eedn, maxPairwise: 0 });
    const plan = { ...generated, steps: generated.steps.slice(0, 3).map((step, index) => ({ ...step, stepIndex: index })) };

    const observation = await executeNodeObservationV2WithTimeout(wasmPath, runtimeInterface, plan, {
      mode: "stateful",
      timeoutMs: 1000,
      memoryCapBytes: 256 * 1024,
      tableEntryCap: 16,
    });

    expect(observation.completeness).toBe("complete");
    expect(observation.blockedReasons).toEqual([]);
    expect(observation.importTrace?.[0]).toMatchObject({
      module: "env",
      field: "tick",
      ordinal: 0,
      phase: "start",
      stepIndex: null,
      arguments: [{ type: "i32", signed: 5, bits: "0x00000005" }],
      results: [{ type: "i32", signed: 5, bits: "0x00000005" }],
    });
    expect(observation.steps[0].phase).toBe("start");
    expect(observation.steps.slice(1).every((step) => step.phase === "exported-call")).toBe(true);
    expect(observation.steps[1].stateBefore.globals.find((entry) => entry.names.includes("counter"))?.value).toMatchObject({
      type: "i32",
      signed: 5,
    });
    expect(observation.resources.memories[0]).toMatchObject({
      index: 0,
      names: ["memory"],
      byteLength: 131072,
      complete: true,
    });
    expect(observation.resources.memories[0].chunkHashes.length).toBe(2);
    expect(observation.resources.tables[0]).toMatchObject({
      index: 0,
      names: ["table"],
      length: 2,
      complete: true,
    });
    expect(observation.resources.tables[0].entries[0].relation).toBe("funcref:0");
    expect(observation.steps[1].firstChangedResource).toEqual({ kind: "global", index: 1 });
  });

  test("executes v128 exports through Wasm-side scalar adapters", async () => {
    const { wasmPath } = compileWat(`(module
      (func (export "echo") (param v128) (result v128)
        local.get 0))`);
    const runtimeInterface = buildRuntimeInterfaceFromWasm(wasmPath);
    const generated = buildInvocationPlanV2(runtimeInterface, { seed: 11n, maxPairwise: 0 });
    const plan = { ...generated, steps: generated.steps.slice(0, 2) };
    const observation = await executeNodeObservationV2WithTimeout(wasmPath, runtimeInterface, plan, {
      mode: "stateful",
      timeoutMs: 1000,
      memoryCapBytes: 1024,
      tableEntryCap: 16,
    });
    expect(observation.completeness).toBe("complete");
    const calls = observation.steps.filter((step) => step.exportName === "echo");
    expect(calls).toHaveLength(2);
    expect(calls[0].outcome).toEqual({
      kind: "returned",
      values: [calls[0].arguments[0]],
    });
  });

  test("adapts imported v128 functions and records exact import events", async () => {
    const { wasmPath } = compileWat(`(module
      (import "env" "echo" (func $echo (param v128) (result v128)))
      (func (export "run") (result i64)
        v128.const i64x2 7 9
        call $echo
        i64x2.extract_lane 1))`);
    const runtimeInterface = buildRuntimeInterfaceFromWasm(wasmPath);
    expect(runtimeInterface.imports.functions[0].support).toBe("scalar-adapter");
    const plan = buildInvocationPlanV2(runtimeInterface, { seed: 12n });
    const observation = await executeNodeObservationV2WithTimeout(wasmPath, runtimeInterface, plan, {
      mode: "stateful",
      timeoutMs: 1000,
      memoryCapBytes: 1024,
      tableEntryCap: 16,
    });
    expect(observation.completeness).toBe("complete");
    expect(observation.importTrace?.[0]).toMatchObject({
      module: "env",
      field: "echo",
      arguments: [{ type: "v128", bits: "0x00000000000000070000000000000009" }],
      results: [{ type: "v128", bits: "0x00000000000000070000000000000009" }],
    });
    expect(observation.steps.find((step) => step.exportName === "run")?.outcome).toMatchObject({
      kind: "returned",
      values: [{ type: "i64", signed: "9" }],
    });
  });

  test("constructs imported tags and observes thrown user exceptions", async () => {
    const { wasmPath } = compileWat(`(module
      (import "env" "event" (tag $event (param i32)))
      (func (export "run")
        i32.const 7
        throw $event))`);
    const runtimeInterface = buildRuntimeInterfaceFromWasm(wasmPath);
    expect(runtimeInterface.imports.tags?.[0]).toMatchObject({
      module: "env",
      field: "event",
      signature: { params: ["i32"], results: [] },
    });
    const plan = buildInvocationPlanV2(runtimeInterface, { seed: 7n });
    const observation = await executeNodeObservationV2WithTimeout(wasmPath, runtimeInterface, plan, {
      mode: "stateful",
      timeoutMs: 1000,
      memoryCapBytes: 1024,
      tableEntryCap: 16,
    });
    expect(observation.blockedReasons.some((reason) => reason.startsWith("instantiation-failure"))).toBe(false);
    expect(observation.steps.find((step) => step.exportName === "run")?.outcome).toMatchObject({
      kind: "trapped",
      trapClass: "user-exception",
    });
  });

  test("proves cross-table aliases from immutable active element segments", async () => {
    const { wasmPath } = compileWat(`(module
      (table $left (export "left") 1 funcref)
      (table $right (export "right") 2 funcref)
      (func $a)
      (func $b)
      (elem (table $left) (i32.const 0) func $a)
      (elem (table $right) (i32.const 0) func $b $a))`);
    const runtimeInterface = buildRuntimeInterfaceFromWasm(wasmPath);
    const plan = buildInvocationPlanV2(runtimeInterface, { seed: 9n });
    const observation = await executeNodeObservationV2WithTimeout(wasmPath, runtimeInterface, plan, {
      mode: "stateful",
      timeoutMs: 1000,
      memoryCapBytes: 1024,
      tableEntryCap: 16,
    });

    expect(observation.completeness).toBe("complete");
    expect(observation.blockedReasons).not.toContain("cross-table-reference-identity-unavailable: tables=2");
    expect(observation.resources.tables[0].entries[0].relation).toBe("funcidx:0");
    expect(observation.resources.tables[1].entries.map((entry) => entry.relation)).toEqual(["funcidx:1", "funcidx:0"]);
  });

  test("blocks incomplete memory observation instead of silently sampling", async () => {
    const { wasmPath } = compileWat(RUNTIME_WAT);
    const runtimeInterface = buildRuntimeInterfaceFromWasm(wasmPath);
    const generated = buildInvocationPlanV2(runtimeInterface, { seed: 1n, maxPairwise: 0 });
    const plan = { ...generated, steps: generated.steps.slice(0, 1) };

    const observation = await executeNodeObservationV2WithTimeout(wasmPath, runtimeInterface, plan, {
      mode: "stateful",
      timeoutMs: 1000,
      memoryCapBytes: 64 * 1024,
      tableEntryCap: 16,
    });

    expect(observation.completeness).toBe("incomplete");
    expect(observation.blockedReasons).toContain("memory-over-cap: memory[0] bytes=131072 cap=65536");
    expect(observation.resources.memories[0].complete).toBe(false);
  });

  test("freshly instantiates each independent call while stateful calls accumulate", async () => {
    const { wasmPath } = compileWat(`(module
      (global $g (export "g") (mut i32) (i32.const 0))
      (func (export "inc") (result i32)
        global.get $g
        i32.const 1
        i32.add
        global.set $g
        global.get $g))`);
    const runtimeInterface = buildRuntimeInterfaceFromWasm(wasmPath);
    const generated = buildInvocationPlanV2(runtimeInterface, { seed: 2n });
    const first = generated.steps[0];
    const plan = { ...generated, steps: [first, first].map((step, index) => ({ ...step, stepIndex: index })) };

    const stateful = await executeNodeObservationV2WithTimeout(wasmPath, runtimeInterface, plan, {
      mode: "stateful",
      timeoutMs: 1000,
      memoryCapBytes: 1024,
      tableEntryCap: 16,
    });
    const independent = await executeNodeObservationV2WithTimeout(wasmPath, runtimeInterface, plan, {
      mode: "independent",
      timeoutMs: 1000,
      memoryCapBytes: 1024,
      tableEntryCap: 16,
    });

    expect(stateful.steps.slice(1).map((step) => step.outcome)).toEqual([
      { kind: "returned", values: [{ type: "i32", signed: 1, bits: "0x00000001" }] },
      { kind: "returned", values: [{ type: "i32", signed: 2, bits: "0x00000002" }] },
    ]);
    expect(independent.steps.slice(1).map((step) => step.outcome)).toEqual([
      { kind: "returned", values: [{ type: "i32", signed: 1, bits: "0x00000001" }] },
      { kind: "returned", values: [{ type: "i32", signed: 1, bits: "0x00000001" }] },
    ]);
  });
});
