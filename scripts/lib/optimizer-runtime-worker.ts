import { parentPort, workerData } from "node:worker_threads";

import { executeNodeInvocationPlan, type InvocationPlan } from "./optimizer-correctness";

const data = workerData as { wasmPath: string; plan: InvocationPlan };

void executeNodeInvocationPlan(data.wasmPath, data.plan).then(
  (observation) => parentPort?.postMessage({ ok: true, observation }),
  (error) => parentPort?.postMessage({
    ok: false,
    detail: error instanceof Error ? error.message : String(error),
  }),
);
