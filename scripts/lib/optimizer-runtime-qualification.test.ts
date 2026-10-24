import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { afterAll, expect, test } from "bun:test";
import { buildInvocationPlanV2, compareRuntimeObservationsV2, type RuntimeMemoryObservationV2 } from "./optimizer-runtime";
import { buildRuntimeInterfaceFromWasm, executeNodeObservationV2WithTimeout, runNodeThreeWaySemanticOracleV2, type NodeObservationV2Options } from "./optimizer-runtime-executor";

const directory = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-oracle-qualification-"));
afterAll(() => fs.rmSync(directory, { recursive: true, force: true }));
let sequence = 0;
function compile(wat: string): string {
  const file = path.join(directory, `fixture-${sequence++}.wasm`);
  const source = file.replace(/wasm$/, "wat");
  fs.writeFileSync(source, wat);
  for (const args of [["parse", source, "-o", file], ["validate", "--features", "all", file]]) {
    const result = spawnSync("wasm-tools", args, { encoding: "utf8" });
    if (result.status !== 0) throw new Error(result.stderr || String(result.error));
  }
  return file;
}
function hash(file: string): string {
  return `sha256:${crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex")}`;
}
const options = { mode: "stateful" as const, timeoutMs: 3000, memoryCapBytes: 65536, tableEntryCap: 16, eventCap: 64, diagnosticMode: "disabled" as const };
async function observe(file: string, overrides: Partial<NodeObservationV2Options> = {}) {
  const iface = buildRuntimeInterfaceFromWasm(file);
  const plan = buildInvocationPlanV2(iface, { seed: 0x5eedn, maxPairwise: 0 });
  return executeNodeObservationV2WithTimeout(file, iface, plan, { ...options, ...overrides });
}
function eventFixture(values: number[], ending = "i32.const 7"): string {
  return compile(`(module (import "observe" "event" (func $event (param i32)))
    (func (export "run") (result i32) ${values.map(value => `i32.const ${value} call $event`).join(" ")} ${ending}))`);
}

test("records the hash of the exact loaded module and verifies its expected artifact", async () => {
  const file = compile(`(module (func (export "run") (result i32) i32.const 7))`);
  const result = await observe(file, { expectedArtifactHash: hash(file) });
  expect(result.completeness).toBe("complete");
  expect(result.artifact).toEqual({ expectedHash: hash(file), loadedHash: hash(file), verified: true });
  expect(result.traceLimit).toEqual({ cap: 64, observedEventCount: 0, exhausted: false });
  expect(result.diagnosticMode).toBe("disabled");
});

test("rejects the input replayed as a different expected output even with equal return values", async () => {
  const input = compile(`(module (func (export "run") (result i32) i32.const 7))`);
  const output = compile(`(module (func (export "run") (result i32) i32.const 0 i32.const 7 i32.add))`);
  expect(hash(input)).not.toBe(hash(output));
  const correct = await observe(output, { expectedArtifactHash: hash(output) });
  const wrong = await observe(input, { expectedArtifactHash: hash(output) });
  expect(correct.completeness).toBe("complete");
  expect(wrong.compilation.status).toBe("not-attempted");
  expect(wrong.blockedReasons).toContain("artifact-identity-mismatch");
  expect(wrong.artifact).toEqual({ expectedHash: hash(output), loadedHash: hash(input), verified: false });
  expect(compareRuntimeObservationsV2(correct, wrong, "strict").classification).toBe("blocked");
});

test("reaching the scalar event cap blocks equal truncated traces and bounds recording", async () => {
  const file = eventFixture([1, 2, 3, 4]);
  const result = await observe(file, { eventCap: 2 });
  expect(result.completeness).toBe("incomplete");
  expect(result.importTrace?.length).toBe(2);
  expect(result.traceLimit).toEqual({ cap: 2, observedEventCount: 2, exhausted: true });
  expect(result.blockedReasons).toContain("event-trace-cap:2");
  expect(result.steps.at(-1)?.outcome.kind).toBe("unsupported");
  expect(compareRuntimeObservationsV2(result, structuredClone(result), "strict").classification).toBe("blocked");
});

test("below-cap scalar traces complete, including an exact-boundary exhaustion control", async () => {
  const file = eventFixture([1, 2]);
  const complete = await observe(file, { eventCap: 3 });
  expect(complete.completeness).toBe("complete");
  expect(complete.traceLimit).toEqual({ cap: 3, observedEventCount: 2, exhausted: false });
  expect((await observe(file, { eventCap: 2 })).completeness).toBe("incomplete");
});

