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

function writeWasmHex(hex: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-atomic-litmus-"));
  const wasmPath = path.join(dir, "module.wasm");
  fs.writeFileSync(wasmPath, Buffer.from(hex, "hex"));
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

const WAIT_NOTIFY_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "wait-notify-two-workers",
  workerCount: 2,
  exportName: "run",
  workerArguments: [[0], [1]],
  memoryImport: { module: "env", field: "memory", initial: 1, maximum: 1 },
  observedI32Offsets: [0],
  trials: 2,
  allowedOutcomes: [
    { threadResults: [0, 1], memoryI32: [1] },
    { threadResults: [1, 0], memoryI32: [1] },
  ],
};

const WAIT_NOTIFY_LIVENESS_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "wait-notify-required-wake",
  workerCount: 2,
  exportName: "run",
  workerArguments: [[0], [1]],
  memoryImport: { module: "env", field: "memory", initial: 1, maximum: 1 },
  observedI32Offsets: [0, 4],
  trials: 2,
  allowedOutcomes: [
    { threadResults: [0, 1], memoryI32: [0, 1] },
    { threadResults: [2, -1], memoryI32: [0, 1] },
  ],
  requiredObservedOutcomes: [
    { threadResults: [0, 1], memoryI32: [0, 1] },
  ],
};

const CMPXCHG_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "i32-cmpxchg-two-workers",
  workerCount: 2,
  exportName: "run",
  workerArguments: [[1], [2]],
  memoryImport: { module: "env", field: "memory", initial: 1, maximum: 1 },
  observedI32Offsets: [0],
  trials: 2,
  allowedOutcomes: [
    { threadResults: [0, 1], memoryI32: [1] },
    { threadResults: [2, 0], memoryI32: [2] },
  ],
};

const MULTI_MEMORY_RMW_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "i32-rmw-add-selected-second-memory",
  workerCount: 2,
  exportName: "run",
  workerArguments: [[0], [1]],
  memoryImport: { module: "env", field: "memory0", initial: 1, maximum: 1 },
  additionalMemoryImports: [
    { module: "env", field: "memory1", initial: 1, maximum: 1 },
  ],
  observedI32Offsets: [0],
  trials: 2,
  allowedOutcomes: [
    { threadResults: [0, 1], memoryI32: [0] },
    { threadResults: [1, 0], memoryI32: [0] },
  ],
};

const MEMORY64_RMW_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "i32-rmw-add-shared-memory64",
  workerCount: 2,
  exportName: "run",
  workerArguments: [[], []],
  memoryImport: {
    module: "env",
    field: "memory",
    initial: 1,
    maximum: 1,
    address: "i64",
  },
  observedI32Offsets: [0],
  trials: 2,
  allowedOutcomes: [
    { threadResults: [0, 1], memoryI32: [2] },
    { threadResults: [1, 0], memoryI32: [2] },
  ],
};

// Threads execution defines atomic.rmw.add as one indivisible read-modify-write
// that returns the old value. Two seq_cst additions of one from zero therefore
// permit only the two worker orders below, with memory32 untouched and the
// selected memory64 ending at two.
const MIXED_WIDTH_MEMORY_RMW_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "i32-rmw-add-selected-memory64-beside-memory32",
  workerCount: 2,
  exportName: "run",
  workerArguments: [[], []],
  memoryImport: {
    module: "env",
    field: "memory32",
    initial: 1,
    maximum: 1,
  },
  additionalMemoryImports: [{
    module: "env",
    field: "memory64",
    initial: 1,
    maximum: 1,
    address: "i64",
  }],
  observedI32Offsets: [0],
  additionalObservedI32Locations: [{ memoryImportIndex: 1, offset: 0 }],
  trials: 2,
  allowedOutcomes: [
    { threadResults: [0, 1], memoryI32: [0, 2] },
    { threadResults: [1, 0], memoryI32: [0, 2] },
  ],
};

