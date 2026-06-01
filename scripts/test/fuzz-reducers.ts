import { strict as assert } from "node:assert";

import {
  formatReductionReportLog,
  reduceBinaryByByteSlices,
  reduceBinaryByByteSlicesWithReport,
  reduceModuleFieldsByDeletion,
  reduceModuleFieldsByDeletionWithReport,
  reduceTextByLineDeletion,
  reduceTextByLineDeletionWithReport,
  reduceTextByTokenDeletion,
  reduceTextByTokenDeletionWithReport,
} from "../lib/fuzz-reducers";

export function runFuzzReducersTest(): void {
  const moduleFields = ["type", "import", "func", "export", "custom"];
  const reducedModule = reduceModuleFieldsByDeletion(moduleFields, (candidate) => {
    return candidate.includes("func") && candidate.includes("export") && !candidate.includes("custom");
  });
  assert.deepEqual(reducedModule, ["func", "export"], "module reducer should delete fields while preserving predicate");

  const reducedModuleReport = reduceModuleFieldsByDeletionWithReport(moduleFields, (candidate) => {
    return candidate.includes("func") && candidate.includes("export") && !candidate.includes("custom");
  });
  assert.deepEqual(reducedModuleReport.result, ["func", "export"], "module reducer report should carry reduced fields");
  assert.equal(reducedModuleReport.originalSize, 5, "module reducer report should count original fields");
  assert.equal(reducedModuleReport.finalSize, 2, "module reducer report should count final fields");
  assert.ok(reducedModuleReport.predicateEvaluations > 0, "module reducer report should count predicate evaluations");
  assert.ok(reducedModuleReport.steps.length > 0, "module reducer report should record deletion steps");
  assert.equal(
    reducedModuleReport.steps[0].kind,
    "delete-module-field-range",
    "module reducer report should label module-field deletions",
  );

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

  const reducedTextReport = reduceTextByTokenDeletionWithReport(
    "( module ( func $keep ) ( export \"x\" ) )",
    (candidate) => {
      return candidate.includes("func") && candidate.includes("export") && !candidate.includes("module");
    },
  );
  assert.equal(reducedTextReport.result, "func export", "text reducer report should carry reduced text");
  assert.equal(reducedTextReport.originalSize, 5, "text reducer report should count original tokens");
  assert.equal(reducedTextReport.finalSize, 2, "text reducer report should count final tokens");
  assert.ok(reducedTextReport.predicateEvaluations > 0, "text reducer report should count predicate evaluations");
  assert.ok(reducedTextReport.steps.length > 0, "text reducer report should record deletion steps");
  assert.equal(reducedTextReport.steps[0].kind, "delete-text-token-range", "text reducer report should label token deletions");

  const reducedLines = reduceTextByLineDeletion("header\nkeep func\nnoise\nkeep export\nfooter", (candidate) => {
    return candidate.includes("keep func") && candidate.includes("keep export") && !candidate.includes("noise");
  });
  assert.equal(reducedLines, "keep func\nkeep export", "line reducer should delete lines while preserving predicate");

  const reducedLinesReport = reduceTextByLineDeletionWithReport(
    "header\nkeep func\nnoise\nkeep export\nfooter",
    (candidate) => candidate.includes("keep func") && candidate.includes("keep export") && !candidate.includes("noise"),
  );
  assert.equal(reducedLinesReport.result, "keep func\nkeep export", "line reducer report should carry reduced text");
  assert.equal(reducedLinesReport.originalSize, 5, "line reducer report should count original lines");
  assert.equal(reducedLinesReport.finalSize, 2, "line reducer report should count final lines");
  assert.ok(reducedLinesReport.predicateEvaluations > 0, "line reducer report should count predicate evaluations");
  assert.ok(reducedLinesReport.steps.length > 0, "line reducer report should record deletion steps");
  assert.equal(reducedLinesReport.steps[0].kind, "delete-text-line-range", "line reducer report should label line deletions");

  const unchanged = reduceTextByTokenDeletion("alpha beta", () => false);
  assert.equal(unchanged, "alpha beta", "reducers must preserve original when no deletion preserves predicate");

  const unchangedLines = reduceTextByLineDeletion("alpha\nbeta", () => false);
  assert.equal(unchangedLines, "alpha\nbeta", "line reducer must preserve original when no deletion preserves predicate");

  const reductionLog = formatReductionReportLog({
    status: "mismatch",
    artifactPath: "reduced-input.wasm",
    originalSize: reducedBytesReport.originalSize,
    finalSize: reducedBytesReport.finalSize,
    predicateEvaluations: reducedBytesReport.predicateEvaluations,
    steps: reducedBytesReport.steps,
  });
  assert.match(reductionLog, /^status=mismatch\n/, "reduction log should preserve caller status context");
  assert.match(reductionLog, /\noriginal_size=8\n/, "reduction log should record original size");
  assert.match(reductionLog, /\nfinal_size=2\n/, "reduction log should record final size");
  assert.match(
    reductionLog,
    /\nreduced_artifact_path=reduced-input\.wasm\n/,
    "reduction log should record caller artifact path",
  );
  assert.match(reductionLog, /\nstep=delete-byte-slice\|start=/, "reduction log should record reduction steps");
  assert.ok(reductionLog.endsWith("\n"), "reduction log should end with a newline for stable artifact diffs");
}

if (import.meta.main) {
  runFuzzReducersTest();
}
