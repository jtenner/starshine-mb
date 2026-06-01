import { strict as assert } from "node:assert";

import {
  reduceBinaryByByteSlices,
  reduceBinaryByByteSlicesWithReport,
  reduceModuleFieldsByDeletion,
  reduceTextByTokenDeletion,
} from "../lib/fuzz-reducers";

export function runFuzzReducersTest(): void {
  const moduleFields = ["type", "import", "func", "export", "custom"];
  const reducedModule = reduceModuleFieldsByDeletion(moduleFields, (candidate) => {
    return candidate.includes("func") && candidate.includes("export") && !candidate.includes("custom");
  });
  assert.deepEqual(reducedModule, ["func", "export"], "module reducer should delete fields while preserving predicate");

  const bytes = new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7]);
  const reducedBytes = reduceBinaryByByteSlices(bytes, (candidate) => {
    return candidate.includes(2) && candidate.includes(5) && !candidate.includes(6);
  });
  assert.deepEqual(Array.from(reducedBytes), [2, 5], "binary reducer should delete byte slices while preserving predicate");

  const reducedBytesReport = reduceBinaryByByteSlicesWithReport(bytes, (candidate) => {
    return candidate.includes(2) && candidate.includes(5) && !candidate.includes(6);
  });
  assert.deepEqual(Array.from(reducedBytesReport.result), [2, 5], "binary reducer report should carry the reduced bytes");
  assert.equal(reducedBytesReport.originalSize, 8, "binary reducer report should carry the original size");
  assert.equal(reducedBytesReport.finalSize, 2, "binary reducer report should carry the final size");
  assert.ok(reducedBytesReport.predicateEvaluations > 0, "binary reducer report should count predicate evaluations");
  assert.ok(reducedBytesReport.steps.length > 0, "binary reducer report should record deletion steps");
  assert.equal(reducedBytesReport.steps[0].kind, "delete-byte-slice", "binary reducer report should label byte deletions");

  const reducedText = reduceTextByTokenDeletion("( module ( func $keep ) ( export \"x\" ) )", (candidate) => {
    return candidate.includes("func") && candidate.includes("export") && !candidate.includes("module");
  });
  assert.equal(reducedText, "func export", "text reducer should delete tokens while preserving predicate");

  const unchanged = reduceTextByTokenDeletion("alpha beta", () => false);
  assert.equal(unchanged, "alpha beta", "reducers must preserve original when no deletion preserves predicate");
}

if (import.meta.main) {
  runFuzzReducersTest();
}