const MEMORY64_BOUNDS_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "i32-rmw-add-shared-memory64-bounds",
  workerCount: 2,
  exportName: "run",
  workerArguments: [[], []],
  memoryImport: {
    module: "env",
    field: "memory",
    initial: 1,
    maximum: 1,
    address: "i64",
  },
  observedI32Offsets: [65532],
  trials: 2,
  allowedOutcomes: [
    { threadResults: [0, 1], memoryI32: [2] },
    { threadResults: [1, 0], memoryI32: [2] },
  ],
};

const MULTI_MEMORY_CMPXCHG_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "i32-cmpxchg-selected-second-memory",
  workerCount: 2,
  exportName: "run",
  workerArguments: [[1], [2]],
  memoryImport: { module: "env", field: "memory0", initial: 1, maximum: 1 },
  additionalMemoryImports: [
    { module: "env", field: "memory1", initial: 1, maximum: 1 },
  ],
  observedI32Offsets: [0],
  additionalObservedI32Locations: [
    { memoryImportIndex: 1, offset: 0 },
  ],
  trials: 2,
  allowedOutcomes: [
    { threadResults: [0, 1], memoryI32: [0, 1] },
    { threadResults: [2, 0], memoryI32: [0, 2] },
  ],
};

const ORDERED_STORE_BOUNDARY_SPEC: AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1",
  id: "ordered-store-runtime-boundary",
  workerCount: 2,
  exportName: "run",
  workerArguments: [[], []],
  memoryImport: { module: "env", field: "memory", initial: 1, maximum: 1 },
  observedI32Offsets: [0],
  trials: 1,
  allowedOutcomes: [
    { threadResults: [0, 0], memoryI32: [1] },
  ],
};

const ORDERED_FENCE_BOUNDARY_SPEC: AtomicLitmusSpecV1 = {
  ...ORDERED_STORE_BOUNDARY_SPEC,
  id: "ordered-fence-runtime-boundary",
  allowedOutcomes: [
    { threadResults: [0, 0], memoryI32: [0] },
  ],
};

// Exact binaries emitted by Starshine from minimal valid modules containing
// `(i32.atomic.store <order> (i32.const 0) (i32.const 1))` or
// `(atomic.fence <order>)`, followed by `i32.const 0`. These fixtures
// intentionally bypass `wasm-tools`, whose current WAT parser rejects the
// active-proposal order spellings before a runtime can see them.
const ACQREL_STORE_WASM =
  "0061736d010000000105016000017f02100103656e76066d656d6f727902030101" +
  "030201000707010372756e00000a0f010d0041004101fe1712010041000b";
const RELAXED_STORE_WASM =
  "0061736d010000000105016000017f02100103656e76066d656d6f727902030101" +
  "030201000707010372756e00000a0f010d0041004101fe1712020041000b";
const ACQREL_FENCE_WASM =
  "0061736d010000000105016000017f02100103656e76066d656d6f727902030101" +
  "030201000707010372756e00000a09010700fe030141000b";
const RELAXED_FENCE_WASM =
  "0061736d010000000105016000017f02100103656e76066d656d6f727902030101" +
  "030201000707010372756e00000a09010700fe030241000b";

