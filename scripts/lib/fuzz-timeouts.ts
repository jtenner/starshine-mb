export type FuzzTimeoutRunner = "ordinary" | "pass-fuzz" | "external-adapter";

const DEFAULT_TIMEOUTS_MS: Record<FuzzTimeoutRunner, number> = {
  ordinary: 1_000,
  "pass-fuzz": 5_000,
  "external-adapter": 2_000,
};

export function defaultFuzzCaseTimeoutMs(runner: FuzzTimeoutRunner): number {
  return DEFAULT_TIMEOUTS_MS[runner];
}

export type FuzzTimeoutClassification = {
  runner: FuzzTimeoutRunner;
  timedOut: boolean;
  classification: "completed" | "timeout";
  elapsedMs: number;
  timeoutMs: number;
};

export function classifyFuzzCaseTimeout({
  runner,
  elapsedMs,
  timeoutMs,
}: {
  runner: FuzzTimeoutRunner;
  elapsedMs: number;
  timeoutMs: number;
}): FuzzTimeoutClassification {
  const timedOut = elapsedMs >= timeoutMs;
  return {
    runner,
    timedOut,
    classification: timedOut ? "timeout" : "completed",
    elapsedMs,
    timeoutMs,
  };
}

export async function withFuzzCaseTimeout<T>(
  runner: FuzzTimeoutRunner,
  timeoutMs: number,
  work: () => Promise<T>,
): Promise<{ ok: true; value: T; timeout: FuzzTimeoutClassification } | { ok: false; timeout: FuzzTimeoutClassification }> {
  const start = performance.now();
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  const timeoutPromise = new Promise<"timeout">((resolve) => {
    timeoutId = setTimeout(() => resolve("timeout"), timeoutMs);
  });
  const result = await Promise.race([work(), timeoutPromise]);
  if (timeoutId !== null) clearTimeout(timeoutId);
  const elapsedMs = Math.max(0, Math.round(performance.now() - start));
  if (result === "timeout") {
    return {
      ok: false,
      timeout: classifyFuzzCaseTimeout({ runner, elapsedMs: Math.max(elapsedMs, timeoutMs), timeoutMs }),
    };
  }
  return {
    ok: true,
    value: result as T,
    timeout: classifyFuzzCaseTimeout({ runner, elapsedMs, timeoutMs }),
  };
}
