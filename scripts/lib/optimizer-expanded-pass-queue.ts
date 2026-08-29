import { spawnSync } from "node:child_process";

export type ExpandedPassQueueCommandResult = {
  status: number | null;
  stdout: string;
  stderr: string;
  error?: Error;
};

export type ExpandedPassQueueEntry = {
  ordinal: number;
  name: string;
};

export type ExpandedPassQueueReportV1 = {
  schema: "starshine.optimizer-expanded-pass-queue.v1";
  requested: string[];
  optimizeLevel: number;
  shrinkLevel: number;
  passes: ExpandedPassQueueEntry[];
};

export type LoadedExpandedPassQueue = ExpandedPassQueueReportV1 & {
  passSequence: string[];
};

export function loadExpandedPassQueueFromStarshine(
  wasmPath: string,
  starshineBin: string,
  optimizerArgs: string[],
  run: (bin: string, args: string[]) => ExpandedPassQueueCommandResult = (bin, args) => {
    const result = spawnSync(bin, args, { encoding: "utf8" });
    return {
      status: result.status,
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? "",
      error: result.error,
    };
  },
  argsPrefix: string[] = [],
): LoadedExpandedPassQueue {
  const command = run(starshineBin, [
    ...argsPrefix,
    "--emit-expanded-pass-queue-json",
    ...optimizerArgs,
    wasmPath,
  ]);
  if (command.error != null) throw new Error(`failed to run Starshine expanded-pass-queue report: ${command.error.message}`);
  if (command.status !== 0) {
    throw new Error(`Starshine expanded-pass-queue report failed: ${command.stderr || command.stdout || `exit ${command.status}`}`);
  }
  let report: ExpandedPassQueueReportV1;
  try {
    report = JSON.parse(command.stdout) as ExpandedPassQueueReportV1;
  } catch (error) {
    throw new Error(`invalid Starshine expanded-pass-queue JSON: ${error instanceof Error ? error.message : String(error)}`);
  }
  if (report.schema !== "starshine.optimizer-expanded-pass-queue.v1") {
    throw new Error(`unsupported Starshine expanded-pass-queue schema ${(report as { schema?: string }).schema ?? "missing"}`);
  }
  if (!Array.isArray(report.requested) || !Array.isArray(report.passes)) {
    throw new Error("malformed Starshine expanded-pass-queue report");
  }
  for (let index = 0; index < report.passes.length; index += 1) {
    const entry = report.passes[index];
    if (entry == null || entry.ordinal !== index) {
      throw new Error(`malformed Starshine expanded-pass-queue report: non-contiguous ordinal at index ${index}`);
    }
    if (typeof entry.name !== "string" || entry.name.length === 0) {
      throw new Error(`malformed Starshine expanded-pass-queue report: invalid pass name at index ${index}`);
    }
  }
  return { ...report, passSequence: report.passes.map((entry) => entry.name) };
}
