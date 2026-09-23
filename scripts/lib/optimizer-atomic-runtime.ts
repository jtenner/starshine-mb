import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { fileURLToPath } from "node:url";

import {
  nodeObservationArguments,
  nodeObservationRuntimeIdentity,
} from "./optimizer-runtime-executor.ts";

export type AtomicLitmusOutcomeV1 = {
  threadResults: number[];
  memoryI32: number[];
};

export type AtomicLitmusObservationV1 = AtomicLitmusOutcomeV1 & {
  trial: number;
};

export type AtomicLitmusMemoryImportV1 = {
  module: string;
  field: string;
  initial: number;
  maximum: number;
};

export type AtomicLitmusSpecV1 = {
  schema: "starshine.optimizer-atomic-litmus.v1";
  id: string;
  workerCount: 2;
  exportName: string;
  workerArguments: [number[], number[]];
  memoryImport: AtomicLitmusMemoryImportV1;
  additionalMemoryImports?: AtomicLitmusMemoryImportV1[];
  observedI32Offsets: number[];
  trials: number;
  allowedOutcomes: AtomicLitmusOutcomeV1[];
};

export type AtomicLitmusExecutionV1 = {
  schema: "starshine.optimizer-atomic-litmus-execution.v1";
  runtime: string;
  status: "complete" | "blocked";
  observations: AtomicLitmusObservationV1[];
  detail: string | null;
};

export type AtomicLitmusOutcomeComparisonV1 = {
  classification: "allowed-outcome-match" | "semantic-mismatch" | "blocked";
  failingSide: "original" | "candidate" | null;
  firstDisallowedOutcome: AtomicLitmusObservationV1 | null;
  allowedOutcomeKeys: string[];
  detail: string | null;
};

export type AtomicLitmusComparisonReportV1 = {
  schema: "starshine.optimizer-atomic-litmus-comparison.v1";
  runtime: string;
  spec: AtomicLitmusSpecV1;
  original: AtomicLitmusExecutionV1;
  candidate: AtomicLitmusExecutionV1;
  comparison: AtomicLitmusOutcomeComparisonV1;
};

function outcomeKey(outcome: AtomicLitmusOutcomeV1): string {
  return JSON.stringify({
    threadResults: outcome.threadResults,
    memoryI32: outcome.memoryI32,
  });
}

function isI32(value: number): boolean {
  return Number.isInteger(value) && value >= -2147483648 && value <= 2147483647;
}

function validateOutcomeShape(spec: AtomicLitmusSpecV1, outcome: AtomicLitmusOutcomeV1, label: string): void {
  if (outcome.threadResults.length !== spec.workerCount) {
    throw new Error(`${label} must contain ${spec.workerCount} thread results`);
  }
  if (outcome.memoryI32.length !== spec.observedI32Offsets.length) {
    throw new Error(`${label} must contain ${spec.observedI32Offsets.length} memory values`);
  }
  if (![...outcome.threadResults, ...outcome.memoryI32].every(isI32)) {
    throw new Error(`${label} values must be signed i32 integers`);
  }
}

