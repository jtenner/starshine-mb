import fs from "node:fs";
import { Worker } from "node:worker_threads";

import type {
  AtomicLitmusExecutionV1,
  AtomicLitmusObservationV1,
  AtomicLitmusSpecV1,
  AtomicLitmusThreadResultV1,
} from "./optimizer-atomic-runtime.ts";
import { optimizerRuntimeIdentity } from "./optimizer-runtime.ts";

const THREAD_SOURCE = String.raw`
  const { parentPort, workerData } = require("node:worker_threads");
  (async () => {
    try {
      const imports = {};
      for (const entry of workerData.memoryImports) {
        imports[entry.module] ??= {};
        imports[entry.module][entry.field] = entry.memory;
      }
      const instance = await WebAssembly.instantiate(workerData.module, imports);
      const run = instance.exports[workerData.exportName];
      if (typeof run !== "function") throw new Error("missing i32 litmus function export " + workerData.exportName);
      parentPort.postMessage({ kind: "ready", workerIndex: workerData.workerIndex });
      const gate = new Int32Array(workerData.gate);
      while (Atomics.load(gate, 0) === 0) Atomics.wait(gate, 0, 0);
      let result;
      try {
        const raw = run(...workerData.arguments);
        if (typeof raw !== "number" || !Number.isInteger(raw)) {
          throw new Error("litmus function must return one i32 result");
        }
        result = raw | 0;
      } catch (error) {
        const detail = error instanceof Error ? error.message : String(error);
        if (
          error instanceof WebAssembly.RuntimeError &&
          (/memory access out of bounds/i.test(detail) || /out of bounds memory access/i.test(detail))
        ) {
          result = { trap: "memory-out-of-bounds" };
        } else {
          throw error;
        }
      }
      parentPort.postMessage({ kind: "result", workerIndex: workerData.workerIndex, result });
    } catch (error) {
      parentPort.postMessage({ kind: "error", workerIndex: workerData.workerIndex, detail: error instanceof Error ? error.message : String(error) });
    } finally {
      parentPort.close();
    }
  })();
`;

async function executeTrial(
  module: WebAssembly.Module,
  spec: AtomicLitmusSpecV1,
  trial: number,
): Promise<AtomicLitmusObservationV1> {
  const memoryImports = [spec.memoryImport, ...(spec.additionalMemoryImports ?? [])];
  const memories = memoryImports.map((memoryImport) => memoryImport.address === "i64"
    ? new WebAssembly.Memory({
      address: "i64",
      initial: BigInt(memoryImport.initial),
      maximum: BigInt(memoryImport.maximum),
      shared: true,
    })
    : new WebAssembly.Memory({
      initial: memoryImport.initial,
      maximum: memoryImport.maximum,
      shared: true,
    }));
  const gate = new SharedArrayBuffer(Int32Array.BYTES_PER_ELEMENT);
  const gateView = new Int32Array(gate);
  const workers: Worker[] = [];
  const results = new Array<AtomicLitmusThreadResultV1>(spec.workerCount);
  let ready = 0;
  let completed = 0;
  try {
    await new Promise<void>((resolve, reject) => {
      let settled = false;
      const finishError = (error: unknown) => {
        if (settled) return;
        settled = true;
        reject(error instanceof Error ? error : new Error(String(error)));
      };
      for (let workerIndex = 0; workerIndex < spec.workerCount; workerIndex += 1) {
        const worker = new Worker(THREAD_SOURCE, {
          eval: true,
          workerData: {
            module,
            memoryImports: memoryImports.map((memoryImport, index) => ({
              module: memoryImport.module,
              field: memoryImport.field,
              memory: memories[index],
            })),
            gate,
            workerIndex,
            exportName: spec.exportName,
            arguments: spec.workerArguments[workerIndex],
          },
        });
        workers.push(worker);
        worker.on("message", (message: {
          kind: string;
          workerIndex: number;
          result?: AtomicLitmusThreadResultV1;
          detail?: string;
        }) => {
          if (message.kind === "ready") {
            ready += 1;
            if (ready === spec.workerCount) {
              Atomics.store(gateView, 0, 1);
              Atomics.notify(gateView, 0, spec.workerCount);
            }
          } else if (message.kind === "result") {
            results[message.workerIndex] = message.result as AtomicLitmusThreadResultV1;
            completed += 1;
            if (completed === spec.workerCount && !settled) {
              settled = true;
              resolve();
            }
          } else if (message.kind === "error") {
            finishError(new Error(`thread ${message.workerIndex}: ${message.detail ?? "unknown failure"}`));
          }
        });
        worker.once("error", finishError);
        worker.once("exit", (code) => {
          if (code !== 0 && completed < spec.workerCount) finishError(new Error(`thread ${workerIndex} exited ${code}`));
        });
      }
    });
    const primaryMemoryView = new Int32Array(memories[0].buffer);
    const additionalMemoryValues = (spec.additionalObservedI32Locations ?? []).map((location) => {
      const selectedMemoryView = new Int32Array(memories[location.memoryImportIndex].buffer);
      return Atomics.load(selectedMemoryView, location.offset / 4);
    });
    return {
      trial,
      threadResults: results,
      memoryI32: [
        ...spec.observedI32Offsets.map((offset) => Atomics.load(primaryMemoryView, offset / 4)),
        ...additionalMemoryValues,
      ],
    };
  } finally {
    await Promise.allSettled(workers.map((worker) => worker.terminate()));
  }
}

let input = "";
for await (const chunk of process.stdin) input += chunk.toString();
try {
  const { wasmPath, spec } = JSON.parse(input) as { wasmPath: string; spec: AtomicLitmusSpecV1 };
  const module = await WebAssembly.compile(fs.readFileSync(wasmPath));
  const observations: AtomicLitmusObservationV1[] = [];
  for (let trial = 0; trial < spec.trials; trial += 1) observations.push(await executeTrial(module, spec, trial));
  const execution: AtomicLitmusExecutionV1 = {
    schema: "starshine.optimizer-atomic-litmus-execution.v1",
    runtime: optimizerRuntimeIdentity(),
    status: "complete",
    observations,
    detail: null,
  };
  process.stdout.write(JSON.stringify({ ok: true, execution }));
} catch (error) {
  process.stdout.write(JSON.stringify({
    ok: false,
    detail: error instanceof Error ? error.message : String(error),
  }));
}
