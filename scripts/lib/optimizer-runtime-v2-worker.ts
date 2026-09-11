import {
  executeNodeObservationV2,
  type NodeObservationV2Options,
} from "./optimizer-runtime-executor.ts";
import type { InvocationPlanV2, RuntimeInterfaceV1 } from "./optimizer-runtime.ts";

// This entry point runs only in an explicit Node child. JSON crosses the
// process boundary so it also works when the parent CLI is hosted by Bun.
let input = "";
for await (const chunk of process.stdin) input += chunk.toString();
try {
  const data = JSON.parse(input) as {
    wasmPath: string;
    runtimeInterface: RuntimeInterfaceV1;
    plan: InvocationPlanV2;
    options: Omit<NodeObservationV2Options, "seed"> & { seed?: string };
  };
  const observation = await executeNodeObservationV2(
    data.wasmPath, data.runtimeInterface, data.plan,
    { ...data.options, seed: data.options.seed === undefined ? undefined : BigInt(data.options.seed) },
  );
  process.stdout.write(JSON.stringify({ ok: true, observation }));
} catch (error) {
  process.stdout.write(JSON.stringify({
    ok: false,
    detail: error instanceof Error ? error.message : String(error),
  }));
}
