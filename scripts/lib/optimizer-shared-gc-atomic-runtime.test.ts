import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { expect, test } from "bun:test";

import {
  probeNodeSharedGcAtomicRuntimeV1,
  runNodeSharedGcAtomicComparisonV1,
} from "./optimizer-shared-gc-atomic-runtime";

function compileWat(wat: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-shared-gc-atomic-"));
  const watPath = path.join(dir, "module.wat");
  const wasmPath = path.join(dir, "module.wasm");
  fs.writeFileSync(watPath, wat);
  const result = spawnSync("wasm-tools", ["parse", watPath, "-o", wasmPath], { encoding: "utf8" });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || "wasm-tools parse failed");
  const validation = spawnSync("wasm-tools", ["validate", "--features", "all", wasmPath], { encoding: "utf8" });
  if (validation.error) throw validation.error;
  if (validation.status !== 0) {
    throw new Error(validation.stderr || validation.stdout || "wasm-tools validate failed");
  }
  return wasmPath;
}

test("records the intentional Node shared-GC cross-worker unsupported boundary", async () => {
  const sharedGcRmw = compileWat(`(module
    (type $S (shared (struct (field (mut i32)))))
    (type $F (shared (func (result i32))))
    (global $g (shared (ref $S)) (struct.new $S (i32.const 0)))
    (func $run (type $F) (result i32)
      (struct.atomic.rmw.add seq_cst $S 0
        (global.get $g)
        (i32.const 1)))
    (export "run" (func $run)))`);

  const capability = await probeNodeSharedGcAtomicRuntimeV1(sharedGcRmw, {
    timeoutMs: 3000,
  });

  expect(capability.schema).toBe("starshine.optimizer-shared-gc-atomic-runtime-capability.v1");
  expect(capability.runtime).toContain("--experimental-wasm-shared");
  expect(capability.status).toBe("blocked");
  expect(capability.observation).toBeNull();
  expect(capability.detail).toContain("shared functions/continuations are not supported yet");
});

function compileSharedGcRmw(addend: number): string {
  return compileWat(`(module
    (type $S (shared (struct (field (mut i32)))))
    (func (export "make") (result (ref $S))
      (struct.new $S (i32.const 0)))
    (func (export "add") (param (ref $S)) (result i32)
      (struct.atomic.rmw.add seq_cst $S 0
        (local.get 0)
        (i32.const ${addend}))))`);
}

test("executes shared-GC RMW through per-worker instances and one transferred shared ref", async () => {
  const capability = await probeNodeSharedGcAtomicRuntimeV1(compileSharedGcRmw(1), {
    timeoutMs: 3000,
  });

  expect(capability.status).toBe("complete");
  expect(capability.detail).toBeNull();
  expect(capability.observation?.threadResults.toSorted()).toEqual([0, 1]);
  expect(capability.observation?.finalOldValue).toBe(2);
});

test("rejects a shared-GC RMW candidate that adds two", async () => {
  const report = await runNodeSharedGcAtomicComparisonV1(
    compileSharedGcRmw(1),
    compileSharedGcRmw(2),
    { timeoutMs: 3000 },
  );

  expect(report.original.status).toBe("complete");
  expect(report.candidate.status).toBe("complete");
  expect(report.candidate.observation?.threadResults.toSorted()).toEqual([0, 2]);
  expect(report.candidate.observation?.finalOldValue).toBe(4);
  expect(report.comparison.classification).toBe("semantic-mismatch");
  expect(report.comparison.failingSide).toBe("candidate");
});