export function validateAtomicLitmusSpecV1(spec: AtomicLitmusSpecV1): void {
  if (spec.schema !== "starshine.optimizer-atomic-litmus.v1") throw new Error(`unsupported atomic litmus schema ${spec.schema}`);
  if (spec.workerCount !== 2) throw new Error("atomic litmus v1 requires exactly two workers");
  if (spec.id.length === 0 || spec.exportName.length === 0) throw new Error("atomic litmus id and export name are required");
  if (!Number.isInteger(spec.trials) || spec.trials < 1 || spec.trials > 8) throw new Error("atomic litmus trials must be between 1 and 8");
  if (spec.workerArguments.length !== spec.workerCount || spec.workerArguments.some((args) => args.length > 8 || !args.every(isI32))) {
    throw new Error("atomic litmus worker arguments must be bounded signed i32 vectors");
  }
  const memories = [spec.memoryImport, ...(spec.additionalMemoryImports ?? [])];
  if (memories.length > 4) {
    throw new Error("atomic litmus supports at most four shared memory imports");
  }
  for (const memory of memories) {
    if (
      memory.module.length === 0 || memory.field.length === 0 ||
      !Number.isInteger(memory.initial) || !Number.isInteger(memory.maximum) ||
      memory.initial < 1 || memory.maximum < memory.initial || memory.maximum > 16
    ) {
      throw new Error("atomic litmus shared memory imports require names and valid limits of at most 16 pages");
    }
  }
  if (new Set(memories.map((memory) => `${memory.module}\0${memory.field}`)).size !== memories.length) {
    throw new Error("atomic litmus shared memory import names must be unique");
  }
  if (spec.observedI32Offsets.length < 1 || spec.observedI32Offsets.length > 16) {
    throw new Error("atomic litmus must observe between 1 and 16 i32 locations");
  }
  const byteLength = spec.memoryImport.initial * 64 * 1024;
  if (spec.observedI32Offsets.some((offset) => !Number.isInteger(offset) || offset < 0 || offset % 4 !== 0 || offset + 4 > byteLength)) {
    throw new Error("atomic litmus i32 observation offsets must be aligned and inside the initial memory");
  }
  if (new Set(spec.observedI32Offsets).size !== spec.observedI32Offsets.length) {
    throw new Error("atomic litmus i32 observation offsets must be unique");
  }
  if (spec.allowedOutcomes.length < 1 || spec.allowedOutcomes.length > 32) {
    throw new Error("atomic litmus must declare between 1 and 32 allowed outcomes");
  }
  for (const [index, outcome] of spec.allowedOutcomes.entries()) validateOutcomeShape(spec, outcome, `allowed outcome ${index}`);
  if (new Set(spec.allowedOutcomes.map(outcomeKey)).size !== spec.allowedOutcomes.length) {
    throw new Error("atomic litmus allowed outcomes must be unique");
  }
}

export function compareAtomicLitmusObservationSetsV1(
  spec: AtomicLitmusSpecV1,
  original: AtomicLitmusObservationV1[],
  candidate: AtomicLitmusObservationV1[],
): AtomicLitmusOutcomeComparisonV1 {
  validateAtomicLitmusSpecV1(spec);
  const allowedOutcomeKeys = spec.allowedOutcomes.map(outcomeKey).sort();
  const allowed = new Set(allowedOutcomeKeys);
  if (original.length === 0) {
    return {
      classification: "blocked",
      failingSide: "original",
      firstDisallowedOutcome: null,
      allowedOutcomeKeys,
      detail: "original produced no completed observations",
    };
  }
  const originalDisallowed = original.find((outcome) => !allowed.has(outcomeKey(outcome)));
  if (originalDisallowed !== undefined) {
    return {
      classification: "blocked",
      failingSide: "original",
      firstDisallowedOutcome: originalDisallowed,
      allowedOutcomeKeys,
      detail: "original produced an outcome outside the declared oracle set",
    };
  }
  if (candidate.length === 0) {
    return {
      classification: "blocked",
      failingSide: "candidate",
      firstDisallowedOutcome: null,
      allowedOutcomeKeys,
      detail: "candidate produced no completed observations",
    };
  }
  const candidateDisallowed = candidate.find((outcome) => !allowed.has(outcomeKey(outcome)));
  if (candidateDisallowed !== undefined) {
    return {
      classification: "semantic-mismatch",
      failingSide: "candidate",
      firstDisallowedOutcome: candidateDisallowed,
      allowedOutcomeKeys,
      detail: "candidate produced an outcome outside the declared oracle set",
    };
  }
  return {
    classification: "allowed-outcome-match",
    failingSide: null,
    firstDisallowedOutcome: null,
    allowedOutcomeKeys,
    detail: null,
  };
}

