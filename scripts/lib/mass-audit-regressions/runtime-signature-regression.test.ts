import { expect, test } from "bun:test";
import { fileURLToPath } from "node:url";
import { buildRuntimeInterfaceFromWasm, runNodeThreeWaySemanticOracleV2 } from "../optimizer-runtime-executor.ts";

test("function signatures exclude the parameters and results of nested blocks", () => {
  const fixture = fileURLToPath(new URL("./code-folding-indexed-input.wasm", import.meta.url));
  const report = buildRuntimeInterfaceFromWasm(fixture);
  const run = report.exports.find((entry) => entry.kind === "function" && entry.name === "run");
  expect(run?.signature).toEqual({ params: ["i32", "i32"], results: ["i32"] });
});

test("runtime comparison detects different scalar returns in indexed block functions", async () => {
  const before = fileURLToPath(new URL("./code-folding-indexed-input.wasm", import.meta.url));
  const after = fileURLToPath(new URL("./runtime-signature-changed.wasm", import.meta.url));
  const report = await runNodeThreeWaySemanticOracleV2(before, after, null, {
    seed: 0n,
    policy: "strict",
    mode: "independent",
    timeoutMs: 1000,
    memoryCapBytes: 65536,
    tableEntryCap: 8,
    maxPairwise: 1,
  });
  expect(report.originalVsStarshine?.classification).toBe("semantic-mismatch");
}, 10000);