test("the v128 import adapter obeys the same event cap during a start function", async () => {
  const file = compile(`(module (import "observe" "vector" (func $vector (param v128)))
    (func $start v128.const i32x4 1 2 3 4 call $vector v128.const i32x4 5 6 7 8 call $vector)
    (start $start) (func (export "run") (result i32) i32.const 7))`);
  const result = await observe(file, { eventCap: 1 });
  expect(result.completeness).toBe("incomplete");
  expect(result.importTrace?.length).toBe(1);
  expect(result.blockedReasons).toContain("event-trace-cap:1");
  expect(result.steps[0].outcome).toEqual({ kind: "unsupported", reason: "event-trace-cap:1" });
});

test("executed reordered, duplicated and changed pre-trap effects fail their ordered comparison", async () => {
  const reference = await observe(eventFixture([1, 2]));
  expect(compareRuntimeObservationsV2(reference, await observe(eventFixture([1, 2])), "strict").classification).toBe("semantic-match");
  for (const values of [[2, 1], [1, 1, 2]]) {
    const comparison = compareRuntimeObservationsV2(reference, await observe(eventFixture(values)), "strict");
    expect(comparison.classification).toBe("semantic-mismatch");
    expect(comparison.firstDifferenceCategory).toBe("import-event");
  }
  const beforeTrap = await observe(eventFixture([1, 2], "unreachable"));
  const changedTrap = await observe(eventFixture([1, 9], "unreachable"));
  const comparison = compareRuntimeObservationsV2(beforeTrap, changedTrap, "trap-aware");
  expect(comparison.classification).toBe("semantic-mismatch");
  expect(comparison.firstDifferenceCategory).toBe("import-event");
  expect(comparison.originalOutcomeKind).toBe("trapped");
});

test("candidate-only trace exhaustion remains resource uncertainty rather than a compiler defect", async () => {
  const original = eventFixture([1]);
  const candidate = eventFixture([1, 2, 3]);
  const result = await runNodeThreeWaySemanticOracleV2(original, candidate, null, { ...options, eventCap: 2, seed: 0x5eedn, policy: "strict", maxPairwise: 0 });
  expect(result.original.completeness).toBe("complete");
  expect(result.starshine.completeness).toBe("incomplete");
  expect(result.classification.primary).toBe("blocked-starshine-runtime");
  expect(result.classification.pattern).toBe("starshine-tool-resource-uncertainty");
});

test("catch_all cannot turn a reached trace cap into a match or a compiler defect", async () => {
  for (const start of [false, true]) {
    const body = `try i32.const 1 call $event catch_all end try i32.const 2 call $event catch_all end`;
    const file = compile(`(module (import "observe" "event" (func $event (param i32)))
      ${start ? `(func $start ${body}) (start $start)` : ""}
      (func (export "run") (result i32) ${start ? "" : body} i32.const 7))`);
    const result = await observe(file, { eventCap: 1 });
    expect(result.traceLimit?.exhausted).toBe(true);
    expect(result.importTrace?.length).toBe(1);
    expect(result.completeness).toBe("incomplete");
    expect(result.blockedReasons).toContain("event-trace-cap:1");
    expect(result.steps.at(-1)?.outcome).toEqual({ kind: "unsupported", reason: "event-trace-cap:1" });
    expect(compareRuntimeObservationsV2(result, structuredClone(result), "strict").classification).toBe("blocked");
  }
});

test("interface printing uses the bytes read before an artifact is replaced", () => {
  const original = compile(`(module (func (export "run") (result i32) i32.const 7))`);
  const changed = compile(`(module (func (export "different") (result i32) i32.const 7))`);
  const expected = hash(original);
  const tool = path.join(directory, "replace-before-print.js");
  fs.writeFileSync(tool, `#!/usr/bin/env node\nconst fs=require('node:fs');const cp=require('node:child_process');fs.copyFileSync(${JSON.stringify(changed)},${JSON.stringify(original)});const r=cp.spawnSync('wasm-tools',process.argv.slice(2),{input:fs.readFileSync(0)});process.stdout.write(r.stdout);process.stderr.write(r.stderr);process.exit(r.status);\n`);
  fs.chmodSync(tool, 0o755);
  const iface = buildRuntimeInterfaceFromWasm(original, tool);
  expect(iface.moduleHash).toBe(expected);
  expect(iface.exports.map(e => e.name)).toEqual(["run"]);
});