function blockedExecution(runtime: string, detail: string): AtomicLitmusExecutionV1 {
  return {
    schema: "starshine.optimizer-atomic-litmus-execution.v1",
    runtime,
    status: "blocked",
    observations: [],
    detail,
  };
}

async function executeNodeAtomicLitmusV1(
  wasmPath: string,
  spec: AtomicLitmusSpecV1,
  timeoutMs: number,
  spawnWorker: (command: string, args: string[], options: { stdio: ["pipe", "pipe", "pipe"] }) => ChildProcessWithoutNullStreams,
): Promise<AtomicLitmusExecutionV1> {
  const runtime = nodeObservationRuntimeIdentity();
  return await new Promise((resolve) => {
    const child = spawnWorker("node", [...nodeObservationArguments(), fileURLToPath(new URL("./optimizer-atomic-runtime-worker.ts", import.meta.url))], {
      stdio: ["pipe", "pipe", "pipe"],
    });
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
    }, timeoutMs);
    child.on("error", (error) => { spawnError = error; });
    child.stdin.on("error", (error) => { spawnError ??= error; });
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      if (timedOut) return resolve(blockedExecution(runtime, `timeout:${timeoutMs}ms`));
      if (spawnError !== undefined) return resolve(blockedExecution(runtime, `worker-failure:${spawnError.message}`));
      if (code !== 0) return resolve(blockedExecution(runtime, `worker-failure:Node exited ${code ?? signal}: ${diagnostic}`));
      try {
        const message = JSON.parse(output) as { ok: boolean; execution?: AtomicLitmusExecutionV1; detail?: string };
        if (!message.ok || message.execution === undefined) {
          return resolve(blockedExecution(runtime, `worker-failure:${message.detail ?? "Node returned no execution"}`));
        }
        resolve({ ...message.execution, runtime });
      } catch (error) {
        resolve(blockedExecution(runtime, `worker-failure:invalid Node response: ${String(error)}; ${diagnostic}`));
      }
    });
    child.stdin.end(JSON.stringify({ wasmPath, spec }));
  });
}

export async function runNodeAtomicLitmusComparisonV1(
  originalWasmPath: string,
  candidateWasmPath: string,
  spec: AtomicLitmusSpecV1,
  options: { timeoutMs: number },
  spawnWorker: (command: string, args: string[], options: { stdio: ["pipe", "pipe", "pipe"] }) => ChildProcessWithoutNullStreams = spawn,
): Promise<AtomicLitmusComparisonReportV1> {
  validateAtomicLitmusSpecV1(spec);
  if (!Number.isInteger(options.timeoutMs) || options.timeoutMs < 1 || options.timeoutMs > 60000) {
    throw new Error("atomic litmus timeout must be between 1 and 60000 milliseconds");
  }
  const runtime = nodeObservationRuntimeIdentity();
  const original = await executeNodeAtomicLitmusV1(originalWasmPath, spec, options.timeoutMs, spawnWorker);
  const candidate = await executeNodeAtomicLitmusV1(candidateWasmPath, spec, options.timeoutMs, spawnWorker);
  let comparison: AtomicLitmusOutcomeComparisonV1;
  if (original.status === "blocked") {
    comparison = {
      classification: "blocked",
      failingSide: "original",
      firstDisallowedOutcome: null,
      allowedOutcomeKeys: spec.allowedOutcomes.map(outcomeKey).sort(),
      detail: original.detail,
    };
  } else if (candidate.status === "blocked") {
    comparison = {
      classification: "blocked",
      failingSide: "candidate",
      firstDisallowedOutcome: null,
      allowedOutcomeKeys: spec.allowedOutcomes.map(outcomeKey).sort(),
      detail: candidate.detail,
    };
  } else {
    comparison = compareAtomicLitmusObservationSetsV1(spec, original.observations, candidate.observations);
  }
  return {
    schema: "starshine.optimizer-atomic-litmus-comparison.v1",
    runtime,
    spec,
    original,
    candidate,
    comparison,
  };
}
