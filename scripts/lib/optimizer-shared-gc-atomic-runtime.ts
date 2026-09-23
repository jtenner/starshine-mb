import { spawn } from "node:child_process";

export type SharedGcAtomicObservationV1 = {
  threadResults: [number, number];
  finalOldValue: number;
};

export type SharedGcAtomicRuntimeCapabilityV1 = {
  schema: "starshine.optimizer-shared-gc-atomic-runtime-capability.v1";
  runtime: string;
  status: "complete" | "blocked";
  observation: SharedGcAtomicObservationV1 | null;
  detail: string | null;
};

export type SharedGcAtomicComparisonV1 = {
  classification: "allowed-outcome-match" | "semantic-mismatch" | "blocked";
  failingSide: "original" | "candidate" | null;
  detail: string | null;
};

export type SharedGcAtomicComparisonReportV1 = {
  schema: "starshine.optimizer-shared-gc-atomic-comparison.v1";
  runtime: string;
  original: SharedGcAtomicRuntimeCapabilityV1;
  candidate: SharedGcAtomicRuntimeCapabilityV1;
  comparison: SharedGcAtomicComparisonV1;
};

const THREAD_SOURCE = String.raw`
  const { parentPort, workerData } = require("node:worker_threads");
  (async () => {
    try {
      const instance = await WebAssembly.instantiate(workerData.module);
      const add = instance.exports.add;
      if (typeof add !== "function") throw new Error("missing shared-GC i32 export add");
      parentPort.postMessage({ kind: "ready", workerIndex: workerData.workerIndex });
      const gate = new Int32Array(workerData.gate);
      while (Atomics.load(gate, 0) === 0) Atomics.wait(gate, 0, 0);
      const raw = add(workerData.sharedRef);
      if (typeof raw !== "number" || !Number.isInteger(raw)) {
        throw new Error("shared-GC litmus add export must return one i32 result");
      }
      parentPort.postMessage({ kind: "result", workerIndex: workerData.workerIndex, result: raw | 0 });
    } catch (error) {
      parentPort.postMessage({ kind: "error", workerIndex: workerData.workerIndex, detail: error instanceof Error ? error.message : String(error) });
    } finally {
      parentPort.close();
    }
  })();
`;

const PROBE_SOURCE = String.raw`
  const fs = require("node:fs");
  const { Worker } = require("node:worker_threads");
  const THREAD_SOURCE = ${JSON.stringify(THREAD_SOURCE)};
  const runtime = "node:" + process.version + ":--experimental-wasm-shared";

  (async () => {
    const module = await WebAssembly.compile(fs.readFileSync(process.argv[1]));
    const instance = await WebAssembly.instantiate(module);
    const make = instance.exports.make;
    const add = instance.exports.add;
    if (typeof make !== "function") throw new Error("missing shared-GC reference export make");
    if (typeof add !== "function") throw new Error("missing shared-GC i32 export add");
    const sharedRef = make();
    if (sharedRef === null || typeof sharedRef !== "object") {
      throw new Error("shared-GC make export must return one non-null reference");
    }

    const gate = new SharedArrayBuffer(Int32Array.BYTES_PER_ELEMENT);
    const gateView = new Int32Array(gate);
    const workers = [];
    const results = new Array(2);
    let ready = 0;
    let completed = 0;
    try {
      await new Promise((resolve, reject) => {
        let settled = false;
        const finishError = (error) => {
          if (settled) return;
          settled = true;
          reject(error instanceof Error ? error : new Error(String(error)));
        };
        for (let workerIndex = 0; workerIndex < 2; workerIndex += 1) {
          const worker = new Worker(THREAD_SOURCE, {
            eval: true,
            workerData: { module, sharedRef, gate, workerIndex },
          });
          workers.push(worker);
          worker.on("message", (message) => {
            if (message.kind === "ready") {
              ready += 1;
              if (ready === 2) {
                Atomics.store(gateView, 0, 1);
                Atomics.notify(gateView, 0, 2);
              }
            } else if (message.kind === "result") {
              results[message.workerIndex] = message.result;
              completed += 1;
              if (completed === 2 && !settled) {
                settled = true;
                resolve();
              }
            } else if (message.kind === "error") {
              finishError(new Error("thread " + message.workerIndex + ": " + (message.detail || "unknown failure")));
            }
          });
          worker.once("error", finishError);
          worker.once("exit", (code) => {
            if (results[workerIndex] === undefined) {
              finishError(new Error("thread " + workerIndex + " exited " + code + " before producing a result"));
            }
          });
        }
      });
    } finally {
      await Promise.allSettled(workers.map((worker) => worker.terminate()));
    }

    const observation = {
      threadResults: results,
      finalOldValue: add(sharedRef) | 0,
    };
    process.stdout.write(JSON.stringify({ ok: true, runtime, observation }));
  })().catch((error) => {
    process.stdout.write(JSON.stringify({
      ok: false,
      runtime,
      detail: error instanceof Error ? error.message : String(error),
    }));
  });
`;

