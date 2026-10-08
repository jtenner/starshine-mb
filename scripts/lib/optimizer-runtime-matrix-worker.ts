import { serialize } from "node:v8";
import { runNodeExportInvocationMatrixInProcess } from "./pass-fuzz-compare-task.ts";

// The parent owns the deadline, output bound and process lifetime.
let input = "";
for await (const chunk of process.stdin) input += chunk.toString();
try {
  const data = JSON.parse(input) as {
    leftWasmPath: string;
    rightWasmPath: string;
    maxInvocations: number;
    wasmToolsBin: string;
  };
  const reports = await runNodeExportInvocationMatrixInProcess(
    data.leftWasmPath, data.rightWasmPath, data.maxInvocations, data.wasmToolsBin,
  );
  process.stdout.write(serialize({ reports }));
} catch (error) {
  process.stdout.write(serialize({ error: error instanceof Error ? error.message : String(error) }));
}