describe("atomic allowed-outcome comparison", () => {
  test("rejects unbounded trial and shared-memory specifications", () => {
    expect(() => validateAtomicLitmusSpecV1({ ...RMW_ADD_SPEC, trials: 9 })).toThrow("between 1 and 8");
    expect(() => validateAtomicLitmusSpecV1({
      ...RMW_ADD_SPEC,
      memoryImport: { ...RMW_ADD_SPEC.memoryImport, maximum: 17 },
    })).toThrow("at most 16 pages");
    expect(() => validateAtomicLitmusSpecV1({
      ...RMW_ADD_SPEC,
      additionalMemoryImports: Array.from({ length: 4 }, (_, index) => ({
        module: "env",
        field: `memory${index + 1}`,
        initial: 1,
        maximum: 1,
      })),
    })).toThrow("at most four");
    expect(() => validateAtomicLitmusSpecV1({
      ...RMW_ADD_SPEC,
      additionalMemoryImports: [{ ...RMW_ADD_SPEC.memoryImport }],
    })).toThrow("must be unique");
    expect(() => validateAtomicLitmusSpecV1({
      ...RMW_ADD_SPEC,
      requiredObservedOutcomes: [
        { threadResults: [0, 0], memoryI32: [2] },
      ],
    })).toThrow("must be allowed outcomes");
    expect(() => validateAtomicLitmusSpecV1({
      ...RMW_ADD_SPEC,
      memoryImport: { ...RMW_ADD_SPEC.memoryImport, address: "i128" as "i64" },
    })).toThrow("address must be i32 or i64");
    expect(() => validateAtomicLitmusSpecV1({
      ...MULTI_MEMORY_RMW_SPEC,
      additionalObservedI32Locations: [
        { memoryImportIndex: 2, offset: 0 },
      ],
    })).toThrow("must select an additional memory import");
    expect(() => validateAtomicLitmusSpecV1({
      ...MULTI_MEMORY_RMW_SPEC,
      additionalObservedI32Locations: [
        { memoryImportIndex: 1, offset: 2 },
      ],
    })).toThrow("must be aligned");
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

  test("blocks when the original misses a declared required observation", () => {
    const required = RMW_ADD_SPEC.allowedOutcomes[0];
    const comparison = compareAtomicLitmusObservationSetsV1(
      { ...RMW_ADD_SPEC, requiredObservedOutcomes: [required] },
      [{ trial: 0, ...RMW_ADD_SPEC.allowedOutcomes[1] }],
      [{ trial: 0, ...required }],
    );

    expect(comparison.classification).toBe("blocked");
    expect(comparison.failingSide).toBe("original");
    expect(comparison.firstMissingRequiredOutcome).toEqual(required);
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

  test("observes bounded wait/notify outcomes across two workers", async () => {
    const original = compileWat(`(module
      (import "env" "memory" (memory 1 1 shared))
      (func (export "run") (param i32) (result i32)
        local.get 0
        if (result i32)
          i32.const 0
          i32.const 1
          i32.atomic.store
          i32.const 0
          i32.const 1
          memory.atomic.notify
        else
          i32.const 0
          i32.const 0
          i64.const 5000000000
          memory.atomic.wait32
        end))`);
    const wrong = compileWat(`(module
      (import "env" "memory" (memory 1 1 shared))
      (func (export "run") (param i32) (result i32)
        local.get 0
        if (result i32)
          i32.const 0
          i32.const 2
          i32.atomic.store
          i32.const 0
          i32.const 1
          memory.atomic.notify
        else
          i32.const 0
          i32.const 0
          i64.const 5000000000
          memory.atomic.wait32
        end))`);
    const report = await runNodeAtomicLitmusComparisonV1(original, wrong, WAIT_NOTIFY_SPEC, {
      timeoutMs: 3000,
    });
    expect(report.original.status).toBe("complete");
    expect(report.original.observations).toHaveLength(2);
    expect(report.candidate.status).toBe("complete");
    expect(report.comparison.classification).toBe("semantic-mismatch");
    expect(report.comparison.firstDisallowedOutcome?.memoryI32).toEqual([2]);
  });

  test("requires an actual bounded wait/notify wake outcome", async () => {
    const original = compileWat(`(module
      (import "env" "memory" (memory 1 1 shared))
      (func (export "run") (param $role i32) (result i32)
        (local $tries i32)
        local.get $role
        if (result i32)
          block $done (result i32)
            loop $retry (result i32)
              i32.const 0
              i32.const 1
              memory.atomic.notify
              i32.const 1
              i32.eq
              if
                i32.const 1
                br $done
              end
              local.get $tries
              i32.const 1
              i32.add
              local.tee $tries
              i32.const 256
              i32.lt_u
              if
                i32.const 8
                i32.const 0
                i64.const 1000000
                memory.atomic.wait32
                drop
                br $retry
              end
              i32.const -1
            end
          end
        else
          i32.const 4
          i32.const 1
          i32.atomic.store
          i32.const 0
          i32.const 0
          i64.const 500000000
          memory.atomic.wait32
        end))`);
    const wrong = compileWat(`(module
      (import "env" "memory" (memory 1 1 shared))
      (func (export "run") (param $role i32) (result i32)
        (local $tries i32)
        local.get $role
        if (result i32)
          block $done (result i32)
            loop $retry (result i32)
              i32.const 8
              i32.const 1
              memory.atomic.notify
              i32.const 1
              i32.eq
              if
                i32.const 1
                br $done
              end
              local.get $tries
              i32.const 1
              i32.add
              local.tee $tries
              i32.const 256
              i32.lt_u
              if
                i32.const 8
                i32.const 0
                i64.const 1000000
                memory.atomic.wait32
                drop
                br $retry
              end
              i32.const -1
            end
          end
        else
          i32.const 4
          i32.const 1
          i32.atomic.store
          i32.const 0
          i32.const 0
          i64.const 500000000
          memory.atomic.wait32
        end))`);

    const report = await runNodeAtomicLitmusComparisonV1(
      original,
      wrong,
      WAIT_NOTIFY_LIVENESS_SPEC,
      { timeoutMs: 3000 },
    );

    expect(report.original.status).toBe("complete");
    expect(report.original.observations.some((outcome) => outcome.threadResults[0] === 0 && outcome.threadResults[1] === 1)).toBe(true);
    expect(report.candidate.status).toBe("complete");
    expect(report.candidate.observations.every((outcome) => outcome.threadResults[0] === 2 && outcome.threadResults[1] === -1)).toBe(true);
    expect(report.comparison.classification).toBe("blocked");
    expect(report.comparison.failingSide).toBe("candidate");
    expect(report.comparison.firstMissingRequiredOutcome).toEqual({
      threadResults: [0, 1],
      memoryI32: [0, 1],
    });
  });

  test("observes compare-exchange winner identity across two workers", async () => {
    const original = compileWat(`(module
      (import "env" "memory" (memory 1 1 shared))
      (func (export "run") (param i32) (result i32)
        i32.const 0
        i32.const 0
        local.get 0
        i32.atomic.rmw.cmpxchg))`);
    const wrong = compileWat(`(module
      (import "env" "memory" (memory 1 1 shared))
      (func (export "run") (param i32) (result i32)
        i32.const 0
        i32.const 0
        i32.const 3
        i32.atomic.rmw.cmpxchg))`);
    const report = await runNodeAtomicLitmusComparisonV1(original, wrong, CMPXCHG_SPEC, {
      timeoutMs: 3000,
    });
    expect(report.original.status).toBe("complete");
    expect(report.candidate.status).toBe("complete");
    expect(report.comparison.classification).toBe("semantic-mismatch");
    expect(report.comparison.firstDisallowedOutcome?.memoryI32).toEqual([3]);
  });

  test("observes atomic selection of a nonzero imported shared memory", async () => {
    const original = compileWat(`(module
      (import "env" "memory0" (memory $memory0 1 1 shared))
      (import "env" "memory1" (memory $memory1 1 1 shared))
      (func (export "run") (param i32) (result i32)
        i32.const 0
        i32.const 1
        i32.atomic.rmw.add $memory1))`);
    const wrong = compileWat(`(module
      (import "env" "memory0" (memory $memory0 1 1 shared))
      (import "env" "memory1" (memory $memory1 1 1 shared))
      (func (export "run") (param i32) (result i32)
        i32.const 0
        i32.const 1
        i32.atomic.rmw.add $memory0))`);

    const report = await runNodeAtomicLitmusComparisonV1(
      original,
      wrong,
      MULTI_MEMORY_RMW_SPEC,
      { timeoutMs: 3000 },
    );

    expect(report.original.status).toBe("complete");
    expect(report.original.observations).toHaveLength(2);
    expect(report.original.observations.every((outcome) => outcome.memoryI32[0] === 0)).toBe(true);
    expect(report.candidate.status).toBe("complete");
    expect(report.comparison.classification).toBe("semantic-mismatch");
    expect(report.comparison.firstDisallowedOutcome?.memoryI32).toEqual([2]);
  });

  test("observes bounded shared memory64 atomic outcomes across two workers", async () => {
    const original = compileWat(`(module
      (import "env" "memory" (memory i64 1 1 shared))
      (func (export "run") (result i32)
        i64.const 0
        i32.const 1
        i32.atomic.rmw.add))`);
    const wrong = compileWat(`(module
      (import "env" "memory" (memory i64 1 1 shared))
      (func (export "run") (result i32)
        i64.const 0
        i32.const 2
        i32.atomic.rmw.add))`);
    const report = await runNodeAtomicLitmusComparisonV1(
      original,
      wrong,
      MEMORY64_RMW_SPEC,
      { timeoutMs: 3000 },
    );

    expect(report.original.status).toBe("complete");
    expect(report.original.observations).toHaveLength(2);
    expect(report.original.observations.every((outcome) => (
      outcome.memoryI32[0] === 2 &&
      (outcome.threadResults[0] === 0 && outcome.threadResults[1] === 1 ||
        outcome.threadResults[0] === 1 && outcome.threadResults[1] === 0)
    ))).toBe(true);
    expect(report.candidate.status).toBe("complete");
    expect(report.comparison.classification).toBe("semantic-mismatch");
    expect(report.comparison.firstDisallowedOutcome?.memoryI32).toEqual([4]);
  });

  test("observes mixed memory32 and memory64 atomic target selection", async () => {
    const original = compileWat(`(module
      (import "env" "memory32" (memory $memory32 1 1 shared))
      (import "env" "memory64" (memory $memory64 i64 1 1 shared))
      (func (export "run") (result i32)
        i64.const 0
        i32.const 1
        i32.atomic.rmw.add $memory64))`);
    const wrong = compileWat(`(module
      (import "env" "memory32" (memory $memory32 1 1 shared))
      (import "env" "memory64" (memory $memory64 i64 1 1 shared))
      (func (export "run") (result i32)
        i32.const 0
        i32.const 1
        i32.atomic.rmw.add $memory32))`);
    const report = await runNodeAtomicLitmusComparisonV1(
      original,
      wrong,
      MIXED_WIDTH_MEMORY_RMW_SPEC,
      { timeoutMs: 3000 },
    );

    expect(report.original.status).toBe("complete");
    expect(report.original.observations).toHaveLength(2);
    expect(report.original.observations.every((outcome) => (
      outcome.memoryI32[0] === 0 && outcome.memoryI32[1] === 2 &&
      (outcome.threadResults[0] === 0 && outcome.threadResults[1] === 1 ||
        outcome.threadResults[0] === 1 && outcome.threadResults[1] === 0)
    ))).toBe(true);
    expect(report.candidate.status).toBe("complete");
    expect(report.comparison.classification).toBe("semantic-mismatch");
    expect(report.comparison.firstDisallowedOutcome?.memoryI32).toEqual([2, 0]);
  });

  test("observes a controlled shared memory64 atomic bounds trap", async () => {
    const original = compileWat(`(module
      (import "env" "memory" (memory i64 1 1 shared))
      (func (export "run") (result i32)
        i64.const 65532
        i32.const 1
        i32.atomic.rmw.add))`);
    const wrong = compileWat(`(module
      (import "env" "memory" (memory i64 1 1 shared))
      (func (export "run") (result i32)
        i64.const 65536
        i32.const 1
        i32.atomic.rmw.add))`);

    const report = await runNodeAtomicLitmusComparisonV1(
      original,
      wrong,
      MEMORY64_BOUNDS_SPEC,
      { timeoutMs: 3000 },
    );

    expect(report.original.status).toBe("complete");
    expect(report.original.observations).toHaveLength(2);
    expect(report.candidate.status).toBe("complete");
    expect(report.comparison.classification).toBe("semantic-mismatch");
    expect(report.comparison.firstDisallowedOutcome).toMatchObject({
      threadResults: [
        { trap: "memory-out-of-bounds" },
        { trap: "memory-out-of-bounds" },
      ],
      memoryI32: [0],
    });
  });

  test("keeps unrelated memory64 worker traps blocked", async () => {
    const original = compileWat(`(module
      (import "env" "memory" (memory i64 1 1 shared))
      (func (export "run") (result i32)
        i64.const 65532
        i32.const 1
        i32.atomic.rmw.add))`);
    const unrelatedTrap = compileWat(`(module
      (import "env" "memory" (memory i64 1 1 shared))
      (func (export "run") (result i32)
        unreachable))`);

    const report = await runNodeAtomicLitmusComparisonV1(
      original,
      unrelatedTrap,
      MEMORY64_BOUNDS_SPEC,
      { timeoutMs: 3000 },
    );

    expect(report.original.status).toBe("complete");
    expect(report.candidate.status).toBe("blocked");
    expect(report.candidate.detail).toContain("unreachable");
    expect(report.comparison.classification).toBe("blocked");
    expect(report.comparison.failingSide).toBe("candidate");
  });

  test("observes compare-exchange on a nonzero imported shared memory", async () => {
    const original = compileWat(`(module
      (import "env" "memory0" (memory $memory0 1 1 shared))
      (import "env" "memory1" (memory $memory1 1 1 shared))
      (func (export "run") (param i32) (result i32)
        i32.const 0
        i32.const 0
        local.get 0
        i32.atomic.rmw.cmpxchg $memory1))`);
    const wrong = compileWat(`(module
      (import "env" "memory0" (memory $memory0 1 1 shared))
      (import "env" "memory1" (memory $memory1 1 1 shared))
      (func (export "run") (param i32) (result i32)
        i32.const 0
        i32.const 0
        local.get 0
        i32.atomic.rmw.cmpxchg $memory0))`);

    const report = await runNodeAtomicLitmusComparisonV1(
      original,
      wrong,
      MULTI_MEMORY_CMPXCHG_SPEC,
      { timeoutMs: 3000 },
    );

    expect(report.original.status).toBe("complete");
    expect(report.original.observations).toHaveLength(2);
    expect(report.candidate.status).toBe("complete");
    expect(report.comparison.classification).toBe("semantic-mismatch");
    expect(report.comparison.firstDisallowedOutcome?.memoryI32[1]).toBe(0);
    expect([1, 2]).toContain(report.comparison.firstDisallowedOutcome?.memoryI32[0]);
  });

  test("reports weaker-order stores as unsupported by the Node runtime", async () => {
    for (const hex of [ACQREL_STORE_WASM, RELAXED_STORE_WASM]) {
      const wasm = writeWasmHex(hex);
      const report = await runNodeAtomicLitmusComparisonV1(
        wasm,
        wasm,
        ORDERED_STORE_BOUNDARY_SPEC,
        { timeoutMs: 3000 },
      );

      expect(report.original.status).toBe("blocked");
      expect(report.original.observations).toHaveLength(0);
      expect(report.original.detail).toContain("invalid alignment");
      expect(report.candidate.status).toBe("blocked");
      expect(report.comparison.classification).toBe("blocked");
      expect(report.comparison.failingSide).toBe("original");
    }
  });

  test("reports weaker-order fences as unsupported by the Node runtime", async () => {
    for (const hex of [ACQREL_FENCE_WASM, RELAXED_FENCE_WASM]) {
      const wasm = writeWasmHex(hex);
      const report = await runNodeAtomicLitmusComparisonV1(
        wasm,
        wasm,
        ORDERED_FENCE_BOUNDARY_SPEC,
        { timeoutMs: 3000 },
      );

      expect(report.original.status).toBe("blocked");
      expect(report.original.observations).toHaveLength(0);
      expect(report.original.detail).toContain("invalid atomic operand");
      expect(report.candidate.status).toBe("blocked");
      expect(report.comparison.classification).toBe("blocked");
      expect(report.comparison.failingSide).toBe("original");
    }
  });
});
