import { parentPort, workerData } from "node:worker_threads";

import {
  executeNodeObservationV2,
  type NodeObservationV2Options,
} from "./optimizer-runtime-executor";
import type { InvocationPlanV2, RuntimeInterfaceV1 } from "./optimizer-runtime";

const data = workerData as {
  wasmPath: string;
  runtimeInterface: RuntimeInterfaceV1;
  plan: InvocationPlanV2;
  options: NodeObservationV2Options;
};

void executeNodeObservationV2(
  data.wasmPath,
  data.runtimeInterface,
  data.plan,
  data.options,
).then(
  (observation) => parentPort?.postMessage({ ok: true, observation }),
  (error) => parentPort?.postMessage({
    ok: false,
    detail: error instanceof Error ? error.message : String(error),
  }),
);