test("explicit identity sets cannot omit a present Binaryen artifact", async () => {
  const file = eventFixture([1]);
  await expect(runNodeThreeWaySemanticOracleV2(file, file, file, {
    ...options, seed: 1n, policy: "strict", expectedArtifactHashes: { original: hash(file), starshine: hash(file) },
  })).rejects.toThrow("missing expected Binaryen artifact hash");
});

test("independent-start exhaustion preserves the completed initial start and marks the new start unsupported", async () => {
  const file = compile(`(module (import "observe" "event" (func $event (param i32)))
    (func $start i32.const 1 call $event) (start $start)
    (func (export "run") (result i32) i32.const 7))`);
  const result = await observe(file, { mode: "independent", eventCap: 2 });
  expect(result.completeness).toBe("incomplete");
  expect(result.steps[0].outcome.kind).toBe("returned");
  expect(result.steps[1].outcome).toEqual({ kind: "unsupported", reason: "event-trace-cap:2" });
  expect(result.steps[1].phase).toBe("start");
});

test("observation diagnostics are disabled without changing permitted behavior", async () => {
  const file = compile(`(module (memory (export "memory") 1)
    (func (export "run") (result i32) i32.const 0 i32.const 7 i32.store i32.const 7))`);
  const disabled = await observe(file);
  const enabled = await observe(file, { diagnosticMode: "enabled" });
  expect(disabled.resources.memories[0].diagnosticSamples).toEqual([]);
  expect(enabled.resources.memories[0].diagnosticSamples.length).toBeGreaterThan(0);
  expect(disabled.resources.memories[0].hash).toBe(enabled.resources.memories[0].hash);
  expect(compareRuntimeObservationsV2(disabled, enabled, "strict").classification).toBe("semantic-match");
});

test("an explicit original identity cannot disagree with the metadata snapshot", async () => {
  const actual = eventFixture([1]);
  const expected = eventFixture([2]);
  await expect(runNodeThreeWaySemanticOracleV2(actual, actual, null, {
    ...options, seed: 1n, policy: "strict", expectedArtifactHashes: { original: hash(expected), starshine: hash(actual) },
  })).rejects.toThrow("original artifact identity mismatch");
});

test("independent-start cap handling remains attributed to that start if guest code catches then traps", async () => {
  const file = compile(`(module (import "observe" "event" (func $event (param i32)))
    (func $start try i32.const 1 call $event catch_all unreachable end) (start $start)
    (func (export "run") (result i32) i32.const 7))`);
  const result = await observe(file, { mode: "independent", eventCap: 2 });
  expect(result.steps[0].outcome.kind).toBe("returned");
  expect(result.steps[1].phase).toBe("start");
  expect(result.steps[1].outcome).toEqual({ kind: "unsupported", reason: "event-trace-cap:2" });
  expect(compareRuntimeObservationsV2(result, structuredClone(result), "strict").classification).toBe("blocked");
});

test("diagnostic-only changes cannot hide the index of an independently changed second memory", () => {
  const memory = (index: number, hash: string): RuntimeMemoryObservationV2 => ({index, names: [`m${index}`], byteLength: 65536, complete: true, hash, chunkHashes: [hash], diagnosticSamples: []});
  const before = {schema: "starshine.optimizer-runtime-observation.v2" as const, runtime: {identity:"control",timeoutMs:1}, mode:"stateful" as const,
    compilation:{status:"succeeded" as const},instantiation:{status:"succeeded" as const},completeness:"complete" as const,blockedReasons:[],steps:[],
    resources:{globals:[],tables:[],memories:[memory(0,"same"),memory(1,"old")]}};
  const after = structuredClone(before);
  after.resources.memories[0].diagnosticSamples = [{offset:0,bytes:"00"}];
  after.resources.memories[1].hash = "new";
  after.resources.memories[1].chunkHashes = ["new"];
  const result = compareRuntimeObservationsV2(before, after, "strict");
  expect(result.classification).toBe("semantic-mismatch");
  expect(result.resourceIndex).toBe(1);
});

test("unobservable private tables require no metadata-print subprocess and preserve indirect call results", async () => {
  const file = compile(`(module (type $t (func (result i32))) (table 1 funcref)
    (func $target (result i32) i32.const 7) (elem (i32.const 0) $target)
    (func (export "run") (result i32) i32.const 0 call_indirect (type $t)))`);
  const result = await observe(file, { wasmToolsBin: path.join(directory, "intentionally-unavailable-tool") });
  expect(result.completeness).toBe("complete");
  expect(result.resources.tables).toEqual([]);
  expect(result.steps.at(-1)?.outcome).toEqual({ kind: "returned", values: [{type:"i32",signed:7,bits:"0x00000007"}] });
});
