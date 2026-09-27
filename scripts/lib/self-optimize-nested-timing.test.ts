import { expect, test } from "bun:test";
import {
  parseStarshinePassElapsedMs,
  parseStarshinePerfTimingSummary,
} from "./self-optimize-compare-task";

test("nested cleanup contributes once to enclosing pass and pipeline wall time", () => {
  const trace = [
    "[trace] input fixture:opt pipeline:start requested=1",
    "[trace] input fixture:opt pass[dae2-optimizing]:start",
    "[trace] input fixture:opt pipeline:start requested=2",
    "[trace] input fixture:opt pass[simplify-locals]:start",
    "[trace] input fixture:opt perf:timer name=pass:simplify-locals elapsed_us=900 total_us=900",
    "[trace] input fixture:opt pass[simplify-locals]:done",
    "[trace] input fixture:opt pass[vacuum]:start",
    "[trace] input fixture:opt perf:timer name=pass:vacuum elapsed_us=100 total_us=100",
    "[trace] input fixture:opt pass[vacuum]:done",
    "[trace] input fixture:opt perf:timer name=pipeline elapsed_us=3000 total_us=3000",
    "[trace] input fixture:opt pipeline:done",
    "[trace] input fixture:opt perf:timer name=pass:dae2-optimizing elapsed_us=8200 total_us=8200",
    "[trace] input fixture:opt pass[dae2-optimizing]:done",
    "[trace] input fixture:opt perf:timer name=pipeline elapsed_us=8250 total_us=11250",
    "[trace] input fixture:opt pipeline:done",
  ].join("\n");
  expect(parseStarshinePassElapsedMs(trace)).toBe(8.2);
  const summary = parseStarshinePerfTimingSummary(trace);
  expect(summary.optimizerPipelineElapsedMs).toBe(8.25);
  expect(summary.optimizerPassElapsedMs).toBe(8.2);
});

test("serial pipelines and repeated function passes remain additive", () => {
  const trace = [1, 2].flatMap(() => [
    "pipeline:start requested=1",
    ...[1, 2].flatMap(() => [
      "pass[precompute]:start",
      "perf:timer name=pass:precompute elapsed_us=10 total_us=10",
      "pass[precompute]:done",
    ]),
    "perf:timer name=pipeline elapsed_us=25 total_us=25",
    "pipeline:done",
  ]).join("\n");
  const summary = parseStarshinePerfTimingSummary(trace);
  expect(summary.passElapsedMs).toBe(0.04);
  expect(summary.optimizerPipelineElapsedMs).toBe(0.05);
});

test("legacy traces without scope markers retain their timer sums", () => {
  const trace = [
    "perf:timer name=pass:precompute elapsed_us=12 total_us=12",
    "perf:timer name=pass:precompute elapsed_us=8 total_us=20",
    "perf:timer name=pipeline elapsed_us=30 total_us=30",
    "perf:timer name=pipeline elapsed_us=40 total_us=70",
  ].join("\n");
  const summary = parseStarshinePerfTimingSummary(trace);
  expect(summary.passElapsedMs).toBe(0.02);
  expect(summary.optimizerPipelineElapsedMs).toBe(0.07);
});

test("zero pass durations and raw-skip traces remain valid", () => {
  expect(parseStarshinePassElapsedMs([
    "pass[precompute]:start",
    "perf:timer name=pass:precompute elapsed_us=0 total_us=0",
    "pass[precompute]:done",
  ].join("\n"))).toBe(0);
  expect(parseStarshinePassElapsedMs("pass[precompute]:skip-raw")).toBe(0);
});

test("untimed wrappers preserve measured child work", () => {
  const trace = [
    "pass[wrapper]:start",
    "pass[precompute]:start",
    "perf:timer name=pass:precompute elapsed_us=12 total_us=12",
    "pass[precompute]:done",
    "pass[wrapper]:done",
  ].join("\n");
  expect(parseStarshinePassElapsedMs(trace)).toBe(0.012);
});

test("raw cleanup completion without a start does not close its caller", () => {
  const trace = [
    "pass[dae2-optimizing]:start",
    "pass[simplify-locals]:done",
    "pass[vacuum]:start",
    "perf:timer name=pass:vacuum elapsed_us=40 total_us=40",
    "pass[vacuum]:done",
    "perf:timer name=pass:dae2-optimizing elapsed_us=8000 total_us=8000",
    "pass[dae2-optimizing]:done",
  ].join("\n");
  expect(parseStarshinePassElapsedMs(trace)).toBe(8);
});