function blocked(runtime: string, detail: string): SharedGcAtomicRuntimeCapabilityV1 {
  return {
    schema: "starshine.optimizer-shared-gc-atomic-runtime-capability.v1",
    runtime,
    status: "blocked",
    observation: null,
    detail,
  };
}

function isAllowedObservation(observation: SharedGcAtomicObservationV1): boolean {
  return observation.finalOldValue === 2 && (
    observation.threadResults[0] === 0 && observation.threadResults[1] === 1 ||
    observation.threadResults[0] === 1 && observation.threadResults[1] === 0
  );
}

async function executeNodeSharedGcAtomicRuntimeV1(
  wasmPath: string,
  options: { timeoutMs: number },
): Promise<SharedGcAtomicRuntimeCapabilityV1> {
  if (wasmPath.length === 0) throw new Error("shared-GC atomic runtime probe requires a wasm path");
  if (!Number.isInteger(options.timeoutMs) || options.timeoutMs < 1 || options.timeoutMs > 60000) {
    throw new Error("shared-GC atomic runtime probe timeout must be between 1 and 60000 milliseconds");
  }

  const fallbackRuntime = "node:unknown:--experimental-wasm-shared";
  return await new Promise((resolve) => {
    const child = spawn(
      "node",
      ["--experimental-wasm-shared", "-e", PROBE_SOURCE, wasmPath],
      { stdio: ["ignore", "pipe", "pipe"] },
    );
    let output = "";
    let diagnostic = "";
    let timedOut = false;
    let spawnError: Error | undefined;
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => { output += chunk; });
    child.stderr.on("data", (chunk: string) => { diagnostic += chunk; });
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, options.timeoutMs);
    child.on("error", (error) => { spawnError = error; });
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      if (timedOut) return resolve(blocked(fallbackRuntime, `timeout:${options.timeoutMs}ms`));
      if (spawnError !== undefined) return resolve(blocked(fallbackRuntime, `probe-failure:${spawnError.message}`));
      if (code !== 0) {
        return resolve(blocked(fallbackRuntime, `probe-failure:Node exited ${code ?? signal}: ${diagnostic.trim()}`));
      }
      try {
        const message = JSON.parse(output) as {
          ok: boolean;
          runtime?: string;
          observation?: SharedGcAtomicObservationV1;
          detail?: string;
        };
        const runtime = message.runtime ?? fallbackRuntime;
        if (!message.ok || message.observation === undefined) {
          return resolve(blocked(runtime, `runtime-unsupported:${message.detail ?? "Node returned no observation"}`));
        }
        resolve({
          schema: "starshine.optimizer-shared-gc-atomic-runtime-capability.v1",
          runtime,
          status: "complete",
          observation: message.observation,
          detail: null,
        });
      } catch (error) {
        resolve(blocked(fallbackRuntime, `probe-failure:invalid Node response: ${String(error)}; ${diagnostic.trim()}`));
      }
    });
  });
}

export async function probeNodeSharedGcAtomicRuntimeV1(
  wasmPath: string,
  options: { timeoutMs: number },
): Promise<SharedGcAtomicRuntimeCapabilityV1> {
  const execution = await executeNodeSharedGcAtomicRuntimeV1(wasmPath, options);
  if (execution.status === "complete" && !isAllowedObservation(execution.observation!)) {
    return blocked(execution.runtime, `runtime-invalid-outcome:${JSON.stringify(execution.observation)}`);
  }
  return execution;
}

export async function runNodeSharedGcAtomicComparisonV1(
  originalWasmPath: string,
  candidateWasmPath: string,
  options: { timeoutMs: number },
): Promise<SharedGcAtomicComparisonReportV1> {
  const original = await executeNodeSharedGcAtomicRuntimeV1(originalWasmPath, options);
  let candidate: SharedGcAtomicRuntimeCapabilityV1;
  let comparison: SharedGcAtomicComparisonV1;
  if (original.status === "blocked") {
    candidate = blocked(original.runtime, "not-run:original-blocked");
    comparison = { classification: "blocked", failingSide: "original", detail: original.detail };
  } else if (!isAllowedObservation(original.observation!)) {
    candidate = blocked(original.runtime, "not-run:original-outside-allowed-set");
    comparison = {
      classification: "blocked",
      failingSide: "original",
      detail: `original-outside-allowed-set:${JSON.stringify(original.observation)}`,
    };
  } else {
    candidate = await executeNodeSharedGcAtomicRuntimeV1(candidateWasmPath, options);
    if (candidate.status === "blocked") {
      comparison = { classification: "blocked", failingSide: "candidate", detail: candidate.detail };
    } else if (!isAllowedObservation(candidate.observation!)) {
      comparison = {
        classification: "semantic-mismatch",
        failingSide: "candidate",
        detail: `candidate-outside-allowed-set:${JSON.stringify(candidate.observation)}`,
      };
    } else {
      comparison = { classification: "allowed-outcome-match", failingSide: null, detail: null };
    }
  }
  return {
    schema: "starshine.optimizer-shared-gc-atomic-comparison.v1",
    runtime: original.runtime,
    original,
    candidate,
    comparison,
  };
}
