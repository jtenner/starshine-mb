import { describe, expect, test } from "bun:test";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import type { ChildProcessWithoutNullStreams } from "node:child_process";
import { buildInvocationPlanV2, type RuntimeInterfaceV1 } from "./optimizer-runtime";
import { executeNodeObservationV2WithTimeout } from "./optimizer-runtime-executor";

const runtimeInterface: RuntimeInterfaceV1 = {
  schema: "starshine.optimizer-runtime-interface.v1",
  moduleHash: "test", interfaceHash: "test", features: [], hasStart: false,
  imports: { functions: [], globals: [], memories: [], tables: [], tags: [] },
  exports: [],
};
const plan = buildInvocationPlanV2(runtimeInterface, { seed: 1n, maxPairwise: 0 });
const options = { mode: "independent" as const, timeoutMs: 10, memoryCapBytes: 1024, tableEntryCap: 16 };

function controlledChild() {
  const child = Object.assign(new EventEmitter(), {
    stdin: new PassThrough(), stdout: new PassThrough(), stderr: new PassThrough(),
    signals: [] as string[],
    kill(signal: string) { this.signals.push(signal); return true; },
  });
  return { child, spawn: () => child as unknown as ChildProcessWithoutNullStreams };
}

describe("observation worker failure attribution", () => {
  test("deadline waits for child close and preserves unknown execution phase", async () => {
    const { child, spawn } = controlledChild();
    let completed = false;
    const pending = executeNodeObservationV2WithTimeout("unused.wasm", runtimeInterface, plan, options, spawn)
      .then((result) => { completed = true; return result; });
    await new Promise((resolve) => setTimeout(resolve, 30));
    expect(child.signals).toEqual(["SIGKILL"]);
    expect(completed).toBe(false);
    child.emit("close", null, "SIGKILL");
    const result = await pending;
    expect(result.compilation).toEqual({ status: "unknown" });
    expect(result.instantiation).toEqual({ status: "unknown" });
    expect(result.steps).toEqual([]);
    expect(result.completeness).toBe("incomplete");
    expect(result.blockedReasons).toEqual(["timeout:10ms"]);
  });

  test("worker exit without observation does not invent an instantiation failure", async () => {
    const { child, spawn } = controlledChild();
    const pending = executeNodeObservationV2WithTimeout("unused.wasm", runtimeInterface, plan, { ...options, timeoutMs: 1000 }, spawn);
    child.stderr.write("controlled worker failure");
    child.emit("close", 1, null);
    const result = await pending;
    expect(result.instantiation).toEqual({ status: "unknown" });
    expect(result.steps).toEqual([]);
    expect(result.blockedReasons).toEqual(["worker-failure:Node exited 1: controlled worker failure"]);
    expect(child.signals).toEqual([]);
  });
});
