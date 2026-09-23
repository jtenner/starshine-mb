import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { describe, expect, test } from "bun:test";

import {
  compareAtomicLitmusObservationSetsV1,
  runNodeAtomicLitmusComparisonV1,
  validateAtomicLitmusSpecV1,
  type AtomicLitmusSpecV1,
} from "./optimizer-atomic-runtime";

function compileWat(wat: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-atomic-litmus-"));
  const watPath = path.join(dir, "module.wat");
  const wasmPath = path.join(dir, "module.wasm");
  fs.writeFileSync(watPath, wat);
  const result = spawnSync("wasm-tools", ["parse", watPath, "-o", wasmPath], { encoding: "utf8" });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || "wasm-tools parse failed");
  return wasmPath;
}

const RMW_ADD_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "i32-rmw-add-two-workers",
  workerCount: 2,
  exportName: "rmw",
  workerArguments: [[0], [1]],
  memoryImport: { module: "env", field: "memory", initial: 1, maximum: 1 },
  observedI32Offsets: [0],
  trials: 2,
  allowedOutcomes: [
    { threadResults: [0, 1], memoryI32: [2] },
    { threadResults: [1, 0], memoryI32: [2] },
  ],
};

describe("atomic allowed-outcome comparison", () => {
  test("rejects unbounded trial and shared-memory specifications", () => {
    expect(() => validateAtomicLitmusSpecV1({ ...RMW_ADD_SPEC, trials: 9 })).toThrow("between 1 and 8");
    expect(() => validateAtomicLitmusSpecV1({
      ...RMW_ADD_SPEC,
      memoryImport: { ...RMW_ADD_SPEC.memoryImport, maximum: 17 },
    })).toThrow("at most 16 pages");
  });

  test("accepts different allowed schedules without requiring exact replay", () => {
    const comparison = compareAtomicLitmusObservationSetsV1(
      RMW_ADD_SPEC,
      [{ trial: 0, threadResults: [0, 1], memoryI32: [2] }],
      [{ trial: 0, threadResults: [1, 0], memoryI32: [2] }],
    );

    expect(comparison.classification).toBe("allowed-outcome-match");
    expect(comparison.failingSide).toBeNull();
    expect(comparison.firstDisallowedOutcome).toBeNull();
  });

  test("rejects a transformed module that leaves the declared outcome set", async () => {
    const original = compileWat(`(module
      (import "env" "memory" (memory 1 1 shared))
      (func (export "rmw") (param i32) (result i32)
        i32.const 0
        i32.const 1
        i32.atomic.rmw.add))`);
    const wrong = compileWat(`(module
      (import "env" "memory" (memory 1 1 shared))
      (func (export "rmw") (param i32) (result i32)
        i32.const 0
        i32.const 2
        i32.atomic.rmw.add))`);

    const report = await runNodeAtomicLitmusComparisonV1(original, wrong, RMW_ADD_SPEC, {
      timeoutMs: 3000,
    });

    expect(report.schema).toBe("starshine.optimizer-atomic-litmus-comparison.v1");
    expect(report.original.status).toBe("complete");
    expect(report.original.observations).toHaveLength(2);
    expect(report.candidate.status).toBe("complete");
    expect(report.comparison.classification).toBe("semantic-mismatch");
    expect(report.comparison.failingSide).toBe("candidate");
    expect(report.comparison.firstDisallowedOutcome).toMatchObject({
      memoryI32: [4],
    });
  });
});
