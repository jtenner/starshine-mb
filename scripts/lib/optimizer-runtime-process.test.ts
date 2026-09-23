import { describe, expect, test } from "bun:test";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import type { ChildProcessWithoutNullStreams } from "node:child_process";
import {
  buildInvocationPlanV2,
  classifyStarshineRuntimeDiagnostic,
  classifyThreeWaySemanticComparison,
  compareRuntimeObservationsV2,
  type RuntimeInterfaceV1,
} from "./optimizer-runtime";
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

    const original = {
      ...result,
      compilation: { status: "succeeded" as const },
      instantiation: { status: "succeeded" as const },
      completeness: "complete" as const,
      blockedReasons: [],
    };
    const comparison = compareRuntimeObservationsV2(original, result, "strict");
    expect(comparison.classification).toBe("blocked");
    expect(comparison.diagnostics).toEqual(["timeout:10ms"]);
    const starshineDiagnostic = classifyStarshineRuntimeDiagnostic(result);
    const classificationInput = {
      originalVsStarshine: "blocked" as const,
      originalVsBinaryen: "unknown" as const,
      starshineVsBinaryen: "unknown" as const,
      starshineDiagnostic,
    };
    const classification = classifyThreeWaySemanticComparison(classificationInput);
    expect(classification.primary).toBe("blocked-starshine-runtime");
    expect(classification.pattern).toBe("starshine-tool-resource-uncertainty");
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

test("stack-switching configuration reaches Node and changes observation identity", async () => {
  const previous = process.env.STARSHINE_NODE_WASMFX;
  try {
    const observe = async (enabled: string) => {
      process.env.STARSHINE_NODE_WASMFX = enabled;
      const { child } = controlledChild();
      let args: string[] = [];
      const pending = executeNodeObservationV2WithTimeout("unused.wasm", runtimeInterface, plan, { ...options, timeoutMs: 1000 }, (_command, received) => {
        args = received;
        return child as unknown as ChildProcessWithoutNullStreams;
      });
      child.stdout.write(JSON.stringify({ ok: true, observation: {
        schema: "starshine.optimizer-runtime-observation.v2",
        runtime: { identity: "worker-base-identity", timeoutMs: 1000 },
        mode: "independent", compilation: { status: "succeeded" }, instantiation: { status: "succeeded" },
        completeness: "complete", blockedReasons: [], steps: [], importTrace: [],
        resources: { globals: [], memories: [], tables: [] },
      } }));
      child.emit("close", 0, null);
      return { args, observation: await pending };
    };
    const disabled = await observe("0");
    const enabled = await observe("1");
    const restored = await observe("0");
    expect(enabled.args[0]).toBe("--experimental-wasm-wasmfx");
    expect(disabled.args).toHaveLength(1);
    expect(enabled.observation.runtime.identity).not.toBe(disabled.observation.runtime.identity);
    expect(enabled.observation.runtime.identity).toContain(":config:");
    expect(restored.observation.runtime.identity).toBe(disabled.observation.runtime.identity);
    expect(disabled.observation.runtime.identity).toMatch(/^node:v/);
  } finally {
    if (previous === undefined) delete process.env.STARSHINE_NODE_WASMFX;
    else process.env.STARSHINE_NODE_WASMFX = previous;
  }
});
